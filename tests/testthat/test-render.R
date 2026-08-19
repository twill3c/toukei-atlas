# レンダリングのテスト(T-010, T-011, T-016, T-018 系, T-019, T-021, F-09/F-11)。
# 統合部分は Rscript build/03_render.R 実行後の out/ を検査する。
suppressPackageStartupMessages({library(sf); library(digest)})
source("../../R/themes.R", chdir = TRUE)
source("../../R/metrics.R", chdir = TRUE)
source("../../R/plot_map.R", chdir = TRUE)

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
out_dir <- file.path(root, "out")

# 3 地域のミニ地図フィクスチャ(決定論テスト用の固定入力)
mini_sf <- local({
  sq <- function(x0, y0) st_polygon(list(cbind(c(x0, x0 + 1, x0 + 1, x0, x0),
                                               c(y0, y0, y0 + 1, y0 + 1, y0))))
  st_sf(code = c("00001", "00002", "00003"),
        name = c("甲", "乙", "丙"),
        value = c(10, 25, 40),
        geometry = st_sfc(sq(0, 0), sq(1, 0), sq(0, 1), crs = 6668))
})

test_that("G-04: 同一入力の 2 回レンダリングでバイト一致(T-010)", {
  th <- THEMES[[1]]
  spec <- scale_spec(th$scale, mini_sf$value)
  f1 <- tempfile(fileext = ".svg"); f2 <- tempfile(fileext = ".svg")
  save_map_svg(plot_map(mini_sf, th, spec), f1, width = 4, height = 4)
  save_map_svg(plot_map(mini_sf, th, spec), f2, width = 4, height = 4)
  expect_equal(digest(file = f1, algo = "sha256"), digest(file = f2, algo = "sha256"))
})

test_that("G-04: ミニ地図の回帰フィクスチャとハッシュ一致(T-011)", {
  fixture <- file.path(testthat::test_path(), "fixtures", "mini_map.svg")
  expect_true(file.exists(fixture), info = "フィクスチャ未生成(build/make_fixture.R)")
  skip_if_not(file.exists(fixture))
  th <- THEMES[[1]]
  spec <- scale_spec(th$scale, mini_sf$value)
  f <- tempfile(fileext = ".svg")
  save_map_svg(plot_map(mini_sf, th, spec), f, width = 4, height = 4)
  expect_equal(digest(file = f, algo = "sha256"),
               digest(file = fixture, algo = "sha256"))
})

# ---- 以下は out/ の統合検査(03_render 実行後) ----

theme_ids <- vapply(THEMES, function(t) t$id, "")

test_that("out/ に全テーマページ + index が存在(F-08/F-09)", {
  expect_true(dir.exists(out_dir), info = "out/ がない(03_render 未実行)")
  skip_if_not(dir.exists(out_dir))
  for (id in theme_ids) {
    expect_true(file.exists(file.path(out_dir, id, "index.html")), info = id)
    for (svg in c("map.svg", "ranking.svg", "hist.svg")) {
      expect_true(file.exists(file.path(out_dir, id, svg)), info = paste(id, svg))
    }
  }
  expect_true(file.exists(file.path(out_dir, "index.html")))
  expect_true(file.exists(file.path(out_dir, "style.css")))
})

test_that("各テーマページに定型 4 ブロック + フッタがあり、JS を含まない(T-016/F-10/F-11)", {
  skip_if_not(dir.exists(out_dir))
  for (id in theme_ids) {
    html <- paste(readLines(file.path(out_dir, id, "index.html"),
                            encoding = "UTF-8", warn = FALSE), collapse = "\n")
    for (cls in c("block-map", "block-ranking", "block-hist", "block-notes",
                  "site-footer")) {
      expect_match(html, cls, fixed = TRUE, info = paste(id, cls))
    }
    expect_false(grepl("<script", html, fixed = TRUE), info = id)
    expect_match(html, "© 2026 坂田哲朗", fixed = TRUE)
  }
})

test_that("注記ブロックに出典・定義・取得日がある(T-019/F-12)", {
  skip_if_not(dir.exists(out_dir))
  for (id in theme_ids) {
    html <- paste(readLines(file.path(out_dir, id, "index.html"),
                            encoding = "UTF-8", warn = FALSE), collapse = "\n")
    for (key in c("出典", "指標の定義", "データ取得日", "国勢調査")) {
      expect_match(html, key, fixed = TRUE, info = paste(id, key))
    }
  }
})

test_that("ページ転送量: HTML + SVG 合計 2MB 以下(T-021/N-04)", {
  skip_if_not(dir.exists(out_dir))
  for (id in theme_ids) {
    files <- list.files(file.path(out_dir, id), full.names = TRUE)
    total <- sum(file.size(files))
    expect_lt(total, 2 * 1024^2)
  }
})
