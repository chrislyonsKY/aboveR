# Architecture — aboveR

> LiDAR Terrain Analysis and Change Detection from Above
> Built on lidR + terra + sf | Integrates with KyFromAbove on AWS

---

## Overview

aboveR provides terrain analysis functions that don't exist in lidR (which is forestry-focused) or terra (which is general-purpose raster). The package targets environmental, infrastructure, agricultural, and mining applications of LiDAR-derived elevation data: change detection between epochs, volume estimation, terrain profiling, erosion analysis, reclamation monitoring, and flood risk assessment.

The KyFromAbove access module integrates with Kentucky's cloud-native elevation data on AWS S3, including Ian Horn's STAC catalog work (github.com/ianhorn/kyfromabove-stac) and the existing tile index GeoPackages.

---

## KyFromAbove Data Infrastructure (Reference)

### S3 Bucket Structure

Bucket: `s3://kyfromabove/` (us-west-2, public, unsigned access)

```
kyfromabove/
├── elevation/
│   ├── DEM/
│   │   ├── Phase1/          # 5ft resolution DEMs (COG)
│   │   ├── Phase2/          # 2ft resolution DEMs (COG)
│   │   └── Phase3/          # 2ft resolution DEMs (COG, ongoing)
│   ├── contours/            # 5ft, 10ft, 20ft, 40ft intervals (GPKG, FGDB)
│   ├── pointcloud/
│   │   ├── Phase1/          # LAZ format
│   │   ├── Phase2/          # COPC format
│   │   └── Phase3/          # COPC format (ongoing)
│   └── spot_elevations/     # GPKG
├── imagery/
│   ├── orthos/              # 3-6" resolution ortho (COG)
│   │   ├── Phase1/
│   │   ├── Phase2/
│   │   └── Phase3/
│   └── oblique/             # Side-angle photography (COG, Phase 3 only)
└── indexes/
    └── tile grids            # GeoPackage tile index files
```

### Key Parameters

- **Grid:** Kentucky-specific 5000x5000 foot tiles
- **CRS:** EPSG:3089 (Kentucky Single Zone, FIPS:1600)
- **DEM resolution:** 5ft (Phase 1), 2ft (Phase 2/3)
- **Point cloud:** LAZ (Phase 1), COPC (Phase 2/3)
- **Imagery:** COG, 3-6 inch resolution
- **Access:** Unsigned S3 (no credentials needed)
- **Total size:** ~131 TiB across all products

### STAC Catalog (In Development)

Ian Horn (github.com/ianhorn) is building a STAC catalog for KyFromAbove:
- Repo: github.com/ianhorn/kyfromabove-stac
- Backend: stac-fastapi-pgstac (Docker image at hub.docker.com/r/ianhorn/stac-fastapi-pgstac)
- STAC Index listing: stacindex.org/catalogs/kyfromabove
- Status: Under development — when live, aboveR should support both STAC and direct S3 tile index access

### Tile Index Access (Current Method)

Ian's examples (github.com/ianhorn/kyfromabove-on-aws-examples) show the current access pattern:
1. Download tile index GeoPackage from S3 (contains tilename, key, aws_url, size, geometry)
2. Spatial query: sf::st_intersection(tile_index, aoi) to find matching tiles
3. Extract S3 URLs for matching tiles
4. Read COGs directly via /vsicurl/ or download individual tiles
5. County boundaries available via KY ArcGIS Server REST endpoints

---

## Module Design

```
R/
├── # ── Core Analysis ──
├── change.R               # terrain_change(), change_by_zone()
├── volume.R               # estimate_volume(), impoundment_curve()
├── profile.R              # terrain_profile(), boundary_terrain_profile()
├── highwall.R             # classify_highwall(), bench_detection()
├── reclamation.R          # reclamation_progress(), surface_roughness()
├── erosion.R              # detect_channels(), pond_sedimentation()
│
├── # ── KyFromAbove Access ──
├── kfa_tiles.R            # kfa_find_tiles(), kfa_tile_index()
├── kfa_read.R             # kfa_read_dem(), kfa_read_pointcloud(), kfa_read_ortho()
├── kfa_stac.R             # kfa_stac_search() — uses rstac when STAC catalog is live
├── kfa_constants.R        # S3 bucket paths, EPSG codes, phase metadata
│
├── # ── Utilities ──
├── classify.R             # Mining/environmental point classification helpers
├── visualize.R            # Plot methods, color ramps for change maps
├── utils.R                # Shared utilities, CRS handling
└── aboveR-package.R       # Package-level documentation
```

