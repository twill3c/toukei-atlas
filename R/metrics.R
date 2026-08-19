# 指標計算・ランキング・色スケールの純関数(loop_003)。IO・時刻・乱数禁止。

suppressPackageStartupMessages(library(dplyr))

# テーマ定義(R/themes.R)から市区町村ごとの指標値を計算する。
# 分母 0(例: 双葉町の率)は NA(SPEC: 0/0 は未定義)。
compute_theme_values <- function(df, theme) {
  numer <- if (theme$numerator == "pop_diff") {
    df$pop_total - df$pop_2015
  } else {
    df[[theme$numerator]]
  }
  denom <- df[[theme$denominator]]
  ratio <- ifelse(is.na(denom) | denom == 0, NA_real_, numer / denom)
  # % 系(単位が % のテーマ)は 100 倍、実数系(人/km² 等)はそのまま
  value <- if (theme$unit == "%") 100 * ratio else ratio
  tibble(code = df$code, name = df$name,
         pref_code = df$pref_code, value = value)
}

# 上位/下位 n 件。同値は code 昇順で安定。NA は除外。
ranking_data <- function(values, n = 10) {
  v <- values[!is.na(values$value), ]
  k <- min(n, nrow(v))
  list(top    = v[order(-v$value, v$code), ][seq_len(k), ],
       bottom = v[order(v$value, v$code), ][seq_len(k), ])
}

# 色スケール仕様。seq: viridis(明度単調)、div: 青-白-赤(中点 0、0 対称)(N-05)。
# palette は [0,1] の位置 → 色。地図・棒・凡例のすべてがこの仕様を参照する。
scale_spec <- function(scale_type, values) {
  rng <- range(values, na.rm = TRUE)
  if (scale_type == "div") {
    m <- max(abs(rng))
    ramp <- grDevices::colorRamp(c("#2166ac", "#f7f7f7", "#b2182b"))
    list(type = "div", limits = c(-m, m), midpoint = 0,
         palette = function(x) {
           rgb <- ramp(x)
           grDevices::rgb(rgb[, 1], rgb[, 2], rgb[, 3], maxColorValue = 255)
         })
  } else {
    cols <- viridisLite::viridis(256)
    list(type = "seq", limits = rng, midpoint = NULL,
         palette = function(x) substr(cols[pmax(1, round(x * 255) + 1)], 1, 7))
  }
}
