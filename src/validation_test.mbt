///|
test "validation accepts normal fixture input" {
  let gerber = validate_gerber(fixture_gerber(small_fixture()))
  let excellon = validate_excellon(fixture_excellon(small_fixture()))
  assert_true(gerber.is_valid())
  assert_true(excellon.is_valid())
  assert_true(gerber.records > 10)
  assert_true(excellon.shapes > 0)
  assert_true(validation_status_name(gerber.status) != "invalid")
}

///|
test "validation rejects empty and oversized input" {
  let options = strict_validation_options()
  let empty = validate_gerber("", options~)
  assert_true(!empty.is_valid())
  assert_true(empty.error_count() >= 1)
  let oversized = validate_gerber("X1Y1D02*X2Y2D01*M02*", options~)
  assert_true(oversized.error_count() >= 1)
}

///|
test "validation reports malformed coordinates" {
  let options = default_validation_options()
  let result = validate_gerber("%MOMM*%XbadY2D01*", options~)
  assert_true(result.issues.any(issue => issue.code == "invalid-coordinate"))
  assert_true(result.summary().contains("records="))
}

///|
test "validation normalizers remove comments and whitespace" {
  let gerber = normalize_gerber("%MOMM*%G04 comment*\n%X1Y2D02*")
  let excellon = normalize_excellon("; comment\nM48\n METRIC \n")
  assert_true(!gerber.contains("comment"))
  assert_true(gerber.contains("MOMM"))
  assert_true(excellon.contains("M48"))
  assert_true(!excellon.contains(" comment"))
}

///|
test "board validation maps DFM severities" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_segment(x1=0.0, y1=0.0, x2=1.0, y2=0.0, width=0.01),
    ]),
  ])
  let result = validate_board(board)
  assert_true(result.issues.length() > 0)
  assert_true(result.issues.any(issue => issue.severity is DfmError))
  assert_true(result.issues.all(issue => issue.format().contains(issue.code)))
}

///|
test "validation issue formatting handles optional locations" {
  let issue = validation_issue(
    "code",
    "message",
    dfm_warning(),
    Some(4),
    Some(2),
  )
  assert_true(issue.format().contains("4:2"))
  assert_true(issue.severity_name() == "warning")
}
