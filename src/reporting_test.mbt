///|
test "json escaping protects report fields" {
  let escaped = json_escape("quote=\" slash=\\ line\n")
  assert_true(escaped.contains("\\\""))
  assert_true(escaped.contains("\\\\"))
  assert_true(escaped.contains("\\n"))
  assert_true(json_string("hello") == "\"hello\"")
}

///|
test "board and shape JSON include geometry" {
  let board = board_from_layers([
    layer(name="F\"Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_segment(x1=0.0, y1=0.0, x2=1.0, y2=2.0, width=0.2),
      shape_pad(x=1.0, y=2.0, diameter=0.8),
      shape_region(points=[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0)]),
    ]),
  ])
  let json = board_to_json(board, include_shapes=true)
  assert_true(json.contains("segment"))
  assert_true(json.contains("pad"))
  assert_true(json.contains("region"))
  assert_true(json.contains("F\\\"Cu"))
}

///|
test "report JSON and SARIF are machine readable strings" {
  let board = fixture_board(tiny_fixture())
  let report = report(board)
  let json = report_to_json(report, include_shapes=true)
  assert_true(json.contains("\"board\""))
  assert_true(json.contains("\"issues\""))
  let dfm = run_dfm(board)
  let sarif = dfm_to_sarif(dfm)
  assert_true(sarif.contains("\"version\":\"2.1.0\""))
  assert_true(sarif.contains("\"runs\""))
  assert_true(dfm_to_csv(dfm).contains("severity,rule"))
}

///|
test "text and github annotation outputs enumerate findings" {
  let report = run_dfm(fixture_board(tiny_fixture()))
  let text = dfm_to_text(report)
  let annotations = dfm_to_github_annotations(report)
  assert_true(text.contains("layers="))
  if report.findings.length() > 0 {
    assert_true(annotations.contains("::"))
  }
}

///|
test "document JSON includes parsed source evidence" {
  let document = parse_gerber_document(
    "%MOMM*%ADD10C,0.2*%D10*X1Y1D02*X2Y1D01*",
  )
  let json = document_to_json(document, include_shapes=true)
  assert_true(json.contains("records="))
  assert_true(json.contains("\"aperture_count\":1"))
  assert_true(json.contains("\"shapes\""))
}
