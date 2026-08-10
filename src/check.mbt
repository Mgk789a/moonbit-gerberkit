///|
pub fn check(
  board : Board,
  min_width? : Double = 0.1,
  min_drill? : Double = 0.2,
) -> Array[Issue] {
  let issues : Array[Issue] = []
  for layer in board.layers {
    if layer.shapes.length() == 0 {
      issues.push({
        rule: "empty-layer",
        severity: "warning",
        message: "layer has no geometry",
        layer: layer.name,
      })
    }
    for shape in layer.shapes {
      match shape {
        Segment(x1=_, y1=_, x2=_, y2=_, width~) if width < min_width =>
          issues.push({
            rule: "minimum-width",
            severity: "error",
            message: "trace width is below the configured limit",
            layer: layer.name,
          })
        DrillHit(x=_, y=_, diameter~) if diameter < min_drill =>
          issues.push({
            rule: "drill-size",
            severity: "warning",
            message: "drill diameter is unusually small",
            layer: layer.name,
          })
        _ => ()
      }
    }
  }
  issues
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
