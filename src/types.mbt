///|
pub enum LengthUnit {
  Millimeter
  Inch
}

///|
pub fn LengthUnit::scale_to_mm(self : LengthUnit) -> Double {
  match self {
    Millimeter => 1.0
    Inch => 25.4
  }
}

///|
pub enum LayerKind {
  Copper
  SolderMask
  Silkscreen
  Drill
  Mechanical
  Unknown
}

///|
pub enum Shape {
  Segment(
    x1~ : Double,
    y1~ : Double,
    x2~ : Double,
    y2~ : Double,
    width~ : Double
  )
  Pad(x~ : Double, y~ : Double, diameter~ : Double)
  Flash(x~ : Double, y~ : Double, aperture~ : Int)
  Region(points~ : Array[(Double, Double)])
  DrillHit(x~ : Double, y~ : Double, diameter~ : Double)
}

///|
pub struct Layer {
  name : String
  kind : LayerKind
  unit : LengthUnit
  shapes : Array[Shape]
}

///|
pub struct Board {
  layers : Array[Layer]
}

///|
pub fn empty_board() -> Board {
  { layers: [] }
}

///|
pub fn board_from_layers(layers : Array[Layer]) -> Board {
  { layers, }
}

///|
pub struct BoundingBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
pub struct Issue {
  rule : String
  severity : String
  message : String
  layer : String
}

///|
pub struct Report {
  board : Board
  issues : Array[Issue]
  bbox : BoundingBox?
}

///|
pub fn kind_to_string(kind : LayerKind) -> String {
  match kind {
    Copper => "copper"
    SolderMask => "solder-mask"
    Silkscreen => "silkscreen"
    Drill => "drill"
    Mechanical => "mechanical"
    Unknown => "unknown"
  }
}

///|
pub fn unit_to_string(unit : LengthUnit) -> String {
  match unit {
    Millimeter => "mm"
    Inch => "in"
  }
}

///|
pub fn supported_layer_kinds() -> Array[LayerKind] {
  [Copper, SolderMask, Silkscreen, Drill, Mechanical, Unknown]
}

///|
pub fn supported_shapes() -> Array[Shape] {
  [Flash(x=0.0, y=0.0, aperture=0), Region(points=[])]
}
