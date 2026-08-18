# data/raw/ の境界(N03)・国勢調査「主な結果」・面積調を結合し、
# data/processed/municipalities.gpkg と prefectures_reference.csv を書き出す。
# 契約は SPEC §2.3 / AGENTS §4。変換ロジックは R/prepare.R(純関数)。

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(readxl)
})
source("R/prepare.R")

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)

# 1. 境界: zip からシェープファイルを展開(未展開時のみ)して読む
shp_dir <- "data/raw/extracted"
shp <- file.path(shp_dir, "N03-20210101_GML/N03-21_210101.shp")
if (!file.exists(shp)) {
  message("extract: boundary shapefile")
  # utils::unzip は zip64(このアーカイブは 688MB の geojson を含む)非対応のため zip パッケージを使う。
  # メンバー名の区切りが \\ のためリストから動的に解決する
  members <- zip::zip_list("data/raw/boundary_n03_2021_gml.zip")$filename
  wanted <- members[grepl("N03-21_210101\\.(shp|shx|dbf|prj)$", members)]
  stopifnot(length(wanted) == 4)
  zip::unzip("data/raw/boundary_n03_2021_gml.zip", files = wanted, exdir = shp_dir)
  # 展開後のパスも区切り差を吸収して正規化する
  got <- list.files(shp_dir, recursive = TRUE, full.names = TRUE,
                    pattern = "N03-21_210101\\.(shp|shx|dbf|prj)$")
  dir.create(dirname(shp), recursive = TRUE, showWarnings = FALSE)
  file.rename(got, file.path(dirname(shp), basename(got)))
}
message("read: boundary")
bnd <- st_read(shp, quiet = TRUE,
               query = "SELECT N03_007 AS code FROM \"N03-21_210101\"")
bnd <- st_set_crs(bnd, 6668)  # JGD2011(prj は JGD2011 地理座標系)

# 2. 国勢調査「主な結果」
message("read: census")
census_raw <- suppressMessages(
  read_excel("data/raw/census2020_major_results.xlsx",
             sheet = "第１面事項_2020年", skip = 9, col_names = FALSE)
)
census <- parse_census_major(census_raw)
muni <- census_municipal_units(census)
ref <- census_reference(census)

# 3. 面積調(令和2年10月1日時点)
message("read: area")
area_raw <- suppressMessages(
  read_csv("data/raw/area_gsi_r1_r5_mencho.csv", skip = 4,
           locale = locale(encoding = "cp932"), col_types = cols(.default = "c"))
)
area <- parse_area_csv(area_raw)

# 4. 集約・結合
message("aggregate: boundary (union by code) — 数分かかる")
bnd_agg <- aggregate_boundary(bnd)
m <- join_municipalities(bnd_agg, muni, area)

# 5. 書き出し
message("write: municipalities.gpkg (", nrow(m), " units)")
unlink("data/processed/municipalities.gpkg")
st_write(m, "data/processed/municipalities.gpkg", quiet = TRUE)

ref_out <- ref |>
  transmute(level, pref_code = substr(code, 1, 2), code, name,
            pop_total, pop_2015,
            area_ref = area_pub, density_ref = density_pub,
            rate_65over_pub)
write_csv(ref_out, "data/processed/prefectures_reference.csv")
message("done")
