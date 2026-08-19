# T-018(F-10): フッタ定義。フリート標準の順序・全 https・ラベル非空。
source("../../R/footer.R", chdir = TRUE)

test_that("フッタリンクの構成(T-018)", {
  links <- footer_links()
  labels <- vapply(links, function(l) l$label, character(1))

  # フリート標準 5 リンク(kobai-walk と同構成)
  expect_equal(labels, c("MIT License", "GitHub",
                         "toukei-atlas の歩き方", "toukei-atlas 設計図",
                         "App Menu"))
  # 歩き方と設計図は別のアーティファクト
  hrefs <- vapply(links, function(l) l$href, character(1))
  expect_false(hrefs[3] == hrefs[4])
  expect_match(hrefs[3], "^https://claude\\.ai/code/artifact/")
  expect_match(hrefs[4], "^https://claude\\.ai/code/artifact/")
  for (l in links) {
    expect_match(l$href, "^https://")
    expect_gt(nchar(l$label), 0)
  }
  # プレースホルダ URL が混入していないこと(F-10)
  html <- footer_html(links)
  expect_false(grepl("<artifact", html, fixed = TRUE))
  expect_match(html, "© 2026 坂田哲朗", fixed = TRUE)
})