---

## KyFromAbove Access Design

### Dual Access Path

```
User provides AOI (sf polygon or bbox)
    │
    ├─ IF STAC catalog is available (kfa_stac_search)
    │   └─ rstac query → item URLs → terra::rast(/vsicurl/...)
    │
    └─ ELSE fallback to tile index (kfa_find_tiles)
        ├─ Download tile index GPKG from S3 (cached locally)
        ├─ sf::st_intersection(tile_index, aoi) → matching tiles
        ├─ Build S3 URLs from key column + bucket base
        └─ terra::rast(/vsicurl/...) or download to local
```

### Key Functions

```r
# Find tiles covering an area of interest
tiles <- kfa_find_tiles(
  aoi = my_boundary_sf,         # sf polygon or bbox
  product = "dem",              # "dem", "pointcloud", "ortho", "contours", "oblique"
  phase = 2,                    # 1, 2, or 3
  method = "auto"               # "auto" tries STAC first, falls back to tile index
)
# Returns: tibble with tilename, s3_url, phase, resolution, bbox, geometry

# Read DEM tiles directly (merges + crops to AOI)
dem <- kfa_read_dem(
  aoi = my_boundary_sf,
  phase = 2,                    # 2ft resolution
  merge = TRUE,                 # Mosaic tiles into single SpatRaster
  crop = TRUE                   # Crop to AOI extent
)
# Returns: terra SpatRaster via /vsicurl/ (no full download needed for COGs)

# Read point cloud tiles
las <- kfa_read_pointcloud(
  aoi = my_boundary_sf,
  phase = 2                     # COPC format — lidR reads COPC natively
)
# Returns: lidR LAS object

# Read ortho imagery
ortho <- kfa_read_ortho(
  aoi = my_boundary_sf,
  phase = 3,                    # 3-inch resolution
  type = "nadir"                # "nadir" or "oblique"
)
# Returns: terra SpatRaster (RGB)
```

### Caching Strategy

```r
# Tile index GeoPackages are cached locally (they're ~50MB each)
# Cache location: tools::R_user_dir("aboveR", "cache")  — CRAN-approved
# Cache checked first, refreshed if older than 30 days
# DEMs can optionally be cached for repeated analysis:
dem <- kfa_read_dem(aoi, phase = 2, cache = TRUE)
```

---

## Core Analysis Functions

### terrain_change()

```
terrain_change(before, after, tolerance = 0.1)
    │
    ├─ Validate: same CRS, same resolution (or resample after to match before)
    ├─ Align extents: crop to intersection
    ├─ Compute: after - before → change raster
    ├─ Classify: cut (< -tolerance), fill (> tolerance), stable (within tolerance)
    └─ Return: SpatRaster with continuous change values + classified layer

change_by_zone(change_raster, zones_sf, id_field)
    │
    ├─ terra::extract(change, zones, fun = c(sum, mean, min, max))
    ├─ Compute volumes: sum(cell_values * cell_area) for cut and fill separately
    └─ Return: tibble with zone_id, cut_volume_m3, fill_volume_m3, net_change_m3,
               area_m2, mean_change_m, max_cut_m, max_fill_m
```

### estimate_volume()

```
estimate_volume(surface, reference, boundary, method = "trapezoidal")
    │
    ├─ Crop both rasters to boundary extent
    ├─ Compute difference: surface - reference
    ├─ Method dispatch:
    │   ├─ "trapezoidal" → sum(abs(diff) * cell_area)
    │   ├─ "simpson"     → Simpson's 1/3 rule integration
    │   └─ "triangulated"→ Delaunay triangulation volume
    └─ Return: list(volume_m3, area_m2, mean_depth_m, max_depth_m, method)
```

