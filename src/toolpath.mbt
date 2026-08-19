///|
/// CAM toolpath planning for board outlines, copper contours, slots, and
/// drill hits. The planner emits an inspectable intermediate representation
/// before serialising machine instructions, so safety checks can run in CI.
pub enum ToolpathMoveKind {
  ToolRapid
  ToolCut
  ToolPlunge
  ToolRetract
  ToolDrill
  ToolPause
} derive(Debug, Eq)

///|
pub enum ToolpathSourceKind {
  OutlineSource
  CopperSource
  SlotSource
  DrillSource
  FixtureSource
} derive(Debug, Eq)

///|
pub enum ToolpathIssueSeverity {
  ToolpathInfo
  ToolpathWarning
  ToolpathError
} derive(Debug, Eq)

///|
pub enum ToolpathRule {
  EmptyPath
  NonFinitePoint
  OutsideWorkArea
  ExcessiveDepth
  UnsafeRapid
  DuplicateMove
  OpenToolpathContour
  ToolDiameterMismatch
  DrillOutsideBoard
  FeedOutOfRange
} derive(Debug, Eq)

///|
pub struct ToolMachineProfile {
  name : String
  unit : LengthUnit
  tool_diameter : Double
  cut_depth : Double
  safe_height : Double
  rapid_feed : Double
  cut_feed : Double
  plunge_feed : Double
  spindle_rpm : Int
  max_width : Double
  max_height : Double
  allow_outside_rapid : Bool
} derive(Debug)

///|
pub struct ToolpathPoint {
  point : Point2
  z : Double
  feed : Double
} derive(Debug)

///|
pub struct ToolMove {
  sequence : Int
  kind : ToolpathMoveKind
  start : Point2
  end : Point2
  start_z : Double
  end_z : Double
  feed : Double
  length : Double
  source : ToolpathSourceKind
  layer : String
} derive(Debug)

///|
pub struct Toolpath {
  name : String
  source : ToolpathSourceKind
  layer : String
  closed : Bool
  moves : Array[ToolMove]
  start : Point2?
  end : Point2?
  cut_length : Double
  rapid_length : Double
  estimated_seconds : Double
} derive(Debug)

