///|
test "advanced parser handles modal draw and flash records" {
  let text = "%FSLAX24Y24*%MOMM*%ADD10C,0.3*%D10*X1Y1D02*X5Y1D01*X5Y4D01*X2Y2D03*M02*"
  let document = parse_gerber_document(text, name="F.Cu")
  assert_true(document.layer.kind is Copper)
  assert_true(document.layer.shapes.length() == 3)
  assert_true(document.draws == 2)
  assert_true(document.flashes == 1)
  assert_true(document.apertures.count() == 1)
  assert_true(document.error_count() == 0)
}

///|
test "advanced parser uses inch units" {
  let document = parse_gerber_document(
    "%FSLAX24Y24*%MOIN*%ADD10C,0.1*%D10*X010000Y010000D02*X020000Y010000D01*",
  )
  match document.layer.shapes[0] {
    Segment(x1~, y1~, x2~, y2=_, width~) => {
      assert_true(x1 == 25.4)
      assert_true(y1 == 25.4)
      assert_true(x2 == 50.8)
      assert_true(width == 2.54)
    }
    _ => fail("expected segment")
  }
}

///|
test "advanced parser handles closed region" {
  let text = "%MOMM*%G36*X0Y0D02*X10Y0D01*X10Y10D01*X0Y10D01*X0Y0D01*G37*"
  let document = parse_gerber_document(text, name="Edge.Cuts")
  assert_true(document.regions == 1)
  assert_true(document.layer.shapes.length() == 1)
  match document.layer.shapes[0] {
    Region(points~) => assert_true(points.length() >= 3)
    _ => fail("expected region")
  }
}

///|
test "advanced parser reports unterminated region" {
  let document = parse_gerber_document("%G36*X0Y0D02*X1Y0D01*X1Y1D01*")
  assert_true(document.warning_count() >= 1)
  assert_true(
    document.diagnostics.any(item => item.code == "unterminated-region"),
  )
}

///|
test "advanced parser understands circular interpolation" {
  let text = "%FSLAX24Y24*%MOMM*%ADD10C,0.2*%D10*X000000Y000000D02*G03X100000Y000000I050000J000000D01*"
  let document = parse_gerber_document(text)
  assert_true(document.draws == 1)
  assert_true(document.layer.shapes.length() > 1)
  assert_true(
    document.layer.shapes.all(shape => {
      match shape {
        Segment(..) => true
        _ => false
      }
    }),
  )
}

///|
test "aperture table supports circle rectangle obround polygon" {
  let table = new_aperture_table()
  table.add_or_replace(parse_aperture_definition(10, "C,1.0"))
  table.add_or_replace(parse_aperture_definition(11, "R,2.0X1.0"))
  table.add_or_replace(parse_aperture_definition(12, "O,3.0X1.0"))
  table.add_or_replace(parse_aperture_definition(13, "P,2.0X6X15"))
  assert_true(table.count() == 4)
  assert_true(table.require(10).area() > 0.0)
  assert_true(table.require(11).outer_height() == 1.0)
  assert_true(table.require(12).area() > 0.0)
  assert_true(table.require(13).is_known())
}

///|
test "aperture macros retain primitives and bounds" {
  let aperture_macro_value = aperture_macro(name="TEST", primitives=[
    parse_macro_primitive("1,1,2,0,0"),
    parse_macro_primitive("4,1,3,0,0,2,0,1,1"),
  ])
  assert_true(aperture_macro_value.primitive_count() == 2)
  assert_true(aperture_macro_value.bounds() is Some(_))
}

///|
test "parser accepts missing coordinates as modal moves" {
  let document = parse_gerber_document(
    "%FSLAX24Y24*%ADD10C,0.2*%D10*X010000Y010000D02*X020000D01*Y030000D01*",
  )
  assert_true(document.layer.shapes.length() == 2)
  match document.layer.shapes[1] {
    Segment(x2=_, y2=3.0, ..) => ()
    _ => fail("expected modal Y update")
  }
}

///|
test "parser JSON exposes diagnostics and apertures" {
  let document = parse_gerber_document("%AD10C,0.2*%D10*X1Y1D02*")
  let json = document_to_json(document, include_shapes=true)
  assert_true(json.contains("aperture_count"))
  assert_true(json.contains("diagnostics"))
  assert_true(json.contains("shape_count"))
}
