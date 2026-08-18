# data/raw/ の境界(N03)と統計 CSV を結合し、data/processed/ に
# 描画用データ(GeoPackage + テーマ別数値 CSV)を書き出す。
#
# 契約(loop_002 で実装、テスト T-004〜T-009 が先行):
#  入力: data/raw/*(pins.csv 経由の取得物のみ)
#  出力: data/processed/municipalities.gpkg
#          - 列: code(JIS X 0402, character 5 桁), name, pref_code, pref_name,
#                pop_total, pop_65over, pop_0_14, pop_2015, area_km2, geometry
#          - CRS: JGD2011(EPSG:6668)、政令市は区単位、rmapshaper 簡略化済み
#  不変量: code は全経路 character(先頭ゼロ保護)。結合は full join 後に
#          両側の孤児を検査し、孤児 > 0 なら stop(G-02)。

stop("loop_002 で実装する(テスト先行)。SPEC §2.3 / TEST_SPEC T-004〜T-009 参照")
