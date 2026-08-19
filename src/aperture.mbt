///|
/// The aperture geometry used by Gerber draw and flash operations.
pub enum ApertureKind {
  CircleAperture(diameter~ : Double)
  RectangleAperture(width~ : Double, height~ : Double)
  ObroundAperture(width~ : Double, height~ : Double)
  PolygonAperture(diameter~ : Double, vertices~ : Int, rotation~ : Double)
  MacroAperture(name~ : String, modifiers~ : Array[Double])
  UnknownAperture(raw~ : String)
} derive(Debug)

///|
pub struct Aperture {
  code : Int
  kind : ApertureKind
  hole : Double?
} derive(Debug)

///|
pub fn aperture(code~ : Int, kind~ : ApertureKind, hole? : Double) -> Aperture {
  { code, kind, hole }
}

///|
pub fn Aperture::is_known(self : Aperture) -> Bool {
  match self.kind {
    UnknownAperture(..) => false
    _ => true
  }
}

///|
pub fn Aperture::outer_width(self : Aperture) -> Double {
  match self.kind {
    CircleAperture(diameter~) => diameter
    RectangleAperture(width~, height=_) => width
    ObroundAperture(width~, height=_) => width
    PolygonAperture(diameter~, ..) => diameter
    MacroAperture(..) | UnknownAperture(..) => 0.0
  }
}

///|
pub fn Aperture::outer_height(self : Aperture) -> Double {
  match self.kind {
    CircleAperture(diameter~) => diameter
    RectangleAperture(width=_, height~) => height
    ObroundAperture(width=_, height~) => height
    PolygonAperture(diameter~, ..) => diameter
    MacroAperture(..) | UnknownAperture(..) => 0.0
  }
}

///|
pub fn Aperture::radius(self : Aperture) -> Double {
  min(self.outer_width(), self.outer_height()) / 2.0
}

///|
pub fn Aperture::area(self : Aperture) -> Double {
  let hole_area = match self.hole {
    Some(d) => 3.141592653589793 * (d / 2.0) * (d / 2.0)
    None => 0.0
  }
  let area = match self.kind {
    CircleAperture(diameter~) =>
      3.141592653589793 * (diameter / 2.0) * (diameter / 2.0)
    RectangleAperture(width~, height~) => width * height
    ObroundAperture(width~, height~) => {
      let radius = min(width, height) / 2.0
      let straight = max(width, height) - 2.0 * radius
      3.141592653589793 * radius * radius + 2.0 * radius * straight
    }
    PolygonAperture(diameter~, vertices~, ..) =>
      if vertices < 3 {
        0.0
      } else {
        let r = diameter / 2.0
        vertices.to_double() *
        r *
        r *
        polygon_sine(2.0 * 3.141592653589793 / vertices.to_double()) /
        2.0
      }
    MacroAperture(..) | UnknownAperture(..) => 0.0
  }
  max(0.0, area - hole_area)
}

///|
pub fn Aperture::bounds(self : Aperture, center : Point2) -> Rect2 {
  rect2(
    min_x=center.x - self.outer_width() / 2.0,
    min_y=center.y - self.outer_height() / 2.0,
    max_x=center.x + self.outer_width() / 2.0,
    max_y=center.y + self.outer_height() / 2.0,
  )
}

///|
pub fn Aperture::to_shape(self : Aperture, center : Point2) -> Shape {
  match self.kind {
    CircleAperture(diameter~) => Pad(x=center.x, y=center.y, diameter~)
    RectangleAperture(..)
    | ObroundAperture(..)
    | PolygonAperture(..)
    | MacroAperture(..)
    | UnknownAperture(..) => Flash(x=center.x, y=center.y, aperture=self.code)
  }
}

///|
pub struct ApertureTable {
  apertures : Array[Aperture]
  macros : Array[ApertureMacro]
} derive(Debug)

///|
pub fn new_aperture_table() -> ApertureTable {
  { apertures: [], macros: [] }
}

///|
pub fn ApertureTable::clear(self : ApertureTable) -> Unit {
  self.apertures.clear()
  self.macros.clear()
}

///|
pub fn ApertureTable::add_or_replace(
  self : ApertureTable,
  value : Aperture,
) -> Unit {
  let mut replaced = false
  for i, old in self.apertures {
    if old.code == value.code {
      self.apertures[i] = value
      replaced = true
    }
  }
  if !replaced {
    self.apertures.push(value)
  }
}

