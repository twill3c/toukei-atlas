# フッタ定義(F-10)。フリート標準の並び:
# MIT License(© 2026 坂田哲朗)・GitHub・歩き方・設計図・App Menu
# 歩き方/設計図はアーティファクト公開後に URL を差し込む。それまで行自体を出さない
# (プレースホルダ URL の出力は F-10 で禁止)。

footer_links <- function() {
  links <- list(
    list(label = "MIT License",
         href = "https://github.com/twill3c/toukei-atlas/blob/main/LICENSE"),
    list(label = "GitHub",
         href = "https://github.com/twill3c/toukei-atlas"),
    # list(label = "toukei-atlas の歩き方", href = "<artifact URL>"),
    # list(label = "toukei-atlas 設計図",   href = "<artifact URL>"),
    list(label = "App Menu",
         href = "https://app-menu-amber.vercel.app")
  )
  links
}

# フッタ 1 ブロック分の HTML を返す純関数。
footer_html <- function(links = footer_links()) {
  parts <- vapply(seq_along(links), function(i) {
    l <- links[[i]]
    sep <- if (i > 1) " ・ " else ""
    suffix <- if (l$label == "MIT License") " © 2026 坂田哲朗" else ""
    sprintf('%s<a href="%s" target="_blank" rel="noopener">%s</a>%s',
            sep, l$href, l$label, suffix)
  }, character(1))
  sprintf('<footer class="site-footer"><p>%s</p></footer>',
          paste(parts, collapse = ""))
}
