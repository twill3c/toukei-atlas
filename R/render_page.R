# HTML 生成の純関数(loop_003)。glue テンプレート展開のみ。IO はビルド側。

suppressPackageStartupMessages(library(glue))

# テーマページ 1 枚分の HTML。tpl は site/template_page.html の文字列。
render_page_html <- function(tpl, theme_def, footer, unit_label, fetched_date,
                             boundary_source, definition) {
  glue(tpl,
       title = theme_def$title,
       definition = definition,
       source = theme_def$source,
       unit = theme_def$unit,
       unit_label = unit_label,
       boundary_source = boundary_source,
       fetched_date = fetched_date,
       footer = footer,
       .open = "{{", .close = "}}")
}

# index の HTML。cards は組み立て済みのカード HTML 断片。
render_index_html <- function(tpl, cards, footer) {
  glue(tpl, cards = cards, footer = footer, .open = "{{", .close = "}}")
}

# index 用カード 1 枚。
render_card_html <- function(theme_def, summary_line) {
  glue(
    '<a class="theme-card" href="{theme_def$id}/">',
    '<img src="{theme_def$id}/map.svg" alt="{theme_def$title}のサムネイル" loading="lazy">',
    '<div class="card-body"><h2>{theme_def$title}</h2>',
    '<p>{summary_line}</p></div></a>'
  )
}

# 指標の定義文(注記・meta description 用)。
theme_definition_text <- function(theme_def) {
  num_label <- c(pop_65over = "65 歳以上人口", pop_total = "総人口",
                 pop_0_14 = "0〜14 歳(15 歳未満)人口",
                 pop_diff = "2020 年人口 − 2015 年組替人口",
                 hh_single = "単独世帯数")[theme_def$numerator]
  den_label <- c(pop_total = "総人口", area_km2 = "面積(km²)",
                 pop_2015 = "2015 年組替人口",
                 hh_general = "一般世帯数")[theme_def$denominator]
  paste0(num_label, " ÷ ", den_label,
         if (theme_def$unit == "%") "(百分率)" else "")
}
