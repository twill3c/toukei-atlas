# 指標計算・ランキング・スケールの純関数テスト(T-012〜T-014, T-017, T-022, T-023)。
source("../../R/themes.R", chdir = TRUE)
source("../../R/metrics.R", chdir = TRUE)

fix <- data.frame(
  code = c("11111", "22222", "33333", "44444"),
  name = c("あ市", "い市", "う町", "え村"),
  pref_code = c("11", "22", "33", "44"),
  pop_total = c(1000, 2000, 500, 0),
  pop_2015  = c(1000, 1900, 550, 0),
  pop_0_14  = c(100, 300, 50, 0),
  pop_65over = c(300, 400, 200, 0),
  area_km2  = c(4, 10, 25, 2),
  hh_general = c(400, 1000, 200, 0),
  hh_single  = c(100, 400, 30, 0)
)

theme_by_id <- function(id) THEMES[[which(vapply(THEMES, function(t) t$id, "") == id)]]

test_that("人口密度の計算(T-022)", {
  v <- compute_theme_values(fix, theme_by_id("jinko-mitsudo"))
  expect_equal(v$value[v$code == "11111"], 250)   # 1000 / 4
  expect_equal(v$value[v$code == "22222"], 200)   # 2000 / 10
})

test_that("増減率の計算と 0 人口の扱い(T-023)", {
  v <- compute_theme_values(fix, theme_by_id("jinko-zogen"))
  expect_equal(v$value[v$code == "22222"], 100 * (2000 - 1900) / 1900)
  expect_equal(v$value[v$code == "33333"], 100 * (500 - 550) / 550)
  # 分母 0(双葉町型)は NA(SPEC: 0/0 は未定義)
  expect_true(is.na(v$value[v$code == "44444"]))
})

test_that("高齢化率・年少人口率(T-022 系)", {
  k <- compute_theme_values(fix, theme_by_id("koreika"))
  expect_equal(k$value[k$code == "11111"], 30)    # 300/1000
  n <- compute_theme_values(fix, theme_by_id("nensho"))
  expect_equal(n$value[n$code == "22222"], 15)    # 300/2000
  expect_true(is.na(k$value[k$code == "44444"]))  # 0 人口 → NA
})

test_that("単独世帯率の計算と 0 世帯の扱い(T-024/F-05)", {
  v <- compute_theme_values(fix, theme_by_id("tandoku"))
  expect_equal(v$value[v$code == "11111"], 25)   # 100/400
  expect_equal(v$value[v$code == "22222"], 40)   # 400/1000
  expect_true(is.na(v$value[v$code == "44444"])) # 一般世帯 0 → NA
})

test_that("ランキング: 上位/下位 n 件・同値はコード順で安定(T-017)", {
  vals <- data.frame(
    code = sprintf("%05d", 1:25),
    name = paste0("m", 1:25),
    value = c(rep(5, 3), 25:4)
  )
  r <- ranking_data(vals, n = 10)
  expect_equal(nrow(r$top), 10)
  expect_equal(nrow(r$bottom), 10)
  expect_equal(r$top$value[1], max(vals$value))
  expect_true(all(diff(r$top$value) <= 0))
  expect_true(all(diff(r$bottom$value) >= 0))
  # 同値(value=5)はコード昇順
  tie <- r$bottom[r$bottom$value == 5, "code"]
  expect_equal(tie, sort(tie))
  # NA は順位に含めない
  vals$value[1] <- NA
  r2 <- ranking_data(vals, n = 10)
  expect_false(any(is.na(r2$top$value)), info = "NA が上位に混入")
  expect_false(any(is.na(r2$bottom$value)))
})

test_that("スケール仕様: 端点=データ min/max、発散は中点 0(T-012/T-014)", {
  vals <- c(2.5, 10, 7, NA, 4)
  s <- scale_spec("seq", vals)
  expect_equal(s$limits, c(2.5, 10))
  d <- scale_spec("div", c(-3, 5, NA, 1))
  expect_equal(d$midpoint, 0)
  expect_equal(d$limits, c(-5, 5))  # 発散は 0 対称
})

test_that("連続スケールの色は値に対し明度単調(T-013)", {
  s <- scale_spec("seq", c(0, 100))
  cols <- s$palette(seq(0, 1, length.out = 8))
  L <- farver::decode_colour(cols, to = "lab")[, "l"]
  expect_true(all(diff(L) > 0) || all(diff(L) < 0))
})
