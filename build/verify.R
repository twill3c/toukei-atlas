# 品質ゲート(AGENTS.md §3 / SPEC.md §4)。green 以外は非ゼロ終了。
# 使い方: Rscript build/verify.R
suppressPackageStartupMessages(library(testthat))

res <- test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
message("verify: all tests green")
