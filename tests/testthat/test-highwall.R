# Tests for classify_highwall()

dem_path <- system.file("extdata/dem_before.tif", package = "aboveR")

test_that("classify_highwall() returns raster by default", {
  skip_if(dem_path == "", message = "Sample data not installed")
  dem <- terra::rast(dem_path)

  hw <- classify_highwall(dem, slope_threshold = 5)

  expect_s4_class(hw, "SpatRaster")
  expect_equal(names(hw), "highwall")
})

test_that("classify_highwall() returns polygons when requested", {
  skip_if(dem_path == "", message = "Sample data not installed")
  dem <- terra::rast(dem_path)

  hw <- classify_highwall(dem, slope_threshold = 5, as_polygons = TRUE)

  expect_s3_class(hw, "sf")
  expect_true("area_m2" %in% names(hw))
})

test_that("classify_highwall() validates input", {
  expect_error(classify_highwall("not_raster"), "SpatRaster")
})
