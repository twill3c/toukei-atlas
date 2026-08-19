# F-06 人口カルトグラム(ドーリング)のテスト(loop_006)。
# 方式の根拠: 連続カルトグラムは itermax=60 でも東京の面積シェアが目標比 -50%
# (loop_006 stage 2 実験)。ドーリングは円面積 ∝ 人口が構成上厳密。
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(digest)
})
source("../../R/cartogram_page.R", chdir = TRUE)

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
out_dir <- file.path(root, "out")

# 4 県分の固定入力(重心座標と人口)
mini_pref <- tibble(
  pref_code = c("01", "02", "03", "04"),
  name = c("甲", "乙", "丙", "丁"),
  pop = c(100, 400, 900, 1600),
  x = c(0, 100000, 0, 100000),
  y = c(0, 0, 100000, 100000)
)

test_that("ドーリング円の面積シェア = 人口シェア(厳密、T-030)", {
  cg <- dorling_circles(mini_pref)
  expect_equal(nrow(cg), 4)
  a <- as.numeric(st_area(cg))
  expect_equal(a / sum(a), mini_pref$pop / sum(mini_pref$pop), tolerance = 1e-6)
})

test_that("ドーリングの決定論: 同一入力 2 回で幾何一致(T-031/G-04)", {
  g1 <- st_as_binary(st_geometry(dorling_circles(mini_pref)))
  g2 <- st_as_binary(st_geometry(dorling_circles(mini_pref)))
  expect_identical(g1, g2)
})

test_that("円同士が重ならない: 中心間距離 ≥ 半径和(T-032)", {
  cg <- dorling_circles(mini_pref)
  ctr <- st_coordinates(st_centroid(st_geometry(cg)))
  r <- sqrt(as.numeric(st_area(cg)) / pi)
  for (i in 1:(nrow(cg) - 1)) {
    for (j in (i + 1):nrow(cg)) {
      d <- sqrt(sum((ctr[i, ] - ctr[j, ])^2))
      expect_gte(d, (r[i] + r[j]) * (1 - 1e-3))
    }
  }
})

test_that("out/cartogram に定型ページ一式がある(F-06/F-08)", {
  d <- file.path(out_dir, "cartogram")
  expect_true(file.exists(file.path(d, "index.html")), info = "03_render 未実行")
  skip_if_not(file.exists(file.path(d, "index.html")))
  for (svg in c("map.svg", "ranking.svg", "hist.svg")) {
    expect_true(file.exists(file.path(d, svg)), info = svg)
  }
  html <- paste(readLines(file.path(d, "index.html"), encoding = "UTF-8",
                          warn = FALSE), collapse = "\n")
  for (cls in c("block-map", "block-ranking", "block-hist", "block-notes", "site-footer")) {
    expect_match(html, cls, fixed = TRUE)
  }
  expect_false(grepl("<script", html, fixed = TRUE))
  expect_match(html, "ドーリング", fixed = TRUE)
  # 公表都道府県人口に基づく(円は published 値から作る)
  expect_match(html, "国勢調査", fixed = TRUE)
})

test_that("index にカルトグラムカードがある(F-09)", {
  idx <- file.path(out_dir, "index.html")
  skip_if_not(file.exists(idx))
  html <- paste(readLines(idx, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(html, "cartogram/", fixed = TRUE)
})
