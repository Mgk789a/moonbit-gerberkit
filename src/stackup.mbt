///|
/// Layer-stack modelling for fabrication planning and controlled-impedance
/// estimation.  The model deliberately keeps units in millimetres so it can
/// be composed with parsed Gerber and Excellon geometry without hidden unit
/// conversions.
pub enum StackupLayerKind {
  SignalCopper
  PlaneCopper
  CoreDielectric
  PrepregDielectric
  SolderMask
  SurfaceFinish
  MechanicalLayer
} derive(Debug, Eq)

///|
pub enum StackupLayerRole {
  OuterCopper
  InnerCopper
  Dielectric
  Mask
  Finish
  Mechanical
} derive(Debug, Eq)

///|
pub struct StackupLayer {
  index : Int
  name : String
  kind : StackupLayerKind
  thickness : Double
  dielectric_constant : Double
  loss_tangent : Double
  copper_weight_oz : Double
  material : String
} derive(Debug)

///|
pub struct Stackup {
  name : String
  unit : LengthUnit
  layers : Array[StackupLayer]
  finished_thickness : Double?
} derive(Debug)

///|
pub enum StackupIssueSeverity {
  StackupInfo
  StackupWarning
  StackupError
} derive(Debug, Eq)

///|
pub enum StackupRule {
  EmptyStackup
  InvalidThickness
  InvalidDielectric
  InvalidCopperWeight
  LayerOrder
  MissingOuterCopper
  MissingDielectric
  ExcessiveThickness
  ThicknessMismatch
  UnsupportedMaterial
  MissingFinishedThickness
} derive(Debug, Eq)

///|
pub struct StackupIssue {
  rule : StackupRule
  severity : StackupIssueSeverity
  layer_index : Int?
  message : String
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct StackupValidation {
  stackup_name : String
  issues : Array[StackupIssue]
  layer_count : Int
  total_thickness : Double
  copper_layers : Int
  dielectric_layers : Int
} derive(Debug)

///|
pub struct StackupTolerance {
  thickness_plus : Double
  thickness_minus : Double
  dielectric_plus : Double
  dielectric_minus : Double
  copper_plus : Double
  copper_minus : Double
} derive(Debug)

///|
pub struct ImpedanceEstimate {
  trace_width : Double
  trace_thickness : Double
  reference_distance : Double
  dielectric_constant : Double
  impedance : Double
  lower_bound : Double
  upper_bound : Double
  model : String
  valid : Bool
} derive(Debug)

///|
pub struct DifferentialImpedanceEstimate {
  trace_width : Double
  spacing : Double
  reference_distance : Double
  dielectric_constant : Double
  single_ended : Double
  differential : Double
  valid : Bool
} derive(Debug)

///|
pub fn stackup_layer_kind_name(kind : StackupLayerKind) -> String {
  match kind {
    SignalCopper => "signal-copper"
    PlaneCopper => "plane-copper"
    CoreDielectric => "core-dielectric"
    PrepregDielectric => "prepreg-dielectric"
    SolderMask => "solder-mask"
    SurfaceFinish => "surface-finish"
    MechanicalLayer => "mechanical"
  }
}

///|
pub fn stackup_layer_role_name(role : StackupLayerRole) -> String {
  match role {
    OuterCopper => "outer-copper"
    InnerCopper => "inner-copper"
    Dielectric => "dielectric"
    Mask => "mask"
    Finish => "finish"
    Mechanical => "mechanical"
  }
}

///|
pub fn stackup_severity_name(severity : StackupIssueSeverity) -> String {
  match severity {
    StackupInfo => "info"
    StackupWarning => "warning"
    StackupError => "error"
  }
}

///|
pub fn stackup_rule_name(rule : StackupRule) -> String {
  match rule {
    EmptyStackup => "empty-stackup"
    InvalidThickness => "invalid-thickness"
    InvalidDielectric => "invalid-dielectric"
    InvalidCopperWeight => "invalid-copper-weight"
    LayerOrder => "layer-order"
    MissingOuterCopper => "missing-outer-copper"
    MissingDielectric => "missing-dielectric"
    ExcessiveThickness => "excessive-thickness"
    ThicknessMismatch => "thickness-mismatch"
    UnsupportedMaterial => "unsupported-material"
    MissingFinishedThickness => "missing-finished-thickness"
  }
}

///|
pub fn stackup_layer(
  index~ : Int,
  name~ : String,
  kind~ : StackupLayerKind,
  thickness~ : Double,
  dielectric_constant~ : Double,
  loss_tangent~ : Double,
  copper_weight_oz~ : Double,
  material~ : String,
) -> StackupLayer {
  {
    index: if index < 0 {
      0
    } else {
      index
    },
    name,
    kind,
    thickness: if thickness < 0.0 {
      0.0
    } else {
      thickness
    },
    dielectric_constant: if dielectric_constant < 0.0 {
      0.0
    } else {
      dielectric_constant
    },
    loss_tangent: if loss_tangent < 0.0 {
      0.0
    } else {
      loss_tangent
    },
    copper_weight_oz: if copper_weight_oz < 0.0 {
      0.0
    } else {
      copper_weight_oz
    },
    material,
  }
}

///|
pub fn signal_copper_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  copper_weight_oz? : Double = 1.0,
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=SignalCopper,
    thickness~,
    dielectric_constant=1.0,
    loss_tangent=0.0,
    copper_weight_oz~,
    material="copper",
  )
}

