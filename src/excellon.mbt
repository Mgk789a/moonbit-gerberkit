///|
pub enum ExcellonZeroMode {
  ExcellonLeadingZeros
  ExcellonTrailingZeros
  ExcellonDecimal
} derive(Debug, Eq)

///|
pub struct ExcellonFormat {
  integer_digits : Int
  decimal_digits : Int
  zero_mode : ExcellonZeroMode
  unit : LengthUnit
} derive(Debug)

///|
pub fn excellon_format(
  integer_digits~ : Int,
  decimal_digits~ : Int,
  zero_mode~ : ExcellonZeroMode,
  unit~ : LengthUnit,
) -> ExcellonFormat {
  { integer_digits, decimal_digits, zero_mode, unit }
}

///|
pub fn default_excellon_format() -> ExcellonFormat {
  excellon_format(
    integer_digits=2,
    decimal_digits=4,
    zero_mode=ExcellonDecimal,
    unit=Millimeter,
  )
}

///|
pub fn ExcellonFormat::parse_number(
  self : ExcellonFormat,
  raw : String,
) -> Double? {
  if raw == "" {
    None
  } else if raw.contains(".") {
    parse_decimal(raw[:]).map(v => v * self.unit.scale_to_mm())
  } else if self.zero_mode is ExcellonDecimal {
    parse_decimal(raw[:]).map(v => v * self.unit.scale_to_mm())
  } else {
    let mut sign = 1.0
    let mut digits = raw
    if raw.has_prefix("-") {
      sign = -1.0
      digits = raw[1:].to_owned()
    } else if raw.has_prefix("+") {
      digits = raw[1:].to_owned()
    }
    let total = self.integer_digits + self.decimal_digits
    let missing = total - digits.length()
    let normalized = if self.zero_mode is ExcellonLeadingZeros && missing > 0 {
      "0".repeat(missing) + digits
    } else if self.zero_mode is ExcellonTrailingZeros && missing > 0 {
      digits + "0".repeat(missing)
    } else {
      digits
    }
    parse_decimal(normalized[:]).map(v => {
      sign * v / self.scale() * self.unit.scale_to_mm()
    })
  }
}

///|
pub fn ExcellonFormat::scale(self : ExcellonFormat) -> Double {
  let mut result = 1.0
  for _ in 0..<self.decimal_digits {
    result *= 10.0
  }
  result
}

///|
pub struct DrillTool {
  code : Int
  diameter : Double
  feed_rate : Double?
  retract_rate : Double?
  description : String?
} derive(Debug)

///|
pub fn drill_tool(code~ : Int, diameter~ : Double) -> DrillTool {
  { code, diameter, feed_rate: None, retract_rate: None, description: None }
}

///|
pub fn DrillTool::valid(self : DrillTool) -> Bool {
  self.code > 0 && self.diameter > 0.0
}

///|
pub fn DrillTool::area(self : DrillTool) -> Double {
  3.141592653589793 * (self.diameter / 2.0) * (self.diameter / 2.0)
}

///|
pub struct ExcellonDocument {
  layer : Layer
  tools : Array[DrillTool]
  diagnostics : Array[ParseDiagnostic]
  records : Int
  hits : Int
  slots : Int
  unit : LengthUnit
} derive(Debug)

///|
pub fn ExcellonDocument::tool_count(self : ExcellonDocument) -> Int {
  self.tools.length()
}

///|
pub fn ExcellonDocument::error_count(self : ExcellonDocument) -> Int {
  self.diagnostics.filter(item => item.is_error()).length()
}

///|
pub fn ExcellonDocument::summary(self : ExcellonDocument) -> String {
  "records=\{self.records}, tools=\{self.tools.length()}, hits=\{self.hits}, slots=\{self.slots}, unit=\{unit_to_string(self.unit)}, errors=\{self.error_count()}"
}

///|
pub fn ExcellonDocument::tool(
  self : ExcellonDocument,
  code : Int,
) -> DrillTool? {
  find_drill_tool(self.tools, code)
}

///|
struct ExcellonState {
  mut format : ExcellonFormat
  mut current_tool : DrillTool?
  mut current : Point2
  mut slot_start : Point2?
  mut route_mode : Bool
  mut absolute_mode : Bool
} derive(Debug)

///|
fn new_excellon_state() -> ExcellonState {
  {
    format: default_excellon_format(),
    current_tool: None,
    current: point2(x=0.0, y=0.0),
    slot_start: None,
    route_mode: false,
    absolute_mode: true,
  }
}

///|
fn find_drill_tool(tools : Array[DrillTool], code : Int) -> DrillTool? {
  for tool in tools {
    if tool.code == code {
      return Some(tool)
    }
  }
  None
}

///|
fn excellon_tool_code(record : String) -> Int? {
  if !record.has_prefix("T") {
    None
  } else {
    record_code_value(record, "T")
  }
}

///|
fn excellon_tool_diameter(record : String) -> Double? {
  match record.find("C") {
    Some(index) => parse_decimal(record[index + 1:]).map(v => v)
    None => None
  }
}

///|
fn excellon_update_format(state : ExcellonState, record : String) -> Unit {
  let unit = if record.has_prefix("INCH") || record.contains("INCH") {
    Inch
  } else if record.has_prefix("METRIC") || record.contains("METRIC") {
    Millimeter
  } else {
    state.format.unit
  }
  let zero_mode = if record.contains("TZ") {
    ExcellonTrailingZeros
  } else if record.contains("LZ") {
    ExcellonLeadingZeros
  } else if record.contains(".") {
    ExcellonDecimal
  } else {
    state.format.zero_mode
  }
  state.format = excellon_format(
    integer_digits=state.format.integer_digits,
    decimal_digits=state.format.decimal_digits,
    zero_mode~,
    unit~,
  )
}

