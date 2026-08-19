///|
pub struct GerberDocument {
  layer : Layer
  diagnostics : Array[ParseDiagnostic]
  apertures : ApertureTable
  records : Int
  commands : Int
  draws : Int
  flashes : Int
  moves : Int
  regions : Int
} derive(Debug)

///|
pub fn GerberDocument::has_errors(self : GerberDocument) -> Bool {
  self.diagnostics.any(item => item.is_error())
}

///|
pub fn GerberDocument::warning_count(self : GerberDocument) -> Int {
  self.diagnostics.filter(item => item.severity is WarningDiagnostic).length()
}

///|
pub fn GerberDocument::error_count(self : GerberDocument) -> Int {
  self.diagnostics.filter(item => item.is_error()).length()
}

///|
pub fn GerberDocument::summary(self : GerberDocument) -> String {
  "records=\{self.records}, commands=\{self.commands}, draws=\{self.draws}, flashes=\{self.flashes}, moves=\{self.moves}, regions=\{self.regions}, warnings=\{self.warning_count()}, errors=\{self.error_count()}"
}

///|
pub fn document_layer(document : GerberDocument) -> Layer {
  document.layer
}

///|
fn parser_diagnostic(
  diagnostics : Array[ParseDiagnostic],
  severity : DiagnosticSeverity,
  code : String,
  message : String,
  record_index : Int,
  record : String,
) -> Unit {
  diagnostics.push(
    diagnostic(
      severity~,
      code~,
      message~,
      line=record_index + 1,
      column=1,
      record~,
    ),
  )
}

///|
fn parser_aperture_code(record : String) -> Int? {
  if !record.has_prefix("AD") {
    None
  } else {
    match record_code_value(record[2:].to_owned(), "D") {
      Some(code) if code >= 10 => Some(code)
      _ => None
    }
  }
}

///|
fn parser_aperture_definition(record : String) -> String {
  match record.find("C,") {
    Some(index) => record[index:].to_owned()
    None =>
      match record.find("R,") {
        Some(index) => record[index:].to_owned()
        None =>
          match record.find("O,") {
            Some(index) => record[index:].to_owned()
            None =>
              match record.find("P,") {
                Some(index) => record[index:].to_owned()
                None => record
              }
          }
      }
  }
}

///|
fn parser_select_code(record : String) -> Int? {
  if record.has_prefix("D") && !record.has_prefix("D0") {
    record_code_value(record, "D")
  } else {
    None
  }
}

///|
fn parser_line_kind(name : String) -> LayerKind {
  let upper = name.to_upper()
  if upper.contains("DRILL") || upper.contains("PTH") || upper.contains("NPTH") {
    Drill
  } else if upper.contains("MASK") {
    SolderMask
  } else if upper.contains("SILK") {
    Silkscreen
  } else if upper.contains("EDGE") ||
    upper.contains("OUTLINE") ||
    upper.contains("MECH") {
    Mechanical
  } else if upper.contains("CU") || upper.contains("COPPER") {
    Copper
  } else {
    Copper
  }
}

///|
fn parser_default_width(
  table : ApertureTable,
  code : Int?,
  unit : LengthUnit,
) -> Double {
  match code {
    Some(value) => {
      let aperture = table.require(value)
      let width = aperture.outer_width()
      if width > 0.0 {
        width * unit.scale_to_mm()
      } else {
        0.2
      }
    }
    None => 0.2
  }
}

///|
fn parser_add_segment(
  shapes : Array[Shape],
  from : Point2,
  to : Point2,
  width : Double,
) -> Unit {
  if !from.near(to) {
    shapes.push(
      Segment(
        x1=from.x,
        y1=from.y,
        x2=to.x,
        y2=to.y,
        width=if width <= 0.0 { 0.2 } else { width },
      ),
    )
  }
}

///|
fn parser_add_flash(
  shapes : Array[Shape],
  table : ApertureTable,
  code : Int?,
  point : Point2,
) -> Unit {
  match code {
    Some(value) => shapes.push(table.require(value).to_shape(point))
    None => shapes.push(Flash(x=point.x, y=point.y, aperture=0))
  }
}