///|
pub fn plane_copper_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  copper_weight_oz? : Double = 1.0,
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=PlaneCopper,
    thickness~,
    dielectric_constant=1.0,
    loss_tangent=0.0,
    copper_weight_oz~,
    material="copper",
  )
}

///|
pub fn core_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  dielectric_constant~ : Double,
  loss_tangent? : Double = 0.02,
  material? : String = "FR-4 core",
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=CoreDielectric,
    thickness~,
    dielectric_constant~,
    loss_tangent~,
    copper_weight_oz=0.0,
    material~,
  )
}

///|
pub fn prepreg_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  dielectric_constant~ : Double,
  loss_tangent? : Double = 0.02,
  material? : String = "FR-4 prepreg",
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=PrepregDielectric,
    thickness~,
    dielectric_constant~,
    loss_tangent~,
    copper_weight_oz=0.0,
    material~,
  )
}

///|
pub fn solder_mask_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  dielectric_constant? : Double = 3.3,
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=SolderMask,
    thickness~,
    dielectric_constant~,
    loss_tangent=0.04,
    copper_weight_oz=0.0,
    material="solder mask",
  )
}

///|
pub fn surface_finish_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  material? : String = "ENIG",
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=SurfaceFinish,
    thickness~,
    dielectric_constant=1.0,
    loss_tangent=0.0,
    copper_weight_oz=0.0,
    material~,
  )
}

///|
pub fn mechanical_stackup_layer(
  index~ : Int,
  name~ : String,
  thickness~ : Double,
  material? : String = "mechanical",
) -> StackupLayer {
  stackup_layer(
    index~,
    name~,
    kind=MechanicalLayer,
    thickness~,
    dielectric_constant=1.0,
    loss_tangent=0.0,
    copper_weight_oz=0.0,
    material~,
  )
}

///|
pub fn stackup(
  name~ : String,
  layers~ : Array[StackupLayer],
  unit? : LengthUnit = Millimeter,
) -> Stackup {
  { name, unit, layers: layers.copy(), finished_thickness: None }
}

///|
pub fn StackupLayer::role(self : StackupLayer) -> StackupLayerRole {
  match self.kind {
    SignalCopper | PlaneCopper =>
      if self.index == 0 {
        OuterCopper
      } else {
        InnerCopper
      }
    CoreDielectric | PrepregDielectric => Dielectric
    SolderMask => Mask
    SurfaceFinish => Finish
    MechanicalLayer => Mechanical
  }
}

///|
pub fn StackupLayer::is_copper(self : StackupLayer) -> Bool {
  self.kind is SignalCopper || self.kind is PlaneCopper
}

///|
pub fn StackupLayer::is_dielectric(self : StackupLayer) -> Bool {
  self.kind is CoreDielectric || self.kind is PrepregDielectric
}

///|
pub fn StackupLayer::is_reference_plane(self : StackupLayer) -> Bool {
  self.kind is PlaneCopper
}

///|
pub fn StackupLayer::is_signal(self : StackupLayer) -> Bool {
  self.kind is SignalCopper
}

///|
pub fn StackupLayer::effective_dielectric(self : StackupLayer) -> Double {
  if self.dielectric_constant <= 0.0 {
    1.0
  } else {
    self.dielectric_constant
  }
}

///|
pub fn StackupLayer::copper_thickness_um(self : StackupLayer) -> Double {
  self.thickness * 1000.0
}

///|
pub fn StackupLayer::copper_area_weight(self : StackupLayer) -> Double {
  if self.is_copper() {
    self.copper_weight_oz * 0.0348
  } else {
    0.0
  }
}

///|
pub fn StackupLayer::summary(self : StackupLayer) -> String {
  "\{self.index} \{self.name} \{stackup_layer_kind_name(self.kind)} t=\{self.thickness}mm er=\{self.effective_dielectric()} material=\{self.material}"
}

///|
pub fn Stackup::layer_count(self : Stackup) -> Int {
  self.layers.length()
}

///|
pub fn Stackup::layers(self : Stackup) -> Array[StackupLayer] {
  self.layers.copy()
}

///|
pub fn Stackup::layer(self : Stackup, index : Int) -> StackupLayer? {
  self.layers.get(index)
}

///|
pub fn Stackup::layer_named(self : Stackup, name : String) -> StackupLayer? {
  for layer in self.layers {
    if layer.name == name {
      return Some(layer)
    }
  }
  None
}

///|
pub fn Stackup::total_thickness(self : Stackup) -> Double {
  self.layers.fold(init=0.0, (total, layer) => total + layer.thickness)
}

