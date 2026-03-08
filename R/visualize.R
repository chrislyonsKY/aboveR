# visualize — aboveR
# Plot methods and color ramps for change maps (internal)

#' Diverging Color Ramp for Change Maps
#'
#' Returns a blue-white-red color ramp centered at zero, suitable for
#' terrain change visualisation. Cut (negative) is blue, fill (positive)
#' is red.
#'
#' @param n Integer. Number of colors.
#' @returns Character vector of hex color values.
#' @noRd
change_colors <- function(n = 100L) {
  grDevices::colorRampPalette(c("#2166AC", "#67A9CF", "#D1E5F0",
                                 "#F7F7F7",
                                 "#FDDBC7", "#EF8A62", "#B2182B"))(n)
}

#' Terrain Color Ramp
#'
#' Green-brown-white hypsometric color ramp for elevation maps.
#'
#' @param n Integer. Number of colors.
#' @returns Character vector of hex color values.
#' @noRd
terrain_colors <- function(n = 100L) {
  grDevices::colorRampPalette(c("#1B7837", "#7FBC41", "#C2A541",
                                 "#A67026", "#8C510A", "#D9D9D9",
                                 "#F5F5F5"))(n)
}
