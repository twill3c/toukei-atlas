# T-018(F-10): フッタ定義。フリート標準の順序・全 https・ラベル非空。
source("../../R/footer.R", chdir = TRUE)

test_that("フッタリンクの構成(T-018)", {
  links <- footer_links()
  labels <- vapply(links, function(l) l$label, character(1))

  # 公開済みリンクのみ。歩き方/設計図はアーティファクト公開後にここへ挿入する
  expect_equal(labels, c("MIT License", "GitHub", "App Menu"))
  for (l in links) {
    expect_match(l$href, "^https://")
    expect_gt(nchar(l$label), 0)
  }
  # プレースホルダ URL が混入していないこと(F-10)
  html <- footer_html(links)
  expect_false(grepl("<artifact", html, fixed = TRUE))
  expect_match(html, "© 2026 坂田哲朗", fixed = TRUE)
})
