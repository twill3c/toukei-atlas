# data/pins.csv に固定した取得物を data/raw/ へダウンロードし、SHA256 を検証する(F-13)。
# ハッシュ不一致は即エラー。再実行は冪等(検証済みファイルはスキップ)。

suppressPackageStartupMessages({
  library(readr)
  library(digest)
})

pins <- read_csv("data/pins.csv", col_types = "cccc")
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nrow(pins))) {
  p <- pins[i, ]
  dest <- file.path("data/raw", p$filename)
  if (file.exists(dest) && digest(file = dest, algo = "sha256") == p$sha256) {
    message("ok (cached): ", p$filename)
    next
  }
  message("fetch: ", p$url)
  download.file(p$url, dest, mode = "wb", quiet = TRUE)
  got <- digest(file = dest, algo = "sha256")
  if (got != p$sha256) {
    stop(sprintf("SHA256 mismatch for %s\n  expected: %s\n  got:      %s",
                 p$filename, p$sha256, got))
  }
  message("ok (fetched): ", p$filename)
}
