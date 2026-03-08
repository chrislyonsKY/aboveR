# Test that all exported functions exist and are callable

test_that("all core analysis functions are exported", {
  expect_true(is.function(terrain_change))
  expect_true(is.function(change_by_zone))
  expect_true(is.function(estimate_volume))
  expect_true(is.function(impoundment_curve))
  expect_true(is.function(terrain_profile))
  expect_true(is.function(boundary_terrain_profile))
  expect_true(is.function(classify_highwall))
  expect_true(is.function(reclamation_progress))
  expect_true(is.function(surface_roughness))
  expect_true(is.function(detect_channels))
  expect_true(is.function(pond_sedimentation))
})

test_that("all KyFromAbove functions are exported", {
  expect_true(is.function(kfa_find_tiles))
  expect_true(is.function(kfa_tile_index))
  expect_true(is.function(kfa_read_dem))
  expect_true(is.function(kfa_read_pointcloud))
  expect_true(is.function(kfa_read_ortho))
  expect_true(is.function(kfa_stac_search))
})
