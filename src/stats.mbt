///|
pub struct LayerStats {
  name : String
  kind : String
  shapes : Int
  segments : Int
  pads : Int
  drills : Int
  regions : Int
}

///|
pub fn layer_stats(layer : Layer) -> LayerStats {
  let mut segments = 0
  let mut pads = 0
  let mut drills = 0
  let mut regions = 0
  for shape in layer.shapes {
    match shape {
      Segment(..) => segments += 1
      Pad(..) | Flash(..) => pads += 1
      DrillHit(..) => drills += 1
      Region(..) => regions += 1
    }
  }
  {
    name: layer.name,
    kind: kind_to_string(layer.kind),
    shapes: layer.shapes.length(),
    segments,
    pads,
    drills,
    regions,
  }
}

///|
pub fn board_stats(board : Board) -> Array[LayerStats] {
  board.layers.map(layer_stats)
}

///|
pub fn issue_count(report : Report, severity~ : String) -> Int {
  report.issues.filter(issue => issue.severity == severity).length()
}