///|
pub fn ApertureTable::get(self : ApertureTable, code : Int) -> Aperture? {
  for aperture in self.apertures {
    if aperture.code == code {
      return Some(aperture)
    }
  }
  None
}

///|
pub fn ApertureTable::require(self : ApertureTable, code : Int) -> Aperture {
  self.get(code).unwrap_or(aperture(code~, kind=UnknownAperture(raw="D{code}")))
}

///|
pub fn ApertureTable::count(self : ApertureTable) -> Int {
  self.apertures.length()
}

///|
pub enum MacroPrimitive {
  MacroCircle(exposure~ : Int, diameter~ : Double, x~ : Double, y~ : Double)
  MacroVector(
    exposure~ : Int,
    width~ : Double,
    x1~ : Double,
    y1~ : Double,
    x2~ : Double,
    y2~ : Double
  )
  MacroCenterLine(
    exposure~ : Int,
    width~ : Double,
    height~ : Double,
    x~ : Double,
    y~ : Double
  )
  MacroOutline(exposure~ : Int, points~ : Array[Point2])
  MacroPolygon(
    exposure~ : Int,
    vertices~ : Int,
    diameter~ : Double,
    rotation~ : Double,
    x~ : Double,
    y~ : Double
  )
  MacroComment(text~ : String)
  MacroUnknown(raw~ : String)
} derive(Debug)

///|
pub struct ApertureMacro {
  name : String
  primitives : Array[MacroPrimitive]
} derive(Debug)

///|
pub fn aperture_macro(
  name~ : String,
  primitives~ : Array[MacroPrimitive],
) -> ApertureMacro {
  { name, primitives }
}

///|
pub fn ApertureMacro::primitive_count(self : ApertureMacro) -> Int {
  self.primitives.length()
}

///|
pub fn ApertureMacro::bounds(self : ApertureMacro) -> Rect2? {
  let mut result : Rect2? = None
  for primitive in self.primitives {
    let candidate : Rect2? = match primitive {
      MacroCircle(diameter~, x~, y~, ..) =>
        Some(
          rect2(
            min_x=x - diameter / 2.0,
            min_y=y - diameter / 2.0,
            max_x=x + diameter / 2.0,
            max_y=y + diameter / 2.0,
          ),
        )
      MacroVector(width~, x1~, y1~, x2~, y2~, ..) => {
        let r = width / 2.0
        Some(
          rect2(
            min_x=min(x1, x2) - r,
            min_y=min(y1, y2) - r,
            max_x=max(x1, x2) + r,
            max_y=max(y1, y2) + r,
          ),
        )
      }
      MacroCenterLine(width~, height~, x~, y~, ..) =>
        Some(
          rect2(
            min_x=x - width / 2.0,
            min_y=y - height / 2.0,
            max_x=x + width / 2.0,
            max_y=y + height / 2.0,
          ),
        )
      MacroOutline(points~, ..) => polyline(points, closed=true).bounds()
      MacroPolygon(diameter~, x~, y~, ..) =>
        Some(
          rect2(
            min_x=x - diameter / 2.0,
            min_y=y - diameter / 2.0,
            max_x=x + diameter / 2.0,
            max_y=y + diameter / 2.0,
          ),
        )
      MacroComment(..) | MacroUnknown(..) => None
    }
    match (result, candidate) {
      (None, Some(next)) => result = Some(next)
      (Some(old), Some(next)) => result = Some(old.union(next))
      _ => ()
    }
  }
  result
}

///|
fn aperture_number(text : StringView, index : Int) -> Double {
  match text.split(",").to_array().get(index) {
    Some(value) => parse_decimal(value).unwrap_or(0.0)
    None => 0.0
  }
}

///|
fn aperture_int(text : StringView, index : Int, fallback : Int) -> Int {
  match text.split(",").to_array().get(index) {
    Some(value) => parse_decimal(value).map(v => v.to_int()).unwrap_or(fallback)
    None => fallback
  }
}