### impoundment_curve()

```
impoundment_curve(dem, pour_point, max_stage_m, interval_m = 0.5)
    │
    ├─ For each stage from 0 to max_stage_m at interval:
    │   ├─ Flood fill from pour_point to current stage elevation
    │   ├─ Compute water surface area at stage
    │   └─ Compute cumulative volume below stage
    └─ Return: tibble with stage_m, area_m2, volume_m3 (stage-storage curve)
              + plot method for stage-storage curve
```

### terrain_profile()

```
terrain_profile(dem_or_las, transect_sf, interval_m = 1.0)
    │
    ├─ Densify transect line at interval_m spacing
    ├─ Extract elevation at each sample point
    ├─ Compute: cumulative distance_along, slope between samples
    └─ Return: tibble with distance_m, elevation_m, slope_deg, x, y
              + plot method for cross-section visualization
```

---

## Exported Functions

### Core Analysis
- `terrain_change()` — Compute elevation change between two DEMs
- `change_by_zone()` — Summarize change by polygon zones (permits, parcels, etc.)
- `estimate_volume()` — Cut/fill volume between two surfaces within a boundary
- `impoundment_curve()` — Stage-storage relationship for a depression
- `terrain_profile()` — Cross-section elevation profile along a transect
- `boundary_terrain_profile()` — Profile along a polygon boundary with buffer
- `classify_highwall()` — Detect steep terrain faces from DEM slope analysis
- `reclamation_progress()` — Track multi-epoch return to target grade
- `surface_roughness()` — Compute terrain roughness index in moving window
- `detect_channels()` — Find erosion channels from flow accumulation on high-res DEM
- `pond_sedimentation()` — Quantify sediment volume in a pond vs as-built surface

### KyFromAbove Access
- `kfa_find_tiles()` — Find KyFromAbove tiles covering an area of interest
- `kfa_tile_index()` — Load and cache a tile index GeoPackage
- `kfa_read_dem()` — Read and mosaic KyFromAbove DEMs for an AOI
- `kfa_read_pointcloud()` — Read KyFromAbove point cloud for an AOI
- `kfa_read_ortho()` — Read KyFromAbove ortho or oblique imagery for an AOI
- `kfa_stac_search()` — Search KyFromAbove STAC catalog (when available)

---

## Dependencies

### Imports (always available)
- **lidR** — LAS/LAZ/COPC I/O, ground classification, DTM generation
- **terra** — SpatRaster operations, COG reading via /vsicurl/
- **sf** — Vector operations, spatial queries, tile index intersection

### Suggests (checked at runtime)
- **rstac** — STAC catalog access (for kfa_stac_search)
- **httr2** — Direct S3 HTTP requests for tile index download
- **rgl** — 3D point cloud visualization
- **mapview** — Interactive map preview
- **ggplot2** — Static visualization
- **whitebox** — Hydrologic analysis (channel detection, flow accumulation)
- **cli** — Progress bars for tile downloads and long computations
- **testthat (>= 3.0.0)** — Testing
- **knitr, rmarkdown** — Vignettes
- **withr** — Temp dir management in tests

---

## Architectural Decisions

### AD-01: Build on lidR, do not replace it
lidR handles LAS I/O, point cloud indexing, ground classification, and DTM generation. aboveR adds domain-specific terrain analysis on top. Users who need forestry features (canopy models, tree segmentation) use lidR directly.

### AD-02: terra for rasters, sf for vectors
Modern R spatial stack. No legacy sp/raster dependencies. COG access via terra's built-in /vsicurl/ support. This is critical for KyFromAbove cloud-native access — terra can read COGs on S3 without downloading the full file.

