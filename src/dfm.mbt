///|
pub enum DfmSeverity {
  DfmInfo
  DfmWarning
  DfmError
} derive(Debug, Eq)

///|
pub fn dfm_info_severity() -> DfmSeverity {
  DfmInfo
}

///|
pub enum DfmRuleId {
  EmptyLayerRule
  MinimumWidthRule
  MinimumDrillRule
  MinimumClearanceRule
  AnnularRingRule
  BoardSizeRule
  OutlineClosedRule
  RegionValidityRule
  DuplicateShapeRule
  LayerBalanceRule
  NonFiniteGeometryRule
  UnknownApertureRule
  MissingDrillLayerRule
} derive(Debug, Eq)

///|
pub struct DfmConfig {
  min_width : Double
  min_drill : Double
  min_clearance : Double
  min_annular_ring : Double
  max_board_width : Double
  max_board_height : Double
  require_outline : Bool
  require_drill_layer : Bool
  check_duplicates : Bool
  check_geometry : Bool
} derive(Debug)

///|
pub fn default_dfm_config() -> DfmConfig {
  {
    min_width: 0.1,
    min_drill: 0.2,
    min_clearance: 0.15,
    min_annular_ring: 0.1,
    max_board_width: 1000.0,
    max_board_height: 1000.0,
    require_outline: false,
    require_drill_layer: false,
    check_duplicates: true,
    check_geometry: true,
  }
}

///|
pub fn DfmConfig::with_minimums(
  self : DfmConfig,
  min_width? : Double = 0.1,
  min_drill? : Double = 0.2,
  min_clearance? : Double = 0.15,
) -> DfmConfig {
  {
    min_width: if min_width < 0.0 {
      0.0
    } else {
      min_width
    },
    min_drill: if min_drill < 0.0 {
      0.0
    } else {
      min_drill
    },
    min_clearance: if min_clearance < 0.0 {
      0.0
    } else {
      min_clearance
    },
    min_annular_ring: self.min_annular_ring,
    max_board_width: self.max_board_width,
    max_board_height: self.max_board_height,
    require_outline: self.require_outline,
    require_drill_layer: self.require_drill_layer,
    check_duplicates: self.check_duplicates,
    check_geometry: self.check_geometry,
  }
}

///|
pub fn dfm_severity_name(value : DfmSeverity) -> String {
  match value {
    DfmInfo => "info"
    DfmWarning => "warning"
    DfmError => "error"
  }
}

///|
pub fn dfm_rule_name(value : DfmRuleId) -> String {
  match value {
    EmptyLayerRule => "empty-layer"
    MinimumWidthRule => "minimum-width"
    MinimumDrillRule => "minimum-drill"
    MinimumClearanceRule => "minimum-clearance"
    AnnularRingRule => "annular-ring"
    BoardSizeRule => "board-size"
    OutlineClosedRule => "outline-closed"
    RegionValidityRule => "region-validity"
    DuplicateShapeRule => "duplicate-shape"
    LayerBalanceRule => "layer-balance"
    NonFiniteGeometryRule => "non-finite-geometry"
    UnknownApertureRule => "unknown-aperture"
    MissingDrillLayerRule => "missing-drill-layer"
  }
}

