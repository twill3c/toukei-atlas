# テーマ定義(SPEC §2.1)。1 テーマ = 1 ページ = 定型レイアウト(F-08)。
# 各テーマは「指標の計算式・スケール種別・出典表記」をデータとして持ち、
# 描画関数(plot_map.R 等)はこの定義だけを見て動く。

# scale: "seq"(viridis 連続)| "div"(青-赤発散、中点 0)  (N-05)
# unit:  凡例・注記に表示する単位
THEMES <- list(
  list(
    id = "koreika",          # F-01
    title = "高齢化率",
    numerator = "pop_65over", denominator = "pop_total",
    scale = "seq", unit = "%",
    source = "国勢調査 2020（e-Stat）"
  ),
  list(
    id = "jinko-mitsudo",    # F-02
    title = "人口密度",
    numerator = "pop_total", denominator = "area_km2",
    scale = "seq", unit = "人/km²",
    source = "国勢調査 2020 + 全国都道府県市区町村別面積調"
  ),
  list(
    id = "jinko-zogen",      # F-03
    title = "人口増減率（2015→2020）",
    numerator = "pop_diff", denominator = "pop_2015",
    scale = "div", unit = "%",
    source = "国勢調査 2015 / 2020（e-Stat）"
  ),
  list(
    id = "nensho",           # F-04
    title = "年少人口率",
    numerator = "pop_0_14", denominator = "pop_total",
    scale = "seq", unit = "%",
    source = "国勢調査 2020（e-Stat）"
  )
  # F-05 単独世帯率, F-06 カルトグラム, F-07 フローマップ は後続ループで追加
)