///|
pub struct ToolpathIssue {
  rule : ToolpathRule
  severity : ToolpathIssueSeverity
  path_name : String
  message : String
  sequence : Int?
  location : Point2?
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct ToolpathPlan {
  profile : ToolMachineProfile
  paths : Array[Toolpath]
  issues : Array[ToolpathIssue]
  total_cut_length : Double
  total_rapid_length : Double
  estimated_seconds : Double
  bounds : Rect2?
} derive(Debug)

///|
pub struct ToolpathSummary {
  path_count : Int
  move_count : Int
  cut_moves : Int
  rapid_moves : Int
  drill_moves : Int
  cut_length : Double
  rapid_length : Double
  estimated_seconds : Double
} derive(Debug)

///|
pub fn toolpath_move_kind_name(value : ToolpathMoveKind) -> String {
  match value {
    ToolRapid => "rapid"
    ToolCut => "cut"
    ToolPlunge => "plunge"
    ToolRetract => "retract"
    ToolDrill => "drill"
    ToolPause => "pause"
  }
}

///|
pub fn toolpath_source_name(value : ToolpathSourceKind) -> String {
  match value {
    OutlineSource => "outline"
    CopperSource => "copper"
    SlotSource => "slot"
    DrillSource => "drill"
    FixtureSource => "fixture"
  }
}

///|
pub fn toolpath_severity_name(value : ToolpathIssueSeverity) -> String {
  match value {
    ToolpathInfo => "info"
    ToolpathWarning => "warning"
    ToolpathError => "error"
  }
}

///|
pub fn toolpath_rule_name(value : ToolpathRule) -> String {
  match value {
    EmptyPath => "empty-path"
    NonFinitePoint => "non-finite-point"
    OutsideWorkArea => "outside-work-area"
    ExcessiveDepth => "excessive-depth"
    UnsafeRapid => "unsafe-rapid"
    DuplicateMove => "duplicate-operation"
    OpenToolpathContour => "open-contour"
    ToolDiameterMismatch => "tool-diameter-mismatch"
    DrillOutsideBoard => "drill-outside-board"
    FeedOutOfRange => "feed-out-of-range"
  }
}

///|
pub fn default_tool_machine_profile() -> ToolMachineProfile {
  {
    name: "desktop-cnc-mm",
    unit: Millimeter,
    tool_diameter: 0.8,
    cut_depth: -0.2,
    safe_height: 2.0,
    rapid_feed: 1800.0,
    cut_feed: 300.0,
    plunge_feed: 80.0,
    spindle_rpm: 12000,
    max_width: 300.0,
    max_height: 300.0,
    allow_outside_rapid: false,
  }
}

///|
pub fn fine_tool_machine_profile() -> ToolMachineProfile {
  {
    name: "fine-copper-cnc-mm",
    unit: Millimeter,
    tool_diameter: 0.2,
    cut_depth: -0.12,
    safe_height: 1.5,
    rapid_feed: 1400.0,
    cut_feed: 120.0,
    plunge_feed: 40.0,
    spindle_rpm: 18000,
    max_width: 200.0,
    max_height: 200.0,
    allow_outside_rapid: false,
  }
}

///|
pub fn tool_machine_profile(
  name~ : String,
  tool_diameter~ : Double,
  cut_depth~ : Double,
  safe_height~ : Double,
  rapid_feed~ : Double,
  cut_feed~ : Double,
  plunge_feed~ : Double,
  spindle_rpm~ : Int,
  max_width~ : Double,
  max_height~ : Double,
  allow_outside_rapid~ : Bool,
) -> ToolMachineProfile {
  {
    name,
    unit: Millimeter,
    tool_diameter: if tool_diameter < 0.0 {
      -tool_diameter
    } else {
      tool_diameter
    },
    cut_depth: if cut_depth > 0.0 {
      -cut_depth
    } else {
      cut_depth
    },
    safe_height: if safe_height < 0.0 {
      0.0
    } else {
      safe_height
    },
    rapid_feed: if rapid_feed < 0.0 {
      0.0
    } else {
      rapid_feed
    },
    cut_feed: if cut_feed < 0.0 {
      0.0
    } else {
      cut_feed
    },
    plunge_feed: if plunge_feed < 0.0 {
      0.0
    } else {
      plunge_feed
    },
    spindle_rpm: if spindle_rpm < 0 {
      0
    } else {
      spindle_rpm
    },
    max_width: if max_width < 0.0 {
      0.0
    } else {
      max_width
    },
    max_height: if max_height < 0.0 {
      0.0
    } else {
      max_height
    },
    allow_outside_rapid,
  }
}

///|
pub fn ToolMachineProfile::summary(self : ToolMachineProfile) -> String {
  "\{self.name}: tool=\{self.tool_diameter}mm depth=\{self.cut_depth}mm safe=\{self.safe_height}mm feed=\{self.cut_feed}mm/min spindle=\{self.spindle_rpm}rpm"
}

///|
pub fn ToolMachineProfile::work_area(self : ToolMachineProfile) -> Rect2 {
  rect2(min_x=0.0, min_y=0.0, max_x=self.max_width, max_y=self.max_height)
}

///|
pub fn ToolMachineProfile::is_valid(self : ToolMachineProfile) -> Bool {
  self.tool_diameter > 0.0 &&
  self.safe_height >= 0.0 &&
  self.cut_depth < 0.0 &&
  self.cut_feed > 0.0 &&
  self.plunge_feed > 0.0 &&
  self.max_width > 0.0 &&
  self.max_height > 0.0
}

///|
pub fn ToolMachineProfile::with_tool(
  self : ToolMachineProfile,
  diameter : Double,
) -> ToolMachineProfile {
  {
    name: self.name,
    unit: self.unit,
    tool_diameter: if diameter < 0.0 {
      -diameter
    } else {
      diameter
    },
    cut_depth: self.cut_depth,
    safe_height: self.safe_height,
    rapid_feed: self.rapid_feed,
    cut_feed: self.cut_feed,
    plunge_feed: self.plunge_feed,
    spindle_rpm: self.spindle_rpm,
    max_width: self.max_width,
    max_height: self.max_height,
    allow_outside_rapid: self.allow_outside_rapid,
  }
}

///|
pub fn ToolMachineProfile::with_depth(
  self : ToolMachineProfile,
  depth : Double,
) -> ToolMachineProfile {
  {
    name: self.name,
    unit: self.unit,
    tool_diameter: self.tool_diameter,
    cut_depth: if depth > 0.0 {
      -depth
    } else {
      depth
    },
    safe_height: self.safe_height,
    rapid_feed: self.rapid_feed,
    cut_feed: self.cut_feed,
    plunge_feed: self.plunge_feed,
    spindle_rpm: self.spindle_rpm,
    max_width: self.max_width,
    max_height: self.max_height,
    allow_outside_rapid: self.allow_outside_rapid,
  }
}

///|
pub fn ToolMachineProfile::with_feeds(
  self : ToolMachineProfile,
  rapid : Double,
  cut : Double,
  plunge : Double,
) -> ToolMachineProfile {
  {
    name: self.name,
    unit: self.unit,
    tool_diameter: self.tool_diameter,
    cut_depth: self.cut_depth,
    safe_height: self.safe_height,
    rapid_feed: if rapid < 0.0 {
      0.0
    } else {
      rapid
    },
    cut_feed: if cut < 0.0 {
      0.0
    } else {
      cut
    },
    plunge_feed: if plunge < 0.0 {
      0.0
    } else {
      plunge
    },
    spindle_rpm: self.spindle_rpm,
    max_width: self.max_width,
    max_height: self.max_height,
    allow_outside_rapid: self.allow_outside_rapid,
  }
}

///|
pub fn ToolMachineProfile::converted(
  self : ToolMachineProfile,
  unit : LengthUnit,
) -> ToolMachineProfile {
  if unit == self.unit {
    self
  } else {
    let scale = self.unit.scale_to_mm() / unit.scale_to_mm()
    {
      name: self.name,
      unit,
      tool_diameter: self.tool_diameter * scale,
      cut_depth: self.cut_depth * scale,
      safe_height: self.safe_height * scale,
      rapid_feed: self.rapid_feed * scale,
      cut_feed: self.cut_feed * scale,
      plunge_feed: self.plunge_feed * scale,
      spindle_rpm: self.spindle_rpm,
      max_width: self.max_width * scale,
      max_height: self.max_height * scale,
      allow_outside_rapid: self.allow_outside_rapid,
    }
  }
}

///|
pub fn toolpath_move(
  sequence : Int,
  kind : ToolpathMoveKind,
  start : Point2,
  end : Point2,
  start_z : Double,
  end_z : Double,
  feed : Double,
  source : ToolpathSourceKind,
  layer : String,
) -> ToolMove {
  {
    sequence,
    kind,
    start,
    end,
    start_z,
    end_z,
    feed,
    length: start.distance(end),
    source,
    layer,
  }
}

///|
pub fn toolpath_point(
  point : Point2,
  z : Double,
  feed : Double,
) -> ToolpathPoint {
  { point, z, feed: if feed < 0.0 { 0.0 } else { feed } }
}

///|
pub fn ToolpathPoint::to_text(self : ToolpathPoint) -> String {
  "X\{self.point.x} Y\{self.point.y} Z\{self.z} F\{self.feed}"
}

///|
pub fn slot_toolpath(
  name : String,
  ring : Ring2,
  layer : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> Toolpath {
  toolpath_from_ring(name~, ring~, source=SlotSource, layer~, profile~)
}

///|
pub fn pause_path(
  name : String,
  point : Point2,
  layer : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> Toolpath {
  let path = tp_empty_path(name, FixtureSource, layer)
  tp_add_move(
    path,
    ToolPause,
    point,
    point,
    profile.safe_height,
    profile.safe_height,
    0.0,
    FixtureSource,
    layer,
  )
}

///|
pub fn ToolMove::is_cut(self : ToolMove) -> Bool {
  self.kind is ToolCut || self.kind is ToolDrill
}

///|
pub fn ToolMove::is_rapid(self : ToolMove) -> Bool {
  self.kind is ToolRapid
}

///|
pub fn ToolMove::is_vertical(self : ToolMove) -> Bool {
  self.start.near(self.end) && self.start_z != self.end_z
}

///|
pub fn ToolMove::format(self : ToolMove) -> String {
  "\{self.sequence}: \{toolpath_move_kind_name(self.kind)} (\{self.start.x},\{self.start.y},\{self.start_z}) -> (\{self.end.x},\{self.end.y},\{self.end_z}) F\{self.feed}"
}

///|
fn tp_empty_path(
  name : String,
  source : ToolpathSourceKind,
  layer : String,
) -> Toolpath {
  {
    name,
    source,
    layer,
    closed: false,
    moves: [],
    start: None,
    end: None,
    cut_length: 0.0,
    rapid_length: 0.0,
    estimated_seconds: 0.0,
  }
}

///|
fn tp_add_move(
  path : Toolpath,
  kind : ToolpathMoveKind,
  start : Point2,
  end : Point2,
  start_z : Double,
  end_z : Double,
  feed : Double,
  source : ToolpathSourceKind,
  layer : String,
) -> Toolpath {
  let operation = toolpath_move(
    path.moves.length(),
    kind,
    start,
    end,
    start_z,
    end_z,
    feed,
    source,
    layer,
  )
  let moves = path.moves.copy()
  moves.push(operation)
  let first = match path.start {
    None => Some(start)
    Some(value) => Some(value)
  }
  let cut_length = if operation.is_cut() {
    path.cut_length + operation.length
  } else {
    path.cut_length
  }
  let rapid_length = if operation.is_rapid() {
    path.rapid_length + operation.length
  } else {
    path.rapid_length
  }
  let speed = if feed <= 0.0 { 1.0 } else { feed }
  {
    name: path.name,
    source: path.source,
    layer: path.layer,
    closed: path.closed,
    moves,
    start: first,
    end: Some(end),
    cut_length,
    rapid_length,
    estimated_seconds: path.estimated_seconds + operation.length / speed * 60.0,
  }
}

///|
fn tp_set_closed(path : Toolpath, closed : Bool) -> Toolpath {
  {
    name: path.name,
    source: path.source,
    layer: path.layer,
    closed,
    moves: path.moves,
    start: path.start,
    end: path.end,
    cut_length: path.cut_length,
    rapid_length: path.rapid_length,
    estimated_seconds: path.estimated_seconds,
  }
}

///|
pub fn toolpath_from_points(
  name~ : String,
  points~ : Array[Point2],
  source~ : ToolpathSourceKind,
  layer~ : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
  closed? : Bool = true,
) -> Toolpath {
  let path = tp_empty_path(name, source, layer)
  if points.length() == 0 {
    return path
  }
  let first = points[0]
  let mut current = point2(x=first.x, y=first.y)
  let mut result = tp_add_move(
    path,
    ToolRapid,
    current,
    current,
    profile.safe_height,
    profile.safe_height,
    profile.rapid_feed,
    source,
    layer,
  )
  result = tp_add_move(
    result,
    ToolPlunge,
    current,
    current,
    profile.safe_height,
    profile.cut_depth,
    profile.plunge_feed,
    source,
    layer,
  )
  for point in points[1:] {
    result = tp_add_move(
      result,
      ToolCut,
      current,
      point,
      profile.cut_depth,
      profile.cut_depth,
      profile.cut_feed,
      source,
      layer,
    )
    current = point
  }
  if closed && points.length() > 1 && !current.near(first) {
    result = tp_add_move(
      result,
      ToolCut,
      current,
      first,
      profile.cut_depth,
      profile.cut_depth,
      profile.cut_feed,
      source,
      layer,
    )
  }
  result = tp_add_move(
    result,
    ToolRetract,
    current,
    current,
    profile.cut_depth,
    profile.safe_height,
    profile.plunge_feed,
    source,
    layer,
  )
  result
}

///|
pub fn toolpath_from_ring(
  name~ : String,
  ring~ : Ring2,
  source~ : ToolpathSourceKind,
  layer~ : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> Toolpath {
  toolpath_from_points(
    name~,
    points=ring.points,
    source~,
    layer~,
    profile~,
    closed=ring.closed,
  )
}

///|
fn tp_segment_points(
  shape : Shape,
) -> (Array[Point2], ToolpathSourceKind, Bool) {
  match shape {
    Segment(x1~, y1~, x2~, y2~, ..) =>
      ([point2(x=x1, y=y1), point2(x=x2, y=y2)], CopperSource, false)
    Pad(x~, y~, diameter~) => {
      let ring = ring2(points=[
        point2(x=x + diameter / 2.0, y~),
        point2(x~, y=y + diameter / 2.0),
        point2(x=x - diameter / 2.0, y~),
        point2(x~, y=y - diameter / 2.0),
      ])
      (ring.points, CopperSource, true)
    }
    Flash(x~, y~, ..) => ([point2(x~, y~)], CopperSource, false)
    DrillHit(x~, y~, diameter~) => {
      let ring = ring2(points=[
        point2(x=x + diameter / 2.0, y~),
        point2(x~, y=y + diameter / 2.0),
        point2(x=x - diameter / 2.0, y~),
        point2(x~, y=y - diameter / 2.0),
      ])
      (ring.points, DrillSource, true)
    }
    Region(points~) =>
      (points.map(pair => point2(x=pair.0, y=pair.1)), OutlineSource, true)
  }
}

///|
pub fn toolpath_from_shape(
  name~ : String,
  shape~ : Shape,
  layer~ : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> Toolpath {
  let data = tp_segment_points(shape)
  toolpath_from_points(
    name~,
    points=data.0,
    source=data.1,
    layer~,
    profile~,
    closed=data.2,
  )
}

///|
pub fn Toolpath::move_count(self : Toolpath) -> Int {
  self.moves.length()
}

///|
pub fn Toolpath::cut_move_count(self : Toolpath) -> Int {
  self.moves.filter(operation => operation.is_cut()).length()
}

///|
pub fn Toolpath::rapid_move_count(self : Toolpath) -> Int {
  self.moves.filter(operation => operation.is_rapid()).length()
}

///|
pub fn Toolpath::bounds(self : Toolpath) -> Rect2? {
  let points : Array[Point2] = []
  for operation in self.moves {
    points.push(operation.start)
    points.push(operation.end)
  }
  convex_hull(points).bounds()
}

///|
pub fn Toolpath::summary(self : Toolpath) -> String {
  "\{self.name}: moves=\{self.move_count()}, cuts=\{self.cut_length}mm, rapids=\{self.rapid_length}mm, time=\{self.estimated_seconds}s"
}

///|
pub fn Toolpath::reversed(self : Toolpath) -> Toolpath {
  let result = tp_empty_path(self.name + " reversed", self.source, self.layer)
  let mut output = result
  for operation in self.moves.rev() {
    let kind = operation.kind
    output = tp_add_move(
      output,
      kind,
      operation.end,
      operation.start,
      operation.end_z,
      operation.start_z,
      operation.feed,
      operation.source,
      operation.layer,
    )
  }
  tp_set_closed(output, self.closed)
}

///|
pub fn Toolpath::translated(self : Toolpath, offset : Point2) -> Toolpath {
  let result = tp_empty_path(self.name, self.source, self.layer)
  let mut output = result
  for operation in self.moves {
    output = tp_add_move(
      output,
      operation.kind,
      operation.start.add(offset),
      operation.end.add(offset),
      operation.start_z,
      operation.end_z,
      operation.feed,
      operation.source,
      operation.layer,
    )
  }
  tp_set_closed(output, self.closed)
}

///|
pub fn Toolpath::is_empty(self : Toolpath) -> Bool {
  self.moves.length() == 0
}

///|
fn tp_issue(
  rule : ToolpathRule,
  severity : ToolpathIssueSeverity,
  path_name : String,
  message : String,
  sequence : Int?,
  location : Point2?,
  measured : Double?,
  limit : Double?,
) -> ToolpathIssue {
  { rule, severity, path_name, message, sequence, location, measured, limit }
}

///|
pub fn validate_toolpath(
  path : Toolpath,
  profile : ToolMachineProfile,
) -> Array[ToolpathIssue] {
  let issues : Array[ToolpathIssue] = []
  if path.moves.length() == 0 {
    issues.push(
      tp_issue(
        EmptyPath,
        ToolpathError,
        path.name,
        "path has no moves",
        None,
        None,
        None,
        None,
      ),
    )
    return issues
  }
  if profile.tool_diameter <= 0.0 {
    issues.push(
      tp_issue(
        ToolDiameterMismatch,
        ToolpathError,
        path.name,
        "machine profile has no positive tool diameter",
        None,
        None,
        Some(profile.tool_diameter),
        Some(0.0),
      ),
    )
  }
  let work_area = profile.work_area()
  let mut previous : ToolMove? = None
  for operation in path.moves {
    if operation.start.x.is_nan() ||
      operation.start.y.is_nan() ||
      operation.end.x.is_nan() ||
      operation.end.y.is_nan() {
      issues.push(
        tp_issue(
          NonFinitePoint,
          ToolpathError,
          path.name,
          "operation contains a non-finite coordinate",
          Some(operation.sequence),
          Some(operation.end),
          None,
          None,
        ),
      )
    }
    if !profile.allow_outside_rapid &&
      operation.kind is ToolRapid &&
      !work_area.contains(operation.end) {
      let rule = if path.source is DrillSource {
        DrillOutsideBoard
      } else {
        OutsideWorkArea
      }
      issues.push(
        tp_issue(
          rule,
          ToolpathError,
          path.name,
          "rapid destination is outside machine work area",
          Some(operation.sequence),
          Some(operation.end),
          None,
          None,
        ),
      )
    }
    if operation.end_z < profile.cut_depth - 0.000001 {
      issues.push(
        tp_issue(
          ExcessiveDepth,
          ToolpathError,
          path.name,
          "cut depth exceeds machine profile",
          Some(operation.sequence),
          Some(operation.end),
          Some(operation.end_z),
          Some(profile.cut_depth),
        ),
      )
    }
    if operation.feed < 0.0 {
      issues.push(
        tp_issue(
          FeedOutOfRange,
          ToolpathError,
          path.name,
          "negative feed rate",
          Some(operation.sequence),
          Some(operation.end),
          Some(operation.feed),
          Some(0.0),
        ),
      )
    }
    match previous {
      Some(old) if old.end.near(operation.start) &&
        !(operation.kind is ToolRapid) =>
        issues.push(
          tp_issue(
            UnsafeRapid,
            ToolpathWarning,
            path.name,
            "cut begins away from the previous endpoint",
            Some(operation.sequence),
            Some(operation.start),
            Some(old.end.distance(operation.start)),
            Some(0.000001),
          ),
        )
      Some(old) if old.end.near(operation.end) &&
        old.start.near(operation.start) &&
        old.kind == operation.kind =>
        issues.push(
          tp_issue(
            DuplicateMove,
            ToolpathWarning,
            path.name,
            "duplicate consecutive operation",
            Some(operation.sequence),
            Some(operation.start),
            None,
            None,
          ),
        )
      _ => ()
    }
    previous = Some(operation)
  }
  if path.closed &&
    path.start is Some(first) &&
    path.end is Some(last) &&
    !first.near(last) {
    issues.push(
      tp_issue(
        OpenToolpathContour,
        ToolpathWarning,
        path.name,
        "closed contour does not return to its start",
        None,
        path.end,
        Some(first.distance(last)),
        Some(0.000001),
      ),
    )
  }
  issues
}

///|
pub fn ToolpathPlan::path_count(self : ToolpathPlan) -> Int {
  self.paths.length()
}

///|
pub fn ToolpathPlan::move_count(self : ToolpathPlan) -> Int {
  self.paths.fold(init=0, (total, path) => total + path.move_count())
}

///|
pub fn ToolpathPlan::error_count(self : ToolpathPlan) -> Int {
  self.issues.filter(issue => issue.severity is ToolpathError).length()
}

///|
pub fn ToolpathPlan::warning_count(self : ToolpathPlan) -> Int {
  self.issues.filter(issue => issue.severity is ToolpathWarning).length()
}

///|
pub fn ToolpathPlan::is_valid(self : ToolpathPlan) -> Bool {
  self.error_count() == 0 && self.profile.is_valid()
}

///|
pub fn ToolpathPlan::summary(self : ToolpathPlan) -> ToolpathSummary {
  let mut moves = 0
  let mut cuts = 0
  let mut rapids = 0
  let mut drills = 0
  for path in self.paths {
    moves += path.move_count()
    cuts += path.cut_move_count()
    rapids += path.rapid_move_count()
    drills += path.moves
      .filter(operation => operation.kind is ToolDrill)
      .length()
  }
  {
    path_count: self.paths.length(),
    move_count: moves,
    cut_moves: cuts,
    rapid_moves: rapids,
    drill_moves: drills,
    cut_length: self.total_cut_length,
    rapid_length: self.total_rapid_length,
    estimated_seconds: self.estimated_seconds,
  }
}

///|
pub fn ToolpathPlan::path(self : ToolpathPlan, index : Int) -> Toolpath? {
  self.paths.get(index)
}

///|
pub fn ToolpathPlan::issues(self : ToolpathPlan) -> Array[ToolpathIssue] {
  self.issues.copy()
}

///|
fn tp_plan_from_paths(
  profile : ToolMachineProfile,
  paths : Array[Toolpath],
) -> ToolpathPlan {
  let issues : Array[ToolpathIssue] = []
  if paths.length() == 0 {
    issues.push(
      tp_issue(
        EmptyPath,
        ToolpathInfo,
        "plan",
        "plan contains no toolpaths",
        None,
        None,
        None,
        None,
      ),
    )
  }
  let mut cut = 0.0
  let mut rapid = 0.0
  let mut seconds = 0.0
  let mut bounds : Rect2? = None
  for path in paths {
    cut += path.cut_length
    rapid += path.rapid_length
    seconds += path.estimated_seconds
    match (bounds, path.bounds()) {
      (None, Some(value)) => bounds = Some(value)
      (Some(old), Some(value)) => bounds = Some(old.union(value))
      _ => ()
    }
    issues.append(validate_toolpath(path, profile))
  }
  {
    profile,
    paths,
    issues,
    total_cut_length: cut,
    total_rapid_length: rapid,
    estimated_seconds: seconds,
    bounds,
  }
}

///|
pub fn plan_toolpaths(
  name~ : String,
  rings~ : Array[Ring2],
  source? : ToolpathSourceKind = OutlineSource,
  layer? : String = "Edge.Cuts",
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> ToolpathPlan {
  let paths : Array[Toolpath] = []
  for index, ring in rings {
    paths.push(
      toolpath_from_ring(
        name="\{name}-\{index}",
        ring~,
        source~,
        layer~,
        profile~,
      ),
    )
  }
  tp_plan_from_paths(profile, paths)
}

///|
pub fn plan_shapes(
  shapes : Array[Shape],
  layer_name : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> ToolpathPlan {
  let paths : Array[Toolpath] = []
  for index, shape in shapes {
    paths.push(
      toolpath_from_shape(
        name="\{layer_name}-\{index}",
        shape~,
        layer=layer_name,
        profile~,
      ),
    )
  }
  tp_plan_from_paths(profile, paths)
}

///|
pub fn plan_board_toolpaths(
  board : Board,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
  include_copper? : Bool = true,
  include_drills? : Bool = true,
  include_outline? : Bool = true,
) -> ToolpathPlan {
  let paths : Array[Toolpath] = []
  for layer in board.layers {
    let include_layer = if layer.kind is Drill {
      include_drills
    } else if layer.kind is Mechanical {
      include_outline
    } else {
      include_copper
    }
    if include_layer {
      for index, shape in layer.shapes {
        let source = match layer.kind {
          Drill => DrillSource
          Mechanical => OutlineSource
          _ => CopperSource
        }
        let path = toolpath_from_shape(
          name="\{layer.name}-\{index}",
          shape~,
          layer=layer.name,
          profile~,
        )
        if path.source != source {
          let renamed = {
            name: path.name,
            source,
            layer: path.layer,
            closed: path.closed,
            moves: path.moves,
            start: path.start,
            end: path.end,
            cut_length: path.cut_length,
            rapid_length: path.rapid_length,
            estimated_seconds: path.estimated_seconds,
          }
          paths.push(renamed)
        } else {
          paths.push(path)
        }
      }
    }
  }
  tp_plan_from_paths(profile, paths)
}

///|
pub fn reorder_toolpaths_nearest(
  paths : Array[Toolpath],
  origin? : Point2 = point2(x=0.0, y=0.0),
) -> Array[Toolpath] {
  let remaining = paths.copy()
  let result : Array[Toolpath] = []
  let mut current = origin
  while remaining.length() > 0 {
    let mut best_index = 0
    let mut best_distance = 1000000000.0
    for index, path in remaining {
      let distance = match path.start {
        Some(start) => current.distance(start)
        None => 1000000000.0
      }
      if distance < best_distance {
        best_index = index
        best_distance = distance
      }
    }
    let chosen = remaining[best_index]
    ignore(remaining.remove(best_index))
    match chosen.end {
      Some(end) => current = end
      None => ()
    }
    result.push(chosen)
  }
  result
}

///|
pub fn optimize_toolpath_plan(plan : ToolpathPlan) -> ToolpathPlan {
  let ordered = reorder_toolpaths_nearest(plan.paths)
  tp_plan_from_paths(plan.profile, ordered)
}

///|
pub fn add_fixture_frame(
  plan : ToolpathPlan,
  bounds : Rect2,
  margin : Double,
) -> ToolpathPlan {
  let expanded = bounds.expand(if margin < 0.0 { 0.0 } else { margin })
  let fixture = toolpath_from_ring(
    name="fixture-frame",
    ring=rect_to_ring(expanded),
    source=FixtureSource,
    layer="Fixture",
    profile=plan.profile,
  )
  let paths = plan.paths.copy()
  paths.push(fixture)
  tp_plan_from_paths(plan.profile, paths)
}

///|
pub fn drill_path(
  name : String,
  point : Point2,
  layer : String,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> Toolpath {
  let path = tp_empty_path(name, DrillSource, layer)
  let mut result = tp_add_move(
    path,
    ToolRapid,
    point,
    point,
    profile.safe_height,
    profile.safe_height,
    profile.rapid_feed,
    DrillSource,
    layer,
  )
  result = tp_add_move(
    result,
    ToolDrill,
    point,
    point,
    profile.safe_height,
    profile.cut_depth,
    profile.plunge_feed,
    DrillSource,
    layer,
  )
  result = tp_add_move(
    result,
    ToolRetract,
    point,
    point,
    profile.cut_depth,
    profile.safe_height,
    profile.plunge_feed,
    DrillSource,
    layer,
  )
  result
}

///|
pub fn drill_board(
  board : Board,
  profile? : ToolMachineProfile = default_tool_machine_profile(),
) -> ToolpathPlan {
  let paths : Array[Toolpath] = []
  for layer in board.layers {
    if layer.kind is Drill {
      for index, shape in layer.shapes {
        match shape {
          DrillHit(x~, y~, ..) =>
            paths.push(
              drill_path(
                "\{layer.name}-\{index}",
                point2(x~, y~),
                layer.name,
                profile~,
              ),
            )
          _ => ()
        }
      }
    }
  }
  tp_plan_from_paths(profile, paths)
}

///|
pub fn ToolpathSummary::summary(self : ToolpathSummary) -> String {
  "paths=\{self.path_count}, moves=\{self.move_count}, cuts=\{self.cut_moves}, rapids=\{self.rapid_moves}, drills=\{self.drill_moves}, cut_length=\{self.cut_length}mm, rapid_length=\{self.rapid_length}mm, time=\{self.estimated_seconds}s"
}

///|
pub fn ToolpathSummary::estimated_minutes(self : ToolpathSummary) -> Double {
  self.estimated_seconds / 60.0
}

///|
pub fn ToolpathSummary::cut_ratio(self : ToolpathSummary) -> Double {
  let total = self.cut_length + self.rapid_length
  if total <= 0.0 {
    0.0
  } else {
    self.cut_length / total
  }
}

///|
pub fn toolpath_issue_to_json(issue : ToolpathIssue) -> String {
  let sequence = match issue.sequence {
    Some(value) => value.to_string()
    None => "null"
  }
  let location = match issue.location {
    Some(point) => "{\"x\":\{point.x},\"y\":\{point.y}}"
    None => "null"
  }
  let measured = match issue.measured {
    Some(value) => value.to_string()
    None => "null"
  }
  let limit = match issue.limit {
    Some(value) => value.to_string()
    None => "null"
  }
  "{\"rule\":\{json_string(toolpath_rule_name(issue.rule))},\"severity\":\{json_string(toolpath_severity_name(issue.severity))},\"path\":\{json_string(issue.path_name)},\"message\":\{json_string(issue.message)},\"sequence\":\{sequence},\"location\":\{location},\"measured\":\{measured},\"limit\":\{limit}}"
}

///|
pub fn toolpath_move_to_json(operation : ToolMove) -> String {
  "{\"sequence\":\{operation.sequence},\"kind\":\{json_string(toolpath_move_kind_name(operation.kind))},\"start\":{\"x\":\{operation.start.x},\"y\":\{operation.start.y},\"z\":\{operation.start_z}},\"end\":{\"x\":\{operation.end.x},\"y\":\{operation.end.y},\"z\":\{operation.end_z}},\"feed\":\{operation.feed},\"length\":\{operation.length},\"source\":\{json_string(toolpath_source_name(operation.source))},\"layer\":\{json_string(operation.layer)}}"
}

///|
pub fn toolpath_to_json(
  path : Toolpath,
  include_moves? : Bool = true,
) -> String {
  let moves = if include_moves {
    ",\"moves\":[" + path.moves.map(toolpath_move_to_json).join(",") + "]"
  } else {
    ""
  }
  "{\"name\":\{json_string(path.name)},\"source\":\{json_string(toolpath_source_name(path.source))},\"layer\":\{json_string(path.layer)},\"closed\":\{path.closed},\"move_count\":\{path.move_count()},\"cut_length\":\{path.cut_length},\"rapid_length\":\{path.rapid_length},\"estimated_seconds\":\{path.estimated_seconds}\{moves}}"
}

///|
pub fn toolpath_plan_to_json(
  plan : ToolpathPlan,
  include_moves? : Bool = false,
) -> String {
  let summary = plan.summary()
  let paths = plan.paths
    .map(path => toolpath_to_json(path, include_moves~))
    .join(",")
  let issues = plan.issues.map(toolpath_issue_to_json).join(",")
  "{\"profile\":\{json_string(plan.profile.name)},\"valid\":\{plan.is_valid()},\"path_count\":\{summary.path_count},\"move_count\":\{summary.move_count},\"cut_length\":\{summary.cut_length},\"rapid_length\":\{summary.rapid_length},\"estimated_seconds\":\{summary.estimated_seconds},\"paths\":[\{paths}],\"issues\":[\{issues}]}"
}

///|
pub fn toolpath_moves_to_csv(plan : ToolpathPlan) -> String {
  let mut output = "path,sequence,kind,start_x,start_y,start_z,end_x,end_y,end_z,feed,length,source,layer\n"
  for path in plan.paths {
    for operation in path.moves {
      output += json_escape(path.name) +
        "," +
        operation.sequence.to_string() +
        "," +
        toolpath_move_kind_name(operation.kind) +
        "," +
        operation.start.x.to_string() +
        "," +
        operation.start.y.to_string() +
        "," +
        operation.start_z.to_string() +
        "," +
        operation.end.x.to_string() +
        "," +
        operation.end.y.to_string() +
        "," +
        operation.end_z.to_string() +
        "," +
        operation.feed.to_string() +
        "," +
        operation.length.to_string() +
        "," +
        toolpath_source_name(operation.source) +
        "," +
        json_escape(operation.layer) +
        "\n"
    }
  }
  output
}

///|
pub fn toolpath_plan_to_text(plan : ToolpathPlan) -> String {
  let mut output = "Toolpath plan: \{plan.profile.summary()}\n"
  output += plan.summary().summary() + "\n"
  output += "valid=\{plan.is_valid()}, errors=\{plan.error_count()}, warnings=\{plan.warning_count()}\n"
  for path in plan.paths {
    output += "- " + path.summary() + "\n"
  }
  if plan.issues.length() > 0 {
    output += "Issues:\n"
    for issue in plan.issues {
      output += "  - \{toolpath_severity_name(issue.severity)} \{toolpath_rule_name(issue.rule)} [\{issue.path_name}]: \{issue.message}\n"
    }
  }
  output
}

///|
pub fn toolpath_to_gcode(
  plan : ToolpathPlan,
  program_name? : String = "GERBERKIT",
) -> String {
  let mut output = "%"
  output += "(\{program_name})\n"
  output += "G21\nG90\nG17\n"
  output += "S\{plan.profile.spindle_rpm} M3\n"
  for path in plan.paths {
    output += "(\{path.name})\n"
    for operation in path.moves {
      let command = match operation.kind {
        ToolRapid => "G0"
        ToolCut => "G1"
        ToolPlunge => "G1"
        ToolRetract => "G0"
        ToolDrill => "G1"
        ToolPause => "M0"
      }
      output += command +
        " X\{operation.end.x} Y\{operation.end.y} Z\{operation.end_z}"
      if operation.kind is ToolCut ||
        operation.kind is ToolPlunge ||
        operation.kind is ToolDrill {
        output += " F\{operation.feed}"
      }
      output += "\n"
    }
  }
  output += "G0 Z\{plan.profile.safe_height}\nM5\nM30\n%"
  output
}

///|
pub fn toolpath_to_linuxcnc(
  plan : ToolpathPlan,
  program_name? : String = "GERBERKIT",
) -> String {
  let base = toolpath_to_gcode(plan, program_name~)
  "(LinuxCNC generated by moonbit-gerberkit)\n" + base
}

///|
pub fn ToolpathPlan::bounds_width(self : ToolpathPlan) -> Double {
  match self.bounds {
    Some(value) => value.width()
    None => 0.0
  }
}

///|
pub fn ToolpathPlan::bounds_height(self : ToolpathPlan) -> Double {
  match self.bounds {
    Some(value) => value.height()
    None => 0.0
  }
}

///|
pub fn ToolpathPlan::machine_utilization(self : ToolpathPlan) -> Double {
  let area = self.profile.max_width * self.profile.max_height
  match self.bounds {
    Some(value) if area > 0.0 => value.area() / area
    _ => 0.0
  }
}

///|
pub fn ToolpathPlan::recalculate(self : ToolpathPlan) -> ToolpathPlan {
  tp_plan_from_paths(self.profile, self.paths.copy())
}

///|
pub fn ToolpathPlan::with_profile(
  self : ToolpathPlan,
  profile : ToolMachineProfile,
) -> ToolpathPlan {
  let paths : Array[Toolpath] = []
  for path in self.paths {
    let points : Array[Point2] = []
    for operation in path.moves {
      if operation.kind is ToolRapid ||
        operation.kind is ToolPlunge ||
        operation.kind is ToolCut ||
        operation.kind is ToolDrill {
        points.push(operation.end)
      }
    }
    if points.length() > 0 {
      paths.push(
        toolpath_from_points(
          name=path.name,
          points~,
          source=path.source,
          layer=path.layer,
          profile~,
          closed=path.closed,
        ),
      )
    }
  }
  tp_plan_from_paths(profile, paths)
}

///|
pub fn toolpath_plan_issue_count(
  plan : ToolpathPlan,
  severity : ToolpathIssueSeverity,
) -> Int {
  plan.issues.filter(issue => issue.severity == severity).length()
}

///|
pub fn toolpath_plan_has_source(
  plan : ToolpathPlan,
  source : ToolpathSourceKind,
) -> Bool {
  plan.paths.any(path => path.source == source)
}

///|
pub fn Toolpath::source_name(self : Toolpath) -> String {
  toolpath_source_name(self.source)
}

///|
pub fn Toolpath::start_point(self : Toolpath) -> Point2? {
  self.start
}

///|
pub fn Toolpath::end_point(self : Toolpath) -> Point2? {
  self.end
}

///|
pub fn Toolpath::last_move(self : Toolpath) -> ToolMove? {
  self.moves.last()
}

///|
pub fn Toolpath::first_cut(self : Toolpath) -> ToolMove? {
  for operation in self.moves {
    if operation.is_cut() {
      return Some(operation)
    }
  }
  None
}

///|
pub fn Toolpath::max_depth(self : Toolpath) -> Double {
  self.moves.fold(init=0.0, (depth, operation) => {
    if operation.end_z < depth {
      operation.end_z
    } else {
      depth
    }
  })
}

///|
pub fn Toolpath::uses_safe_height(
  self : Toolpath,
  safe_height : Double,
  tolerance? : Double = 0.000001,
) -> Bool {
  for operation in self.moves {
    if operation.kind is ToolRapid &&
      operation.start_z < safe_height - tolerance {
      return false
    }
  }
  true
}

///|
pub fn ToolpathPlan::all_paths_use_safe_height(self : ToolpathPlan) -> Bool {
  self.paths.all(path => path.uses_safe_height(self.profile.safe_height))
}

///|
pub fn ToolpathPlan::to_gcode(self : ToolpathPlan) -> String {
  toolpath_to_gcode(self)
}

///|
pub fn ToolpathPlan::to_csv(self : ToolpathPlan) -> String {
  toolpath_moves_to_csv(self)
}

///|
pub fn ToolpathPlan::to_json(self : ToolpathPlan) -> String {
  toolpath_plan_to_json(self)
}