///|
fn excellon_axis(record : String, axis : Char) -> String? {
  record_coordinate(record, axis)
}

///|
fn excellon_point(state : ExcellonState, record : String) -> Point2? {
  let x = match excellon_axis(record, 'X') {
    Some(value) => state.format.parse_number(value).unwrap_or(state.current.x)
    None => state.current.x
  }
  let y = match excellon_axis(record, 'Y') {
    Some(value) => state.format.parse_number(value).unwrap_or(state.current.y)
    None => state.current.y
  }
  if excellon_axis(record, 'X') is None && excellon_axis(record, 'Y') is None {
    None
  } else {
    let point = if state.absolute_mode {
      point2(x~, y~)
    } else {
      point2(x=state.current.x + x, y=state.current.y + y)
    }
    state.current = point
    Some(point)
  }
}

///|
fn excellon_diagnostic(
  diagnostics : Array[ParseDiagnostic],
  severity : DiagnosticSeverity,
  code : String,
  message : String,
  line : Int,
  record : String,
) -> Unit {
  diagnostics.push(
    diagnostic(severity~, code~, message~, line~, column=1, record~),
  )
}

///|
/// Parse Excellon drill files, including tool tables, units, zero suppression, and slots.
pub fn parse_excellon_document(
  text : String,
  name? : String = "drill",
) -> ExcellonDocument {
  let state = new_excellon_state()
  let tools : Array[DrillTool] = []
  let diagnostics : Array[ParseDiagnostic] = []
  let shapes : Array[Shape] = []
  let records = tokenize_excellon(text)
  let mut current_line = 0
  let mut hits = 0
  let mut slots = 0
  for record in records {
    current_line += 1
    if record == "M48" {
      ()
    } else if record.has_prefix("METRIC") || record.has_prefix("INCH") {
      excellon_update_format(state, record)
    } else if record == "M71" {
      state.format = excellon_format(
        integer_digits=state.format.integer_digits,
        decimal_digits=state.format.decimal_digits,
        zero_mode=state.format.zero_mode,
        unit=Millimeter,
      )
    } else if record == "M72" {
      state.format = excellon_format(
        integer_digits=state.format.integer_digits,
        decimal_digits=state.format.decimal_digits,
        zero_mode=state.format.zero_mode,
        unit=Inch,
      )
    } else if record.has_prefix("G90") {
      state.absolute_mode = true
    } else if record.has_prefix("G91") {
      state.absolute_mode = false
    } else if record.has_prefix("G00") {
      state.route_mode = false
    } else if record.has_prefix("G01") {
      state.route_mode = true
    } else if record.has_prefix("T") {
      match (excellon_tool_code(record), excellon_tool_diameter(record)) {
        (Some(code), Some(diameter)) if diameter > 0.0 => {
          let tool = drill_tool(
            code~,
            diameter=diameter * state.format.unit.scale_to_mm(),
          )
          tools.push(tool)
          state.current_tool = Some(tool)
        }
        (Some(code), None) => {
          state.current_tool = find_drill_tool(tools, code)
          if state.current_tool is None {
            excellon_diagnostic(
              diagnostics,
              WarningDiagnostic,
              "unknown-tool",
              "a drill hit selected a tool that was not defined",
              current_line,
              record,
            )
          }
        }
        _ =>
          excellon_diagnostic(
            diagnostics,
            WarningDiagnostic,
            "invalid-tool",
            "tool record does not contain a valid T-code and diameter",
            current_line,
            record,
          )
      }
    } else if record.has_prefix("G85") {
      state.route_mode = true
      match excellon_point(state, record) {
        Some(point) => state.slot_start = Some(point)
        None => ()
      }
    } else if record == "G05" {
      state.route_mode = false
      match state.slot_start {
        Some(start) => {
          let diameter = state.current_tool.map(t => t.diameter).unwrap_or(0.8)
          shapes.push(
            Segment(
              x1=start.x,
              y1=start.y,
              x2=state.current.x,
              y2=state.current.y,
              width=diameter,
            ),
          )
          slots += 1
          state.slot_start = None
        }
        None => ()
      }
    } else if record == "M30" || record == "M00" {
      ()
    } else {
      match excellon_point(state, record) {
        Some(point) => {
          let diameter = state.current_tool.map(t => t.diameter).unwrap_or(0.8)
          if state.route_mode {
            match state.slot_start {
              Some(start) => {
                shapes.push(
                  Segment(
                    x1=start.x,
                    y1=start.y,
                    x2=point.x,
                    y2=point.y,
                    width=diameter,
                  ),
                )
                slots += 1
                state.slot_start = Some(point)
              }
              None => state.slot_start = Some(point)
            }
          } else {
            shapes.push(DrillHit(x=point.x, y=point.y, diameter~))
            hits += 1
          }
        }
        None =>
          if !record.has_prefix(";") && record != "%" {
            excellon_diagnostic(
              diagnostics,
              InfoDiagnostic,
              "unhandled-record",
              "record was ignored because it is not a drill coordinate",
              current_line,
              record,
            )
          }
      }
    }
  }
  {
    layer: { name, kind: Drill, unit: Millimeter, shapes },
    tools,
    diagnostics,
    records: records.length(),
    hits,
    slots,
    unit: state.format.unit,
  }
}

///|
pub fn parse_excellon_with_diagnostics(
  text : String,
  name? : String = "drill",
) -> (Layer, Array[ParseDiagnostic]) {
  let document = parse_excellon_document(text, name~)
  (document.layer, document.diagnostics)
}
