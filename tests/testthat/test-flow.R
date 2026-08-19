# F-07 都道府県間人口移動フローマップのオラクル(loop_007)。
# データの根拠(stage 2 検分): 表2 OD、対角=「-」(自県は非該当)、
# 国籍コード 60000 = 移動者(総数)、行=移動前住所地・列=現住所地。
# 総数 2,463,992 人は統計局公表の 2020 年都道府県間移動者数と一致(取得 2026-08-19)。
suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
})
source("../../R/flow_page.R", chdir = TRUE)

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
out_dir <- file.path(root, "out")
xlsx <- file.path(root, "data", "raw", "flow_jumin2020_od.xlsx")

od_cache <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      raw <- suppressMessages(read_excel(xlsx, sheet = 1, col_names = FALSE))
      cache <<- parse_od(raw)
    }
    cache
  }
})

test_that("OD 行列: 47×47−対角 = 2,162 セル・全国総数 2,463,992 に一致", {
  skip_if_not(file.exists(xlsx))
  od <- od_cache()
  expect_equal(nrow(od), 47 * 46)
  expect_false(any(od$origin == od$dest))
  expect_equal(sum(od$n), 2463992)
})

test_that("OD 周辺和: 行和 = 表の全国列(転出計)・列和 = 表の総数行(転入計)", {
  skip_if_not(file.exists(xlsx))
  raw <- suppressMessages(read_excel(xlsx, sheet = 1, col_names = FALSE))
  od <- od_cache()
  marg <- parse_od_marginals(raw)
  out_sum <- od |> group_by(origin) |> summarise(n = sum(n), .groups = "drop") |>
    arrange(origin)
  in_sum <- od |> group_by(dest) |> summarise(n = sum(n), .groups = "drop") |>
    arrange(dest)
  expect_equal(out_sum$n, marg$out_total[order(marg$pref_code)])
  expect_equal(in_sum$n, marg$in_total[order(marg$pref_code)])
})

test_that("転入超過: 全国合計は 0(国内移動の保存則)", {
  skip_if_not(file.exists(xlsx))
  net <- net_migration(od_cache())
  expect_equal(nrow(net), 47)
  expect_equal(sum(net$net), 0)
})

test_that("上位フロー抽出: 降順・同数はコード順で安定", {
  od <- tibble(
    origin = c("01", "02", "03", "04", "05"),
    dest   = c("13", "13", "13", "13", "13"),
    n      = c(100, 300, 100, 500, 300)
  )
  top <- flows_top(od, 3)
  expect_equal(top$n, c(500, 300, 300))
  expect_equal(top$origin, c("04", "02", "05"))
})

test_that("out/flow に定型ページ一式がある(F-07/F-08)", {
  d <- file.path(out_dir, "flow")
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
  expect_match(html, "住民基本台帳", fixed = TRUE)
})

test_that("index にフローマップカードがある(F-09)", {
  idx <- file.path(out_dir, "index.html")
  skip_if_not(file.exists(idx))
  html <- paste(readLines(idx, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(html, "flow/", fixed = TRUE)
})
