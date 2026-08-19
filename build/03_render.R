# data/processed/ からテーマ別ページ(SVG 3 点 + HTML)と index を out/ に生成する。
# 契約: SPEC §2.2(F-08〜F-12)。ロジックは R/(純関数)、IO は本スクリプトのみ。

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})
source("R/themes.R")
source("R/metrics.R")
source("R/plot_map.R")
source("R/render_page.R")
source("R/footer.R")

BOUNDARY_SOURCE <- "国土数値情報 行政区域データ 2021 年版(国土交通省)"
MAP_CAPTION <- "地図は東経 122〜149 度の範囲(南鳥島・沖ノ鳥島は表示範囲外、統計には含む)"
fetched_date <- trimws(readLines("data/FETCHED_DATE.txt", n = 1))

message("read: municipalities.gpkg")
m <- st_read("data/processed/municipalities.gpkg", quiet = TRUE)

message("simplify for rendering")
# 描画専用の平面簡略化(GEOS・度単位)。s2 有効のままだと許容値がメートル解釈になり
# GEOMETRYCOLLECTION 化もするため、明示的に無効化して行う(loop_003 実験:
# tol=0.005 deg で 1,450 万 → 約 6 万頂点・空幾何 0)。精度が要る面積照合は gpkg 側(G-03)。
old_s2 <- sf_use_s2()
suppressMessages(sf_use_s2(FALSE))
g <- suppressWarnings(st_simplify(st_geometry(m), dTolerance = 0.005))
suppressMessages(sf_use_s2(old_s2))
empty <- st_is_empty(g)
g[empty] <- st_geometry(m)[empty]  # 潰れた小島は原形を残す(値の欠落防止)
st_geometry(m) <- g

tpl_page <- paste(readLines("site/template_page.html", encoding = "UTF-8"), collapse = "\n")
tpl_index <- paste(readLines("site/template_index.html", encoding = "UTF-8"), collapse = "\n")
footer <- footer_html()

dir.create("out", showWarnings = FALSE)
file.copy("site/style.css", "out/style.css", overwrite = TRUE)

cards <- character(0)
for (th in THEMES) {
  message("render: ", th$id)
  vals <- compute_theme_values(st_drop_geometry(m), th)
  spec <- scale_spec(th$scale, vals$value)
  map_sf <- m["code"]
  map_sf$value <- vals$value[match(map_sf$code, vals$code)]

  dir.create(file.path("out", th$id), showWarnings = FALSE)
  save_map_svg(plot_map(map_sf, th, spec,
                        xlim = c(122, 149), ylim = c(24, 46),
                        caption = MAP_CAPTION),
               file.path("out", th$id, "map.svg"), width = 8, height = 8.5)
  save_map_svg(plot_ranking(ranking_data(vals), th, spec),
               file.path("out", th$id, "ranking.svg"), width = 6.5, height = 9)
  save_map_svg(plot_hist(vals, th, spec),
               file.path("out", th$id, "hist.svg"), width = 6.5, height = 4)

  html <- render_page_html(
    tpl_page, th, footer,
    unit_label = paste0("市区町村(政令指定都市は区単位)、",
                        format(nrow(m), big.mark = ","), " 地域"),
    fetched_date = fetched_date,
    boundary_source = BOUNDARY_SOURCE,
    definition = theme_definition_text(th))
  writeLines(html, file.path("out", th$id, "index.html"), useBytes = TRUE)

  rng <- range(vals$value, na.rm = TRUE)
  summary_line <- sprintf("最小 %.1f 〜 最大 %.1f %s(%s 市区町村)",
                          rng[1], rng[2], th$unit,
                          format(sum(!is.na(vals$value)), big.mark = ","))
  cards <- c(cards, render_card_html(th, summary_line))
}

# ---- F-06 人口カルトグラム(ドーリング・都道府県単位) ----
message("render: cartogram")
source("R/cartogram_page.R")
ref <- read_csv("data/processed/prefectures_reference.csv",
                col_types = cols(.default = "c")) |>
  filter(level == "pref") |>
  transmute(pref_code, name, pop = as.numeric(pop_total))

old_s2 <- sf_use_s2(); suppressMessages(sf_use_s2(FALSE))
pref_geom <- m |> group_by(pref_code) |> summarise(.groups = "drop")
suppressMessages(sf_use_s2(old_s2))
ctr <- st_coordinates(st_centroid(st_transform(st_geometry(pref_geom), AEA_JP)))
pref_df <- pref_geom |> st_drop_geometry() |>
  mutate(x = ctr[, 1], y = ctr[, 2]) |>
  inner_join(ref, by = "pref_code")