///|
pub struct DfmFinding {
  rule : DfmRuleId
  severity : DfmSeverity
  message : String
  layer : String
  shape_index : Int?
  location : Point2?
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub fn dfm_finding(
  rule : DfmRuleId,
  severity : DfmSeverity,
  message : String,
  layer : String,
  shape_index : Int?,
  location : Point2?,
  measured : Double?,
  limit : Double?,
) -> DfmFinding {
  { rule, severity, message, layer, shape_index, location, measured, limit }
}

///|
pub fn DfmFinding::rule_name(self : DfmFinding) -> String {
  dfm_rule_name(self.rule)
}

///|
pub fn DfmFinding::severity_name(self : DfmFinding) -> String {
  dfm_severity_name(self.severity)
}

///|
pub fn DfmFinding::format(self : DfmFinding) -> String {
  let position = match self.location {
    Some(point) => " at (\{point.x},\{point.y})"
    None => ""
  }
  let value = match (self.measured, self.limit) {
    (Some(measured), Some(limit)) => " measured=\{measured} limit=\{limit}"
    _ => ""
  }
  "\{self.severity_name()} \{self.rule_name()} [\{self.layer}]\{position}: \{self.message}\{value}"
}

///|
pub struct DfmReport {
  findings : Array[DfmFinding]
  config : DfmConfig
  layer_count : Int
  shape_count : Int
  checked_rules : Int
} derive(Debug)

///|
pub fn DfmReport::error_count(self : DfmReport) -> Int {
  self.findings.filter(finding => finding.severity is DfmError).length()
}

///|
pub fn DfmReport::warning_count(self : DfmReport) -> Int {
  self.findings.filter(finding => finding.severity is DfmWarning).length()
}

///|
pub fn DfmReport::info_count(self : DfmReport) -> Int {
  self.findings.filter(finding => finding.severity is DfmInfo).length()
}

///|
pub fn DfmReport::passed(self : DfmReport) -> Bool {
  self.error_count() == 0
}

///|
pub fn DfmReport::summary(self : DfmReport) -> String {
  "layers=\{self.layer_count}, shapes=\{self.shape_count}, rules=\{self.checked_rules}, errors=\{self.error_count()}, warnings=\{self.warning_count()}, infos=\{self.info_count()}"
}

///|
pub fn DfmReport::to_issues(self : DfmReport) -> Array[Issue] {
  self.findings.map(finding => {
    rule: finding.rule_name(),
    severity: finding.severity_name(),
    message: finding.message,
    layer: finding.layer,
  })
}

///|
fn dfm_add(
  findings : Array[DfmFinding],
  rule : DfmRuleId,
  severity : DfmSeverity,
  message : String,
  layer : String,
  index : Int?,
  point : Point2?,
  measured : Double?,
  limit : Double?,
) -> Unit {
  findings.push(
    dfm_finding(rule, severity, message, layer, index, point, measured, limit),
  )
}

///|
fn shape_point(shape : Shape) -> Point2? {
  match shape {
    Segment(x1~, y1~, ..) => Some(point2(x=x1, y=y1))
    Pad(x~, y~, ..) => Some(point2(x~, y~))
    Flash(x~, y~, ..) => Some(point2(x~, y~))
    DrillHit(x~, y~, ..) => Some(point2(x~, y~))
    Region(points~) => points.get(0).map(pair => point2(x=pair.0, y=pair.1))
  }
}

///|
fn shape_box(shape : Shape) -> Rect2? {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) =>
      Some(
        rect2(
          min_x=min(x1, x2) - width / 2.0,
          min_y=min(y1, y2) - width / 2.0,
          max_x=max(x1, x2) + width / 2.0,
          max_y=max(y1, y2) + width / 2.0,
        ),
      )
    Pad(x~, y~, diameter~) =>
      Some(
        rect2(
          min_x=x - diameter / 2.0,
          min_y=y - diameter / 2.0,
          max_x=x + diameter / 2.0,
          max_y=y + diameter / 2.0,
        ),
      )
    DrillHit(x~, y~, diameter~) =>
      Some(
        rect2(
          min_x=x - diameter / 2.0,
          min_y=y - diameter / 2.0,
          max_x=x + diameter / 2.0,
          max_y=y + diameter / 2.0,
        ),
      )
    Flash(x~, y~, ..) => Some(rect2(min_x=x, min_y=y, max_x=x, max_y=y))
    Region(points~) =>
      polyline(points.map(pair => point2(x=pair.0, y=pair.1)), closed=true).bounds()
  }
}

///|
fn point_segment_distance(
  point : Point2,
  start : Point2,
  end : Point2,
) -> Double {
  let direction = end.sub(start)
  let length_squared = direction.length_squared()
  if length_squared == 0.0 {
    point.distance(start)
  } else {
    let t = clamp(
      point.sub(start).dot(direction) / length_squared,
      low=0.0,
      high=1.0,
    )
    point.distance(start.add(direction.scale(t)))
  }
}

