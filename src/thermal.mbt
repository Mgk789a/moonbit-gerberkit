///|
/// Thermal design review for copper distribution, pads, vias, and current
/// capacity. The model is intentionally deterministic: it gives an early
/// manufacturing estimate from Gerber geometry and reports the assumptions
/// next to every finding.
pub enum ThermalRole {
  ThermalPower
  ThermalGround
  ThermalSignal
  ThermalMixed
  ThermalUnknown
} derive(Debug, Eq)

///|
pub enum ThermalSeverity {
  ThermalInfo
  ThermalWarning
  ThermalCritical
} derive(Debug, Eq)

///|
pub struct ThermalProfile {
  name : String
  ambient_c : Double
  maximum_c : Double
  copper_conductivity : Double
  copper_thickness : Double
  convection : Double
  minimum_pad_area : Double
  maximum_current : Double
  warning_current : Double
  via_pitch : Double
  minimum_spokes : Int
  require_spokes : Bool
} derive(Debug)

///|
pub struct ThermalPad {
  layer : String
  index : Int
  location : Point2
  diameter : Double
  area : Double
  estimated_current : Double
  via_count : Int
  spoke_count : Int
  role : ThermalRole
  temperature_c : Double
} derive(Debug)

///|
pub struct ThermalFinding {
  severity : ThermalSeverity
  code : String
  message : String
  recommendation : String
  layer : String?
  location : Point2?
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct ThermalReport {
  profile : ThermalProfile
  pads : Array[ThermalPad]
  findings : Array[ThermalFinding]
  copper_area : Double
  heat_spread_area : Double
  estimated_capacity : Double
  maximum_temperature_c : Double
  valid : Bool
} derive(Debug)

///|
pub struct ThermalCell {
  column : Int
  row : Int
  center : Point2
  temperature_c : Double
  copper_area : Double
  occupied : Bool
} derive(Debug)

///|
pub struct ThermalGrid {
  bounds : Rect2
  columns : Int
  rows : Int
  cell_size : Double
  cells : Array[ThermalCell]
} derive(Debug)

///|
pub struct ThermalDelta {
  previous_temperature : Double
  current_temperature : Double
  previous_capacity : Double
  current_capacity : Double
  temperature_change : Double
  capacity_change : Double
  improved : Bool
} derive(Debug)

///|
pub fn thermal_role_name(value : ThermalRole) -> String {
  match value {
    ThermalPower => "power"
    ThermalGround => "ground"
    ThermalSignal => "signal"
    ThermalMixed => "mixed"
    ThermalUnknown => "unknown"
  }
}

///|
pub fn thermal_severity_name(value : ThermalSeverity) -> String {
  match value {
    ThermalInfo => "info"
    ThermalWarning => "warning"
    ThermalCritical => "critical"
  }
}

///|
pub fn thermal_profile(
  name~ : String,
  ambient_c~ : Double,
  maximum_c~ : Double,
  copper_conductivity~ : Double,
  copper_thickness~ : Double,
  convection~ : Double,
  minimum_pad_area~ : Double,
  maximum_current~ : Double,
  warning_current~ : Double,
  via_pitch~ : Double,
  minimum_spokes~ : Int,
  require_spokes~ : Bool,
) -> ThermalProfile {
  {
    name,
    ambient_c: if ambient_c < -50.0 {
      -50.0
    } else {
      ambient_c
    },
    maximum_c: if maximum_c <= ambient_c {
      ambient_c + 1.0
    } else {
      maximum_c
    },
    copper_conductivity: if copper_conductivity <= 0.0 {
      1.0
    } else {
      copper_conductivity
    },
    copper_thickness: if copper_thickness <= 0.0 {
      0.035
    } else {
      copper_thickness
    },
    convection: if convection <= 0.0 {
      1.0
    } else {
      convection
    },
    minimum_pad_area: if minimum_pad_area < 0.0 {
      0.0
    } else {
      minimum_pad_area
    },
    maximum_current: if maximum_current < 0.0 {
      0.0
    } else {
      maximum_current
    },
    warning_current: if warning_current < 0.0 {
      0.0
    } else {
      warning_current
    },
    via_pitch: if via_pitch <= 0.0 {
      1.0
    } else {
      via_pitch
    },
    minimum_spokes: if minimum_spokes < 0 {
      0
    } else {
      minimum_spokes
    },
    require_spokes,
  }
}

///|
pub fn standard_thermal_profile() -> ThermalProfile {
  thermal_profile(
    name="standard-1oz",
    ambient_c=25.0,
    maximum_c=105.0,
    copper_conductivity=1.0,
    copper_thickness=0.035,
    convection=1.0,
    minimum_pad_area=0.5,
    maximum_current=3.0,
    warning_current=2.0,
    via_pitch=1.0,
    minimum_spokes=4,
    require_spokes=false,
  )
}

///|
pub fn high_current_thermal_profile() -> ThermalProfile {
  thermal_profile(
    name="high-current-2oz",
    ambient_c=25.0,
    maximum_c=100.0,
    copper_conductivity=1.2,
    copper_thickness=0.070,
    convection=1.0,
    minimum_pad_area=1.2,
    maximum_current=8.0,
    warning_current=5.0,
    via_pitch=1.2,
    minimum_spokes=6,
    require_spokes=true,
  )
}

///|
pub fn compact_thermal_profile() -> ThermalProfile {
  thermal_profile(
    name="compact-enclosure",
    ambient_c=40.0,
    maximum_c=95.0,
    copper_conductivity=0.9,
    copper_thickness=0.035,
    convection=0.65,
    minimum_pad_area=0.35,
    maximum_current=1.5,
    warning_current=1.0,
    via_pitch=0.8,
    minimum_spokes=3,
    require_spokes=true,
  )
}

///|
pub fn conservative_thermal_profile() -> ThermalProfile {
  thermal_profile(
    name="conservative",
    ambient_c=25.0,
    maximum_c=85.0,
    copper_conductivity=0.75,
    copper_thickness=0.035,
    convection=0.5,
    minimum_pad_area=0.8,
    maximum_current=1.0,
    warning_current=0.6,
    via_pitch=0.8,
    minimum_spokes=4,
    require_spokes=true,
  )
}

///|
pub fn ThermalProfile::summary(self : ThermalProfile) -> String {
  "\{self.name}: ambient=\{self.ambient_c}C max=\{self.maximum_c}C copper=\{self.copper_thickness}mm current=\{self.maximum_current}A"
}

///|
pub fn ThermalProfile::with_current_limit(
  self : ThermalProfile,
  maximum_current : Double,
  warning_current : Double,
) -> ThermalProfile {
  thermal_profile(
    name=self.name,
    ambient_c=self.ambient_c,
    maximum_c=self.maximum_c,
    copper_conductivity=self.copper_conductivity,
    copper_thickness=self.copper_thickness,
    convection=self.convection,
    minimum_pad_area=self.minimum_pad_area,
    maximum_current~,
    warning_current~,
    via_pitch=self.via_pitch,
    minimum_spokes=self.minimum_spokes,
    require_spokes=self.require_spokes,
  )
}

///|
pub fn ThermalProfile::with_temperature_limit(
  self : ThermalProfile,
  maximum_c : Double,
) -> ThermalProfile {
  thermal_profile(
    name=self.name,
    ambient_c=self.ambient_c,
    maximum_c~,
    copper_conductivity=self.copper_conductivity,
    copper_thickness=self.copper_thickness,
    convection=self.convection,
    minimum_pad_area=self.minimum_pad_area,
    maximum_current=self.maximum_current,
    warning_current=self.warning_current,
    via_pitch=self.via_pitch,
    minimum_spokes=self.minimum_spokes,
    require_spokes=self.require_spokes,
  )
}

///|
pub fn ThermalPad::utilization(
  self : ThermalPad,
  profile : ThermalProfile,
) -> Double {
  if profile.maximum_current <= 0.0 {
    1.0
  } else {
    self.estimated_current / profile.maximum_current
  }
}

///|
pub fn ThermalPad::is_hot(self : ThermalPad, profile : ThermalProfile) -> Bool {
  self.temperature_c > profile.maximum_c
}

///|
pub fn ThermalPad::summary(self : ThermalPad) -> String {
  "pad \{self.layer}[\{self.index}] at \{self.location.x},\{self.location.y}: area=\{self.area}, current=\{self.estimated_current}A, temp=\{self.temperature_c}C, vias=\{self.via_count}, spokes=\{self.spoke_count}"
}

///|
pub fn ThermalFinding::is_critical(self : ThermalFinding) -> Bool {
  self.severity is ThermalCritical
}

///|
pub fn ThermalFinding::is_warning(self : ThermalFinding) -> Bool {
  self.severity is ThermalWarning
}

///|
pub fn ThermalFinding::summary(self : ThermalFinding) -> String {
  let layer = match self.layer {
    Some(value) => " layer=" + value
    None => ""
  }
  "\{thermal_severity_name(self.severity)} \{self.code}\{layer}: \{self.message}"
}

///|
pub fn ThermalReport::critical_count(self : ThermalReport) -> Int {
  self.findings.filter(item => item.is_critical()).length()
}

///|
pub fn ThermalReport::warning_count(self : ThermalReport) -> Int {
  self.findings.filter(item => item.is_warning()).length()
}

///|
pub fn ThermalReport::is_valid(self : ThermalReport) -> Bool {
  self.valid
}

///|
pub fn ThermalReport::hot_pad_count(self : ThermalReport) -> Int {
  self.pads.filter(pad => pad.temperature_c > self.profile.maximum_c).length()
}

///|
pub fn ThermalReport::summary(self : ThermalReport) -> String {
  "profile=\{self.profile.name}, pads=\{self.pads.length()}, copper=\{self.copper_area}, spread=\{self.heat_spread_area}, capacity=\{self.estimated_capacity}A, max_temp=\{self.maximum_temperature_c}C, critical=\{self.critical_count()}, warnings=\{self.warning_count()}"
}

///|
fn thermal_distance(a : Point2, b : Point2) -> Double {
  a.distance(b)
}

///|
fn thermal_shape_center(shape : Shape) -> Point2? {
  match shape {
    Segment(x1~, y1~, x2~, y2~, ..) =>
      Some(point2(x=(x1 + x2) / 2.0, y=(y1 + y2) / 2.0))
    Pad(x~, y~, ..) => Some(point2(x~, y~))
    Flash(x~, y~, ..) => Some(point2(x~, y~))
    DrillHit(x~, y~, ..) => Some(point2(x~, y~))
    Region(points~) =>
      if points.length() == 0 {
        None
      } else {
        let mut x = 0.0
        let mut y = 0.0
        for pair in points {
          x += pair.0
          y += pair.1
        }
        Some(
          point2(
            x=x / points.length().to_double(),
            y=y / points.length().to_double(),
          ),
        )
      }
  }
}

///|
fn thermal_shape_diameter(shape : Shape) -> Double {
  match shape {
    Pad(diameter~, ..) => diameter
    Flash(..) => 1.0
    DrillHit(diameter~, ..) => diameter
    Segment(x1~, y1~, x2~, y2~, width~) => {
      let _ = x1 + y1 + x2 + y2
      width
    }
    Region(points~) => {
      let mut result = 0.0
      for first in points {
        for second in points {
          let dx = first.0 - second.0
          let dy = first.1 - second.1
          let distance = (dx * dx + dy * dy).sqrt()
          if distance > result {
            result = distance
          }
        }
      }
      result
    }
  }
}

///|
fn thermal_shape_area(shape : Shape) -> Double {
  let value = shape_area(shape)
  if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn thermal_layer_copper_area(layer : Layer) -> Double {
  if layer.kind is Copper {
    layer.shapes.fold(init=0.0, (sum, shape) => sum + thermal_shape_area(shape))
  } else {
    0.0
  }
}

///|
fn thermal_board_copper_area(board : Board) -> Double {
  board.layers.fold(init=0.0, (sum, layer) => {
    sum + thermal_layer_copper_area(layer)
  })
}

///|
fn thermal_pad_area(shape : Shape) -> Double {
  match shape {
    Pad(..) => thermal_shape_area(shape)
    Flash(..) => 0.7853981633974483
    _ => 0.0
  }
}

///|
fn thermal_via_count(board : Board, location : Point2, radius : Double) -> Int {
  let mut count = 0
  for layer in board.layers {
    for shape in layer.shapes {
      match shape {
        DrillHit(x~, y~, ..) =>
          if thermal_distance(location, point2(x~, y~)) <= radius {
            count += 1
          }
        _ => ()
      }
    }
  }
  count
}

///|
fn thermal_spoke_count(
  layer : Layer,
  location : Point2,
  radius : Double,
) -> Int {
  let mut count = 0
  for shape in layer.shapes {
    match shape {
      Segment(x1~, y1~, x2~, y2~, ..) => {
        let first = thermal_distance(location, point2(x=x1, y=y1))
        let second = thermal_distance(location, point2(x=x2, y=y2))
        if first <= radius || second <= radius {
          count += 1
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn thermal_role_for_layer(layer : Layer) -> ThermalRole {
  if layer.kind is Drill {
    ThermalUnknown
  } else if layer.name.to_upper().contains("GND") ||
    layer.name.to_upper().contains("GROUND") {
    ThermalGround
  } else if layer.name.to_upper().contains("PWR") ||
    layer.name.to_upper().contains("POWER") ||
    layer.name.to_upper().contains("VCC") {
    ThermalPower
  } else if layer.kind is Copper {
    ThermalMixed
  } else {
    ThermalSignal
  }
}

///|
fn thermal_temperature(
  profile : ThermalProfile,
  area : Double,
  current : Double,
  spread : Double,
) -> Double {
  let normalized_area = if area <= 0.000001 { 0.000001 } else { area }
  let normalized_spread = if spread <= 0.000001 { 0.000001 } else { spread }
  let heat = current * current / (normalized_area + normalized_spread)
  let rise = heat / (profile.convection * profile.copper_conductivity)
  profile.ambient_c + rise * 8.0
}

///|
fn thermal_current_capacity(
  profile : ThermalProfile,
  area : Double,
  spread : Double,
) -> Double {
  let effective = if area + spread <= 0.0 { 0.0 } else { area + spread }
  effective.sqrt() *
  profile.copper_conductivity *
  (profile.copper_thickness / 0.035).sqrt() *
  profile.convection.sqrt() *
  4.5
}

///|
fn thermal_pad_from_shape(
  board : Board,
  layer : Layer,
  index : Int,
  shape : Shape,
  profile : ThermalProfile,
) -> ThermalPad? {
  match thermal_shape_center(shape) {
    None => None
    Some(location) => {
      let area = thermal_pad_area(shape)
      if area <= 0.0 {
        None
      } else {
        let radius = max(profile.via_pitch * 1.5, thermal_shape_diameter(shape))
        let vias = thermal_via_count(board, location, radius)
        let spokes = thermal_spoke_count(layer, location, radius)
        let spread = area + vias.to_double() * profile.via_pitch * 0.2
        let capacity = thermal_current_capacity(profile, area, spread)
        let temperature = thermal_temperature(
          profile,
          area,
          min(capacity, profile.maximum_current),
          spread,
        )
        Some({
          layer: layer.name,
          index,
          location,
          diameter: thermal_shape_diameter(shape),
          area,
          estimated_current: capacity,
          via_count: vias,
          spoke_count: spokes,
          role: thermal_role_for_layer(layer),
          temperature_c: temperature,
        })
      }
    }
  }
}

///|
fn thermal_finding(
  severity : ThermalSeverity,
  code : String,
  message : String,
  recommendation : String,
  layer : String?,
  location : Point2?,
  measured : Double?,
  limit : Double?,
) -> ThermalFinding {
  { severity, code, message, recommendation, layer, location, measured, limit }
}

///|
fn thermal_pad_findings(
  pad : ThermalPad,
  profile : ThermalProfile,
) -> Array[ThermalFinding] {
  let findings : Array[ThermalFinding] = []
  if pad.area < profile.minimum_pad_area {
    findings.push(
      thermal_finding(
        ThermalCritical,
        "pad-area",
        "copper area is below the thermal minimum",
        "increase copper area or add a thermal land",
        Some(pad.layer),
        Some(pad.location),
        Some(pad.area),
        Some(profile.minimum_pad_area),
      ),
    )
  }
  if pad.estimated_current > profile.maximum_current {
    findings.push(
      thermal_finding(
        ThermalCritical,
        "current-capacity",
        "estimated pad capacity exceeds the selected process limit",
        "widen the copper path, add copper pour, or reduce load",
        Some(pad.layer),
        Some(pad.location),
        Some(pad.estimated_current),
        Some(profile.maximum_current),
      ),
    )
  } else if pad.estimated_current > profile.warning_current {
    findings.push(
      thermal_finding(
        ThermalWarning,
        "current-headroom",
        "current demand is close to the thermal profile limit",
        "reserve additional copper area for production variation",
        Some(pad.layer),
        Some(pad.location),
        Some(pad.estimated_current),
        Some(profile.maximum_current),
      ),
    )
  }
  if pad.temperature_c > profile.maximum_c {
    findings.push(
      thermal_finding(
        ThermalCritical,
        "temperature",
        "estimated junction temperature exceeds the thermal ceiling",
        "improve spreading and airflow before release",
        Some(pad.layer),
        Some(pad.location),
        Some(pad.temperature_c),
        Some(profile.maximum_c),
      ),
    )
  } else if pad.temperature_c > profile.maximum_c - 10.0 {
    findings.push(
      thermal_finding(
        ThermalWarning,
        "temperature-headroom",
        "estimated temperature leaves less than 10 C of headroom",
        "review enclosure temperature and copper spreading",
        Some(pad.layer),
        Some(pad.location),
        Some(pad.temperature_c),
        Some(profile.maximum_c),
      ),
    )
  }
  if profile.require_spokes && pad.spoke_count < profile.minimum_spokes {
    findings.push(
      thermal_finding(
        ThermalWarning,
        "thermal-spokes",
        "pad has fewer relief spokes than the selected profile",
        "add or widen thermal relief connections",
        Some(pad.layer),
        Some(pad.location),
        Some(pad.spoke_count.to_double()),
        Some(profile.minimum_spokes.to_double()),
      ),
    )
  }
  if profile.require_spokes && pad.via_count == 0 && pad.role is ThermalPower {
    findings.push(
      thermal_finding(
        ThermalWarning,
        "via-spreading",
        "power pad has no nearby thermal spreading vias",
        "add a via array with a documented pitch",
        Some(pad.layer),
        Some(pad.location),
        Some(0.0),
        Some(1.0),
      ),
    )
  }
  findings
}

///|
pub fn analyze_thermal(
  board : Board,
  profile? : ThermalProfile = standard_thermal_profile(),
) -> ThermalReport {
  let pads : Array[ThermalPad] = []
  let findings : Array[ThermalFinding] = []
  for layer in board.layers {
    for index in 0..<layer.shapes.length() {
      match
        thermal_pad_from_shape(
          board,
          layer,
          index,
          layer.shapes[index],
          profile,
        ) {
        None => ()
        Some(pad) =>
          if layer.kind is Copper {
            pads.push(pad)
            for finding in thermal_pad_findings(pad, profile) {
              findings.push(finding)
            }
          }
      }
    }
  }
  let copper_area = thermal_board_copper_area(board)
  let spread = copper_area * 0.75
  let capacity = thermal_current_capacity(profile, copper_area, spread)
  let maximum_temperature = pads.fold(init=profile.ambient_c, (current, pad) => {
    if pad.temperature_c > current {
      pad.temperature_c
    } else {
      current
    }
  })
  if copper_area == 0.0 {
    findings.push(
      thermal_finding(
        ThermalInfo,
        "no-copper",
        "board contains no copper geometry for thermal estimation",
        "provide copper layers before using the thermal gate",
        None,
        None,
        Some(0.0),
        Some(profile.minimum_pad_area),
      ),
    )
  }
  {
    profile,
    pads,
    findings,
    copper_area,
    heat_spread_area: spread,
    estimated_capacity: capacity,
    maximum_temperature_c: maximum_temperature,
    valid: findings.filter(item => item.severity is ThermalCritical).length() ==
    0,
  }
}

///|
pub fn thermal_capacity(
  board : Board,
  profile? : ThermalProfile = standard_thermal_profile(),
) -> Double {
  let area = thermal_board_copper_area(board)
  thermal_current_capacity(profile, area, area * 0.75)
}

///|
pub fn thermal_temperature_for_board(
  board : Board,
  current : Double,
  profile? : ThermalProfile = standard_thermal_profile(),
) -> Double {
  let area = thermal_board_copper_area(board)
  thermal_temperature(profile, area, current, area * 0.75)
}

///|
pub fn ThermalGrid::cell_count(self : ThermalGrid) -> Int {
  self.cells.length()
}

///|
pub fn ThermalGrid::cell(
  self : ThermalGrid,
  column : Int,
  row : Int,
) -> ThermalCell? {
  if column < 0 || row < 0 || column >= self.columns || row >= self.rows {
    None
  } else {
    self.cells.get(row * self.columns + column)
  }
}

///|
pub fn ThermalGrid::maximum_temperature(self : ThermalGrid) -> Double {
  self.cells.fold(init=0.0, (current, cell) => {
    if cell.temperature_c > current {
      cell.temperature_c
    } else {
      current
    }
  })
}

///|
pub fn ThermalGrid::average_temperature(self : ThermalGrid) -> Double {
  if self.cells.length() == 0 {
    0.0
  } else {
    self.cells.fold(init=0.0, (sum, cell) => sum + cell.temperature_c) /
    self.cells.length().to_double()
  }
}

///|
pub fn ThermalGrid::occupied_count(self : ThermalGrid) -> Int {
  self.cells.filter(cell => cell.occupied).length()
}

///|
fn thermal_cell_copper(
  board : Board,
  center : Point2,
  radius : Double,
) -> Double {
  let mut area = 0.0
  for layer in board.layers {
    if layer.kind is Copper {
      for shape in layer.shapes {
        match thermal_shape_center(shape) {
          Some(location) if thermal_distance(location, center) <= radius =>
            area += thermal_shape_area(shape)
          _ => ()
        }
      }
    }
  }
  area
}

///|
fn thermal_cell_temperature(
  board : Board,
  profile : ThermalProfile,
  center : Point2,
  radius : Double,
) -> Double {
  let copper = thermal_cell_copper(board, center, radius)
  let current = thermal_current_capacity(profile, copper, copper * 0.5)
  thermal_temperature(
    profile,
    copper,
    min(current, profile.maximum_current),
    copper * 0.5,
  )
}

///|
pub fn thermal_grid(
  board : Board,
  profile? : ThermalProfile = standard_thermal_profile(),
  cell_size? : Double = 5.0,
) -> ThermalGrid {
  let metrics = board_metrics(board)
  let bounds = match metrics.bounds {
    Some(value) => value
    None => rect2(min_x=0.0, min_y=0.0, max_x=cell_size, max_y=cell_size)
  }
  let safe_size = if cell_size <= 0.0 { 1.0 } else { cell_size }
  let raw_columns = (bounds.width() / safe_size).ceil().to_int()
  let raw_rows = (bounds.height() / safe_size).ceil().to_int()
  let columns = if raw_columns < 1 {
    1
  } else if raw_columns > 256 {
    256
  } else {
    raw_columns
  }
  let rows = if raw_rows < 1 {
    1
  } else if raw_rows > 256 {
    256
  } else {
    raw_rows
  }
  let cells : Array[ThermalCell] = []
  for row in 0..<rows {
    for column in 0..<columns {
      let center = point2(
        x=bounds.min_x + (column.to_double() + 0.5) * safe_size,
        y=bounds.min_y + (row.to_double() + 0.5) * safe_size,
      )
      let copper = thermal_cell_copper(board, center, safe_size * 0.75)
      let occupied = copper > 0.0
      cells.push({
        column,
        row,
        center,
        temperature_c: thermal_cell_temperature(
          board,
          profile,
          center,
          safe_size * 0.75,
        ),
        copper_area: copper,
        occupied,
      })
    }
  }
  { bounds, columns, rows, cell_size: safe_size, cells }
}

///|
pub fn thermal_delta(
  previous : ThermalReport,
  current : ThermalReport,
) -> ThermalDelta {
  let temperature_change = current.maximum_temperature_c -
    previous.maximum_temperature_c
  let capacity_change = current.estimated_capacity - previous.estimated_capacity
  {
    previous_temperature: previous.maximum_temperature_c,
    current_temperature: current.maximum_temperature_c,
    previous_capacity: previous.estimated_capacity,
    current_capacity: current.estimated_capacity,
    temperature_change,
    capacity_change,
    improved: temperature_change <= 0.0 && capacity_change >= 0.0,
  }
}

///|
pub fn ThermalDelta::summary(self : ThermalDelta) -> String {
  "temperature=\{self.previous_temperature} -> \{self.current_temperature} (delta=\{self.temperature_change}), capacity=\{self.previous_capacity} -> \{self.current_capacity} (delta=\{self.capacity_change}), improved=\{self.improved}"
}

///|
fn thermal_optional_number(value : Double?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}

///|
fn thermal_optional_point(value : Point2?) -> String {
  match value {
    Some(point) => "{\"x\":\{point.x},\"y\":\{point.y}}"
    None => "null"
  }
}

///|
pub fn ThermalPad::to_json(self : ThermalPad) -> String {
  "{\"layer\":\{json_string(self.layer)},\"index\":\{self.index},\"x\":\{self.location.x},\"y\":\{self.location.y},\"diameter\":\{self.diameter},\"area\":\{self.area},\"current\":\{self.estimated_current},\"vias\":\{self.via_count},\"spokes\":\{self.spoke_count},\"role\":\{json_string(thermal_role_name(self.role))},\"temperature_c\":\{self.temperature_c}}"
}

///|
pub fn ThermalFinding::to_json(self : ThermalFinding) -> String {
  let layer = match self.layer {
    Some(value) => json_string(value)
    None => "null"
  }
  "{\"severity\":\{json_string(thermal_severity_name(self.severity))},\"code\":\{json_string(self.code)},\"message\":\{json_string(self.message)},\"recommendation\":\{json_string(self.recommendation)},\"layer\":\{layer},\"location\":\{thermal_optional_point(self.location)},\"measured\":\{thermal_optional_number(self.measured)},\"limit\":\{thermal_optional_number(self.limit)}}"
}

///|
pub fn ThermalReport::to_json(self : ThermalReport) -> String {
  let pads = self.pads.map(ThermalPad::to_json).join(",")
  let findings = self.findings.map(ThermalFinding::to_json).join(",")
  "{\"profile\":\{json_string(self.profile.name)},\"pads\":[\{pads}],\"findings\":[\{findings}],\"copper_area\":\{self.copper_area},\"spread_area\":\{self.heat_spread_area},\"capacity\":\{self.estimated_capacity},\"maximum_temperature_c\":\{self.maximum_temperature_c},\"valid\":\{self.valid}}"
}

///|
pub fn ThermalReport::to_text(self : ThermalReport) -> String {
  let mut output = "Thermal report\n\{self.profile.summary()}\n\{self.summary()}\n"
  for pad in self.pads {
    output += "  \{pad.summary()}\n"
  }
  for finding in self.findings {
    output += "  \{finding.summary()}\n"
    output += "    recommendation: \{finding.recommendation}\n"
  }
  output
}

///|
pub fn ThermalGrid::to_json(self : ThermalGrid) -> String {
  let cells = self.cells
    .map(cell => {
      "{\"column\":\{cell.column},\"row\":\{cell.row},\"x\":\{cell.center.x},\"y\":\{cell.center.y},\"temperature_c\":\{cell.temperature_c},\"copper_area\":\{cell.copper_area},\"occupied\":\{cell.occupied}}"
    })
    .join(",")
  "{\"columns\":\{self.columns},\"rows\":\{self.rows},\"cell_size\":\{self.cell_size},\"cells\":[\{cells}]}"
}

///|
pub fn ThermalGrid::to_csv(self : ThermalGrid) -> String {
  let mut output = "column,row,x,y,temperature_c,copper_area,occupied\n"
  for cell in self.cells {
    output += "\{cell.column},\{cell.row},\{cell.center.x},\{cell.center.y},\{cell.temperature_c},\{cell.copper_area},\{cell.occupied}\n"
  }
  output
}

///|
pub fn ThermalReport::to_csv(self : ThermalReport) -> String {
  let mut output = "severity,code,layer,x,y,measured,limit,message\n"
  for finding in self.findings {
    let layer = match finding.layer {
      Some(value) => value
      None => ""
    }
    let (x, y) = match finding.location {
      Some(point) => (point.x.to_string(), point.y.to_string())
      None => ("", "")
    }
    output += "\{thermal_severity_name(finding.severity)},\{finding.code},\{layer},\{x},\{y},\{thermal_optional_number(finding.measured)},\{thermal_optional_number(finding.limit)},\{finding.message}\n"
  }
  output
}

///|
pub fn thermal_profile_catalog() -> Array[ThermalProfile] {
  [
    standard_thermal_profile(),
    high_current_thermal_profile(),
    compact_thermal_profile(),
    conservative_thermal_profile(),
  ]
}

///|
pub fn thermal_catalog_markdown() -> String {
  let mut output = "| Profile | Ambient C | Maximum C | Thickness mm | Warning A | Maximum A |\n|---|---:|---:|---:|---:|---:|\n"
  for profile in thermal_profile_catalog() {
    output += "|\{profile.name}|\{profile.ambient_c}|\{profile.maximum_c}|\{profile.copper_thickness}|\{profile.warning_current}|\{profile.maximum_current}|\n"
  }
  output
}

///|
pub fn thermal_report_health(report : ThermalReport) -> Bool {
  report.valid &&
  report.critical_count() == 0 &&
  report.maximum_temperature_c <= report.profile.maximum_c
}