### AD-03: Dual KyFromAbove access path (STAC + tile index)
Ian Horn's STAC catalog (github.com/ianhorn/kyfromabove-stac) is under active development. When live, aboveR uses it via rstac (Suggests). Until then, falls back to S3 tile index GeoPackages using Ian's documented access pattern. `method = "auto"` tries STAC first. Both paths return the same tibble structure so downstream code doesn't care which method was used.

### AD-04: KyFromAbove utilities are self-contained
The `kfa_*()` functions are in separate R files (kfa_tiles.R, kfa_read.R, kfa_stac.R, kfa_constants.R). Core analysis functions (terrain_change, estimate_volume, etc.) work with any DEM/LAS data from any source — USGS 3DEP, state LiDAR programs, commercial acquisitions. The package is fully useful without KyFromAbove.

### AD-05: Local caching for tile indexes and optionally DEMs
Tile index GeoPackages (~50MB) are cached in `tools::R_user_dir("aboveR", "cache")` — the CRAN-approved user cache location. DEMs can be cached with `cache = TRUE` for repeated analysis of the same area. Cache is invalidated after 30 days by default.

### AD-06: EPSG:3089 awareness
KyFromAbove data is in Kentucky Single Zone (EPSG:3089). kfa_* functions handle the 3089 ↔ user CRS reprojection transparently. Core analysis functions accept any CRS and validate that input rasters share the same CRS before computation.

---

## KyFromAbove Organization & Collaboration

### Kentucky Division of Geographic Information (github.com/kydgi)

The official GitHub org for DGI — Chris Lyons's division. Maintains:
- **aws-js-s3-explorer** — Fork of AWS S3 explorer for KyFromAbove bucket browsing
- **pz-nacis-2025** — "Visualizing landscape change with KyFromAbove lidar point clouds" (Jupyter Notebook, presented at NACIS 2025)
- **kytopo-phase2** — Kentucky Topo series, Phase 2 (HTML viewer)
- **dsm-viewer** — Digital Surface Model viewer for Phase 1 and 2 (HTML)
- **oblique-viewer** — Oblique imagery viewer and downloader (HTML)
- **oblique-scene-viewer** — Oblique viewer with a Web Scene (HTML)
- **obliques-schools** — Using oblique imagery for school facility maps (HTML)
- **ky-exb-app-viewer-help** — ArcGIS Experience Builder viewer help

This is the official org for the team that produces the data aboveR consumes. aboveR should be listed as a community tool on kydgi when ready.

### Key People

**Ian Horn** (github.com/ianhorn) — GIS Analyst at DGI, Frankfort KY. Manages KyFromAbove's AWS infrastructure and is building the STAC catalog.
- Repos: kyfromabove-on-aws-examples, kyfromabove-stac, kyfromabove-gisconference2025-workshop
- Docker: hub.docker.com/r/ianhorn/stac-fastapi-pgstac
- His Python notebooks are the reference implementation for tile index access patterns

### Official Resources

| Resource | URL |
|----------|-----|
| KyFromAbove program site | kyfromabove.ky.gov |
| S3 bucket (public) | s3://kyfromabove/ (us-west-2) |
| AWS Open Data Registry | registry.opendata.aws/kyfromabove |
| STAC Index listing | stacindex.org/catalogs/kyfromabove |
| KyGeoNet portal | kygeonet.ky.gov |
| Open Data portal | opengisdata.ky.gov |
| ArcGIS Server | kygisserver.ky.gov/arcgis |
| DGI division page | technology.ky.gov/GIS |
| Contact | kyfromabove@ky.gov |

### Collaboration Opportunities

- Ian contributes to or reviews the kfa_* access module
- aboveR's STAC integration tested against his pgstac backend
- His Python examples (kyfromabove-on-aws-examples) provide reference implementations for the R equivalents
- The pz-nacis-2025 repo ("Visualizing landscape change with KyFromAbove lidar point clouds") aligns directly with aboveR's terrain_change() capabilities
- His KY GIS Conference 2025 workshop could include an aboveR section
- The tile index GeoPackage schema (tilename, key, aws_url, size, geometry) is the contract aboveR's kfa_find_tiles() builds on
- aboveR could be featured as a community tool on the kydgi org when ready
