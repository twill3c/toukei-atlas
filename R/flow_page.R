# F-07 都道府県間人口移動フローマップの純関数(loop_007)。
# 入力: 住民基本台帳人口移動報告 表2(移動前住所地 × 現住所地)の生データフレーム
# (read_excel col_names=FALSE)。構造の根拠は stage 2 検分(test-flow.R 冒頭に記載)。

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(sf)
})

# 生シートから 47×46 のフロー(origin, dest, n)を取り出す。
# 行 = 国籍コード 60000(移動者)かつ移動前住所地コードが 5 桁(00000 総数を除く)。
# 列 = 5 行目が都道府県名・6 行目が「総数」の列。対角は「-」(自県は非該当)。
# origin 行には 21 大都市(例 34100 広島市)・3大都市圏・不詳(80000)も混在する。
# 都道府県コード(01000〜47000)だけを取る。47 行の全国列合計 = 総数を検分済み。
PREF_CODE_RE <- "^(0[1-9]|[1-3][0-9]|4[0-7])000$"

parse_od <- function(raw) {
  origin_rows <- which(raw[[2]] == "60000" & grepl(PREF_CODE_RE, raw[[6]]))
  stopifnot(length(origin_rows) == 47)
  name2code <- setNames(substr(unlist(raw[origin_rows, 6]), 1, 2),
                        unlist(raw[origin_rows, 7]))
  dest_name <- unlist(raw[5, ])
  sex <- unlist(raw[6, ])
  dest_cols <- which(!is.na(dest_name) & dest_name %in% names(name2code) &
                     !is.na(sex) & sex == "総数")
  stopifnot(length(dest_cols) == 47)

  grid <- expand.grid(i = seq_along(origin_rows), j = seq_along(dest_cols))
  od <- tibble(
    origin = substr(unlist(raw[origin_rows, 6])[grid$i], 1, 2),
    dest   = unname(name2code[dest_name[dest_cols][grid$j]]),
    cell   = mapply(function(i, j) unlist(raw[origin_rows[i], dest_cols[j]]),
                    grid$i, grid$j)
  )
  diag_ok <- all(od$cell[od$origin == od$dest] == "-")
  if (!diag_ok) stop("対角セルが「-」でない — 表構造が想定と異なる")
  od <- od[od$origin != od$dest, ]
  od$n <- as.numeric(od$cell)
  if (any(is.na(od$n))) stop("非対角セルに数値でない値がある")
  od$cell <- NULL
  as_tibble(od)
}

# 周辺和(表自身が持つ転出計=全国列・転入計=総数行)を取り出す。
parse_od_marginals <- function(raw) {
  origin_rows <- which(raw[[2]] == "60000" & grepl(PREF_CODE_RE, raw[[6]]))
  total_row <- which(raw[[2]] == "60000" & raw[[6]] == "00000")[1]
  dest_name <- unlist(raw[5, ]); sex <- unlist(raw[6, ])
  name2code <- setNames(substr(unlist(raw[origin_rows, 6]), 1, 2),
                        unlist(raw[origin_rows, 7]))
  dest_cols <- which(!is.na(dest_name) & dest_name %in% names(name2code) &
                     !is.na(sex) & sex == "総数")
  zenkoku_col <- which(!is.na(dest_name) & dest_name == "全国" &
                       !is.na(sex) & sex == "総数")[1]
  tibble(
    pref_code = substr(unlist(raw[origin_rows, 6]), 1, 2),
    out_total = as.numeric(unlist(raw[origin_rows, zenkoku_col])),
    in_total  = as.numeric(unlist(raw[total_row, dest_cols]))[
      match(substr(unlist(raw[origin_rows, 6]), 1, 2),
            unname(name2code[dest_name[dest_cols]]))]
  )
}

# 転入超過(net = 転入 − 転出)。国内移動なので全国合計は恒等的に 0。
net_migration <- function(od) {
  inn <- od |> group_by(pref_code = dest) |> summarise(in_n = sum(n), .groups = "drop")
  out <- od |> group_by(pref_code = origin) |> summarise(out_n = sum(n), .groups = "drop")
  inner_join(inn, out, by = "pref_code") |> mutate(net = in_n - out_n)
}

# 上位 n フロー。同数は origin, dest コード順で安定。
flows_top <- function(od, n = 30) {
  od[order(-od$n, od$origin, od$dest), ][seq_len(min(n, nrow(od))), ]
}

# フローマップ: 純移動コロプレス + 上位フローの曲線束。
# pref_sf: pref_code + geometry、net_df: net_migration の出力、
# ctr: pref_code, x, y(経緯度)の重心表。
plot_flow_map <- function(pref_sf, net_df, flows, ctr, xlim, ylim, caption = NULL) {
  m <- left_join(pref_sf, net_df, by = "pref_code")
  seg <- flows |>
    left_join(ctr, by = c("origin" = "pref_code")) |>
    rename(x0 = x, y0 = y) |>
    left_join(ctr, by = c("dest" = "pref_code")) |>
    rename(x1 = x, y1 = y)
  lim <- max(abs(range(net_df$net)))
  ggplot(m) +
    geom_sf(aes(fill = net), colour = "#ffffff", linewidth = 0.15) +
    scale_fill_gradient2(low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
                         midpoint = 0, limits = c(-lim, lim),
                         name = "転入超過(人)") +
    geom_curve(data = seg,
               aes(x = x0, y = y0, xend = x1, yend = y1, linewidth = n),
               curvature = 0.25, alpha = 0.45, colour = "#1a1d21",
               arrow = arrow(length = unit(4, "pt"), type = "closed")) +
    scale_linewidth_continuous(range = c(0.2, 2.2), name = "移動者数(人)") +
    coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
    labs(title = "都道府県間人口移動(2020 年)", caption = caption) +
    theme_void(base_family = "sans") +
    theme(plot.background = element_rect(fill = "#ffffff", colour = NA),
          legend.position = "inside", legend.position.inside = c(0.87, 0.3),
          legend.title = element_text(size = 8),
          legend.text = element_text(size = 7),
          plot.title = element_text(size = 13, face = "bold", hjust = 0.02),
          plot.caption = element_text(size = 7, colour = "#666666"))
}