///|
pub fn Stackup::copper_layer_count(self : Stackup) -> Int {
  self.layers.filter(layer => layer.is_copper()).length()
}

///|
pub fn Stackup::signal_layer_count(self : Stackup) -> Int {
  self.layers.filter(layer => layer.is_signal()).length()
}

///|
pub fn Stackup::plane_layer_count(self : Stackup) -> Int {
  self.layers.filter(layer => layer.is_reference_plane()).length()
}

///|
pub fn Stackup::dielectric_layer_count(self : Stackup) -> Int {
  self.layers.filter(layer => layer.is_dielectric()).length()
}

///|
pub fn Stackup::outer_copper(self : Stackup) -> StackupLayer? {
  for layer in self.layers {
    if layer.is_copper() && layer.index == 0 {
      return Some(layer)
    }
  }
  None
}

///|
pub fn Stackup::first_copper(self : Stackup) -> StackupLayer? {
  for layer in self.layers {
    if layer.is_copper() {
      return Some(layer)
    }
  }
  None
}

///|
pub fn Stackup::last_copper(self : Stackup) -> StackupLayer? {
  let mut result : StackupLayer? = None
  for layer in self.layers {
    if layer.is_copper() {
      result = Some(layer)
    }
  }
  result
}

///|
pub fn Stackup::dielectric_between(
  self : Stackup,
  lower_index : Int,
  upper_index : Int,
) -> Double {
  let low = if lower_index < upper_index { lower_index } else { upper_index }
  let high = if lower_index < upper_index { upper_index } else { lower_index }
  let mut total = 0.0
  if low < 0 || high >= self.layers.length() {
    return 0.0
  }
  for index in (low + 1)..<high {
    let candidate = self.layers[index]
    if candidate.is_dielectric() {
      total += candidate.thickness
    }
  }
  total
}

///|
pub fn Stackup::average_dielectric_between(
  self : Stackup,
  lower_index : Int,
  upper_index : Int,
) -> Double {
  let low = if lower_index < upper_index { lower_index } else { upper_index }
  let high = if lower_index < upper_index { upper_index } else { lower_index }
  let mut weighted = 0.0
  let mut thickness = 0.0
  if low < 0 || high >= self.layers.length() {
    return 1.0
  }
  for index in (low + 1)..<high {
    let candidate = self.layers[index]
    if candidate.is_dielectric() {
      weighted += candidate.thickness * candidate.effective_dielectric()
      thickness += candidate.thickness
    }
  }
  if thickness <= 0.0 {
    1.0
  } else {
    weighted / thickness
  }
}

///|
pub fn Stackup::adjacent_reference(
  self : Stackup,
  signal_index : Int,
) -> StackupLayer? {
  if signal_index < 0 || signal_index >= self.layers.length() {
    return None
  }
  let mut nearest : StackupLayer? = None
  let mut nearest_distance = 1000000000.0
  for index in 0..<self.layers.length() {
    let candidate = self.layers[index]
    if candidate.is_reference_plane() {
      let distance = (index - signal_index).abs().to_double()
      if distance < nearest_distance {
        nearest = Some(candidate)
        nearest_distance = distance
      }
    }
  }
  nearest
}

///|
pub fn Stackup::has_valid_indices(self : Stackup) -> Bool {
  for index, layer in self.layers {
    if layer.index != index {
      return false
    }
  }
  true
}

///|
pub fn Stackup::finished_or_nominal_thickness(self : Stackup) -> Double {
  match self.finished_thickness {
    Some(value) => value
    None => self.total_thickness()
  }
}

///|
pub fn default_stackup_tolerance() -> StackupTolerance {
  {
    thickness_plus: 0.1,
    thickness_minus: 0.1,
    dielectric_plus: 0.15,
    dielectric_minus: 0.15,
    copper_plus: 0.005,
    copper_minus: 0.005,
  }
}

///|
pub fn tight_stackup_tolerance() -> StackupTolerance {
  {
    thickness_plus: 0.05,
    thickness_minus: 0.05,
    dielectric_plus: 0.08,
    dielectric_minus: 0.08,
    copper_plus: 0.003,
    copper_minus: 0.003,
  }
}

///|
pub fn stackup_tolerance(
  thickness_plus~ : Double,
  thickness_minus~ : Double,
  dielectric_plus~ : Double,
  dielectric_minus~ : Double,
  copper_plus~ : Double,
  copper_minus~ : Double,
) -> StackupTolerance {
  {
    thickness_plus: if thickness_plus < 0.0 {
      0.0
    } else {
      thickness_plus
    },
    thickness_minus: if thickness_minus < 0.0 {
      0.0
    } else {
      thickness_minus
    },
    dielectric_plus: if dielectric_plus < 0.0 {
      0.0
    } else {
      dielectric_plus
    },
    dielectric_minus: if dielectric_minus < 0.0 {
      0.0
    } else {
      dielectric_minus
    },
    copper_plus: if copper_plus < 0.0 {
      0.0
    } else {
      copper_plus
    },
    copper_minus: if copper_minus < 0.0 {
      0.0
    } else {
      copper_minus
    },
  }
}

