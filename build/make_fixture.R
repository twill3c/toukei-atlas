# G-04 回帰フィクスチャ(tests/testthat/fixtures/mini_map.svg)の生成。
# 実行はフィクスチャ更新時のみ(test: update fixtures 専用コミット + 理由記録)。
suppressPackageStartupMessages(library(sf))
source("R/themes.R")
source("R/metrics.R")
source("R/plot_map.R")

sq <- function(x0, y0) st_polygon(list(cbind(c(x0, x0 + 1, x0 + 1, x0, x0),
                                             c(y0, y0, y0 + 1, y0 + 1, y0))))
mini <- st_sf(code = c("00001", "00002", "00003"),
              name = c("甲", "乙", "丙"),
              value = c(10, 25, 40),
              geometry = st_sfc(sq(0, 0), sq(1, 0), sq(0, 1), crs = 6668))

dir.create("tests/testthat/fixtures", recursive = TRUE, showWarnings = FALSE)
th <- THEMES[[1]]
spec <- scale_spec(th$scale, mini$value)
save_map_svg(plot_map(mini, th, spec), "tests/testthat/fixtures/mini_map.svg",
             width = 4, height = 4)
message("fixture written")