stopifnot(nrow(pref_df) == 47)

circles <- dorling_circles(pref_df)
carto_def <- list(id = "cartogram", title = "人口カルトグラム",
                  unit = "万人",
                  source = "国勢調査 2020(e-Stat)公表の都道府県人口")
vals_pref <- tibble(code = pref_df$pref_code, name = pref_df$name,
                    value = pref_df$pop / 1e4)
spec_pref <- scale_spec("seq", vals_pref$value)

dir.create("out/cartogram", showWarnings = FALSE)
save_map_svg(plot_cartogram(circles), "out/cartogram/map.svg",
             width = 8, height = 8.5)
save_map_svg(plot_ranking(ranking_data(vals_pref), carto_def, spec_pref),
             "out/cartogram/ranking.svg", width = 6.5, height = 9)
save_map_svg(plot_hist(vals_pref, carto_def, spec_pref, bins = 24),
             "out/cartogram/hist.svg", width = 6.5, height = 4)

carto_html <- render_page_html(
  tpl_page, carto_def, footer,
  unit_label = "都道府県、47 地域",
  fetched_date = fetched_date,
  boundary_source = paste0(BOUNDARY_SOURCE, "(円の配置座標に使用)"),
  definition = "円の面積 ∝ 2020 年総人口(ドーリング・カルトグラム。円面積の比 = 人口比が厳密)")
writeLines(carto_html, "out/cartogram/index.html", useBytes = TRUE)
cards <- c(cards, render_card_html(
  list(id = "cartogram", title = "人口カルトグラム"),
  "円の面積 = 都道府県人口。ドーリング式(面積比例が厳密)"))

# ---- F-07 都道府県間人口移動フローマップ ----
message("render: flow")
source("R/flow_page.R")
library(readxl)
flow_raw <- suppressMessages(
  read_excel("data/raw/flow_jumin2020_od.xlsx", sheet = 1, col_names = FALSE))
od <- parse_od(flow_raw)
net <- net_migration(od) |>
  left_join(ref |> select(pref_code, name), by = "pref_code")
# pref_geom は planar combine 由来で退化エッジを含みうる — s2 を切って重心を取る(HC-002)
old_s2 <- sf_use_s2(); suppressMessages(sf_use_s2(FALSE))
ctr_ll <- suppressWarnings(st_coordinates(st_centroid(st_geometry(pref_geom))))
suppressMessages(sf_use_s2(old_s2))
ctr_df <- tibble(pref_code = pref_geom$pref_code,
                 x = ctr_ll[, 1], y = ctr_ll[, 2])

flow_def <- list(id = "flow", title = "都道府県間人口移動",
                 unit = "人",
                 source = "住民基本台帳人口移動報告 2020 年 表2(総務省統計局)")
vals_net <- tibble(code = net$pref_code, name = net$name, value = net$net)
spec_net <- scale_spec("div", vals_net$value)

dir.create("out/flow", showWarnings = FALSE)
save_map_svg(plot_flow_map(pref_geom, net, flows_top(od, 30), ctr_df,
                           xlim = c(127, 146), ylim = c(26, 46),
                           caption = "曲線 = 移動者数上位 30 フロー(矢印は移動方向)。塗り = 転入超過数。"),
             "out/flow/map.svg", width = 8, height = 8.5)
save_map_svg(plot_ranking(ranking_data(vals_net), flow_def, spec_net),
             "out/flow/ranking.svg", width = 6.5, height = 9)
save_map_svg(plot_hist(vals_net, flow_def, spec_net, bins = 24),
             "out/flow/hist.svg", width = 6.5, height = 4)

flow_html <- render_page_html(
  tpl_page, flow_def, footer,
  unit_label = "都道府県、47 地域(2020 年の都道府県間移動 2,463,992 人)",
  fetched_date = fetched_date,
  boundary_source = paste0(BOUNDARY_SOURCE, "(塗り分けと重心座標に使用)"),
  definition = "転入超過数 = 他都道府県からの転入者数 − 他都道府県への転出者数(日本人・外国人を含む移動者)")
writeLines(flow_html, "out/flow/index.html", useBytes = TRUE)
cards <- c(cards, render_card_html(
  list(id = "flow", title = "都道府県間人口移動"),
  "移動者数上位 30 フローの曲線束 + 転入超過の塗り分け(2020 年)"))

writeLines(render_index_html(tpl_index, paste(cards, collapse = "\n"), footer),
           "out/index.html", useBytes = TRUE)
message("done → out/")