///|
pub fn StackupTolerance::thickness_range(
  self : StackupTolerance,
  nominal : Double,
) -> (Double, Double) {
  (nominal - self.thickness_minus, nominal + self.thickness_plus)
}

///|
pub fn StackupTolerance::dielectric_range(
  self : StackupTolerance,
  nominal : Double,
) -> (Double, Double) {
  (nominal - self.dielectric_minus, nominal + self.dielectric_plus)
}

///|
pub fn StackupTolerance::copper_range(
  self : StackupTolerance,
  nominal : Double,
) -> (Double, Double) {
  (nominal - self.copper_minus, nominal + self.copper_plus)
}

///|
pub fn StackupTolerance::contains_thickness(
  self : StackupTolerance,
  nominal : Double,
  measured : Double,
) -> Bool {
  let range = self.thickness_range(nominal)
  measured >= range.0 && measured <= range.1
}

///|
pub fn StackupTolerance::contains_dielectric(
  self : StackupTolerance,
  nominal : Double,
  measured : Double,
) -> Bool {
  let range = self.dielectric_range(nominal)
  measured >= range.0 && measured <= range.1
}

///|
pub fn StackupTolerance::contains_copper(
  self : StackupTolerance,
  nominal : Double,
  measured : Double,
) -> Bool {
  let range = self.copper_range(nominal)
  measured >= range.0 && measured <= range.1
}

///|
pub fn standard_two_layer_stackup() -> Stackup {
  stackup(name="2-layer FR-4", layers=[
    signal_copper_layer(index=0, name="Top Copper", thickness=0.035),
    core_layer(
      index=1,
      name="FR-4 Core",
      thickness=1.5,
      dielectric_constant=4.2,
    ),
    signal_copper_layer(index=2, name="Bottom Copper", thickness=0.035),
  ]).with_finished_thickness(1.57)
}

///|
pub fn standard_four_layer_stackup() -> Stackup {
  stackup(name="4-layer FR-4", layers=[
    signal_copper_layer(index=0, name="L1 Signal", thickness=0.035),
    prepreg_layer(
      index=1,
      name="Prepreg 1",
      thickness=0.18,
      dielectric_constant=4.1,
    ),
    plane_copper_layer(index=2, name="L2 Ground", thickness=0.035),
    core_layer(index=3, name="Core", thickness=0.8, dielectric_constant=4.2),
    plane_copper_layer(index=4, name="L3 Power", thickness=0.035),
    prepreg_layer(
      index=5,
      name="Prepreg 2",
      thickness=0.18,
      dielectric_constant=4.1,
    ),
    signal_copper_layer(index=6, name="L4 Signal", thickness=0.035),
  ]).with_finished_thickness(1.3)
}

///|
pub fn standard_six_layer_stackup() -> Stackup {
  stackup(name="6-layer FR-4", layers=[
    signal_copper_layer(index=0, name="L1 Signal", thickness=0.035),
    prepreg_layer(
      index=1,
      name="Prepreg 1",
      thickness=0.1,
      dielectric_constant=4.0,
    ),
    plane_copper_layer(index=2, name="L2 Ground", thickness=0.035),
    core_layer(index=3, name="Core 1", thickness=0.2, dielectric_constant=4.2),
    signal_copper_layer(index=4, name="L3 Signal", thickness=0.035),
    prepreg_layer(
      index=5,
      name="Prepreg 2",
      thickness=0.7,
      dielectric_constant=4.2,
    ),
    signal_copper_layer(index=6, name="L4 Signal", thickness=0.035),
    core_layer(index=7, name="Core 2", thickness=0.2, dielectric_constant=4.2),
    plane_copper_layer(index=8, name="L5 Ground", thickness=0.035),
    prepreg_layer(
      index=9,
      name="Prepreg 3",
      thickness=0.1,
      dielectric_constant=4.0,
    ),
    signal_copper_layer(index=10, name="L6 Signal", thickness=0.035),
  ]).with_finished_thickness(1.61)
}

///|
fn stackup_issue(
  rule : StackupRule,
  severity : StackupIssueSeverity,
  layer_index : Int?,
  message : String,
  measured : Double?,
  limit : Double?,
) -> StackupIssue {
  { rule, severity, layer_index, message, measured, limit }
}

