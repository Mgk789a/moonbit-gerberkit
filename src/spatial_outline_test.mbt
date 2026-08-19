///|
test "spatial index inserts and queries board shapes" {
  let board = fixture_board(small_fixture())
  let index = spatial_index_for_board(board, cell_size=5.0)
  assert_true(index.entry_count() == board_shape_count(board))
  assert_true(index.cell_count() > 0)
  let hits = index.query(rect2(min_x=0.0, min_y=0.0, max_x=10.0, max_y=10.0))
  assert_true(hits.length() > 0)
  assert_true(index.query_point(point2(x=1.0, y=1.0), radius=2.0).length() > 0)
}

///|
test "spatial index deduplicates cells and supports nearest" {
  let board = fixture_board(tiny_fixture())
  let index = spatial_index_for_board(board, cell_size=100.0)
  assert_true(index.occupied_cells().length() > 0)
  assert_true(index.occupied_cells().length() <= 4)
  assert_true(index.nearest(point2(x=0.0, y=0.0), limit=2).length() <= 2)
  assert_true(
    index
    .layer_query(0, rect2(min_x=0.0, min_y=0.0, max_x=100.0, max_y=100.0))
    .length() >
    0,
  )
  assert_true(index.shape_query(0, 0) is Some(_))
}

///|
test "spatial index overlap pairs are stable" {
  let board = board_from_layers([
    layer(name="F.Cu", kind=copper_layer_kind(), unit=millimeter_unit(), shapes=[
      shape_pad(x=1.0, y=1.0, diameter=1.0),
      shape_pad(x=1.0, y=1.0, diameter=1.0),
      shape_pad(x=10.0, y=10.0, diameter=1.0),
    ]),
  ])
  let pairs = spatial_index_for_board(board, cell_size=2.0).overlap_pairs()
  assert_true(pairs.length() >= 1)
  assert_true(pairs.all(pair => pair.0.shape_index < pair.1.shape_index))
}

///|
test "outline analysis extracts rectangle from mechanical layer" {
  let layer = fixture_rectangle_layer(
    "Edge.Cuts",
    mechanical_layer_kind(),
    20.0,
    10.0,
  )
  let analysis = analyze_outline(board_from_layers([layer]))
  assert_true(analysis.loop_count() >= 1)
  assert_true(analysis.bounds is Some(_))
  assert_true(analysis.outer_area > 0.0)
  assert_true(analysis.largest_outer() is Some(_))
  assert_true(analysis.contains(point2(x=10.0, y=5.0)))
  assert_true(!analysis.contains(point2(x=30.0, y=5.0)))
}

///|
test "outline open and invalid contours are reported" {
  let open = board_from_layers([
    layer(
      name="Edge.Cuts",
      kind=mechanical_layer_kind(),
      unit=millimeter_unit(),
      shapes=[
        shape_segment(x1=0.0, y1=0.0, x2=1.0, y2=0.0, width=0.1),
        shape_segment(x1=1.0, y1=0.0, x2=1.0, y2=1.0, width=0.1),
      ],
    ),
  ])
  let analysis = analyze_outline(open)
  assert_true(analysis.open_contours().length() >= 1)
  assert_true(!analysis.is_valid)
  assert_true(analysis.warnings.length() >= 1)
}

///|
test "outline conversion returns region and segments" {
  let contour = outline_from_rectangle(
    rect2(min_x=0.0, min_y=0.0, max_x=4.0, max_y=3.0),
  )
  assert_true(contour.area() == 12.0)
  let region = outline_to_region(contour)
  let segments = outline_to_segments(contour, width=0.15)
  match region {
    Region(points~) => assert_true(points.length() == 4)
    _ => fail("expected region")
  }
  assert_true(segments.length() == 4)
  assert_true(contour.reversed().area() == contour.area())
}
