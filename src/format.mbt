///|
pub enum CoordinateNotation {
  AbsoluteNotation
  IncrementalNotation
} derive(Debug, Eq)

///|
pub enum ZeroSuppression {
  LeadingZeros
  TrailingZeros
  ExplicitZeros
} derive(Debug, Eq)

///|
pub struct CoordinateFormat {
  integer_digits : Int
  decimal_digits : Int
  zero_suppression : ZeroSuppression
  notation : CoordinateNotation
  unit : LengthUnit
} derive(Debug)

///|
pub fn coordinate_format(
  integer_digits~ : Int,
  decimal_digits~ : Int,
  zero_suppression~ : ZeroSuppression,
  notation~ : CoordinateNotation,
  unit~ : LengthUnit,
) -> CoordinateFormat {
  {
    integer_digits: if integer_digits < 0 {
      0
    } else {
      integer_digits
    },
    decimal_digits: if decimal_digits < 0 {
      0
    } else {
      decimal_digits
    },
    zero_suppression,
    notation,
    unit,
  }
}

///|
pub fn default_coordinate_format() -> CoordinateFormat {
  coordinate_format(
    integer_digits=2,
    decimal_digits=4,
    zero_suppression=LeadingZeros,
    notation=AbsoluteNotation,
    unit=Millimeter,
  )
}

///|
pub fn CoordinateFormat::total_digits(self : CoordinateFormat) -> Int {
  self.integer_digits + self.decimal_digits
}

///|
pub fn CoordinateFormat::scale(self : CoordinateFormat) -> Double {
  let mut factor = 1.0
  for _ in 0..<self.decimal_digits {
    factor *= 10.0
  }
  factor
}

///|
pub fn CoordinateFormat::parse_axis(
  self : CoordinateFormat,
  raw : String,
) -> Double? {
  if raw == "" {
    None
  } else if raw.contains(".") {
    parse_decimal(raw[:]).map(value => value * self.unit.scale_to_mm())
  } else {
    let mut sign = 1.0
    let mut digits = raw
    if raw.has_prefix("-") {
      sign = -1.0
      digits = raw[1:].to_owned()
    } else if raw.has_prefix("+") {
      digits = raw[1:].to_owned()
    }
    let expected = self.total_digits()
    let missing = expected - digits.length()
    let normalized = if self.zero_suppression is LeadingZeros && missing > 0 {
      "0".repeat(missing) + digits
    } else if self.zero_suppression is TrailingZeros && missing > 0 {
      digits + "0".repeat(missing)
    } else {
      digits
    }
    match parse_decimal(normalized[:]) {
      Some(value) => {
        let scaled = sign * value / self.scale()
        Some(scaled * self.unit.scale_to_mm())
      }
      None => None
    }
  }
}

///|
pub fn CoordinateFormat::format_axis(
  self : CoordinateFormat,
  value_mm : Double,
) -> String {
  let value = value_mm / self.unit.scale_to_mm()
  let scaled = (value * self.scale()).round().to_int()
  let sign = if scaled < 0 { "-" } else { "" }
  let absolute = scaled.abs().to_string()
  let total = self.total_digits()
  let padded = if absolute.length() < total {
    "0".repeat(total - absolute.length()) + absolute
  } else {
    absolute
  }
  let split = padded.length() - self.decimal_digits
  let integer_part = if split <= 0 { "0" } else { padded[:split].to_owned() }
  let fraction_part = if self.decimal_digits == 0 {
    ""
  } else if split <= 0 {
    "0".repeat(-split) + padded
  } else {
    padded[split:].to_owned()
  }
  if self.decimal_digits == 0 {
    sign + integer_part
  } else {
    sign + integer_part + "." + fraction_part
  }
}

///|
pub fn parse_format_statement(
  statement : String,
  current : CoordinateFormat,
) -> CoordinateFormat {
  let value = statement.trim().to_owned()
  let zero_suppression = if value.has_prefix("FSL") {
    LeadingZeros
  } else if value.has_prefix("FST") {
    TrailingZeros
  } else {
    ExplicitZeros
  }
  let notation = if value.contains("I") {
    IncrementalNotation
  } else {
    AbsoluteNotation
  }
  let x_start = match value.find("X") {
    Some(i) => i + 1
    None => 0
  }
  let x_digits = if x_start + 2 <= value.length() {
    value[x_start:x_start + 2].to_owned()
  } else {
    "24"
  }
  let y_start = match value.find("Y") {
    Some(i) => i + 1
    None => x_start
  }
  let y_digits = if y_start + 2 <= value.length() {
    value[y_start:y_start + 2].to_owned()
  } else {
    x_digits
  }
  let integer_digits = parse_decimal(x_digits[:1])
    .map(v => v.to_int())
    .unwrap_or(current.integer_digits)
  let decimal_digits = parse_decimal(x_digits[1:])
    .map(v => v.to_int())
    .unwrap_or(current.decimal_digits)
  let y_integer = parse_decimal(y_digits[:1])
    .map(v => v.to_int())
    .unwrap_or(integer_digits)
  let y_decimal = parse_decimal(y_digits[1:])
    .map(v => v.to_int())
    .unwrap_or(decimal_digits)
  coordinate_format(
    integer_digits=if integer_digits > y_integer {
      integer_digits
    } else {
      y_integer
    },
    decimal_digits=if decimal_digits > y_decimal {
      decimal_digits
    } else {
      y_decimal
    },
    zero_suppression~,
    notation~,
    unit=current.unit,
  )
}

