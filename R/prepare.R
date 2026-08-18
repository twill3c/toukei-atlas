# 結合パイプラインの純関数群(loop_002)。IO・時刻・乱数は禁止(AGENTS §4)。
# 入力はビルドスクリプトが読み込んだ生データフレーム/sf オブジェクト。

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
})

# N03 に存在するが国勢調査の集計対象外の市区町村(北方領土 6 村)。
# 出典: 総務省の市区町村数(1,741 = 1,718 市町村 + 23 特別区)に不含。
EXCLUDED_CODES <- c("01695", "01696", "01697", "01698", "01699", "01700")

num <- function(x) suppressWarnings(as.numeric(x))

# 人数カウント列用: 統計表の「-」は皆無(0)を表す(例: 双葉町 07546 は 2015/2020 とも人口 0)。
# 率・平均年齢などの導出列は 0/0 が未定義のため「-」を NA のまま残す(num を使う)。
num_count <- function(x) {
  x <- ifelse(x == "-", "0", x)
  suppressWarnings(as.numeric(x))
}

# 「主な結果」第1面(skip=9, col_names=FALSE で読んだ生データ)を整形する。
# 列位置は loop_001/002 の調査で確定(SPEC §2.1)。
parse_census_major <- function(raw) {
  out <- tibble(
    pref_name = sub("^[0-9]+_", "", raw[[1]]),
    code      = sub("_.*$", "", raw[[2]]),
    name      = sub("^[0-9]+_", "", raw[[2]]),
    kind      = raw[[4]],
    pop_total = num_count(raw[[5]]),
    pop_2015  = num_count(raw[[8]]),
    change_rate_pub = num(raw[[10]]),
    area_pub  = num(raw[[11]]),
    density_pub = num(raw[[12]]),
    pop_0_14  = num_count(raw[[15]]),
    pop_15_64 = num_count(raw[[16]]),
    pop_65over = num_count(raw[[17]]),
    rate_0_14_pub  = num(raw[[18]]),
    rate_15_64_pub = num(raw[[19]]),
    rate_65over_pub = num(raw[[20]])
  )
  out <- out[!is.na(out$code) & grepl("^[0-9]{5}$", out$code), ]
  out$pref_code <- substr(out$code, 1, 2)
  out
}

# 集計単位(市区町村、政令市は区)に絞る。kind: 0=区, 2=市, 3=町村。
census_municipal_units <- function(census) {
  filter(census, kind %in% c("0", "2", "3"))
}

# 都道府県 + 全国の照合用参照表。kind: a= 全国/都道府県。
census_reference <- function(census) {
  ref <- filter(census, kind == "a")
  ref$level <- ifelse(ref$code == "00000", "national", "pref")
  ref
}

# 面積調(skip=4, cp932, 全列 character で読んだ生データ)から
# 令和2年10月1日時点の面積を取り出す。
parse_area_csv <- function(raw) {
  code <- raw[["標準地域コード"]]
  col <- grep("令和2年10月1日", names(raw), fixed = TRUE)[1]
  out <- tibble(code = code, area_km2 = num(raw[[col]]))
  out[!is.na(out$code) & grepl("^[0-9]{5}$", out$code) & !is.na(out$area_km2), ]
}

# N03 境界(code 列のみの sf)を集計単位に整える:
# 除外コード・コード無し(所属未定地)を落とし、簡略化 → コード単位に union。
aggregate_boundary <- function(bnd, tolerance_deg = 0.0008) {
  bnd <- bnd[!is.na(bnd$code) & !(bnd$code %in% EXCLUDED_CODES), ]
  bnd <- st_make_valid(bnd)
  st_geometry(bnd) <- st_simplify(st_geometry(bnd), dTolerance = tolerance_deg)
  bnd <- bnd[!st_is_empty(bnd), ]
  agg <- bnd |>
    group_by(code) |>
    summarise(.groups = "drop")
  agg <- st_make_valid(agg)
  agg[!st_is_empty(agg), ]
}

# 境界 × 国勢調査 × 面積調 を結合する。孤児(片側にしかないコード)は即エラー(G-02)。
join_municipalities <- function(boundary_agg, census_muni, area) {
  b <- boundary_agg$code
  c_ <- census_muni$code
  orphan_b <- setdiff(b, c_)
  orphan_c <- setdiff(c_, b)
  if (length(orphan_b) > 0 || length(orphan_c) > 0) {
    stop(sprintf("G-02 違反 — 境界のみ: [%s] / 国勢調査のみ: [%s]",
                 paste(orphan_b, collapse = ","), paste(orphan_c, collapse = ",")))
  }
  m <- boundary_agg |>
    left_join(census_muni, by = "code") |>
    left_join(area, by = "code")
  if (any(is.na(m$area_km2))) {
    stop(sprintf("面積調に欠落: %s",
                 paste(m$code[is.na(m$area_km2)], collapse = ",")))
  }
  m
}
