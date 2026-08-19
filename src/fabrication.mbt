///|
/// Manufacturing capability profiles and board-level acceptance estimates.
///
/// This module keeps fabrication policy separate from geometric parsing. A
/// caller can use the same parsed board with a prototype, standard, or fine
/// pitch profile and receive deterministic checks, utilization, and a small
/// production estimate suitable for CI reports.
pub enum FabricationClass {
  PrototypeClass
  StandardClass
  FinePitchClass
} derive(Debug, Eq)

///|
pub enum MaterialFamily {
  Fr4Material
  HighTgMaterial
  AluminumMaterial
  FlexibleMaterial
} derive(Debug, Eq)

///|
pub struct FabricationProfile {
  name : String
  class : FabricationClass
  material : MaterialFamily
  min_trace_width : Double
  min_clearance : Double
  min_drill : Double
  max_board_width : Double
  max_board_height : Double
  max_layers : Int
  preferred_finish : String
} derive(Debug)

///|
pub struct FabricationCheck {
  code : String
  passed : Bool
  message : String
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct FabricationAssessment {
  profile : FabricationProfile
  passed : Bool
  score : Double
  checks : Array[FabricationCheck]
  board_area : Double
  copper_area : Double
  drill_count : Int
  estimated_minutes : Double
  estimated_cost : Double
} derive(Debug)

///|
pub fn prototype_fabrication_profile() -> FabricationProfile {
  {
    name: "prototype-fr4",
    class: PrototypeClass,
    material: Fr4Material,
    min_trace_width: 0.15,
    min_clearance: 0.15,
    min_drill: 0.25,
    max_board_width: 300.0,
    max_board_height: 300.0,
    max_layers: 4,
    preferred_finish: "HASL",
  }
}

///|
pub fn standard_fabrication_profile() -> FabricationProfile {
  {
    name: "standard-fr4",
    class: StandardClass,
    material: Fr4Material,
    min_trace_width: 0.10,
    min_clearance: 0.10,
    min_drill: 0.20,
    max_board_width: 500.0,
    max_board_height: 500.0,
    max_layers: 8,
    preferred_finish: "ENIG",
  }
}

///|
pub fn fine_pitch_fabrication_profile() -> FabricationProfile {
  {
    name: "fine-pitch-high-tg",
    class: FinePitchClass,
    material: HighTgMaterial,
    min_trace_width: 0.075,
    min_clearance: 0.075,
    min_drill: 0.15,
    max_board_width: 400.0,
    max_board_height: 400.0,
    max_layers: 12,
    preferred_finish: "ENIG",
  }
}

///|
pub fn aluminum_fabrication_profile() -> FabricationProfile {
  {
    name: "aluminum-thermal",
    class: StandardClass,
    material: AluminumMaterial,
    min_trace_width: 0.15,
    min_clearance: 0.15,
    min_drill: 0.30,
    max_board_width: 400.0,
    max_board_height: 400.0,
    max_layers: 2,
    preferred_finish: "HASL",
  }
}

///|
pub fn flexible_fabrication_profile() -> FabricationProfile {
  {
    name: "flexible-polyimide",
    class: PrototypeClass,
    material: FlexibleMaterial,
    min_trace_width: 0.12,
    min_clearance: 0.12,
    min_drill: 0.20,
    max_board_width: 250.0,
    max_board_height: 150.0,
    max_layers: 4,
    preferred_finish: "ENIG",
  }
}

///|
pub fn fabrication_class_name(value : FabricationClass) -> String {
  match value {
    PrototypeClass => "prototype"
    StandardClass => "standard"
    FinePitchClass => "fine-pitch"
  }
}

///|
pub fn material_family_name(value : MaterialFamily) -> String {
  match value {
    Fr4Material => "FR-4"
    HighTgMaterial => "high-Tg FR-4"
    AluminumMaterial => "aluminum"
    FlexibleMaterial => "flexible-polyimide"
  }
}

///|
pub fn FabricationProfile::name(self : FabricationProfile) -> String {
  self.name
}

///|
pub fn FabricationProfile::class_name(self : FabricationProfile) -> String {
  fabrication_class_name(self.class)
}

///|
pub fn FabricationProfile::material_name(self : FabricationProfile) -> String {
  material_family_name(self.material)
}

///|
pub fn FabricationProfile::summary(self : FabricationProfile) -> String {
  "\{self.name}: class=\{self.class_name()}, material=\{self.material_name()}, trace>=\{self.min_trace_width}mm, clearance>=\{self.min_clearance}mm, drill>=\{self.min_drill}mm, max=\{self.max_board_width}x\{self.max_board_height}mm, layers<=\{self.max_layers}, finish=\{self.preferred_finish}"
}

///|
pub fn FabricationCheck::code(self : FabricationCheck) -> String {
  self.code
}

///|
pub fn FabricationCheck::is_passed(self : FabricationCheck) -> Bool {
  self.passed
}

///|
pub fn FabricationCheck::format(self : FabricationCheck) -> String {
  let state = if self.passed { "pass" } else { "fail" }
  let measurement = match (self.measured, self.limit) {
    (Some(measured), Some(limit)) => " measured=\{measured} limit=\{limit}"
    (Some(measured), None) => " measured=\{measured}"
    _ => ""
  }
  "[\{state}] \{self.code}: \{self.message}\{measurement}"
}

///|
pub fn FabricationAssessment::check_count(self : FabricationAssessment) -> Int {
  self.checks.length()
}

///|
pub fn FabricationAssessment::failed_check_count(
  self : FabricationAssessment,
) -> Int {
  self.checks.filter(check => !check.passed).length()
}

///|
pub fn FabricationAssessment::summary(self : FabricationAssessment) -> String {
  "profile=\{self.profile.name}, passed=\{self.passed}, score=\{self.score}, checks=\{self.check_count()}, failed=\{self.failed_check_count()}, area=\{self.board_area}mm2, copper=\{self.copper_area}mm2, drills=\{self.drill_count}, eta=\{self.estimated_minutes}min, cost=\{self.estimated_cost}"
}

///|
fn fabrication_check(
  checks : Array[FabricationCheck],
  code : String,
  passed : Bool,
  message : String,
  measured : Double?,
  limit : Double?,
) -> Unit {
  checks.push({ code, passed, message, measured, limit })
}

///|
fn fabrication_min_trace(board : Board) -> Double? {
  let mut value : Double? = None
  for layer in board.layers {
    for shape in layer.shapes {
      match shape {
        Segment(width~, ..) =>
          value = match value {
            Some(old) => Some(if width < old { width } else { old })
            None => Some(width)
          }
        _ => ()
      }
    }
  }
  value
}

///|
fn fabrication_min_drill(board : Board) -> Double? {
  let mut value : Double? = None
  for layer in board.layers {
    for shape in layer.shapes {
      match shape {
        DrillHit(diameter~, ..) =>
          value = match value {
            Some(old) => Some(if diameter < old { diameter } else { old })
            None => Some(diameter)
          }
        _ => ()
      }
    }
  }
  value
}

///|
fn fabrication_drill_count(board : Board) -> Int {
  let mut count = 0
  for layer in board.layers {
    for shape in layer.shapes {
      match shape {
        DrillHit(..) => count += 1
        _ => ()
      }
    }
  }
  count
}

///|
fn fabrication_copper_area(board : Board) -> Double {
  let mut total = 0.0
  for layer in board.layers {
    if layer.kind is Copper {
      for shape in layer.shapes {
        total += shape_area(shape)
      }
    }
  }
  total
}

///|
fn fabrication_layer_check(
  board : Board,
  profile : FabricationProfile,
  checks : Array[FabricationCheck],
) -> Unit {
  let layer_count = board.layers.length()
  fabrication_check(
    checks,
    "layer-count",
    layer_count > 0 && layer_count <= profile.max_layers,
    "board layer count is within the profile capacity",
    Some(layer_count.to_double()),
    Some(profile.max_layers.to_double()),
  )
}

///|
fn fabrication_size_check(
  board : Board,
  profile : FabricationProfile,
  checks : Array[FabricationCheck],
) -> (Double, Double, Double) {
  match board_bounds(board) {
    Some(bounds) => {
      let width = bounds.max_x - bounds.min_x
      let height = bounds.max_y - bounds.min_y
      fabrication_check(
        checks,
        "board-size",
        width <= profile.max_board_width && height <= profile.max_board_height,
        "board dimensions fit the selected fabrication envelope",
        Some(max(width, height)),
        Some(max(profile.max_board_width, profile.max_board_height)),
      )
      (width, height, width * height)
    }
    None => {
      fabrication_check(
        checks,
        "board-size",
        false,
        "board has no measurable geometry",
        None,
        None,
      )
      (0.0, 0.0, 0.0)
    }
  }
}

///|
fn fabrication_geometry_checks(
  board : Board,
  profile : FabricationProfile,
  checks : Array[FabricationCheck],
) -> Unit {
  match fabrication_min_trace(board) {
    Some(value) =>
      fabrication_check(
        checks,
        "minimum-trace-width",
        value >= profile.min_trace_width,
        "all copper traces meet the minimum width",
        Some(value),
        Some(profile.min_trace_width),
      )
    None =>
      fabrication_check(
        checks,
        "minimum-trace-width",
        false,
        "board contains no trace geometry",
        None,
        Some(profile.min_trace_width),
      )
  }
  match fabrication_min_drill(board) {
    Some(value) =>
      fabrication_check(
        checks,
        "minimum-drill",
        value >= profile.min_drill,
        "all drill hits meet the minimum finished diameter",
        Some(value),
        Some(profile.min_drill),
      )
    None =>
      fabrication_check(
        checks,
        "minimum-drill",
        true,
        "board has no drill layer; drill limit is not applicable",
        None,
        Some(profile.min_drill),
      )
  }
}

///|
pub fn assess_fabrication(
  board : Board,
  profile? : FabricationProfile = standard_fabrication_profile(),
) -> FabricationAssessment {
  let checks : Array[FabricationCheck] = []
  fabrication_layer_check(board, profile, checks)
  let (_, _, area) = fabrication_size_check(board, profile, checks)
  fabrication_geometry_checks(board, profile, checks)
  let dfm_config = default_dfm_config().with_minimums(
    min_width=profile.min_trace_width,
    min_drill=profile.min_drill,
    min_clearance=profile.min_clearance,
  )
  let dfm = run_dfm(board, config=dfm_config)
  fabrication_check(
    checks,
    "dfm-errors",
    dfm.error_count() == 0,
    "expanded DFM rules report no manufacturing errors",
    Some(dfm.error_count().to_double()),
    Some(0.0),
  )
  let passed_count = checks.filter(check => check.passed).length()
  let score = if checks.length() == 0 {
    0.0
  } else {
    100.0 * passed_count.to_double() / checks.length().to_double()
  }
  let drill_count = fabrication_drill_count(board)
  let copper_area = fabrication_copper_area(board)
  let estimated_minutes = 8.0 +
    area / 900.0 +
    drill_count.to_double() * 0.08 +
    board.layers.length().to_double() * 1.5
  let estimated_cost = 12.0 +
    area / 500.0 +
    drill_count.to_double() * 0.04 +
    board.layers.length().to_double() * 2.0
  {
    profile,
    passed: checks.all(check => check.passed),
    score,
    checks,
    board_area: area,
    copper_area,
    drill_count,
    estimated_minutes,
    estimated_cost,
  }
}

///|
pub fn FabricationAssessment::to_json(self : FabricationAssessment) -> String {
  let checks = self.checks
    .map(check => {
      "{\"code\":\{json_string(check.code)},\"passed\":\{check.passed},\"message\":\{json_string(check.message)},\"measured\":\{optional_json_number(check.measured)},\"limit\":\{optional_json_number(check.limit)}}"
    })
    .join(",")
  "{\"profile\":\{json_string(self.profile.name)},\"class\":\{json_string(self.profile.class_name())},\"material\":\{json_string(self.profile.material_name())},\"passed\":\{self.passed},\"score\":\{self.score},\"board_area\":\{self.board_area},\"copper_area\":\{self.copper_area},\"drill_count\":\{self.drill_count},\"estimated_minutes\":\{self.estimated_minutes},\"estimated_cost\":\{self.estimated_cost},\"checks\":[\{checks}]}"
}

///|
pub fn FabricationAssessment::to_text(self : FabricationAssessment) -> String {
  let mut result = self.summary() + "\n" + self.profile.summary() + "\n"
  for check in self.checks {
    result += check.format() + "\n"
  }
  result
}

///|
pub fn compare_fabrication_profiles(
  board : Board,
  profiles : Array[FabricationProfile],
) -> Array[FabricationAssessment] {
  profiles.map(profile => assess_fabrication(board, profile~))
}

///|
pub fn best_fabrication_profile(board : Board) -> FabricationProfile {
  let profiles = [
    prototype_fabrication_profile(),
    standard_fabrication_profile(),
    fine_pitch_fabrication_profile(),
  ]
  let assessments = compare_fabrication_profiles(board, profiles)
  let mut best = profiles[0]
  let mut best_score = -1.0
  for index, assessment in assessments {
    if assessment.passed && assessment.score > best_score {
      best = profiles[index]
      best_score = assessment.score
    } else if best_score < 0.0 && assessment.score > best_score {
      best = profiles[index]
      best_score = assessment.score
    }
  }
  best
}

///|
pub fn fabrication_profile_catalog() -> Array[FabricationProfile] {
  [
    prototype_fabrication_profile(),
    standard_fabrication_profile(),
    fine_pitch_fabrication_profile(),
    aluminum_fabrication_profile(),
    flexible_fabrication_profile(),
  ]
}

///|
pub fn fabrication_catalog_markdown() -> String {
  let mut result = "| Profile | Class | Material | Min trace | Min drill | Envelope | Finish |\n|---|---|---|---:|---:|---:|---|\n"
  for profile in fabrication_profile_catalog() {
    result += "| \{profile.name} | \{profile.class_name()} | \{profile.material_name()} | \{profile.min_trace_width} mm | \{profile.min_drill} mm | \{profile.max_board_width} × \{profile.max_board_height} mm | \{profile.preferred_finish} |\n"
  }
  result
}