///|
fn parser_axis_value(
  state : GerberState,
  record : String,
  axis : Char,
) -> Double {
  match record_coordinate(record, axis) {
    Some(value) => state.format.parse_axis(value).unwrap_or(0.0)
    None => 0.0
  }
}

///|
fn parser_add_region(
  shapes : Array[Shape],
  points : Array[Point2],
  diagnostics : Array[ParseDiagnostic],
  index : Int,
  record : String,
) -> Unit {
  if points.length() < 3 {
    parser_diagnostic(
      diagnostics,
      WarningDiagnostic,
      "region-too-short",
      "region was closed with fewer than three points",
      index,
      record,
    )
  } else {
    let coordinates = points.map(point => (point.x, point.y))
    shapes.push(Region(points=coordinates))
  }
}

///|
fn parser_process_coordinate(
  state : GerberState,
  table : ApertureTable,
  shapes : Array[Shape],
  diagnostics : Array[ParseDiagnostic],
  record : String,
  index : Int,
) -> (Int, Int, Int, Int) {
  let before = state.current
  match state.parse_point(record) {
    None => {
      parser_diagnostic(
        diagnostics,
        WarningDiagnostic,
        "invalid-coordinate",
        "coordinate record does not contain a parseable X or Y value",
        index,
        record,
      )
      (0, 0, 0, 0)
    }
    Some(point) =>
      if state.region_open {
        match state.operation {
          MoveOperation | RegionMoveOperation => {
            state.region_points.clear()
            state.region_points.push(point)
          }
          DrawOperation | RegionDrawOperation =>
            state.append_region_point(point)
          FlashOperation => state.append_region_point(point)
          NoOperation => state.append_region_point(point)
        }
        (0, 0, 1, 0)
      } else {
        match state.operation {
          MoveOperation => (0, 0, 1, 0)
          DrawOperation => {
            let width = parser_default_width(
              table,
              state.aperture_code,
              state.format.unit,
            )
            if state.interpolation == 1 ||
              (
                record_coordinate(record, 'I') is None &&
                record_coordinate(record, 'J') is None
              ) {
              parser_add_segment(shapes, before, point, width)
            } else {
              let direction = if state.interpolation == 2 {
                ClockwiseArc
              } else {
                CounterClockwiseArc
              }
              let arc = arc_from_offsets(
                before,
                point,
                parser_axis_value(state, record, 'I'),
                parser_axis_value(state, record, 'J'),
                direction,
              )
              shapes.append(arc.to_segments(width))
            }
            (1, 0, 0, 0)
          }
          FlashOperation => {
            parser_add_flash(shapes, table, state.aperture_code, point)
            (0, 1, 0, 0)
          }
          RegionMoveOperation | RegionDrawOperation | NoOperation =>
            (0, 0, 0, 0)
        }
      }
  }
}

///|
fn parser_apply_parameter(
  state : GerberState,
  table : ApertureTable,
  diagnostics : Array[ParseDiagnostic],
  record : String,
  index : Int,
) -> Unit {
  if record.has_prefix("FS") {
    state.set_format(parse_format_statement(record, state.format))
  } else if record.has_prefix("MO") {
    let unit = parse_unit_statement(record, state.format.unit)
    state.set_unit(unit)
  } else if record.has_prefix("AD") {
    match parser_aperture_code(record) {
      Some(code) =>
        table.add_or_replace(
          parse_aperture_definition(code, parser_aperture_definition(record)),
        )
      None =>
        parser_diagnostic(
          diagnostics,
          WarningDiagnostic,
          "invalid-aperture",
          "aperture definition does not contain a valid D-code",
          index,
          record,
        )
    }
  } else if record.has_prefix("AM") {
    parser_diagnostic(
      diagnostics,
      InfoDiagnostic,
      "aperture-macro",
      "aperture macro definition was retained for later evaluation",
      index,
      record,
    )
  } else if record.has_prefix("TF") ||
    record.has_prefix("TA") ||
    record.has_prefix("TO") {
    ()
  } else {
    parser_diagnostic(
      diagnostics,
      InfoDiagnostic,
      "unsupported-parameter",
      "parameter record was preserved but not interpreted",
      index,
      record,
    )
  }
}