///|
pub fn parse_unit_statement(
  statement : String,
  current : LengthUnit,
) -> LengthUnit {
  if statement.contains("IN") || statement.contains("INCH") {
    Inch
  } else if statement.contains("MM") || statement.contains("METRIC") {
    Millimeter
  } else {
    current
  }
}

///|
pub fn parse_notation_statement(
  statement : String,
  current : CoordinateNotation,
) -> CoordinateNotation {
  if statement.contains("ICI") || statement.contains("INCREMENTAL") {
    IncrementalNotation
  } else if statement.contains("IMA") || statement.contains("ABSOLUTE") {
    AbsoluteNotation
  } else {
    current
  }
}

///|
pub enum ModalOperation {
  MoveOperation
  DrawOperation
  FlashOperation
  RegionMoveOperation
  RegionDrawOperation
  NoOperation
} derive(Debug, Eq)

///|
pub fn operation_from_code(record : String) -> ModalOperation {
  if record.contains("D01") {
    DrawOperation
  } else if record.contains("D02") {
    MoveOperation
  } else if record.contains("D03") {
    FlashOperation
  } else if record.contains("G36") {
    RegionMoveOperation
  } else if record.contains("G37") {
    RegionDrawOperation
  } else {
    NoOperation
  }
}

///|
pub struct GerberState {
  mut format : CoordinateFormat
  mut current : Point2
  mut previous : Point2
  mut aperture_code : Int?
  mut operation : ModalOperation
  mut interpolation : Int
  quadrant_mode : Int
  mut region_open : Bool
  region_points : Array[Point2]
} derive(Debug)

///|
pub fn new_gerber_state() -> GerberState {
  {
    format: default_coordinate_format(),
    current: point2(x=0.0, y=0.0),
    previous: point2(x=0.0, y=0.0),
    aperture_code: None,
    operation: MoveOperation,
    interpolation: 1,
    quadrant_mode: 1,
    region_open: false,
    region_points: [],
  }
}

///|
pub fn GerberState::set_unit(self : GerberState, unit : LengthUnit) -> Unit {
  self.format = coordinate_format(
    integer_digits=self.format.integer_digits,
    decimal_digits=self.format.decimal_digits,
    zero_suppression=self.format.zero_suppression,
    notation=self.format.notation,
    unit~,
  )
}

///|
pub fn GerberState::set_format(
  self : GerberState,
  format : CoordinateFormat,
) -> Unit {
  self.format = format
}

///|
pub fn GerberState::select_aperture(self : GerberState, code : Int) -> Unit {
  self.aperture_code = Some(code)
}

///|
pub fn GerberState::set_operation(
  self : GerberState,
  operation : ModalOperation,
) -> Unit {
  self.operation = operation
}

///|
pub fn GerberState::set_interpolation(
  self : GerberState,
  interpolation : Int,
) -> Unit {
  self.interpolation = interpolation
}

///|
pub fn GerberState::update_point(
  self : GerberState,
  x : Double?,
  y : Double?,
) -> Point2 {
  let next = match self.format.notation {
    AbsoluteNotation =>
      { x: x.unwrap_or(self.current.x), y: y.unwrap_or(self.current.y) }
    IncrementalNotation =>
      {
        x: self.current.x + x.unwrap_or(0.0),
        y: self.current.y + y.unwrap_or(0.0),
      }
  }
  self.previous = self.current
  self.current = next
  next
}

///|
pub fn GerberState::parse_point(self : GerberState, record : String) -> Point2? {
  let x = match record_coordinate(record, 'X') {
    Some(value) => self.format.parse_axis(value)
    None => None
  }
  let y = match record_coordinate(record, 'Y') {
    Some(value) => self.format.parse_axis(value)
    None => None
  }
  if x is None && y is None {
    None
  } else {
    Some(self.update_point(x, y))
  }
}

///|
pub fn GerberState::start_region(self : GerberState) -> Unit {
  self.region_open = true
  self.region_points.clear()
}

///|
pub fn GerberState::append_region_point(
  self : GerberState,
  point : Point2,
) -> Unit {
  if self.region_open {
    self.region_points.push(point)
  }
}

///|
pub fn GerberState::finish_region(self : GerberState) -> Array[Point2] {
  self.region_open = false
  let result = self.region_points.copy()
  self.region_points.clear()
  result
}

///|
pub fn format_name(format : CoordinateFormat) -> String {
  let zero = match format.zero_suppression {
    LeadingZeros => "L"
    TrailingZeros => "T"
    ExplicitZeros => "D"
  }
  let notation = match format.notation {
    AbsoluteNotation => "A"
    IncrementalNotation => "I"
  }
  "FS\{zero}\{notation}X\{format.integer_digits}\{format.decimal_digits}Y\{format.integer_digits}\{format.decimal_digits}"
}

///|
pub fn operation_name(operation : ModalOperation) -> String {
  match operation {
    MoveOperation => "move"
    DrawOperation => "draw"
    FlashOperation => "flash"
    RegionMoveOperation => "region-move"
    RegionDrawOperation => "region-draw"
    NoOperation => "none"
  }
}
