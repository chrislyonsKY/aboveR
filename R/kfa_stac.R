# kfa_stac — aboveR
# STAC catalog access for KyFromAbove (when catalog is live)
# Reference: github.com/ianhorn/kyfromabove-stac

#' Search KyFromAbove STAC Catalog
#'
#' Queries the KyFromAbove STAC catalog for items matching an area
#' of interest and product type. Requires the 'rstac' package.
#'
#' @param aoi An [sf] object or numeric bbox.
#' @param collection Character. STAC collection ID.
#' @param datetime Character. ISO 8601 datetime or range.
#'
#' @returns A tibble of STAC items with asset URLs.
#'
#' @export
kfa_stac_search <- function(aoi, collection = NULL, datetime = NULL) {
  if (!requireNamespace("rstac", quietly = TRUE)) {
    stop(
      "Package 'rstac' is required for STAC catalog access.\n",
      "Install it with: install.packages('rstac')",
      call. = FALSE
    )
  }
  # TODO: Implement when STAC catalog is live
  stop("KyFromAbove STAC catalog not yet available. Use kfa_find_tiles() with method = 'index'.")
}
