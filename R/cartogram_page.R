# F-06 人口カルトグラム(ドーリング)の純関数(loop_006)。
# 方式の根拠: 連続式は itermax=60 でも東京の面積シェアが目標比 -50%(stage 2 実験)。
# ドーリングは半径 ∝ √人口 が構成上厳密 → 円面積シェア = 人口シェア(オラクル T-030)。

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(ggplot2)
})

# 全国を覆う等積投影(Albers)。カルトグラムページ専用。
AEA_JP <- "+proj=aea +lat_1=30 +lat_2=42 +lat_0=36 +lon_0=138 +datum=WGS84 +units=m"

# df(pref_code, name, pop, x, y[m, AEA])→ ドーリング円の sf。
# cartogram_dorling は乱数を使わず決定論(T-031)。
dorling_circles <- function(df, k = 4) {
  pts <- st_as_sf(df, coords = c("x", "y"), crs = AEA_JP)
  cartogram::cartogram_dorling(pts, "pop", k = k)
}

# カルトグラムの ggplot。fill は人口(viridis)、上位県に県名ラベル。
plot_cartogram <- function(circles, label_top = 15) {
  circles$pop_man <- circles$pop / 1e4
  ctr <- st_coordinates(st_centroid(st_geometry(circles)))
  lab <- cbind(st_drop_geometry(circles), X = ctr[, 1], Y = ctr[, 2]) |>
    arrange(desc(pop)) |>
    head(label_top)
  ggplot(circles) +
    geom_sf(aes(fill = pop_man), colour = "#ffffff", linewidth = 0.3) +
    geom_text(data = lab, aes(X, Y, label = name),
              size = 2.6, colour = "#ffffff", fontface = "bold") +
    scale_fill_viridis_c(name = "総人口(万人)") +
    labs(title = "人口カルトグラム(ドーリング)",
         caption = "円の面積は 2020 年総人口に比例。配置は都道府県の位置関係を近似。") +
    theme_void(base_family = "sans") +
    theme(plot.background = element_rect(fill = "#ffffff", colour = NA),
          legend.position = "inside", legend.position.inside = c(0.88, 0.25),
          legend.title = element_text(size = 9),
          legend.text = element_text(size = 8),
          plot.title = element_text(size = 13, face = "bold", hjust = 0.02),
          plot.caption = element_text(size = 7, colour = "#666666"))
}
