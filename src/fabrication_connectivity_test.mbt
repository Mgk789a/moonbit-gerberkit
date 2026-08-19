///|
test "fabrication profiles expose deterministic manufacturing policy" {
  let catalog = fabrication_profile_catalog()
  assert_true(catalog.length() == 5)
  assert_true(prototype_fabrication_profile().class_name() == "prototype")
  assert_true(standard_fabrication_profile().material_name() == "FR-4")
  assert_true(aluminum_fabrication_profile().material_name() == "aluminum")
  assert_true(
    flexible_fabrication_profile().material_name() == "flexible-polyimide",
  )
  assert_true(fabrication_catalog_markdown().contains("fine-pitch"))
}

///|
test "fabrication assessment reports dimensions, drills, and checks" {
  let board = fixture_board(small_fixture())
  let assessment = assess_fabrication(
    board,
    profile=standard_fabrication_profile(),
  )
  assert_true(assessment.check_count() >= 4)
  assert_true(assessment.board_area > 0.0)
  assert_true(assessment.copper_area > 0.0)
  assert_true(assessment.drill_count > 0)
  assert_true(assessment.score >= 0.0 && assessment.score <= 100.0)
  assert_true(assessment.summary().contains("profile=standard-fr4"))
  assert_true(assessment.to_json().contains("minimum-trace-width"))
  assert_true(assessment.to_text().contains("checks="))
}

///|
test "fabrication assessment rejects empty geometry without crashing" {
  let assessment = assess_fabrication(
    empty_board(),
    profile=prototype_fabrication_profile(),
  )
  assert_true(!assessment.passed)
  assert_true(assessment.failed_check_count() >= 2)
  assert_true(assessment.to_text().contains("board-size"))
}

///|
test "best fabrication profile is deterministic across the catalog" {
  let board = fixture_board(tiny_fixture())
  let best = best_fabrication_profile(board)
  let assessments = compare_fabrication_profiles(
    board,
    fabrication_profile_catalog(),
  )
  assert_true(best.name() != "")
  assert_true(assessments.length() == 5)
  assert_true(assessments.all(item => item.score >= 0.0))
}

///|
test "connectivity graph joins segment endpoints and nearby pads" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_segment(x1=0.0, y1=0.0, x2=10.0, y2=0.0, width=0.2),
      shape_pad(x=10.0, y=0.0, diameter=1.0),
      shape_pad(x=20.0, y=0.0, diameter=1.0),
    ]),
  ])
  let graph = build_connectivity(board, tolerance=0.0001)
  assert_true(graph.node_count() == 4)
  assert_true(graph.internal_link_count() == 1)
  assert_true(graph.geometric_link_count() == 1)
  assert_true(graph.component_count() == 2)
  assert_true(graph.isolated_node_count() == 1)
  assert_true(!graph.has_open_trace_endpoints())
  assert_true(graph.summary().contains("components=2"))
  assert_true(graph.to_json().contains("trace-endpoint"))
  assert_true(graph.to_csv().contains("from,to,distance"))
}

///|
test "connectivity tolerance clamps negative values and separates layers" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_pad(x=1.0, y=1.0, diameter=0.5),
      shape_pad(x=1.0005, y=1.0, diameter=0.5),
    ]),
    layer(name="PTH.drl", kind=drill_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_drill_hit(x=1.0005, y=1.0, diameter=0.3),
    ]),
  ])
  let separated = build_connectivity(board, tolerance=-1.0)
  assert_true(separated.geometric_link_count() == 0)
  let joined = build_connectivity(board, tolerance=0.001)
  assert_true(joined.geometric_link_count() == 1)
  assert_true(joined.drill_terminal_count() == 1)
  assert_true(joined.layer_node_count(0) == 2)
  assert_true(joined.layer_link_count(1) == 0)
  assert_true(joined.layer_summary(0).contains("layer=0"))
}

///|
test "connectivity handles empty regions and open traces" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_region(points=[]),
      shape_segment(x1=0.0, y1=0.0, x2=2.0, y2=0.0, width=0.1),
    ]),
  ])
  let graph = connectivity_from_board(board)
  assert_true(graph.node_count() == 2)
  assert_true(graph.link_count() == 1)
  assert_true(!graph.has_open_trace_endpoints())
  assert_true(graph.component_count() == 1)
}
