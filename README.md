# toukei-atlas — 日本統計地図帳

日本の公的統計(国勢調査ほか)を市区町村単位の主題図にした静的アトラス。
R(sf + ggplot2)で印刷物品質の地図を生成し、Vercel から静的配信する。

- 仕様: [SPEC.md](SPEC.md) / テストとオラクル設計: [TEST_SPEC.md](TEST_SPEC.md) / 開発規範: [AGENTS.md](AGENTS.md)

## 構成

```
R/          純関数(テーマ定義・集計・描画・フッタ)— IO/時刻/乱数禁止
build/      パイプライン(副作用はここだけ)
  01_fetch.R    data/pins.csv → data/raw/(SHA256 検証付き取得)
  02_prepare.R  境界+統計を結合 → data/processed/municipalities.gpkg
  03_render.R   テーマ別 SVG + HTML → out/
  build_all.R   一発ビルド
  verify.R      品質ゲート(testthat: G-01〜G-06)
data/pins.csv   取得物の URL + SHA256 + ライセンス表記(唯一の取得経路)
site/           HTML テンプレート(glue 展開)+ CSS
tests/testthat/ オラクル群(公表値照合・結合完全性・幾何・描画決定論)
out/            静的サイト(Vercel デプロイ対象、git 管理外)
```

## ビルドとデプロイ

```sh
Rscript build/build_all.R   # data/raw → out/
Rscript build/verify.R      # 品質ゲート
cd out && vercel deploy --prod
```

Vercel に R ランタイムはないため、ビルドはローカルで行い `out/` だけをデプロイする。

**push では本番に出さない。** `out/` は git 管理外なので、GitHub 連携がリポジトリルートを
デプロイすると本番が全ページ 404 になる(2026-08-27 に実際に起きた)。
`vercel.json` の `git.deploymentEnabled` で main への push を無効にしてある。
本番反映は必ず上の `cd out && vercel deploy --prod` で行うこと。
`out/.vercel/project.json` が無ければリポジトリルートの `.vercel/project.json` を複製する。

## ライセンスと出典

コードは MIT([LICENSE](LICENSE))。

**統計データは同梱していない。** 取得は `data/pins.csv`(URL + SHA256 + ライセンス表記)
経由のみで、実体はビルド時に取りに行く(F-13)。出典は 4 件で、条件はそれぞれ次による:

| 出典 | 条件 |
|---|---|
| 国土数値情報 行政区域データ(国土交通省) | CC BY 4.0 相当(出典明記) |
| 令和2年国勢調査・住民基本台帳人口移動報告(総務省統計局) | e-Stat 利用規約(出典明記) |
| 全国都道府県市区町村別面積調(国土地理院) | 出典明記 |

各ページの「出典・定義」節に出典を常時表示している。**本サイトの数値は出典の公表値を
再集計したものであり、加工後の値の責任は本サイトにある**(国が作成したものではない)。