///|
pub fn validate_stackup(
  value : Stackup,
  max_thickness? : Double = 8.0,
  expected_finished_tolerance? : Double = 0.2,
) -> StackupValidation {
  let issues : Array[StackupIssue] = []
  let total = value.total_thickness()
  if value.layers.length() == 0 {
    issues.push(
      stackup_issue(
        EmptyStackup,
        StackupError,
        None,
        "stackup has no layers",
        None,
        None,
      ),
    )
  }
  if !value.has_valid_indices() {
    issues.push(
      stackup_issue(
        LayerOrder,
        StackupError,
        None,
        "layer indices are not contiguous",
        None,
        None,
      ),
    )
  }
  let mut copper = 0
  let mut dielectric = 0
  for layer in value.layers {
    if layer.is_copper() {
      copper += 1
    }
    if layer.is_dielectric() {
      dielectric += 1
    }
    if layer.thickness <= 0.0 {
      issues.push(
        stackup_issue(
          InvalidThickness,
          StackupError,
          Some(layer.index),
          "layer thickness must be positive",
          Some(layer.thickness),
          Some(0.0),
        ),
      )
    }
    if layer.is_dielectric() && layer.dielectric_constant < 1.0 {
      issues.push(
        stackup_issue(
          InvalidDielectric,
          StackupError,
          Some(layer.index),
          "dielectric constant must be at least one",
          Some(layer.dielectric_constant),
          Some(1.0),
        ),
      )
    }
    if layer.is_copper() && layer.copper_weight_oz <= 0.0 {
      issues.push(
        stackup_issue(
          InvalidCopperWeight,
          StackupWarning,
          Some(layer.index),
          "copper layer has no copper weight",
          Some(layer.copper_weight_oz),
          Some(0.0),
        ),
      )
    }
    if layer.material == "" {
      issues.push(
        stackup_issue(
          UnsupportedMaterial,
          StackupWarning,
          Some(layer.index),
          "layer material is not documented",
          None,
          None,
        ),
      )
    }
  }
  if copper == 0 {
    issues.push(
      stackup_issue(
        MissingOuterCopper,
        StackupError,
        None,
        "stackup has no copper layer",
        None,
        None,
      ),
    )
  } else if value.outer_copper() is None {
    issues.push(
      stackup_issue(
        MissingOuterCopper,
        StackupWarning,
        None,
        "first stackup layer is not copper",
        None,
        None,
      ),
    )
  }
  if dielectric == 0 && copper > 1 {
    issues.push(
      stackup_issue(
        MissingDielectric,
        StackupError,
        None,
        "multiple copper layers have no dielectric between them",
        None,
        None,
      ),
    )
  }
  if total > max_thickness {
    issues.push(
      stackup_issue(
        ExcessiveThickness,
        StackupWarning,
        None,
        "nominal stackup exceeds maximum thickness",
        Some(total),
        Some(max_thickness),
      ),
    )
  }
  match value.finished_thickness {
    Some(finished) =>
      if (finished - total).abs() > expected_finished_tolerance {
        issues.push(
          stackup_issue(
            ThicknessMismatch,
            StackupWarning,
            None,
            "finished thickness differs from layer sum",
            Some(finished - total),
            Some(expected_finished_tolerance),
          ),
        )
      }
    None =>
      issues.push(
        stackup_issue(
          MissingFinishedThickness,
          StackupInfo,
          None,
          "finished thickness was not specified",
          None,
          None,
        ),
      )
  }
  {
    stackup_name: value.name,
    issues,
    layer_count: value.layers.length(),
    total_thickness: total,
    copper_layers: copper,
    dielectric_layers: dielectric,
  }
}

///|
pub fn StackupValidation::error_count(self : StackupValidation) -> Int {
  self.issues.filter(issue => issue.severity is StackupError).length()
}

///|
pub fn StackupValidation::warning_count(self : StackupValidation) -> Int {
  self.issues.filter(issue => issue.severity is StackupWarning).length()
}

///|
pub fn StackupValidation::is_valid(self : StackupValidation) -> Bool {
  self.error_count() == 0
}

///|
pub fn StackupValidation::issues(
  self : StackupValidation,
) -> Array[StackupIssue] {
  self.issues.copy()
}

///|
pub fn StackupValidation::summary(self : StackupValidation) -> String {
  "stackup=\{self.stackup_name}, layers=\{self.layer_count}, copper=\{self.copper_layers}, dielectric=\{self.dielectric_layers}, thickness=\{self.total_thickness}, errors=\{self.error_count()}, warnings=\{self.warning_count()}"
}

///|
pub fn microstrip_impedance(
  width : Double,
  copper_thickness : Double,
  height : Double,
  dielectric_constant : Double,
) -> ImpedanceEstimate {
  let safe_width = if width <= 0.0 { 0.000001 } else { width }
  let safe_height = if height <= 0.0 { 0.000001 } else { height }
  let safe_thickness = if copper_thickness < 0.0 {
    0.0
  } else {
    copper_thickness
  }
  let er = if dielectric_constant < 1.0 { 1.0 } else { dielectric_constant }
  let effective_width = safe_width + safe_thickness / 3.141592653589793
  let ratio = effective_width / safe_height
  let effective_er = (er + 1.0) / 2.0 +
    (er - 1.0) / 2.0 / (1.0 + 12.0 / ratio).sqrt()
  let impedance = if ratio <= 1.0 {
    60.0 /
    effective_er.sqrt() *
    @math.ln(
      8.0 * safe_height / effective_width +
      effective_width / (4.0 * safe_height),
    )
  } else {
    120.0 *
    3.141592653589793 /
    (effective_er.sqrt() * (ratio + 1.393 + 0.667 * @math.ln(ratio + 1.444)))
  }
  {
    trace_width: safe_width,
    trace_thickness: safe_thickness,
    reference_distance: safe_height,
    dielectric_constant: er,
    impedance,
    lower_bound: impedance,
    upper_bound: impedance,
    model: "hammerstad-microstrip",
    valid: width > 0.0 && height > 0.0 && dielectric_constant >= 1.0,
  }
}

