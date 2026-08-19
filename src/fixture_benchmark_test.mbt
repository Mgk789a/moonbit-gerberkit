///|
test "fixture sizes are monotonic and named" {
  assert_true(
    fixture_size_count(tiny_fixture()) < fixture_size_count(small_fixture()),
  )
  assert_true(
    fixture_size_count(small_fixture()) < fixture_size_count(medium_fixture()),
  )
  assert_true(fixture_size_name(large_fixture()) == "large")
  assert_true(tiny_fixture() is TinyFixture)
  assert_true(large_fixture() is LargeFixture)
}

///|
test "generated fixtures are parseable" {
  let gerber = fixture_gerber(tiny_fixture())
  let excellon = fixture_excellon(tiny_fixture())
  assert_true(validate_gerber(gerber).is_valid())
  assert_true(validate_excellon(excellon).is_valid())
  assert_true(parse_gerber(gerber).shapes.length() > 0)
  assert_true(parse_excellon(excellon).shapes.length() > 0)
}

///|
test "benchmark suite produces operation evidence" {
  let parse = benchmark_parse(tiny_fixture(), iterations=1)
  let drill = benchmark_excellon(tiny_fixture(), iterations=1)
  let dfm = benchmark_dfm(tiny_fixture(), iterations=1)
  let render = benchmark_render(tiny_fixture(), iterations=1)
  assert_true(parse.operations > 0)
  assert_true(drill.operations > 0)
  assert_true(dfm.operations > 0)
  assert_true(render.operations > 0)
  assert_true(parse.summary().contains("gerber-parse"))
}

///|
test "benchmark suite has stable report shape" {
  let suite = run_benchmark_suite(tiny_fixture(), iterations=1)
  assert_true(suite.results.length() == 4)
  assert_true(suite.total_ticks() >= 0)
  assert_true(suite.total_operations() > 0)
  assert_true(suite.summary().contains("fixture=tiny"))
  assert_true(suite.to_json().contains("\"results\""))
  assert_true(suite.to_markdown().contains("Benchmark"))
  assert_true(benchmark_smoke())
}

///|
test "fixture board includes the expected manufacturing layers" {
  let board = fixture_board(small_fixture(), seed=99)
  assert_true(board.layers.length() == 3)
  assert_true(board.layers[0].kind is Copper)
  assert_true(board.layers[1].kind is Drill)
  assert_true(board.layers[2].kind is Mechanical)
  assert_true(board_shape_count(board) > 20)
}
