///|
pub fn check(
  board : Board,
  min_width? : Double = 0.1,
  min_drill? : Double = 0.2,
) -> Array[Issue] {
  let config = {
    min_width,
    min_drill,
    min_clearance: 0.15,
    min_annular_ring: 0.1,
    max_board_width: 1000.0,
    max_board_height: 1000.0,
    require_outline: false,
    require_drill_layer: false,
    check_duplicates: true,
    check_geometry: true,
  }
  check_dfm(board, config~)
}

///|
pub fn report(
  board : Board,
  min_width? : Double = 0.1,
  min_drill? : Double = 0.2,
) -> Report {
  {
    board,
    issues: check(board, min_width~, min_drill~),
    bbox: board_bounds(board),
  }
}