///|
pub fn parse_aperture_definition(code : Int, definition : String) -> Aperture {
  let body = definition.trim().to_owned()
  if body.has_prefix("C,") {
    let rest = body[2:].to_owned()
    if rest.contains("X") {
      aperture(
        code~,
        kind=CircleAperture(diameter=aperture_number(rest[:], 0)),
        hole=aperture_number(rest.replace(old="X", new=",")[:], 1),
      )
    } else {
      aperture(code~, kind=CircleAperture(diameter=aperture_number(rest[:], 0)))
    }
  } else if body.has_prefix("R,") {
    let rest = body[2:]
    aperture(
      code~,
      kind=RectangleAperture(
        width=aperture_number(rest, 0),
        height=if rest.contains("X") {
          aperture_number(rest.replace(old="X", new=",")[:], 1)
        } else {
          aperture_number(rest, 0)
        },
      ),
    )
  } else if body.has_prefix("O,") {
    let rest = body[2:]
    let normalized = rest.replace(old="X", new=",")
    aperture(
      code~,
      kind=ObroundAperture(
        width=aperture_number(normalized[:], 0),
        height=aperture_number(normalized[:], 1),
      ),
    )
  } else if body.has_prefix("P,") {
    let rest = body[2:]
    let normalized = rest.replace(old="X", new=",")
    aperture(
      code~,
      kind=PolygonAperture(
        diameter=aperture_number(normalized[:], 0),
        vertices=aperture_int(normalized[:], 1, 3),
        rotation=aperture_number(normalized[:], 2),
      ),
    )
  } else {
    let name = match body.find(",") {
      Some(i) => body[:i].to_owned()
      None => body
    }
    let rest = match body.find(",") {
      Some(i) => body[i + 1:]
      None => ""
    }
    let modifiers = rest
      .replace(old="X", new=",")
      .split(",")
      .to_array()
      .filter_map(value => parse_decimal(value))
    aperture(code~, kind=MacroAperture(name~, modifiers~))
  }
}

///|
pub fn aperture_kind_name(kind : ApertureKind) -> String {
  match kind {
    CircleAperture(..) => "circle"
    RectangleAperture(..) => "rectangle"
    ObroundAperture(..) => "obround"
    PolygonAperture(..) => "polygon"
    MacroAperture(..) => "macro"
    UnknownAperture(..) => "unknown"
  }
}

///|
pub fn parse_macro_primitive(text : String) -> MacroPrimitive {
  let value = text.trim().to_owned()
  if value == "" {
    MacroComment(text="")
  } else if value[0:1] == "0" {
    MacroComment(text=value)
  } else if value.has_prefix("1,") {
    MacroCircle(
      exposure=aperture_int(value[:], 1, 1),
      diameter=aperture_number(value[:], 2),
      x=aperture_number(value[:], 3),
      y=aperture_number(value[:], 4),
    )
  } else if value.has_prefix("20,") {
    MacroVector(
      exposure=aperture_int(value[:], 1, 1),
      width=aperture_number(value[:], 2),
      x1=aperture_number(value[:], 3),
      y1=aperture_number(value[:], 4),
      x2=aperture_number(value[:], 5),
      y2=aperture_number(value[:], 6),
    )
  } else if value.has_prefix("21,") {
    MacroCenterLine(
      exposure=aperture_int(value[:], 1, 1),
      width=aperture_number(value[:], 2),
      height=aperture_number(value[:], 3),
      x=aperture_number(value[:], 4),
      y=aperture_number(value[:], 5),
    )
  } else if value.has_prefix("4,") {
    let vertices = aperture_int(value[:], 2, 0)
    let points : Array[Point2] = []
    for i in 0..<vertices {
      points.push(
        point2(
          x=aperture_number(value[:], 3 + i * 2),
          y=aperture_number(value[:], 4 + i * 2),
        ),
      )
    }
    MacroOutline(exposure=aperture_int(value[:], 1, 1), points~)
  } else if value.has_prefix("5,") {
    MacroPolygon(
      exposure=aperture_int(value[:], 1, 1),
      vertices=aperture_int(value[:], 2, 3),
      diameter=aperture_number(value[:], 3),
      rotation=aperture_number(value[:], 4),
      x=aperture_number(value[:], 5),
      y=aperture_number(value[:], 6),
    )
  } else {
    MacroUnknown(raw=value)
  }
}

///|
fn polygon_sine(value : Double) -> Double {
  let x = value
  let x2 = x * x
  x - x * x2 / 6.0 + x * x2 * x2 / 120.0 - x * x2 * x2 * x2 / 5040.0
}