///|
pub fn stripline_impedance(
  width : Double,
  copper_thickness : Double,
  dielectric_height : Double,
  dielectric_constant : Double,
) -> ImpedanceEstimate {
  let safe_width = if width <= 0.0 { 0.000001 } else { width }
  let safe_height = if dielectric_height <= 0.0 {
    0.000001
  } else {
    dielectric_height
  }
  let er = if dielectric_constant < 1.0 { 1.0 } else { dielectric_constant }
  let effective_width = safe_width + copper_thickness / 3.141592653589793
  let impedance = 60.0 /
    er.sqrt() *
    @math.ln(1.9 * safe_height / (0.8 * effective_width + copper_thickness))
  {
    trace_width: safe_width,
    trace_thickness: if copper_thickness < 0.0 {
      0.0
    } else {
      copper_thickness
    },
    reference_distance: safe_height,
    dielectric_constant: er,
    impedance,
    lower_bound: impedance,
    upper_bound: impedance,
    model: "homogeneous-stripline",
    valid: width > 0.0 && dielectric_height > 0.0 && dielectric_constant >= 1.0,
  }
}

///|
pub fn impedance_with_tolerance(
  nominal : ImpedanceEstimate,
  width_tolerance : Double,
  height_tolerance : Double,
  dielectric_tolerance : Double,
) -> ImpedanceEstimate {
  let width_error = if width_tolerance < 0.0 {
    -width_tolerance
  } else {
    width_tolerance
  }
  let height_error = if height_tolerance < 0.0 {
    -height_tolerance
  } else {
    height_tolerance
  }
  let dielectric_error = if dielectric_tolerance < 0.0 {
    -dielectric_tolerance
  } else {
    dielectric_tolerance
  }
  let low_width = if nominal.trace_width - width_error <= 0.0 {
    0.000001
  } else {
    nominal.trace_width - width_error
  }
  let high_width = nominal.trace_width + width_error
  let low_height = if nominal.reference_distance - height_error <= 0.0 {
    0.000001
  } else {
    nominal.reference_distance - height_error
  }
  let high_height = nominal.reference_distance + height_error
  let low_er = if nominal.dielectric_constant - dielectric_error < 1.0 {
    1.0
  } else {
    nominal.dielectric_constant - dielectric_error
  }
  let high_er = nominal.dielectric_constant + dielectric_error
  let low = if nominal.model == "homogeneous-stripline" {
    stripline_impedance(
      low_width,
      nominal.trace_thickness,
      high_height,
      high_er,
    ).impedance
  } else {
    microstrip_impedance(
      high_width,
      nominal.trace_thickness,
      low_height,
      high_er,
    ).impedance
  }
  let high = if nominal.model == "homogeneous-stripline" {
    stripline_impedance(high_width, nominal.trace_thickness, low_height, low_er).impedance
  } else {
    microstrip_impedance(
      low_width,
      nominal.trace_thickness,
      high_height,
      low_er,
    ).impedance
  }
  {
    trace_width: nominal.trace_width,
    trace_thickness: nominal.trace_thickness,
    reference_distance: nominal.reference_distance,
    dielectric_constant: nominal.dielectric_constant,
    impedance: nominal.impedance,
    lower_bound: if low < high {
      low
    } else {
      high
    },
    upper_bound: if low > high {
      low
    } else {
      high
    },
    model: nominal.model,
    valid: nominal.valid,
  }
}

///|
pub fn impedance_in_tolerance(
  estimate : ImpedanceEstimate,
  target : Double,
  tolerance : Double,
) -> Bool {
  let margin = if tolerance < 0.0 { -tolerance } else { tolerance }
  estimate.impedance >= target - margin && estimate.impedance <= target + margin
}

///|
pub fn differential_impedance(
  width : Double,
  spacing : Double,
  copper_thickness : Double,
  height : Double,
  dielectric_constant : Double,
) -> DifferentialImpedanceEstimate {
  let single = microstrip_impedance(
    width, copper_thickness, height, dielectric_constant,
  )
  let safe_spacing = if spacing <= 0.0 { 0.000001 } else { spacing }
  let coupling = 0.48 * @math.exp(height / (height + safe_spacing))
  let differential = single.impedance * 2.0 * (1.0 - coupling)
  {
    trace_width: width,
    spacing: safe_spacing,
    reference_distance: height,
    dielectric_constant: if dielectric_constant < 1.0 {
      1.0
    } else {
      dielectric_constant
    },
    single_ended: single.impedance,
    differential,
    valid: single.valid && spacing > 0.0,
  }
}

