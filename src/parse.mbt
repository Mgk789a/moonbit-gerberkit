///|
fn parse_decimal(view : StringView) -> Double? {
  let mut sign = 1.0
  let mut value = 0.0
  let mut fraction = 0.0
  let mut in_fraction = false
  let mut seen = false
  for c in view {
    if c == '-' {
      sign = -1.0
    } else if c == '.' {
      in_fraction = true
    } else if c >= '0' && c <= '9' {
      seen = true
      let digit = (c.to_int() - '0'.to_int()).to_double()
      if in_fraction {
        fraction = fraction * 0.1 + digit * 0.1
      } else {
        value = value * 10.0 + digit
      }
    } else if seen {
      break
    }
  }
  if seen {
    Some(sign * (value + fraction))
  } else {
    None
  }
}

///|
fn number_after(word : String, key : StringView) -> Double? {
  match word.find(key) {
    None => None
    Some(i) => parse_decimal(word[i + key.length():])
  }
}

///|
fn first_number(word : String) -> Double? {
  let mut started = false
  let mut result = ""
  for c in word {
    if !started && ((c >= '0' && c <= '9') || c == '-' || c == '+') {
      started = true
    }
    if started && ((c >= '0' && c <= '9') || c == '.' || c == '-' || c == '+') {
      result = result + c.to_string()
    } else if started {
      break
    }
  }
  parse_decimal(result.view())
}

///|
fn parse_xy(line : String, unit : LengthUnit) -> (Double, Double)? {
  match (number_after(line, "X"), number_after(line, "Y")) {
    (Some(x), Some(y)) => Some((x * unit.scale_to_mm(), y * unit.scale_to_mm()))
    _ => None
  }
}

///|
pub fn parse_gerber(text : String, name? : String = "gerber") -> Layer {
  let unit : LengthUnit = if text.contains("MOIN") { Inch } else { Millimeter }
  let shapes : Array[Shape] = []
  let mut last : (Double, Double)? = None
  let mut width = 0.2
  for raw in text.split("*") {
    let line = raw.trim().to_owned()
    if line.contains("ADD") {
      width = first_number(line).unwrap_or(width)
    }
    if line.contains("D01") {
      match parse_xy(line, unit) {
        Some((x, y)) =>
          match last {
            Some((px, py)) =>
              shapes.push(
                Segment(
                  x1=px,
                  y1=py,
                  x2=x,
                  y2=y,
                  width=width * unit.scale_to_mm(),
                ),
              )
            None => ()
          }
        None => ()
      }
    }
    if line.contains("D03") {
      match parse_xy(line, unit) {
        Some((x, y)) =>
          shapes.push(Pad(x~, y~, diameter=width * unit.scale_to_mm()))
        None => ()
      }
    }
    match parse_xy(line, unit) {
      Some(p) => last = Some(p)
      None => ()
    }
  }
  { name, kind: Copper, unit: Millimeter, shapes }
}

///|
pub fn parse_excellon(text : String, name? : String = "drill") -> Layer {
  let unit : LengthUnit = if text.contains("INCH") { Inch } else { Millimeter }
  let shapes : Array[Shape] = []
  let mut diameter = 0.8
  for raw in text.split("\n") {
    let line = raw.trim().to_owned()
    if line.contains("C") && !line.contains("M48") {
      diameter = first_number(line).unwrap_or(diameter)
    }
    match parse_xy(line, unit) {
      Some((x, y)) =>
        shapes.push(DrillHit(x~, y~, diameter=diameter * unit.scale_to_mm()))
      None => ()
    }
  }
  { name, kind: Drill, unit: Millimeter, shapes }
}

///|
pub fn parse_auto(text : String, name? : String = "input") -> Layer {
  if text.contains("M48") || text.contains("INCH") || text.contains("METRIC") {
    parse_excellon(text, name~)
  } else {
    parse_gerber(text, name~)
  }
}
