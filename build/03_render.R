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

  html <- render_page_html(tpl_page, th, footer, nrow(m), fetched_date,
                           BOUNDARY_SOURCE, theme_definition_text(th))
  writeLines(html, file.path("out", th$id, "index.html"), useBytes = TRUE)

  rng <- range(vals$value, na.rm = TRUE)
  summary_line <- sprintf("最小 %.1f 〜 最大 %.1f %s(%s 市区町村)",
                          rng[1], rng[2], th$unit,
                          format(sum(!is.na(vals$value)), big.mark = ","))
  cards <- c(cards, render_card_html(th, summary_line))
}

writeLines(render_index_html(tpl_index, paste(cards, collapse = "\n"), footer),
           "out/index.html", useBytes = TRUE)
message("done → out/")
