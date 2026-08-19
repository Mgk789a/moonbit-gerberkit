///|
fn parse_decimal(view : StringView) -> Double? {
  let mut sign = 1.0
  let mut value = 0.0
  let mut fraction = 0.0
  let mut fraction_scale = 0.1
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
        fraction += digit * fraction_scale
        fraction_scale *= 0.1
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
pub fn parse_gerber(text : String, name? : String = "gerber") -> Layer {
  parse_gerber_document(text, name~).layer
}

///|
pub fn parse_excellon(text : String, name? : String = "drill") -> Layer {
  parse_excellon_document(text, name~).layer
}

///|
pub fn parse_auto(text : String, name? : String = "input") -> Layer {
  if text.contains("M48") || text.contains("INCH") || text.contains("METRIC") {
    parse_excellon(text, name~)
  } else {
    parse_gerber(text, name~)
  }
}
