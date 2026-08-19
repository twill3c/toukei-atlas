# F-05 単独世帯率のオラクル(loop_005)。
# 列の根拠: 第1面事項シート col37=一般世帯, col46=うち単独世帯(loop_005 stage 2 で
# 全国行を検算: 総世帯 55,830,154 = 一般 55,704,949 + 施設等 125,205、
# 単独 21,151,042 → 率 37.97% ≒ 公表 38.0%)。世帯数は不詳補完前の値。
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
gpkg <- file.path(root, "data", "processed", "municipalities.gpkg")
ref_csv <- file.path(root, "data", "processed", "prefectures_reference.csv")

test_that("世帯列が gpkg に存在し全国合算が公表値と一致(G-01 世帯版)", {
  expect_true(file.exists(gpkg))
  skip_if_not(file.exists(gpkg))
  m <- st_drop_geometry(st_read(gpkg, quiet = TRUE))
  expect_true(all(c("hh_general", "hh_single") %in% names(m)),
              info = "hh 列がない(02_prepare 未更新)")
  skip_if_not(all(c("hh_general", "hh_single") %in% names(m)))
  # 出典: 令和2年国勢調査「主な結果」全国行(取得 2026-08-19)
  expect_equal(sum(m$hh_general), 55704949)
  expect_equal(sum(m$hh_single), 21151042)
})

test_that("世帯の都道府県合算が公表値と一致(G-01 世帯版)", {
  skip_if_not(file.exists(gpkg) && file.exists(ref_csv))
  ref <- read_csv(ref_csv, col_types = cols(.default = "c"))
  skip_if_not(all(c("hh_general", "hh_single") %in% names(ref)),
              "reference に hh 列がない")
  m <- st_drop_geometry(st_read(gpkg, quiet = TRUE))
  agg <- m |> group_by(pref_code) |>
    summarise(g = sum(hh_general), s = sum(hh_single), .groups = "drop")
  r <- ref |> filter(level == "pref") |>
    mutate(across(c(hh_general, hh_single), as.numeric))
  j <- inner_join(agg, r, by = "pref_code")
  expect_equal(nrow(j), 47)
  expect_equal(j$g, j$hh_general)
  expect_equal(j$s, j$hh_single)
})
