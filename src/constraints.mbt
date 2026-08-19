///|
/// Explicit manufacturing constraints independent from the default DFM rules.
/// Constraint sets are useful when a fab house supplies a revision-specific
/// capability sheet or when a board is evaluated against several processes.
pub enum ConstraintKind {
  MinimumTraceWidth
  MinimumShapeClearance
  MinimumEdgeClearance
  MaximumBoardDimension
  MaximumLayerCount
  MinimumDrillDiameter
  MaximumDrillAspect
  MinimumAnnularRing
  MaximumNetLength
  TargetImpedance
  MinimumCopperDensity
  MaximumHoleCount
  ClosedOutline
} derive(Debug, Eq)

///|
pub enum ConstraintSeverity {
  ConstraintNote
  ConstraintWarning
  ConstraintFailure
} derive(Debug, Eq)

///|
pub struct Constraint {
  id : String
  kind : ConstraintKind
  severity : ConstraintSeverity
  limit : Double
  secondary_limit : Double?
  layer : String?
  description : String
  enabled : Bool
} derive(Debug)

///|
pub struct ConstraintSet {
  name : String
  constraints : Array[Constraint]
  stop_on_failure : Bool
} derive(Debug)

///|
pub struct ConstraintFinding {
  constraint_id : String
  kind : ConstraintKind
  severity : ConstraintSeverity
  passed : Bool
  message : String
  layer : String?
  shape_index : Int?
  location : Point2?
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct ConstraintReport {
  set_name : String
  findings : Array[ConstraintFinding]
  checked : Int
  passed : Int
  failed : Int
  warnings : Int
} derive(Debug)

///|
pub struct ConstraintProfileComparison {
  set_name : String
  report : ConstraintReport
  score : Double
  usable : Bool
} derive(Debug)

///|
pub fn constraint_kind_name(value : ConstraintKind) -> String {
  match value {
    MinimumTraceWidth => "minimum-trace-width"
    MinimumShapeClearance => "minimum-shape-clearance"
    MinimumEdgeClearance => "minimum-edge-clearance"
    MaximumBoardDimension => "maximum-board-dimension"
    MaximumLayerCount => "maximum-layer-count"
    MinimumDrillDiameter => "minimum-drill-diameter"
    MaximumDrillAspect => "maximum-drill-aspect"
    MinimumAnnularRing => "minimum-annular-ring"
    MaximumNetLength => "maximum-net-length"
    TargetImpedance => "target-impedance"
    MinimumCopperDensity => "minimum-copper-density"
    MaximumHoleCount => "maximum-hole-count"
    ClosedOutline => "closed-outline"
  }
}

///|
pub fn constraint_severity_name(value : ConstraintSeverity) -> String {
  match value {
    ConstraintNote => "note"
    ConstraintWarning => "warning"
    ConstraintFailure => "failure"
  }
}

///|
pub fn constraint(
  id~ : String,
  kind~ : ConstraintKind,
  severity~ : ConstraintSeverity,
  limit~ : Double,
  secondary_limit~ : Double?,
  layer~ : String?,
  description~ : String,
) -> Constraint {
  {
    id,
    kind,
    severity,
    limit,
    secondary_limit,
    layer,
    description,
    enabled: true,
  }
}

///|
pub fn Constraint::with_enabled(
  self : Constraint,
  enabled : Bool,
) -> Constraint {
  {
    id: self.id,
    kind: self.kind,
    severity: self.severity,
    limit: self.limit,
    secondary_limit: self.secondary_limit,
    layer: self.layer,
    description: self.description,
    enabled,
  }
}

///|
pub fn Constraint::is_enabled(self : Constraint) -> Bool {
  self.enabled
}

///|
pub fn Constraint::summary(self : Constraint) -> String {
  "\{self.id}: \{constraint_kind_name(self.kind)} limit=\{self.limit} \{self.description}"
}

///|
pub fn ConstraintSet::constraint_count(self : ConstraintSet) -> Int {
  self.constraints.length()
}

///|
pub fn ConstraintSet::enabled_count(self : ConstraintSet) -> Int {
  self.constraints.filter(constraint => constraint.enabled).length()
}

///|
pub fn ConstraintSet::constraint(
  self : ConstraintSet,
  id : String,
) -> Constraint? {
  for item in self.constraints {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
pub fn ConstraintSet::enabled_constraints(
  self : ConstraintSet,
) -> Array[Constraint] {
  self.constraints.filter(constraint => constraint.enabled)
}

///|
pub fn ConstraintSet::with_constraint(
  self : ConstraintSet,
  value : Constraint,
) -> ConstraintSet {
  let result = self.constraints.copy()
  result.push(value)
  {
    name: self.name,
    constraints: result,
    stop_on_failure: self.stop_on_failure,
  }
}

///|
pub fn ConstraintSet::without(
  self : ConstraintSet,
  id : String,
) -> ConstraintSet {
  {
    name: self.name,
    constraints: self.constraints.filter(value => value.id != id),
    stop_on_failure: self.stop_on_failure,
  }
}

///|
pub fn ConstraintSet::with_stop_on_failure(
  self : ConstraintSet,
  value : Bool,
) -> ConstraintSet {
  { name: self.name, constraints: self.constraints, stop_on_failure: value }
}

///|
pub fn standard_constraint_set() -> ConstraintSet {
  {
    name: "standard-pcb",
    stop_on_failure: false,
    constraints: [
      constraint(
        id="trace-width",
        kind=MinimumTraceWidth,
        severity=ConstraintFailure,
        limit=0.1,
        secondary_limit=None,
        layer=None,
        description="minimum copper trace width",
      ),
      constraint(
        id="shape-clearance",
        kind=MinimumShapeClearance,
        severity=ConstraintFailure,
        limit=0.1,
        secondary_limit=None,
        layer=None,
        description="minimum same-layer shape clearance",
      ),
      constraint(
        id="edge-clearance",
        kind=MinimumEdgeClearance,
        severity=ConstraintWarning,
        limit=0.25,
        secondary_limit=None,
        layer=None,
        description="minimum distance to outline",
      ),
      constraint(
        id="board-size",
        kind=MaximumBoardDimension,
        severity=ConstraintFailure,
        limit=500.0,
        secondary_limit=Some(500.0),
        layer=None,
        description="maximum board width and height",
      ),
      constraint(
        id="layer-count",
        kind=MaximumLayerCount,
        severity=ConstraintFailure,
        limit=8.0,
        secondary_limit=None,
        layer=None,
        description="maximum manufacturing layers",
      ),
      constraint(
        id="drill-diameter",
        kind=MinimumDrillDiameter,
        severity=ConstraintFailure,
        limit=0.2,
        secondary_limit=None,
        layer=None,
        description="minimum finished drill diameter",
      ),
      constraint(
        id="hole-count",
        kind=MaximumHoleCount,
        severity=ConstraintWarning,
        limit=10000.0,
        secondary_limit=None,
        layer=None,
        description="maximum drill count",
      ),
      constraint(
        id="drill-aspect",
        kind=MaximumDrillAspect,
        severity=ConstraintWarning,
        limit=8.0,
        secondary_limit=None,
        layer=None,
        description="maximum drill aspect ratio",
      ),
      constraint(
        id="annular-ring",
        kind=MinimumAnnularRing,
        severity=ConstraintWarning,
        limit=0.1,
        secondary_limit=None,
        layer=None,
        description="minimum annular ring",
      ),
      constraint(
        id="net-length",
        kind=MaximumNetLength,
        severity=ConstraintNote,
        limit=1000.0,
        secondary_limit=None,
        layer=None,
        description="maximum routed net length",
      ),
      constraint(
        id="impedance",
        kind=TargetImpedance,
        severity=ConstraintNote,
        limit=50.0,
        secondary_limit=Some(5.0),
        layer=None,
        description="target single-ended impedance",
      ),
      constraint(
        id="outline-closed",
        kind=ClosedOutline,
        severity=ConstraintFailure,
        limit=1.0,
        secondary_limit=None,
        layer=None,
        description="outline must be closed",
      ),
      constraint(
        id="copper-density",
        kind=MinimumCopperDensity,
        severity=ConstraintNote,
        limit=0.005,
        secondary_limit=None,
        layer=None,
        description="minimum copper density",
      ),
    ],
  }
}

///|
pub fn prototype_constraint_set() -> ConstraintSet {
  {
    name: "prototype-pcb",
    stop_on_failure: false,
    constraints: [
      constraint(
        id="trace-width",
        kind=MinimumTraceWidth,
        severity=ConstraintWarning,
        limit=0.15,
        secondary_limit=None,
        layer=None,
        description="prototype trace width",
      ),
      constraint(
        id="shape-clearance",
        kind=MinimumShapeClearance,
        severity=ConstraintWarning,
        limit=0.15,
        secondary_limit=None,
        layer=None,
        description="prototype clearance",
      ),
      constraint(
        id="board-size",
        kind=MaximumBoardDimension,
        severity=ConstraintFailure,
        limit=300.0,
        secondary_limit=Some(300.0),
        layer=None,
        description="prototype work area",
      ),
      constraint(
        id="layer-count",
        kind=MaximumLayerCount,
        severity=ConstraintWarning,
        limit=4.0,
        secondary_limit=None,
        layer=None,
        description="prototype layer count",
      ),
      constraint(
        id="drill-diameter",
        kind=MinimumDrillDiameter,
        severity=ConstraintWarning,
        limit=0.25,
        secondary_limit=None,
        layer=None,
        description="prototype drill",
      ),
      constraint(
        id="outline-closed",
        kind=ClosedOutline,
        severity=ConstraintFailure,
        limit=1.0,
        secondary_limit=None,
        layer=None,
        description="outline must be closed",
      ),
    ],
  }
}

///|
pub fn strict_constraint_set() -> ConstraintSet {
  {
    name: "fine-pitch-pcb",
    stop_on_failure: true,
    constraints: [
      constraint(
        id="trace-width",
        kind=MinimumTraceWidth,
        severity=ConstraintFailure,
        limit=0.075,
        secondary_limit=None,
        layer=None,
        description="fine-pitch trace width",
      ),
      constraint(
        id="shape-clearance",
        kind=MinimumShapeClearance,
        severity=ConstraintFailure,
        limit=0.075,
        secondary_limit=None,
        layer=None,
        description="fine-pitch clearance",
      ),
      constraint(
        id="edge-clearance",
        kind=MinimumEdgeClearance,
        severity=ConstraintFailure,
        limit=0.2,
        secondary_limit=None,
        layer=None,
        description="fine-pitch edge clearance",
      ),
      constraint(
        id="board-size",
        kind=MaximumBoardDimension,
        severity=ConstraintFailure,
        limit=400.0,
        secondary_limit=Some(400.0),
        layer=None,
        description="fine-pitch work area",
      ),
      constraint(
        id="layer-count",
        kind=MaximumLayerCount,
        severity=ConstraintFailure,
        limit=12.0,
        secondary_limit=None,
        layer=None,
        description="fine-pitch layer count",
      ),
      constraint(
        id="drill-diameter",
        kind=MinimumDrillDiameter,
        severity=ConstraintFailure,
        limit=0.15,
        secondary_limit=None,
        layer=None,
        description="fine-pitch drill",
      ),
      constraint(
        id="hole-count",
        kind=MaximumHoleCount,
        severity=ConstraintFailure,
        limit=2000.0,
        secondary_limit=None,
        layer=None,
        description="fine-pitch drill count",
      ),
      constraint(
        id="outline-closed",
        kind=ClosedOutline,
        severity=ConstraintFailure,
        limit=1.0,
        secondary_limit=None,
        layer=None,
        description="outline must be closed",
      ),
      constraint(
        id="copper-density",
        kind=MinimumCopperDensity,
        severity=ConstraintWarning,
        limit=0.01,
        secondary_limit=None,
        layer=None,
        description="minimum copper density",
      ),
    ],
  }
}

///|
fn constraint_finding(
  value : Constraint,
  passed : Bool,
  message : String,
  layer : String?,
  shape_index : Int?,
  location : Point2?,
  measured : Double?,
) -> ConstraintFinding {
  {
    constraint_id: value.id,
    kind: value.kind,
    severity: value.severity,
    passed,
    message,
    layer,
    shape_index,
    location,
    measured,
    limit: Some(value.limit),
  }
}

///|
fn constraint_shape_min_width(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let result : Array[ConstraintFinding] = []
  for layer in board.layers {
    for shape_index, shape in layer.shapes {
      match shape {
        Segment(x1~, y1~, x2=_, y2=_, width~) => {
          let passed = width >= rule.limit
          result.push(
            constraint_finding(
              rule,
              passed,
              if passed {
                "trace width passes"
              } else {
                "trace width is below constraint"
              },
              Some(layer.name),
              Some(shape_index),
              Some(point2(x=x1, y=y1)),
              Some(width),
            ),
          )
        }
        _ => ()
      }
    }
  }
  result
}

///|
fn constraint_shape_clearance(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let result : Array[ConstraintFinding] = []
  for layer in board.layers {
    for i in 0..<layer.shapes.length() {
      for j in (i + 1)..<layer.shapes.length() {
        match (shape_bounds(layer.shapes[i]), shape_bounds(layer.shapes[j])) {
          (Some(first), Some(second)) => {
            let dx = if first.max_x < second.min_x {
              second.min_x - first.max_x
            } else if second.max_x < first.min_x {
              first.min_x - second.max_x
            } else {
              0.0
            }
            let dy = if first.max_y < second.min_y {
              second.min_y - first.max_y
            } else if second.max_y < first.min_y {
              first.min_y - second.max_y
            } else {
              0.0
            }
            let distance = (dx * dx + dy * dy).sqrt()
            let passed = distance >= rule.limit
            result.push(
              constraint_finding(
                rule,
                passed,
                if passed {
                  "shape clearance passes"
                } else {
                  "shape clearance is below constraint"
                },
                Some(layer.name),
                Some(i),
                Some(
                  point2(
                    x=(first.min_x + first.max_x) / 2.0,
                    y=(first.min_y + first.max_y) / 2.0,
                  ),
                ),
                Some(distance),
              ),
            )
          }
          _ => ()
        }
      }
    }
  }
  result
}

///|
fn constraint_board_size(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  match board_bounds(board) {
    Some(bounds) => {
      let width = bounds.max_x - bounds.min_x
      let height = bounds.max_y - bounds.min_y
      let width_ok = width <= rule.limit
      let height_limit = rule.secondary_limit.unwrap_or(rule.limit)
      let height_ok = height <= height_limit
      [
        constraint_finding(
          rule,
          width_ok && height_ok,
          if width_ok && height_ok {
            "board dimensions pass"
          } else {
            "board dimensions exceed constraint"
          },
          None,
          None,
          Some(
            point2(
              x=(bounds.min_x + bounds.max_x) / 2.0,
              y=(bounds.min_y + bounds.max_y) / 2.0,
            ),
          ),
          Some(if width > height { width } else { height }),
        ),
      ]
    }
    None =>
      [
        constraint_finding(
          rule,
          false,
          "board has no geometry",
          None,
          None,
          None,
          Some(0.0),
        ),
      ]
  }
}

///|
fn constraint_layer_count(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let count = board.layers.length()
  [
    constraint_finding(
      rule,
      count.to_double() <= rule.limit,
      if count.to_double() <= rule.limit {
        "layer count passes"
      } else {
        "layer count exceeds constraint"
      },
      None,
      None,
      None,
      Some(count.to_double()),
    ),
  ]
}

///|
fn constraint_drills(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let result : Array[ConstraintFinding] = []
  for layer in board.layers {
    if layer.kind is Drill {
      for index, shape in layer.shapes {
        match shape {
          DrillHit(x~, y~, diameter~) => {
            let passed = diameter >= rule.limit
            result.push(
              constraint_finding(
                rule,
                passed,
                if passed {
                  "drill diameter passes"
                } else {
                  "drill diameter is below constraint"
                },
                Some(layer.name),
                Some(index),
                Some(point2(x~, y~)),
                Some(diameter),
              ),
            )
          }
          _ => ()
        }
      }
    }
  }
  result
}

///|
fn constraint_hole_count(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let mut count = 0
  for layer in board.layers {
    if layer.kind is Drill {
      count += layer.shapes
        .filter(shape => {
          match shape {
            DrillHit(..) => true
            _ => false
          }
        })
        .length()
    }
  }
  [
    constraint_finding(
      rule,
      count.to_double() <= rule.limit,
      if count.to_double() <= rule.limit {
        "hole count passes"
      } else {
        "hole count exceeds constraint"
      },
      None,
      None,
      None,
      Some(count.to_double()),
    ),
  ]
}

///|
fn constraint_density(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let metrics = board_metrics(board)
  let density = metrics.density()
  [
    constraint_finding(
      rule,
      density >= rule.limit,
      if density >= rule.limit {
        "copper density passes"
      } else {
        "copper density is below constraint"
      },
      None,
      None,
      None,
      Some(density),
    ),
  ]
}

///|
fn constraint_outline(
  board : Board,
  rule : Constraint,
) -> Array[ConstraintFinding] {
  let outlines = board.layers.filter(layer => layer.kind is Mechanical)
  if outlines.length() == 0 {
    [
      constraint_finding(
        rule,
        false,
        "no mechanical outline layer was found",
        None,
        None,
        None,
        Some(0.0),
      ),
    ]
  } else {
    let analysis = analyze_outline(board)
    [
      constraint_finding(
        rule,
        analysis.is_valid,
        if analysis.is_valid {
          "outline is closed"
        } else {
          "outline is open"
        },
        None,
        None,
        analysis.bounds.map(value => value.center()),
        Some(if analysis.is_valid { 1.0 } else { 0.0 }),
      ),
    ]
  }
}

///|
fn constraint_one(
  board : Board,
  value : Constraint,
) -> Array[ConstraintFinding] {
  match value.kind {
    MinimumTraceWidth => constraint_shape_min_width(board, value)
    MinimumShapeClearance => constraint_shape_clearance(board, value)
    MaximumBoardDimension => constraint_board_size(board, value)
    MaximumLayerCount => constraint_layer_count(board, value)
    MinimumDrillDiameter => constraint_drills(board, value)
    MaximumHoleCount => constraint_hole_count(board, value)
    MinimumCopperDensity => constraint_density(board, value)
    ClosedOutline => constraint_outline(board, value)
    MinimumEdgeClearance => {
      let bounds = board_bounds(board)
      match bounds {
        Some(value_bounds) =>
          [
            constraint_finding(
              value,
              true,
              "edge clearance requires explicit outline geometry",
              None,
              None,
              Some(
                point2(
                  x=(value_bounds.min_x + value_bounds.max_x) / 2.0,
                  y=(value_bounds.min_y + value_bounds.max_y) / 2.0,
                ),
              ),
              None,
            ),
          ]
        None =>
          [
            constraint_finding(
              value,
              false,
              "edge clearance cannot be measured without board bounds",
              None,
              None,
              None,
              None,
            ),
          ]
      }
    }
    MaximumDrillAspect => constraint_drills(board, value)
    MinimumAnnularRing => constraint_drills(board, value)
    MaximumNetLength | TargetImpedance =>
      [
        constraint_finding(
          value,
          true,
          "constraint is evaluated by net/impedance integrations",
          None,
          None,
          None,
          None,
        ),
      ]
  }
}

///|
pub fn evaluate_constraints(
  board : Board,
  set : ConstraintSet,
) -> ConstraintReport {
  let findings : Array[ConstraintFinding] = []
  for value in set.constraints {
    if value.enabled {
      let new_findings = constraint_one(board, value)
      findings.append(new_findings)
      if set.stop_on_failure &&
        new_findings.any(finding => {
          !finding.passed && finding.severity is ConstraintFailure
        }) {
        break
      }
    }
  }
  let passed = findings.filter(finding => finding.passed).length()
  let failed = findings
    .filter(finding => !finding.passed && finding.severity is ConstraintFailure)
    .length()
  let warnings = findings
    .filter(finding => !finding.passed && finding.severity is ConstraintWarning)
    .length()
  {
    set_name: set.name,
    findings,
    checked: findings.length(),
    passed,
    failed,
    warnings,
  }
}

///|
pub fn ConstraintReport::is_valid(self : ConstraintReport) -> Bool {
  self.failed == 0
}

///|
pub fn ConstraintReport::warning_count(self : ConstraintReport) -> Int {
  self.warnings
}

///|
pub fn ConstraintReport::failure_count(self : ConstraintReport) -> Int {
  self.failed
}

///|
pub fn ConstraintReport::pass_rate(self : ConstraintReport) -> Double {
  if self.checked == 0 {
    1.0
  } else {
    self.passed.to_double() / self.checked.to_double()
  }
}

///|
pub fn ConstraintReport::summary(self : ConstraintReport) -> String {
  "set=\{self.set_name}, checked=\{self.checked}, passed=\{self.passed}, warnings=\{self.warnings}, failures=\{self.failed}, pass_rate=\{self.pass_rate()}"
}

///|
pub fn ConstraintReport::findings_for(
  self : ConstraintReport,
  kind : ConstraintKind,
) -> Array[ConstraintFinding] {
  self.findings.filter(finding => finding.kind == kind)
}

///|
pub fn ConstraintReport::failed_constraints(
  self : ConstraintReport,
) -> Array[String] {
  let result : Array[String] = []
  for finding in self.findings {
    if !finding.passed && !result.contains(finding.constraint_id) {
      result.push(finding.constraint_id)
    }
  }
  result
}

///|
pub fn ConstraintReport::worst_clearance(self : ConstraintReport) -> Double? {
  let values = self.findings
    .filter(finding => finding.kind is MinimumShapeClearance)
    .map(finding => finding.measured)
    .filter_map(value => value)
  if values.length() == 0 {
    None
  } else {
    Some(
      values.fold(init=1000000000.0, (best, value) => {
        if value < best {
          value
        } else {
          best
        }
      }),
    )
  }
}

///|
pub fn compare_constraint_sets(
  board : Board,
  sets : Array[ConstraintSet],
) -> Array[ConstraintProfileComparison] {
  let result : Array[ConstraintProfileComparison] = []
  for set in sets {
    let report = evaluate_constraints(board, set)
    let score = if report.checked == 0 {
      100.0
    } else {
      100.0 * report.passed.to_double() / report.checked.to_double() -
      report.warnings.to_double() * 2.0
    }
    result.push({ set_name: set.name, report, score, usable: report.is_valid() })
  }
  result
}

///|
pub fn best_constraint_set(
  board : Board,
  sets : Array[ConstraintSet],
) -> ConstraintProfileComparison? {
  let comparisons = compare_constraint_sets(board, sets)
  let mut best : ConstraintProfileComparison? = None
  for value in comparisons {
    match best {
      None => best = Some(value)
      Some(old) if value.usable && (!old.usable || value.score > old.score) =>
        best = Some(value)
      _ => ()
    }
  }
  best
}

///|
pub fn constraint_finding_to_json(value : ConstraintFinding) -> String {
  let layer = value.layer.map(json_string).unwrap_or("null")
  let shape = value.shape_index
    .map(number => number.to_string())
    .unwrap_or("null")
  let location = match value.location {
    Some(point) => "{\"x\":\{point.x},\"y\":\{point.y}}"
    None => "null"
  }
  let measured = value.measured
    .map(number => number.to_string())
    .unwrap_or("null")
  let limit = value.limit.map(number => number.to_string()).unwrap_or("null")
  "{\"id\":\{json_string(value.constraint_id)},\"kind\":\{json_string(constraint_kind_name(value.kind))},\"severity\":\{json_string(constraint_severity_name(value.severity))},\"passed\":\{value.passed},\"message\":\{json_string(value.message)},\"layer\":\{layer},\"shape_index\":\{shape},\"location\":\{location},\"measured\":\{measured},\"limit\":\{limit}}"
}

///|
pub fn constraint_report_to_json(value : ConstraintReport) -> String {
  let findings = value.findings.map(constraint_finding_to_json).join(",")
  let failures = value.failed_constraints().map(json_string).join(",")
  "{\"set\":\{json_string(value.set_name)},\"valid\":\{value.is_valid()},\"checked\":\{value.checked},\"passed\":\{value.passed},\"warnings\":\{value.warnings},\"failures\":\{value.failed},\"pass_rate\":\{value.pass_rate()},\"failed_constraints\":[\{failures}],\"findings\":[\{findings}]}"
}

///|
pub fn constraint_report_to_text(value : ConstraintReport) -> String {
  let mut output = value.summary() + "\n"
  for finding in value.findings {
    let state = if finding.passed {
      "pass"
    } else {
      constraint_severity_name(finding.severity)
    }
    output += "- \{state} \{finding.constraint_id}: \{finding.message}\n"
  }
  output
}

///|
pub fn constraint_set_to_json(value : ConstraintSet) -> String {
  let constraints = value.constraints
    .map(item => {
      "{\"id\":\{json_string(item.id)},\"kind\":\{json_string(constraint_kind_name(item.kind))},\"severity\":\{json_string(constraint_severity_name(item.severity))},\"limit\":\{item.limit},\"enabled\":\{item.enabled},\"description\":\{json_string(item.description)}}"
    })
    .join(",")
  "{\"name\":\{json_string(value.name)},\"stop_on_failure\":\{value.stop_on_failure},\"constraints\":[\{constraints}]}"
}

///|
pub fn constraints_to_csv(value : ConstraintReport) -> String {
  let mut output = "id,kind,severity,passed,layer,shape_index,measured,limit,message\n"
  for finding in value.findings {
    output += json_escape(finding.constraint_id) +
      "," +
      constraint_kind_name(finding.kind) +
      "," +
      constraint_severity_name(finding.severity) +
      "," +
      finding.passed.to_string() +
      "," +
      finding.layer.map(json_escape).unwrap_or("") +
      "," +
      finding.shape_index.map(number => number.to_string()).unwrap_or("") +
      "," +
      finding.measured.map(number => number.to_string()).unwrap_or("") +
      "," +
      finding.limit.map(number => number.to_string()).unwrap_or("") +
      "," +
      json_escape(finding.message) +
      "\n"
  }
  output
}

///|
pub fn ConstraintProfileComparison::summary(
  self : ConstraintProfileComparison,
) -> String {
  "\{self.set_name}: usable=\{self.usable}, score=\{self.score}, \{self.report.summary()}"
}

///|
pub fn compare_constraints_to_fabrication(
  board : Board,
  profile : FabricationProfile,
) -> ConstraintProfileComparison {
  let set = standard_constraint_set()
  let adjusted = set.with_constraint(
    constraint(
      id="profile-trace-width",
      kind=MinimumTraceWidth,
      severity=ConstraintFailure,
      limit=profile.min_trace_width,
      secondary_limit=None,
      layer=None,
      description="fabrication profile trace width",
    ),
  )
  let report = evaluate_constraints(board, adjusted)
  {
    set_name: profile.name(),
    report,
    score: report.pass_rate() * 100.0,
    usable: report.is_valid(),
  }
}
