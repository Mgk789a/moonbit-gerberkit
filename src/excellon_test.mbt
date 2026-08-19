///|
test "excellon parses tools and drill hits" {
  let text = "M48\nMETRIC,TZ\nT1C0.8\nT2C0.4\n%\nT1\nX1Y2\nX3Y4\nT2\nX5Y6\nM30"
  let document = parse_excellon_document(text, name="PTH.drl")
  assert_true(document.layer.kind is Drill)
  assert_true(document.tool_count() == 2)
  assert_true(document.hits == 3)
  assert_true(document.layer.shapes.length() == 3)
  assert_true(document.tool(2) is Some(_))
}

///|
test "excellon parses inch and explicit decimal coordinates" {
  let document = parse_excellon_document(
    "M48\nINCH,LZ\nT1C0.0315\n%\nT1\nX1.000Y2.000\nM30",
  )
  assert_true(document.unit is Inch)
  match document.layer.shapes[0] {
    DrillHit(x~, y~, diameter~) => {
      assert_true(x == 25.4)
      assert_true(y == 50.8)
      assert_true(approx_equal(diameter, 0.8001, epsilon=0.000001))
    }
    _ => fail("expected drill hit")
  }
}

///|
test "excellon detects unknown selected tool" {
  let document = parse_excellon_document("M48\nMETRIC\n%\nT9\nX1Y1\nM30")
  assert_true(document.diagnostics.any(item => item.code == "unknown-tool"))
  assert_true(document.hits == 1)
}

///|
test "excellon supports absolute and incremental modes" {
  let document = parse_excellon_document(
    "M48\nMETRIC\nT1C0.8\n%\nT1\nG90\nX1Y1\nG91\nX1Y0\nX0Y2\nM30",
  )
  assert_true(document.hits == 3)
  match document.layer.shapes[2] {
    DrillHit(x~, y~, ..) => {
      assert_true(x == 2.0)
      assert_true(y == 3.0)
    }
    _ => fail("expected incremental drill")
  }
}

///|
test "excellon routes a slot into a segment" {
  let text = "M48\nMETRIC\nT1C0.8\n%\nT1\nG85\nX1Y1\nX5Y1\nG05\nM30"
  let document = parse_excellon_document(text)
  assert_true(document.slots >= 1)
  assert_true(
    document.layer.shapes.any(shape => {
      match shape {
        Segment(width=0.8, ..) => true
        _ => false
      }
    }),
  )
}

///|
test "excellon format handles suppressed digits" {
  let leading = excellon_format(
    integer_digits=2,
    decimal_digits=4,
    zero_mode=excellon_leading_zero_mode(),
    unit=millimeter_unit(),
  )
  let trailing = excellon_format(
    integer_digits=2,
    decimal_digits=4,
    zero_mode=excellon_trailing_zero_mode(),
    unit=millimeter_unit(),
  )
  assert_true(leading.parse_number("001250") is Some(0.125))
  assert_true(trailing.parse_number("1250") is Some(12.5))
  assert_true(leading.scale() == 10000.0)
}

///|
test "excellon JSON contains tools and summary" {
  let document = parse_excellon_document(
    "M48\nMETRIC\nT1C0.8\n%\nT1\nX1Y2\nM30",
  )
  let json = excellon_to_json(document, include_shapes=true)
  assert_true(json.contains("\"tools\""))
  assert_true(json.contains("\"summary\""))
  assert_true(json.contains("\"layer\""))
}
