///|
test "dfm finds empty layers and small geometry" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_segment(x1=0.0, y1=0.0, x2=1.0, y2=0.0, width=0.05),
      shape_pad(x=2.0, y=0.0, diameter=0.8),
    ]),
    layer(name="B.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[]),
    layer(name="PTH.drl", kind=drill_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_drill_hit(x=2.0, y=0.0, diameter=0.1),
    ]),
  ])
  let report = run_dfm(board)
  assert_true(report.error_count() >= 1)
  assert_true(report.warning_count() >= 2)
  assert_true(report.findings.any(item => item.rule is EmptyLayerRule))
  assert_true(report.findings.any(item => item.rule is MinimumWidthRule))
  assert_true(report.findings.any(item => item.rule is MinimumDrillRule))
}

///|
test "dfm validates regions and non finite values" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_region(points=[(0.0, 0.0), (4.0, 4.0), (0.0, 4.0), (4.0, 0.0)]),
      shape_pad(x=not_a_number_value(), y=0.0, diameter=1.0),
    ]),
  ])
  let report = run_dfm(board)
  assert_true(report.findings.any(item => item.rule is RegionValidityRule))
  assert_true(report.findings.any(item => item.rule is NonFiniteGeometryRule))
}

///|
test "dfm catches crossing traces and duplicates" {
  let duplicate = shape_segment(x1=0.0, y1=0.0, x2=5.0, y2=0.0, width=0.2)
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      duplicate,
      duplicate,
      shape_segment(x1=2.5, y1=-1.0, x2=2.5, y2=1.0, width=0.2),
    ]),
  ])
  let report = run_dfm(board)
  assert_true(report.findings.any(item => item.rule is DuplicateShapeRule))
  assert_true(report.findings.any(item => item.rule is MinimumClearanceRule))
}

///|
test "dfm checks board size and required layers" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_segment(x1=0.0, y1=0.0, x2=2000.0, y2=0.0, width=0.2),
    ]),
  ])
  let report = run_dfm(board, config=strict_dfm_config())
  assert_true(report.findings.any(item => item.rule is BoardSizeRule))
  assert_true(report.findings.any(item => item.rule is MissingDrillLayerRule))
  assert_true(report.findings.any(item => item.rule is OutlineClosedRule))
}

///|
test "dfm annular ring compares pad and drill at same location" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_pad(x=1.0, y=1.0, diameter=0.8),
    ]),
    layer(name="PTH.drl", kind=drill_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_drill_hit(x=1.0, y=1.0, diameter=0.7),
    ]),
  ])
  let report = run_dfm(board)
  assert_true(report.findings.any(item => item.rule is AnnularRingRule))
}

///|
test "dfm report converts findings to issues and summaries" {
  let report = run_dfm(fixture_board(small_fixture()))
  assert_true(report.summary().contains("layers="))
  assert_true(report.to_issues().length() == report.findings.length())
  let counts = finding_counts(report.findings)
  assert_true(counts.0 + counts.1 + counts.2 == report.findings.length())
  for finding in report.findings {
    assert_true(finding.format().contains(finding.rule_name()))
  }
}

///|
test "legacy check uses the expanded rule engine" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_segment(x1=0.0, y1=0.0, x2=1.0, y2=0.0, width=0.01),
    ]),
  ])
  let issues = check(board, min_width=0.1, min_drill=0.2)
  assert_true(issues.any(issue => issue.rule == "minimum-width"))
  assert_true(report(board).issues.length() >= issues.length())
}
