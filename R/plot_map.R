# 主題図の ggplot 構築と SVG 書き出し(loop_003)。
# plot_* は純関数(ggplot オブジェクトを返すのみ)、save_map_svg だけがファイル IO。

suppressPackageStartupMessages({
  library(ggplot2)
  library(sf)
})

MAP_THEME <- theme_void(base_family = "sans") +
  theme(
    plot.background = element_rect(fill = "#ffffff", colour = NA),
    legend.position = "inside",
    legend.position.inside = c(0.85, 0.28),
    legend.title = element_text(size = 9),
    legend.text = element_text(size = 8),
    plot.title = element_text(size = 13, face = "bold", hjust = 0.02),
    plot.caption = element_text(size = 7, colour = "#666666")
  )

# sf(value 列を持つ)+ テーマ + scale_spec → ggplot オブジェクト。
plot_map <- function(map_sf, theme_def, spec,
                     xlim = NULL, ylim = NULL, caption = NULL) {
  p <- ggplot(map_sf) +
    geom_sf(aes(fill = value), colour = "#ffffff", linewidth = 0.04) +
    MAP_THEME +
    labs(title = theme_def$title,
         fill = paste0(theme_def$title, "\n(", theme_def$unit, ")"),
         caption = caption)
  p <- p + if (spec$type == "div") {
    scale_fill_gradient2(low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
                         midpoint = spec$midpoint, limits = spec$limits,
                         na.value = "#d9d9d9")
  } else {
    scale_fill_viridis_c(limits = spec$limits, na.value = "#d9d9d9")
  }
  if (!is.null(xlim)) {
    p <- p + coord_sf(xlim = xlim, ylim = ylim, expand = FALSE)
  }
  p
}

# 横棒: 上位/下位 10。fill は地図と同じ scale_spec から着色する。
plot_ranking <- function(rank, theme_def, spec) {
  d <- rbind(transform(rank$top, group = "上位 10"),
             transform(rank$bottom, group = "下位 10"))
  d$group <- factor(d$group, levels = c("上位 10", "下位 10"))
  # 表示順: 各群の中で値の降順
  d <- d[order(d$group, -d$value, d$code), ]
  d$label <- factor(paste0(d$name, " (", d$code, ")"),
                    levels = rev(paste0(d$name, " (", d$code, ")")))
  rel <- (d$value - spec$limits[1]) / diff(spec$limits)
  d$fill <- spec$palette(pmin(1, pmax(0, rel)))
  ggplot(d, aes(x = value, y = label)) +
    geom_col(aes(fill = fill), show.legend = FALSE) +
    scale_fill_identity() +
    facet_wrap(~group, ncol = 1, scales = "free_y") +
    labs(x = theme_def$unit, y = NULL) +
    theme_minimal(base_family = "sans", base_size = 10) +
    theme(plot.background = element_rect(fill = "#ffffff", colour = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank())
}

# ヒストグラム(全市区町村の分布)。
plot_hist <- function(values, theme_def, spec, bins = 60) {
  v <- values[!is.na(values$value), ]
  ggplot(v, aes(x = value)) +
    geom_histogram(bins = bins, fill = "#5c88c5", colour = NA) +
    labs(x = paste0(theme_def$title, "(", theme_def$unit, ")"), y = "市区町村数") +
    theme_minimal(base_family = "sans", base_size = 10) +
    theme(plot.background = element_rect(fill = "#ffffff", colour = NA),
          panel.grid.minor = element_blank())
}

# SVG 書き出し(svglite・決定論)。width/height はインチ。
save_map_svg <- function(p, path, width, height) {
  ggsave(path, p, device = svglite::svglite, width = width, height = height,
         bg = "#ffffff")
  invisible(path)
}
