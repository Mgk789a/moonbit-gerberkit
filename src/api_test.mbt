///|
test "parse and inspect a small Gerber layer" {
  let layer = parse_gerber(
    "%MOMM*%ADD10C,0.25*%X1Y1D02*X5Y1D01*X5Y4D01*X2Y2D03*",
  )
  assert_true(layer.shapes.length() == 3)
  let board = board_from_layers([layer])
  let r = report(board)
  assert_true(r.bbox is Some(_))
  assert_true(to_json(r).contains("copper"))
  assert_true(to_svg(board).contains("<svg"))
}

///|
test "parse Excellon drill hits" {
  let layer = parse_excellon("M48\nMETRIC,TZ\nT1C0.8\nX1Y2\nX3Y4\nM30")
  assert_true(layer.kind is Drill)
  assert_true(layer.shapes.length() == 2)
}