///|
fn segment_distance(
  a1 : Point2,
  a2 : Point2,
  b1 : Point2,
  b2 : Point2,
) -> Double {
  if segments_intersect(a1, a2, b1, b2) {
    0.0
  } else {
    min(
      min(
        point_segment_distance(a1, b1, b2),
        point_segment_distance(a2, b1, b2),
      ),
      min(
        point_segment_distance(b1, a1, a2),
        point_segment_distance(b2, a1, a2),
      ),
    )
  }
}

///|
fn dfm_check_empty_layers(board : Board, findings : Array[DfmFinding]) -> Unit {
  for layer in board.layers {
    if layer.shapes.length() == 0 {
      dfm_add(
        findings,
        EmptyLayerRule,
        DfmWarning,
        "layer has no geometry",
        layer.name,
        None,
        None,
        None,
        None,
      )
    }
  }
}

///|
fn dfm_check_minimum_width(
  board : Board,
  findings : Array[DfmFinding],
  config : DfmConfig,
) -> Unit {
  for layer in board.layers {
    for index, shape in layer.shapes {
      match shape {
        Segment(width~, ..) if width < config.min_width =>
          dfm_add(
            findings,
            MinimumWidthRule,
            DfmError,
            "trace width is below the configured manufacturing limit",
            layer.name,
            Some(index),
            shape_point(shape),
            Some(width),
            Some(config.min_width),
          )
        _ => ()
      }
    }
  }
}

///|
fn dfm_check_minimum_drill(
  board : Board,
  findings : Array[DfmFinding],
  config : DfmConfig,
) -> Unit {
  for layer in board.layers {
    for index, shape in layer.shapes {
      match shape {
        DrillHit(diameter~, ..) if diameter < config.min_drill =>
          dfm_add(
            findings,
            MinimumDrillRule,
            DfmWarning,
            "drill diameter is below the configured manufacturing preference",
            layer.name,
            Some(index),
            shape_point(shape),
            Some(diameter),
            Some(config.min_drill),
          )
        _ => ()
      }
    }
  }
}

///|
fn dfm_check_board_size(
  board : Board,
  findings : Array[DfmFinding],
  config : DfmConfig,
) -> Unit {
  match board_bounds(board) {
    Some(bounds) => {
      let width = bounds.max_x - bounds.min_x
      let height = bounds.max_y - bounds.min_y
      let center = point2(
        x=(bounds.min_x + bounds.max_x) / 2.0,
        y=(bounds.min_y + bounds.max_y) / 2.0,
      )
      if width > config.max_board_width {
        dfm_add(
          findings,
          BoardSizeRule,
          DfmError,
          "board width exceeds the configured limit",
          "board",
          None,
          Some(center),
          Some(width),
          Some(config.max_board_width),
        )
      }
      if height > config.max_board_height {
        dfm_add(
          findings,
          BoardSizeRule,
          DfmError,
          "board height exceeds the configured limit",
          "board",
          None,
          Some(center),
          Some(height),
          Some(config.max_board_height),
        )
      }
    }
    None => ()
  }
}

///|
fn dfm_check_regions(board : Board, findings : Array[DfmFinding]) -> Unit {
  for layer in board.layers {
    for index, shape in layer.shapes {
      match shape {
        Region(points~) => {
          let converted = points.map(pair => point2(x=pair.0, y=pair.1))
          if points.length() < 3 {
            dfm_add(
              findings,
              RegionValidityRule,
              DfmError,
              "region must contain at least three vertices",
              layer.name,
              Some(index),
              None,
              Some(points.length().to_double()),
              Some(3.0),
            )
          } else if polygon_self_intersects(converted) {
            dfm_add(
              findings,
              RegionValidityRule,
              DfmError,
              "region boundary self-intersects",
              layer.name,
              Some(index),
              None,
              None,
              None,
            )
          } else if polyline(converted, closed=true).area() == 0.0 {
            dfm_add(
              findings,
              RegionValidityRule,
              DfmWarning,
              "region has zero area",
              layer.name,
              Some(index),
              None,
              None,
              None,
            )
          }
        }
        _ => ()
      }
    }
  }
}

