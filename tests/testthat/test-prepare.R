# G-01/G-02/G-03(T-001〜T-009, T-015): 結合済みデータの公表値オラクル。
# 前提: Rscript build/02_prepare.R 実行済み(data/processed/ が存在)。
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
gpkg <- file.path(root, "data", "processed", "municipalities.gpkg")
ref_csv <- file.path(root, "data", "processed", "prefectures_reference.csv")

skip_if_no_processed <- function() {
  # ビルド前は「失敗」として明示する(skip だと G-01 未検証のまま green に見える)
  expect_true(file.exists(gpkg), info = "data/processed/municipalities.gpkg がない(02_prepare 未実行)")
  expect_true(file.exists(ref_csv), info = "prefectures_reference.csv がない(02_prepare 未実行)")
  if (!file.exists(gpkg) || !file.exists(ref_csv)) skip("processed 不在")
}

load_muni <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- st_read(gpkg, quiet = TRUE)
    cache
  }
})

test_that("結合完全性: 1,896 地域・コード一意・政令市は区単位(T-004/T-005/T-006)", {
  skip_if_no_processed()
  m <- load_muni()
  expect_equal(nrow(m), 1896)
  expect_false(any(duplicated(m$code)))
  expect_true(all(grepl("^[0-9]{5}$", m$code)))
  # 政令市の「市」行と特別区部は存在しない。区は存在する
  expect_false(any(c("01100", "13100", "14100", "27100") %in% m$code))
  expect_true(all(c("01101", "13101", "14101", "27102") %in% m$code))
})

test_that("G-01: 市区町村人口の都道府県合算が公表値と一致(T-001)", {
  skip_if_no_processed()
  m <- st_drop_geometry(load_muni())
  ref <- read_csv(ref_csv, col_types = cols(.default = "c")) |>
    mutate(across(c(pop_total, pop_2015, area_ref), as.numeric))
  agg <- m |> group_by(pref_code) |> summarise(pop = sum(pop_total), .groups = "drop")
  j <- inner_join(agg, ref |> filter(level == "pref"), by = "pref_code")
  expect_equal(nrow(j), 47)
  expect_equal(j$pop, j$pop_total)   # 誤差 0
})

test_that("G-01: 全国人口 126,146,099 人(T-002)", {
  skip_if_no_processed()
  m <- st_drop_geometry(load_muni())
  # 出典: 令和2年国勢調査 人口等基本集計(2021-11-30 公表、取得 2026-08-19)
  expect_equal(sum(m$pop_total), 126146099)
})

test_that("G-01: 高齢化率の自前計算が公表構成比と ±0.1pt 以内(T-003)", {
  skip_if_no_processed()
  m <- st_drop_geometry(load_muni())
  ok <- !is.na(m$rate_65over_pub) & !is.na(m$pop_65over) & m$pop_total > 0
  expect_gt(sum(ok), 1800)
  own <- 100 * m$pop_65over[ok] / m$pop_total[ok]
  expect_lt(max(abs(own - m$rate_65over_pub[ok])), 0.1)
})

test_that("G-03: 幾何の妥当性と CRS(T-007/T-008)", {
  skip_if_no_processed()
  m <- load_muni()
  expect_true(all(st_is_valid(m)))
  expect_equal(st_crs(m)$epsg, 6668L)
})

test_that("G-03: 幾何面積の都道府県合算が面積調(採録単位の合算)と誤差 1% 以内(T-009)", {
  skip_if_no_processed()
  m <- load_muni()
  # 照合基準は「採録した 1,896 地域の面積調値の合算」。都道府県公表値との直接比較は
  # 北方領土(約 5,003 km²、集計対象外)を含むため不可(loop_002 で判明)
  a <- m |>
    mutate(area_geom = as.numeric(st_area(st_geometry(m))) / 1e6) |>
    st_drop_geometry() |>
    group_by(pref_code) |>
    summarise(area_geom = sum(area_geom),
              area_ref = sum(area_km2), .groups = "drop")
  expect_equal(nrow(a), 47)
  rel_err <- abs(a$area_geom - a$area_ref) / a$area_ref
  expect_lt(max(rel_err), 0.01)
})

test_that("G-06: スポット照合 — 区単位で人口最大は世田谷区(T-015)", {
  skip_if_no_processed()
  m <- st_drop_geometry(load_muni())
  # 出典: 令和2年国勢調査(区単位集計)。市単位なら横浜市だが本データは政令市を区に分解している
  expect_equal(m$code[which.max(m$pop_total)], "13112")  # 世田谷区
  expect_equal(m$pop_total[m$code == "13112"], 943664)
})
