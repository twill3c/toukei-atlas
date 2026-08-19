# T-020(F-13): data/pins.csv の取得固定。
# 必須 3 ソース(境界・国勢調査2020・面積調)が pin され、
# data/raw/ の実ファイルと SHA256 が一致すること。
# 2015 年人口は「主な結果」表の組替値列に内蔵されるため独立ファイルは持たない(loop_001 で確認)。
suppressPackageStartupMessages({
  library(readr)
  library(digest)
})

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
pins_path <- file.path(root, "data", "pins.csv")

test_that("pins.csv に必須 4 ソースが固定されている(T-020)", {
  pins <- read_csv(pins_path, col_types = "cccc")
  expect_true(all(c("filename", "url", "sha256", "license_note") == names(pins)))

  # role はファイル名の接頭辞で表す: boundary_ / census2020_ / area_ / flow_
  roles <- c("boundary_", "census2020_", "area_", "flow_")
  for (r in roles) {
    expect_true(any(startsWith(pins$filename, r)),
                info = paste("必須ソースが未 pin:", r))
  }
  expect_true(all(grepl("^https://", pins$url)))
  expect_true(all(grepl("^[0-9a-f]{64}$", pins$sha256)))
  expect_true(all(nchar(pins$license_note) > 0))
})

test_that("pin された全ファイルが data/raw に存在し SHA256 が一致する(T-020)", {
  pins <- read_csv(pins_path, col_types = "cccc")
  expect_gt(nrow(pins), 0)
  for (i in seq_len(nrow(pins))) {
    dest <- file.path(root, "data", "raw", pins$filename[i])
    expect_true(file.exists(dest), info = paste("欠落:", pins$filename[i]))
    if (file.exists(dest)) {
      expect_equal(digest(file = dest, algo = "sha256"), pins$sha256[i],
                   info = paste("ハッシュ不一致:", pins$filename[i]))
    }
  }
})