///|
fn dfm_check_non_finite(board : Board, findings : Array[DfmFinding]) -> Unit {
  for layer in board.layers {
    for index, shape in layer.shapes {
      let invalid = match shape {
        Segment(x1~, y1~, x2~, y2~, width~) =>
          x1.is_nan() ||
          y1.is_nan() ||
          x2.is_nan() ||
          y2.is_nan() ||
          width.is_nan() ||
          x1.is_inf() ||
          y1.is_inf() ||
          x2.is_inf() ||
          y2.is_inf() ||
          width.is_inf()
        Pad(x~, y~, diameter~) | DrillHit(x~, y~, diameter~) =>
          x.is_nan() ||
          y.is_nan() ||
          diameter.is_nan() ||
          x.is_inf() ||
          y.is_inf() ||
          diameter.is_inf()
        Flash(x~, y~, ..) =>
          x.is_nan() || y.is_nan() || x.is_inf() || y.is_inf()
        Region(points~) =>
          points.any(pair => {
            pair.0.is_nan() ||
            pair.1.is_nan() ||
            pair.0.is_inf() ||
            pair.1.is_inf()
          })
      }
      if invalid {
        dfm_add(
          findings,
          NonFiniteGeometryRule,
          DfmError,
          "geometry contains NaN or infinite coordinates",
          layer.name,
          Some(index),
          None,
          None,
          None,
        )
      }
    }
  }
}

///|
fn dfm_check_duplicates(board : Board, findings : Array[DfmFinding]) -> Unit {
  for layer in board.layers {
    for i in 0..<layer.shapes.length() {
      for j in (i + 1)..<layer.shapes.length() {
        if shape_box(layer.shapes[i]) is Some(a) &&
          shape_box(layer.shapes[j]) is Some(b) &&
          a.min_x == b.min_x &&
          a.min_y == b.min_y &&
          a.max_x == b.max_x &&
          a.max_y == b.max_y {
          dfm_add(
            findings,
            DuplicateShapeRule,
            DfmWarning,
            "two shapes occupy the same bounding geometry",
            layer.name,
            Some(j),
            shape_point(layer.shapes[j]),
            None,
            None,
          )
        }
      }
    }
  }
}

///|
fn dfm_check_clearance(
  board : Board,
  findings : Array[DfmFinding],
  config : DfmConfig,
) -> Unit {
  for layer in board.layers {
    for i in 0..<layer.shapes.length() {
      for j in (i + 1)..<layer.shapes.length() {
        match (layer.shapes[i], layer.shapes[j]) {
          (
            Segment(x1=a1x, y1=a1y, x2=a2x, y2=a2y, width=aw),
            Segment(x1=b1x, y1=b1y, x2=b2x, y2=b2y, width=bw),
          ) => {
            let distance = segment_distance(
                point2(x=a1x, y=a1y),
                point2(x=a2x, y=a2y),
                point2(x=b1x, y=b1y),
                point2(x=b2x, y=b2y),
              ) -
              aw / 2.0 -
              bw / 2.0
            if distance < config.min_clearance {
              dfm_add(
                findings,
                MinimumClearanceRule,
                DfmError,
                "parallel or crossing traces are closer than the configured clearance",
                layer.name,
                Some(j),
                Some(point2(x=b1x, y=b1y)),
                Some(distance),
                Some(config.min_clearance),
              )
            }
          }
          _ => ()
        }
      }
    }
  }
}

///|
fn dfm_check_layer_balance(
  board : Board,
  findings : Array[DfmFinding],
  require_drill : Bool,
) -> Unit {
  let has_copper = board.layers.any(layer => layer.kind is Copper)
  let has_drill = board.layers.any(layer => layer.kind is Drill)
  if !has_copper {
    dfm_add(
      findings,
      LayerBalanceRule,
      DfmWarning,
      "board does not contain a copper layer",
      "board",
      None,
      None,
      None,
      None,
    )
  }
  if require_drill && !has_drill {
    dfm_add(
      findings,
      MissingDrillLayerRule,
      DfmError,
      "configuration requires a drill layer",
      "board",
      None,
      None,
      None,
      None,
    )
  }
}

