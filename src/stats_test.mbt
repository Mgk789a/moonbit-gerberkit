///|
test "layer statistics are deterministic" {
  let layer = parse_gerber("%MOMM*%ADD10C,0.25*%X1Y1D02*X5Y1D01*X2Y2D03*")
  let stats = layer_stats(layer)
  assert_true(stats.segments == 1)
  assert_true(stats.pads == 1)
  assert_true(stats.shapes == 2)
}
