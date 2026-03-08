# GitHub Copilot Instructions — aboveR

> LiDAR Terrain Analysis and Change Detection from Above
> Part of [Null Island Labs](https://github.com/null-island-labs) R geospatial toolkit

## Package Context

Terrain analysis functions that lidR (forestry) and terra (general raster) don't provide: change detection between DEM epochs, cut/fill volume estimation, terrain profiling, erosion channel detection, reclamation monitoring, impoundment capacity curves, and flood risk assessment. Built ON TOP of lidR (for LAS I/O) and terra (for raster operations).

Includes KyFromAbove access module for Kentucky's cloud-native elevation data on AWS S3. Dual access path: STAC catalog (github.com/ianhorn/kyfromabove-stac, under development) with fallback to S3 tile index GeoPackages. KyFromAbove data is in EPSG:3089 (Kentucky Single Zone), 5000x5000ft tile grid, unsigned S3 access at s3://kyfromabove/ (us-west-2).

## Exported API

Core analysis: terrain_change(), change_by_zone(), estimate_volume(), impoundment_curve(), terrain_profile(), boundary_terrain_profile(), classify_highwall(), reclamation_progress(), surface_roughness(), detect_channels(), pond_sedimentation()

KyFromAbove access: kfa_find_tiles(), kfa_tile_index(), kfa_read_dem(), kfa_read_pointcloud(), kfa_read_ortho(), kfa_stac_search()

## Dependencies

- **Imports (always available):** lidR, terra, sf
- **Suggests (check at runtime):** rstac, httr2, rgl, mapview, ggplot2, whitebox, cli, testthat

When using rstac or other Suggested packages:
```r
if (!requireNamespace("rstac", quietly = TRUE)) {
  stop("Package 'rstac' is required for STAC access.\n",
       "Install it with: install.packages('rstac')", call. = FALSE)
}
```

## KyFromAbove Constants

```r
KFA_BUCKET <- "kyfromabove"
KFA_REGION <- "us-west-2"
KFA_BASE_URL <- "https://kyfromabove.s3.us-west-2.amazonaws.com"
KFA_CRS <- 3089L  # Kentucky Single Zone
# Phase 1: 5ft DEM, LAZ point cloud
# Phase 2: 2ft DEM, COPC point cloud
# Phase 3: 2ft DEM, COPC point cloud, 3-inch imagery + oblique
```

## CRAN Compliance (Non-Negotiable)

- All exported functions need `@returns` and `@examples` or `@examplesIf`
- KyFromAbove examples use `@examplesIf aboveR:::has_s3_access()`
- Core analysis examples use bundled sample rasters in `inst/extdata/`
- Never write outside `tempdir()` in examples or tests
- Cache files go to `tools::R_user_dir("aboveR", "cache")`
- Network tests use `skip_on_cran()`
- `\donttest{}` for slow computations, never `\dontrun{}`

## R Coding Conventions

- R >= 4.1.0 (native pipe `|>` is acceptable)
- roxygen2 with markdown enabled
- testthat edition 3
- terra SpatRaster for all raster returns
- sf tibble for all vector returns
- lidR LAS for point cloud returns
- Error handling: `stop()` with informative messages and `call. = FALSE`
- Progress bars via cli (Suggests) for long operations

## Key Design Rules

- Core analysis functions accept ANY DEM/LAS, not just KyFromAbove
- kfa_* functions handle EPSG:3089 reprojection transparently
- terrain_change() validates CRS match and resamples if resolutions differ
- estimate_volume() never returns without documenting the method used
- kfa_find_tiles() tries STAC first, falls back to tile index silently
