///|
/// Public constructors for the value types used by the parser and DFM APIs.
///
/// The library keeps representation fields private so that invariants remain
/// stable across releases. These small constructors make the public API
/// convenient for integrations, fixtures, and downstream tests.
pub fn layer(
  name~ : String,
  kind~ : LayerKind,
  unit~ : LengthUnit,
  shapes~ : Array[Shape],
) -> Layer {
  { name, kind, unit, shapes }
}

///|
pub fn shape_segment(
  x1~ : Double,
  y1~ : Double,
  x2~ : Double,
  y2~ : Double,
  width~ : Double,
) -> Shape {
  Segment(x1~, y1~, x2~, y2~, width~)
}

///|
pub fn shape_pad(x~ : Double, y~ : Double, diameter~ : Double) -> Shape {
  Pad(x~, y~, diameter~)
}

///|
pub fn shape_flash(x~ : Double, y~ : Double, aperture~ : Int) -> Shape {
  Flash(x~, y~, aperture~)
}

///|
pub fn shape_region(points~ : Array[(Double, Double)]) -> Shape {
  Region(points~)
}

///|
pub fn shape_drill_hit(x~ : Double, y~ : Double, diameter~ : Double) -> Shape {
  DrillHit(x~, y~, diameter~)
}

///|
pub fn millimeter_unit() -> LengthUnit {
  Millimeter
}

///|
pub fn inch_unit() -> LengthUnit {
  Inch
}

///|
pub fn absolute_notation() -> CoordinateNotation {
  AbsoluteNotation
}

///|
pub fn incremental_notation() -> CoordinateNotation {
  IncrementalNotation
}

///|
pub fn leading_zero_suppression() -> ZeroSuppression {
  LeadingZeros
}

///|
pub fn trailing_zero_suppression() -> ZeroSuppression {
  TrailingZeros
}

///|
pub fn explicit_zero_suppression() -> ZeroSuppression {
  ExplicitZeros
}

///|
pub fn copper_layer_kind() -> LayerKind {
  Copper
}

///|
pub fn solder_mask_layer_kind() -> LayerKind {
  SolderMask
}

///|
pub fn silkscreen_layer_kind() -> LayerKind {
  Silkscreen
}

///|
pub fn drill_layer_kind() -> LayerKind {
  Drill
}

///|
pub fn mechanical_layer_kind() -> LayerKind {
  Mechanical
}

///|
pub fn unknown_layer_kind() -> LayerKind {
  Unknown
}

///|
pub fn dfm_info() -> DfmSeverity {
  DfmInfo
}

///|
pub fn dfm_warning() -> DfmSeverity {
  DfmWarning
}

///|
pub fn dfm_error() -> DfmSeverity {
  DfmError
}

///|
pub fn strict_dfm_config() -> DfmConfig {
  {
    min_width: 0.1,
    min_drill: 0.2,
    min_clearance: 0.15,
    min_annular_ring: 0.1,
    max_board_width: 300.0,
    max_board_height: 300.0,
    require_outline: true,
    require_drill_layer: true,
    check_duplicates: true,
    check_geometry: true,
  }
}

///|
pub fn strict_validation_options() -> ValidationOptions {
  {
    max_records: 2,
    max_shapes: 1,
    reject_unknown_records: true,
    reject_empty_input: true,
    require_end_record: true,
    check_coordinates: true,
  }
}

///|
pub fn gerber_attribute(
  scope~ : GerberAttributeScope,
  name~ : String,
  values~ : Array[String],
  record~ : String,
) -> GerberAttribute {
  { scope, name, values, record }
}

///|
pub fn file_attribute_scope() -> GerberAttributeScope {
  FileAttribute
}

///|
pub fn aperture_attribute_scope() -> GerberAttributeScope {
  ApertureAttribute
}

///|
pub fn object_attribute_scope() -> GerberAttributeScope {
  ObjectAttribute
}

///|
pub fn delete_attribute_scope() -> GerberAttributeScope {
  DeleteAttribute
}

///|
pub fn macro_circle(
  exposure~ : Int,
  diameter~ : Double,
  x~ : Double,
  y~ : Double,
) -> MacroPrimitive {
  MacroCircle(exposure~, diameter~, x~, y~)
}

///|
pub fn macro_outline(
  exposure~ : Int,
  points~ : Array[Point2],
) -> MacroPrimitive {
  MacroOutline(exposure~, points~)
}

///|
pub fn no_operation() -> ModalOperation {
  NoOperation
}

///|
pub fn excellon_leading_zero_mode() -> ExcellonZeroMode {
  ExcellonLeadingZeros
}

///|
pub fn excellon_trailing_zero_mode() -> ExcellonZeroMode {
  ExcellonTrailingZeros
}

///|
pub fn end_of_file_token_kind() -> GerberTokenKind {
  EndOfFile
}

///|
pub fn not_a_number_value() -> Double {
  @double.not_a_number
}
