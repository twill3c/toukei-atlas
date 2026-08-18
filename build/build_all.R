# 一発ビルド(F-15): data/raw → data/processed → out/
# 使い方: Rscript build/build_all.R
for (s in c("build/01_fetch.R", "build/02_prepare.R", "build/03_render.R")) {
  message("== ", s, " ==")
  source(s)
}
message("build complete → out/")