///|
/// Parse a Gerber RS-274X layer with modal state and source diagnostics.
pub fn parse_gerber_document(
  text : String,
  name? : String = "gerber",
) -> GerberDocument {
  let layer_name = name
  let layer_kind = parser_line_kind(layer_name)
  let state = new_gerber_state()
  let table = new_aperture_table()
  let diagnostics : Array[ParseDiagnostic] = []
  let shapes : Array[Shape] = []
  let records = tokenize_records(text)
  let mut commands = 0
  let mut draws = 0
  let mut flashes = 0
  let mut moves = 0
  let mut regions = 0
  let mut index = 0
  for record in records {
    let clean = normalize_record(record)
    if clean == "" {
      index += 1
      continue
    }
    if is_parameter_record(clean) {
      parser_apply_parameter(state, table, diagnostics, clean, index)
    } else if clean.has_prefix("G36") {
      state.start_region()
      state.operation = RegionMoveOperation
      regions += 1
      commands += 1
    } else if clean.has_prefix("G37") {
      if state.region_open {
        parser_add_region(
          shapes,
          state.finish_region(),
          diagnostics,
          index,
          clean,
        )
      } else {
        parser_diagnostic(
          diagnostics,
          WarningDiagnostic,
          "region-close-without-open",
          "G37 was found without a matching G36",
          index,
          clean,
        )
      }
      state.operation = MoveOperation
      commands += 1
    } else if clean.has_prefix("G01") {
      state.set_interpolation(1)
      commands += 1
    } else if clean.has_prefix("G02") {
      state.set_interpolation(2)
      if clean.contains("D01") || clean.contains("D02") || clean.contains("D03") {
        state.set_operation(operation_from_code(clean))
        let counts = parser_process_coordinate(
          state, table, shapes, diagnostics, clean, index,
        )
        draws += counts.0
        flashes += counts.1
        moves += counts.2
      }
      commands += 1
    } else if clean.has_prefix("G03") {
      state.set_interpolation(3)
      if clean.contains("D01") || clean.contains("D02") || clean.contains("D03") {
        state.set_operation(operation_from_code(clean))
        let counts = parser_process_coordinate(
          state, table, shapes, diagnostics, clean, index,
        )
        draws += counts.0
        flashes += counts.1
        moves += counts.2
      }
      commands += 1
    } else if clean.contains("D01") ||
      clean.contains("D02") ||
      clean.contains("D03") {
      let operation = operation_from_code(clean)
      state.set_operation(operation)
      let counts = parser_process_coordinate(
        state, table, shapes, diagnostics, clean, index,
      )
      draws += counts.0
      flashes += counts.1
      moves += counts.2
      commands += 1
    } else if parser_select_code(clean) is Some(code) {
      state.select_aperture(code)
      commands += 1
    } else if clean.has_prefix("M02") || clean.has_prefix("M30") {
      commands += 1
    } else if record_coordinate(clean, 'X') is Some(_) ||
      record_coordinate(clean, 'Y') is Some(_) {
      let counts = parser_process_coordinate(
        state, table, shapes, diagnostics, clean, index,
      )
      draws += counts.0
      flashes += counts.1
      moves += counts.2
    } else {
      parser_diagnostic(
        diagnostics,
        InfoDiagnostic,
        "unhandled-record",
        "record was not a drawing or modal command",
        index,
        clean,
      )
    }
    index += 1
  }
  if state.region_open {
    parser_add_region(
      shapes,
      state.finish_region(),
      diagnostics,
      records.length(),
      "end-of-file",
    )
    parser_diagnostic(
      diagnostics,
      WarningDiagnostic,
      "unterminated-region",
      "file ended while a region was open",
      records.length(),
      "end-of-file",
    )
  }
  {
    layer: {
      name: layer_name,
      kind: layer_kind,
      unit: state.format.unit,
      shapes,
    },
    diagnostics,
    apertures: table,
    records: records.length(),
    commands,
    draws,
    flashes,
    moves,
    regions,
  }
}

///|
pub fn parse_gerber_with_diagnostics(
  text : String,
  name? : String = "gerber",
) -> (Layer, Array[ParseDiagnostic]) {
  let document = parse_gerber_document(text, name~)
  (document.layer, document.diagnostics)
}
