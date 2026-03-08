# highwall — aboveR
# Highwall classification from slope analysis

#' Classify Highwall Areas from a DEM
#'
#' Identifies steep terrain faces (highwalls) typical of surface mining
#' operations by computing slope from a DEM and classifying cells that
#' exceed a slope threshold. Returns a binary raster and optionally
#' vectorised polygons of highwall zones.
#'
#' @param dem A [terra::SpatRaster] representing the terrain surface.
#' @param slope_threshold Numeric. Minimum slope in degrees to classify
#'   as highwall. Default `60`.
#' @param min_area Numeric. Minimum contiguous area (in map units squared)
#'   for a highwall zone. Smaller patches are removed. Default `0`
#'   (keep all).
#' @param as_polygons Logical. Return vectorised polygons instead of a
#'   raster? Default `FALSE`.
#'
#' @returns If `as_polygons = FALSE`, a [terra::SpatRaster] with values
#'   1 (highwall) and `NA` (non-highwall). If `as_polygons = TRUE`, an
#'   [sf] data frame of highwall polygons with an `area_m2` column.
#'
#' @export
#'
#' @examples
#' dem <- terra::rast(system.file("extdata/dem_before.tif", package = "aboveR"))
#' hw <- classify_highwall(dem, slope_threshold = 5)
#' terra::plot(hw)
classify_highwall <- function(dem, slope_threshold = 60, min_area = 0,
                              as_polygons = FALSE) {
  validate_raster(dem, "dem")

  slp <- terra::terrain(dem, v = "slope", unit = "degrees")
  hw <- terra::classify(
    slp,
    rcl = matrix(c(-Inf, slope_threshold, NA,
                    slope_threshold, Inf, 1),
                 ncol = 3, byrow = TRUE)
  )
  names(hw) <- "highwall"

  if (min_area > 0) {
    patches <- terra::patches(hw, directions = 8)
    freq_tbl <- terra::freq(patches)
    ca <- cell_area_m2(dem)
    small_ids <- freq_tbl$value[freq_tbl$count * ca < min_area]
    if (length(small_ids) > 0) {
      hw[patches %in% small_ids] <- NA
    }
  }

  if (as_polygons) {
    polys <- terra::as.polygons(hw, dissolve = TRUE)
    polys_sf <- sf::st_as_sf(polys)
    polys_sf$area_m2 <- as.numeric(sf::st_area(polys_sf))
    return(polys_sf)
  }

  hw
}
