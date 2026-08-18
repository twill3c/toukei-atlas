# data/processed/ からテーマ別ページ(SVG 3 点 + HTML)と index を out/ に生成する。
#
# 契約(loop_003 で実装、テスト T-010〜T-019 が先行):
#  - THEMES(R/themes.R)を走査し、テーマごとに
#      out/<id>/index.html  … 定型レイアウト(F-08): 地図 + 上位/下位10 棒グラフ +
#                             ヒストグラム + 出典・定義注記 + フッタ
#      out/<id>/map.svg, ranking.svg, hist.svg
#  - out/index.html … サムネイルカード一覧(F-09)
#  - HTML は site/template_page.html / template_index.html への glue 展開のみ。
#  - 取得日等の時刻情報は本スクリプトが引数(--fetched-date)で受けて注入する。
#    R/ 内で Sys.Date() を呼ばない(N-01)。
#  - svglite で SVG 出力(フォント埋め込みなし・システム非依存の決定論出力を確認する)。

stop("loop_003 で実装する(テスト先行)。SPEC §2.2 / TEST_SPEC T-010〜T-019 参照")