///|
pub fn Stackup::estimate_microstrip(
  self : Stackup,
  signal_index : Int,
  width : Double,
) -> ImpedanceEstimate? {
  let signal = self.layer(signal_index)
  match signal {
    Some(layer) if layer.is_signal() =>
      match self.adjacent_reference(signal_index) {
        Some(reference) => {
          let distance = self.dielectric_between(signal_index, reference.index)
          let er = self.average_dielectric_between(
            signal_index,
            reference.index,
          )
          Some(microstrip_impedance(width, layer.thickness, distance, er))
        }
        None => None
      }
    _ => None
  }
}

///|
pub fn stackup_to_csv(value : Stackup) -> String {
  let mut output = "index,name,kind,role,thickness_mm,dielectric_constant,loss_tangent,copper_weight_oz,material\n"
  for layer in value.layers {
    output += "\{layer.index},\{json_escape(layer.name)},\{stackup_layer_kind_name(layer.kind)},\{stackup_layer_role_name(layer.role())},\{layer.thickness},\{layer.effective_dielectric()},\{layer.loss_tangent},\{layer.copper_weight_oz},\{json_escape(layer.material)}\n"
  }
  output
}

///|
pub fn stackup_to_json(value : Stackup) -> String {
  let finished = match value.finished_thickness {
    Some(thickness) => thickness.to_string()
    None => "null"
  }
  let layers = value.layers
    .map(layer => {
      "{\"index\":\{layer.index},\"name\":\{json_string(layer.name)},\"kind\":\{json_string(stackup_layer_kind_name(layer.kind))},\"role\":\{json_string(stackup_layer_role_name(layer.role()))},\"thickness_mm\":\{layer.thickness},\"dielectric_constant\":\{layer.effective_dielectric()},\"loss_tangent\":\{layer.loss_tangent},\"copper_weight_oz\":\{layer.copper_weight_oz},\"material\":\{json_string(layer.material)}}"
    })
    .join(",")
  "{\"name\":\{json_string(value.name)},\"unit\":\{json_string(unit_to_string(value.unit))},\"finished_thickness_mm\":\{finished},\"nominal_thickness_mm\":\{value.total_thickness()},\"layers\":[\{layers}]}"
}

///|
pub fn stackup_to_markdown(
  value : Stackup,
  validation? : StackupValidation,
) -> String {
  let mut output = "# " + value.name + "\n\n"
  output += "Nominal thickness: " +
    value.total_thickness().to_string() +
    " mm\n\n"
  output += "| Index | Name | Kind | Thickness (mm) | Er | Copper (oz) | Material |\n| ---: | --- | --- | ---: | ---: | ---: | --- |\n"
  for layer in value.layers {
    output += "| " +
      layer.index.to_string() +
      " | " +
      layer.name +
      " | " +
      stackup_layer_kind_name(layer.kind) +
      " | " +
      layer.thickness.to_string() +
      " | " +
      layer.effective_dielectric().to_string() +
      " | " +
      layer.copper_weight_oz.to_string() +
      " | " +
      layer.material +
      " |\n"
  }
  match validation {
    Some(report) => {
      output += "\n## Validation\n\n"
      output += report.summary() + "\n"
      for issue in report.issues {
        output += "- " +
          stackup_severity_name(issue.severity) +
          ": " +
          stackup_rule_name(issue.rule) +
          " — " +
          issue.message +
          "\n"
      }
    }
    None => ()
  }
  output
}

