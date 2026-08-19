///|
test "pipeline detects Gerber and produces a complete result" {
  let text = fixture_gerber(small_fixture())
  let result = process_text(text, source_name="fixture.gbr")
  assert_true(result.input_kind is GerberInput)
  assert_true(result.input_size == text.length())
  assert_true(result.board.layers.length() == 1)
  assert_true(result.validation.records > 0)
  assert_true(result.outline is Some(_))
  assert_true(result.summary().contains("fixture.gbr"))
  assert_true(result.to_json().contains("\"validation\""))
  assert_true(result.to_sarif().contains("\"runs\""))
}

///|
test "pipeline detects Excellon and renders text formats" {
  let result = process_text(
    fixture_excellon(tiny_fixture()),
    source_name="PTH.drl",
  )
  assert_true(result.input_kind is ExcellonInput)
  assert_true(result.board.layers[0].kind is Drill)
  assert_true(pipeline_render(result, text_pipeline_format()).contains("dfm"))
  assert_true(
    pipeline_render(result, csv_pipeline_format()).contains("severity,rule"),
  )
  assert_true(
    pipeline_render(result, html_pipeline_format()).contains("<html>"),
  )
}

///|
test "pipeline unknown input is reported without crashing" {
  let result = process_text("not a manufacturing file", source_name="input.bin")
  assert_true(result.input_kind is UnknownInput)
  assert_true(result.validation.warning_count() >= 1)
  assert_true(result.error_count() == 0)
  assert_true(pipeline_format_from_name("svg") is SvgOutput)
  assert_true(pipeline_format_from_name("unknown") is JsonOutput)
}

///|
test "pipeline batches layers and preserves input size" {
  let inputs = [
    ("F.Cu", fixture_gerber(tiny_fixture())),
    ("PTH.drl", fixture_excellon(tiny_fixture())),
  ]
  let result = process_many(inputs)
  assert_true(result.input_size > 0)
  assert_true(result.board.layers.length() == 2)
  assert_true(result.board.layers.any(layer => layer.kind is Copper))
  assert_true(result.board.layers.any(layer => layer.kind is Drill))
  assert_true(pipeline_report_many(inputs).contains("\"board\""))
}

///|
test "board metrics report class counts and totals" {
  let board = fixture_board(medium_fixture())
  let metrics = board_metrics(board)
  assert_true(metrics.shape_count == board_shape_count(board))
  assert_true(metrics.layers.length() == 3)
  assert_true(metrics.total_trace_length > 0.0)
  assert_true(metrics.total_copper_area > 0.0)
  assert_true(metrics.total_drill_area > 0.0)
  assert_true(metrics.summary().contains("density="))
  assert_true(metrics.to_json().contains("\"layers\""))
}

///|
test "shape metrics cover every shape constructor" {
  let shapes : Array[Shape] = [
    shape_segment(x1=0.0, y1=0.0, x2=3.0, y2=4.0, width=0.2),
    shape_pad(x=0.0, y=0.0, diameter=1.0),
    shape_flash(x=0.0, y=0.0, aperture=10),
    shape_drill_hit(x=0.0, y=0.0, diameter=0.8),
    shape_region(points=[(0.0, 0.0), (2.0, 0.0), (0.0, 2.0)]),
  ]
  assert_true(shape_class(shapes[0]) is TraceShape)
  assert_true(shape_class(shapes[1]) is PadShape)
  assert_true(shape_class(shapes[2]) is FlashShape)
  assert_true(shape_class(shapes[3]) is DrillShape)
  assert_true(shape_class(shapes[4]) is RegionShape)
  assert_true(shape_length(shapes[0]) == 5.0)
  assert_true(shape_area(shapes[4]) == 2.0)
}

///|
test "board transforms and merges remain deterministic" {
  let board = fixture_board(tiny_fixture())
  let moved = board_translate(board, point2(x=2.0, y=3.0))
  let scaled = board_scale(board, 2.0)
  assert_true(board_shape_count(moved) == board_shape_count(board))
  assert_true(board_shape_count(scaled) == board_shape_count(board))
  assert_true(
    board_merge(board, moved).layers.length() >= board.layers.length(),
  )
  assert_true(
    board_without_empty_layers(board).layers.length() == board.layers.length(),
  )
  assert_true(board_layer_named(board, "F.Cu") is Some(_))
}
