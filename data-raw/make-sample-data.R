#!/usr/bin/env Rscript
# Generate bundled sample data for aboveR examples and tests

library(terra)
library(sf)

set.seed(42)

nr <- 50L
nc <- 50L
x <- matrix(0, nrow = nr, ncol = nc)
for (i in seq_len(nr)) {
  for (j in seq_len(nc)) {
    x[i, j] <- 300 + (i * 0.5) + (j * 0.3) +
      5 * sin(i * pi / 25) * cos(j * pi / 25) +
      rnorm(1, 0, 0.3)
  }
}
dem_before <- rast(x, extent = ext(0, 500, 0, 500), crs = "EPSG:32617")
names(dem_before) <- "elevation"

y <- x
for (i in 15:35) {
  for (j in 15:35) {
    y[i, j] <- x[i, j] - runif(1, 2, 8)
  }
}
for (i in 38:48) {
  for (j in 38:48) {
    y[i, j] <- x[i, j] + runif(1, 1, 5)
  }
}
dem_after <- rast(y, extent = ext(0, 500, 0, 500), crs = "EPSG:32617")
names(dem_after) <- "elevation"

ref_vals <- matrix(310, nrow = nr, ncol = nc)
dem_reference <- rast(ref_vals, extent = ext(0, 500, 0, 500), crs = "EPSG:32617")
names(dem_reference) <- "elevation"

writeRaster(dem_before, "inst/extdata/dem_before.tif", overwrite = TRUE)
writeRaster(dem_after, "inst/extdata/dem_after.tif", overwrite = TRUE)
writeRaster(dem_reference, "inst/extdata/dem_reference.tif", overwrite = TRUE)

zones <- st_sf(
  zone_id = c("zone_A", "zone_B"),
  geometry = st_sfc(
    st_polygon(list(matrix(c(50,50, 250,50, 250,250, 50,250, 50,50), ncol = 2, byrow = TRUE))),
    st_polygon(list(matrix(c(250,250, 450,250, 450,450, 250,450, 250,250), ncol = 2, byrow = TRUE))),
    crs = "EPSG:32617"
  )
)
st_write(zones, "inst/extdata/zones.gpkg", delete_dsn = TRUE, quiet = TRUE)

profile_line <- st_sf(
  id = 1L,
  geometry = st_sfc(
    st_linestring(matrix(c(50, 250, 450, 250), ncol = 2, byrow = TRUE)),
    crs = "EPSG:32617"
  )
)
st_write(profile_line, "inst/extdata/profile_line.gpkg", delete_dsn = TRUE, quiet = TRUE)

site_boundary <- st_sf(
  id = 1L,
  geometry = st_sfc(
    st_polygon(list(matrix(c(
      100, 100, 400, 100, 400, 400, 100, 400, 100, 100
    ), ncol = 2, byrow = TRUE))),
    crs = "EPSG:32617"
  )
)
st_write(site_boundary, "inst/extdata/boundary.gpkg", delete_dsn = TRUE, quiet = TRUE)

cat("Sample data created successfully!\n")
cat(paste(list.files("inst/extdata/"), collapse = "\n"), "\n")