///|
pub fn stackup_issue_to_json(issue : StackupIssue) -> String {
  let index = match issue.layer_index {
    Some(value) => value.to_string()
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
  "{\"rule\":\{json_string(stackup_rule_name(issue.rule))},\"severity\":\{json_string(stackup_severity_name(issue.severity))},\"layer_index\":\{index},\"message\":\{json_string(issue.message)},\"measured\":\{measured},\"limit\":\{limit}}"
}

///|
pub fn stackup_validation_to_json(report : StackupValidation) -> String {
  "{\"stackup\":\{json_string(report.stackup_name)},\"layer_count\":\{report.layer_count},\"total_thickness\":\{report.total_thickness},\"copper_layers\":\{report.copper_layers},\"dielectric_layers\":\{report.dielectric_layers},\"valid\":\{report.is_valid()},\"issues\":[\{report.issues.map(stackup_issue_to_json).join(",")}]}"
}

///|
pub fn StackupLayer::electrical_description(self : StackupLayer) -> String {
  if self.is_copper() {
    "copper \{self.copper_weight_oz}oz / \{self.copper_thickness_um()}um"
  } else if self.is_dielectric() {
    "dielectric Er=\{self.effective_dielectric()} tanD=\{self.loss_tangent}"
  } else {
    stackup_layer_kind_name(self.kind) + " " + self.material
  }
}

///|
pub fn Stackup::electrical_layers(self : Stackup) -> Array[StackupLayer] {
  self.layers.filter(layer => layer.is_copper() || layer.is_dielectric())
}

///|
pub fn Stackup::copper_indices(self : Stackup) -> Array[Int] {
  self.layers.filter(layer => layer.is_copper()).map(layer => layer.index)
}

///|
pub fn Stackup::dielectric_indices(self : Stackup) -> Array[Int] {
  self.layers.filter(layer => layer.is_dielectric()).map(layer => layer.index)
}

///|
pub fn Stackup::material_names(self : Stackup) -> Array[String] {
  let result : Array[String] = []
  for layer in self.layers {
    if !result.contains(layer.material) {
      result.push(layer.material)
    }
  }
  result
}

///|
pub fn Stackup::maximum_copper_weight(self : Stackup) -> Double {
  self.layers.fold(init=0.0, (current, layer) => {
    if layer.copper_weight_oz > current {
      layer.copper_weight_oz
    } else {
      current
    }
  })
}

///|
pub fn Stackup::minimum_dielectric_thickness(self : Stackup) -> Double? {
  let mut result : Double? = None
  for layer in self.layers {
    if layer.is_dielectric() {
      match result {
        None => result = Some(layer.thickness)
        Some(old) if layer.thickness < old => result = Some(layer.thickness)
        _ => ()
      }
    }
  }
  result
}

///|
pub fn Stackup::maximum_dielectric_constant(self : Stackup) -> Double {
  self.layers.fold(init=1.0, (current, layer) => {
    if layer.is_dielectric() && layer.effective_dielectric() > current {
      layer.effective_dielectric()
    } else {
      current
    }
  })
}

///|
pub fn Stackup::is_symmetric(
  self : Stackup,
  tolerance? : Double = 0.001,
) -> Bool {
  let limit = if tolerance < 0.0 { -tolerance } else { tolerance }
  let count = self.layers.length()
  if count < 2 {
    return true
  }
  for index in 0..<(count / 2) {
    let left = self.layers[index]
    let right = self.layers[count - index - 1]
    if left.kind != right.kind ||
      (left.thickness - right.thickness).abs() > limit ||
      (left.effective_dielectric() - right.effective_dielectric()).abs() > limit {
      return false
    }
  }
  true
}

///|
pub fn Stackup::mirror(self : Stackup) -> Stackup {
  let reversed = self.layers
    .rev()
    .map(layer => {
      index: layer.index,
      name: layer.name,
      kind: layer.kind,
      thickness: layer.thickness,
      dielectric_constant: layer.dielectric_constant,
      loss_tangent: layer.loss_tangent,
      copper_weight_oz: layer.copper_weight_oz,
      material: layer.material,
    })
  stackup(name=self.name + " mirrored", layers=reversed, unit=self.unit).with_finished_thickness(
    self.finished_or_nominal_thickness(),
  )
}

///|
pub fn Stackup::with_finished_thickness(
  self : Stackup,
  value : Double,
) -> Stackup {
  {
    name: self.name,
    unit: self.unit,
    layers: self.layers.copy(),
    finished_thickness: Some(if value < 0.0 { 0.0 } else { value }),
  }
}

///|
pub fn Stackup::replace_layer(
  self : Stackup,
  index : Int,
  replacement : StackupLayer,
) -> Stackup {
  let layers = self.layers.map(layer => {
    if layer.index == index {
      replacement
    } else {
      layer
    }
  })
  {
    name: self.name,
    unit: self.unit,
    layers,
    finished_thickness: self.finished_thickness,
  }
}

///|
pub fn Stackup::append_layer(self : Stackup, value : StackupLayer) -> Stackup {
  let layers = self.layers.copy()
  layers.push(value)
  {
    name: self.name,
    unit: self.unit,
    layers,
    finished_thickness: self.finished_thickness,
  }
}

///|
pub fn Stackup::normalized(self : Stackup) -> Stackup {
  let layers : Array[StackupLayer] = []
  for index, layer in self.layers {
    layers.push({
      index,
      name: layer.name,
      kind: layer.kind,
      thickness: layer.thickness,
      dielectric_constant: layer.dielectric_constant,
      loss_tangent: layer.loss_tangent,
      copper_weight_oz: layer.copper_weight_oz,
      material: layer.material,
    })
  }
  {
    name: self.name,
    unit: self.unit,
    layers,
    finished_thickness: self.finished_thickness,
  }
}

///|
pub fn impedance_estimate_to_json(value : ImpedanceEstimate) -> String {
  "{\"model\":\{json_string(value.model)},\"trace_width_mm\":\{value.trace_width},\"trace_thickness_mm\":\{value.trace_thickness},\"reference_distance_mm\":\{value.reference_distance},\"dielectric_constant\":\{value.dielectric_constant},\"impedance_ohm\":\{value.impedance},\"lower_bound_ohm\":\{value.lower_bound},\"upper_bound_ohm\":\{value.upper_bound},\"valid\":\{value.valid}}"
}

///|
pub fn differential_estimate_to_json(
  value : DifferentialImpedanceEstimate,
) -> String {
  "{\"trace_width_mm\":\{value.trace_width},\"spacing_mm\":\{value.spacing},\"reference_distance_mm\":\{value.reference_distance},\"dielectric_constant\":\{value.dielectric_constant},\"single_ended_ohm\":\{value.single_ended},\"differential_ohm\":\{value.differential},\"valid\":\{value.valid}}"
}
