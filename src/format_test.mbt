///|
test "format statement changes zero suppression and digits" {
  let current = default_coordinate_format()
  let parsed = parse_format_statement("FSLAX24Y24", current)
  assert_true(parsed.integer_digits == 2)
  assert_true(parsed.decimal_digits == 4)
  assert_true(parsed.zero_suppression is LeadingZeros)
  assert_true(parsed.notation is AbsoluteNotation)
  assert_true(format_name(parsed).contains("FSLAX24Y24"))
}

///|
test "format statement supports incremental trailing zeros" {
  let parsed = parse_format_statement("FSTIX35Y35", default_coordinate_format())
  assert_true(parsed.zero_suppression is TrailingZeros)
  assert_true(parsed.notation is IncrementalNotation)
  assert_true(parsed.integer_digits == 3)
  assert_true(parsed.decimal_digits == 5)
}

///|
test "coordinate format parses decimal and suppressed values" {
  let format = coordinate_format(
    integer_digits=2,
    decimal_digits=4,
    zero_suppression=leading_zero_suppression(),
    notation=absolute_notation(),
    unit=millimeter_unit(),
  )
  assert_true(format.parse_axis("1.25") is Some(1.25))
  assert_true(format.parse_axis("001250") is Some(0.125))
  assert_true(format.parse_axis("-001250") is Some(-0.125))
  assert_true(format.parse_axis("") is None)
}

///|
test "coordinate format converts inches to millimeters" {
  let format = coordinate_format(
    integer_digits=2,
    decimal_digits=4,
    zero_suppression=explicit_zero_suppression(),
    notation=absolute_notation(),
    unit=inch_unit(),
  )
  assert_true(format.parse_axis("1.0") is Some(25.4))
  assert_true(format.format_axis(25.4) == "01.0000")
}

///|
test "gerber state uses absolute coordinates" {
  let state = new_gerber_state()
  state.set_format(
    coordinate_format(
      integer_digits=2,
      decimal_digits=2,
      zero_suppression=explicit_zero_suppression(),
      notation=absolute_notation(),
      unit=millimeter_unit(),
    ),
  )
  match state.parse_point("X1.5Y2.5") {
    Some(point) => assert_true(point.near(point2(x=1.5, y=2.5)))
    None => fail("expected absolute point")
  }
  match state.parse_point("X3.0") {
    Some(point) => assert_true(point.near(point2(x=3.0, y=2.5)))
    None => fail("expected modal point")
  }
  assert_true(state.current == point2(x=3.0, y=2.5))
}

///|
test "gerber state uses incremental coordinates" {
  let state = new_gerber_state()
  state.set_format(
    coordinate_format(
      integer_digits=2,
      decimal_digits=2,
      zero_suppression=explicit_zero_suppression(),
      notation=incremental_notation(),
      unit=millimeter_unit(),
    ),
  )
  ignore(state.parse_point("X1.0Y2.0"))
  ignore(state.parse_point("X0.5Y-1.0"))
  assert_true(state.current == point2(x=1.5, y=1.0))
}

///|
test "operation codes are modal" {
  assert_true(operation_from_code("X1Y2D01") is DrawOperation)
  assert_true(operation_from_code("X1Y2D02") is MoveOperation)
  assert_true(operation_from_code("X1Y2D03") is FlashOperation)
  assert_true(operation_from_code("G36") is RegionMoveOperation)
  assert_true(operation_name(no_operation()) == "none")
}

///|
test "region state collects and clears points" {
  let state = new_gerber_state()
  state.start_region()
  state.append_region_point(point2(x=0.0, y=0.0))
  state.append_region_point(point2(x=2.0, y=0.0))
  let points = state.finish_region()
  assert_true(points.length() == 2)
  assert_true(!state.region_open)
  assert_true(state.region_points.length() == 0)
}