///|
fn dfm_check_annular_ring(
  board : Board,
  findings : Array[DfmFinding],
  config : DfmConfig,
) -> Unit {
  let pads : Array[(String, Point2, Double)] = []
  let drills : Array[(String, Point2, Double)] = []
  for layer in board.layers {
    for shape in layer.shapes {
      match shape {
        Pad(x~, y~, diameter~) =>
          pads.push((layer.name, point2(x~, y~), diameter))
        DrillHit(x~, y~, diameter~) =>
          drills.push((layer.name, point2(x~, y~), diameter))
        _ => ()
      }
    }
  }
  for pad in pads {
    for drill in drills {
      if pad.1.near(drill.1, epsilon=0.0001) {
        let ring = (pad.2 - drill.2) / 2.0
        if ring < config.min_annular_ring {
          dfm_add(
            findings,
            AnnularRingRule,
            DfmWarning,
            "pad to drill annular ring is below the configured limit",
            pad.0,
            None,
            Some(pad.1),
            Some(ring),
            Some(config.min_annular_ring),
          )
        }
      }
    }
  }
}

///|
fn dfm_check_unknown_apertures(
  board : Board,
  findings : Array[DfmFinding],
) -> Unit {
  for layer in board.layers {
    for index, shape in layer.shapes {
      match shape {
        Flash(aperture=0, ..) =>
          dfm_add(
            findings,
            UnknownApertureRule,
            DfmWarning,
            "flash uses the implicit aperture because no D-code was selected",
            layer.name,
            Some(index),
            shape_point(shape),
            None,
            None,
          )
        _ => ()
      }
    }
  }
}

///|
fn dfm_check_outline(
  board : Board,
  findings : Array[DfmFinding],
  required : Bool,
) -> Unit {
  if !required {
    return
  }
  let outlines = board.layers.filter_map(layer => {
    if layer.kind is Mechanical || layer.name.to_upper().contains("OUTLINE") {
      Some(layer)
    } else {
      None
    }
  })
  if outlines.length() == 0 {
    dfm_add(
      findings,
      OutlineClosedRule,
      DfmError,
      "no mechanical or outline layer was found",
      "board",
      None,
      None,
      None,
      None,
    )
  } else if outlines.all(layer => {
      layer.shapes.all(shape => {
        match shape {
          Region(points~) =>
            points.length() >= 3 &&
            !polygon_self_intersects(
              points.map(pair => point2(x=pair.0, y=pair.1)),
            )
          _ => false
        }
      })
    }) {
    ()
  } else {
    dfm_add(
      findings,
      OutlineClosedRule,
      DfmWarning,
      "outline layer exists but does not contain a valid closed region",
      "board",
      None,
      None,
      None,
      None,
    )
  }
}

///|
/// Run the complete built-in manufacturing rule set.
pub fn run_dfm(
  board : Board,
  config? : DfmConfig = default_dfm_config(),
) -> DfmReport {
  let findings : Array[DfmFinding] = []
  dfm_check_empty_layers(board, findings)
  dfm_check_minimum_width(board, findings, config)
  dfm_check_minimum_drill(board, findings, config)
  dfm_check_board_size(board, findings, config)
  if config.check_geometry {
    dfm_check_regions(board, findings)
    dfm_check_non_finite(board, findings)
    dfm_check_clearance(board, findings, config)
    dfm_check_annular_ring(board, findings, config)
  }
  if config.check_duplicates {
    dfm_check_duplicates(board, findings)
  }
  dfm_check_layer_balance(board, findings, config.require_drill_layer)
  dfm_check_unknown_apertures(board, findings)
  dfm_check_outline(board, findings, config.require_outline)
  {
    findings,
    config,
    layer_count: board.layers.length(),
    shape_count: board.layers.fold(init=0, (sum, layer) => {
      sum + layer.shapes.length()
    }),
    checked_rules: 13,
  }
}

///|
pub fn check_dfm(
  board : Board,
  config? : DfmConfig = default_dfm_config(),
) -> Array[Issue] {
  run_dfm(board, config~).to_issues()
}

///|
pub fn finding_counts(findings : Array[DfmFinding]) -> (Int, Int, Int) {
  (
    findings.filter(finding => finding.severity is DfmError).length(),
    findings.filter(finding => finding.severity is DfmWarning).length(),
    findings.filter(finding => finding.severity is DfmInfo).length(),
  )
}
