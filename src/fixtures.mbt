///|
pub enum FixtureSize {
  TinyFixture
  SmallFixture
  MediumFixture
  LargeFixture
} derive(Debug, Eq)

///|
pub fn tiny_fixture() -> FixtureSize {
  TinyFixture
}

///|
pub fn small_fixture() -> FixtureSize {
  SmallFixture
}

///|
pub fn medium_fixture() -> FixtureSize {
  MediumFixture
}

///|
pub fn large_fixture() -> FixtureSize {
  LargeFixture
}

///|
pub fn fixture_size_count(size : FixtureSize) -> Int {
  match size {
    TinyFixture => 4
    SmallFixture => 16
    MediumFixture => 64
    LargeFixture => 196
  }
}

///|
pub fn fixture_size_name(size : FixtureSize) -> String {
  match size {
    TinyFixture => "tiny"
    SmallFixture => "small"
    MediumFixture => "medium"
    LargeFixture => "large"
  }
}

///|
struct FixtureRng {
  mut state : UInt64
} derive(Debug)

///|
fn fixture_rng(seed : UInt64) -> FixtureRng {
  { state: if seed == 0 { 88172645463393265 } else { seed } }
}

///|
fn FixtureRng::next(self : FixtureRng) -> UInt64 {
  self.state = self.state * 2862933555777941757 + 3037000493
  self.state
}

///|
fn FixtureRng::unit(self : FixtureRng) -> Double {
  (self.next() % 1000000).to_double() / 1000000.0
}

///|
fn FixtureRng::between(
  self : FixtureRng,
  low : Double,
  high : Double,
) -> Double {
  low + (high - low) * self.unit()
}

///|
pub struct BoardBuilder {
  layers : Array[Layer]
} derive(Debug)

///|
pub fn board_builder() -> BoardBuilder {
  { layers: [] }
}

///|
pub fn BoardBuilder::add_layer(self : BoardBuilder, layer : Layer) -> Unit {
  self.layers.push(layer)
}

///|
pub fn BoardBuilder::add_shape(
  self : BoardBuilder,
  layer_name : String,
  shape : Shape,
) -> Unit {
  for _, layer in self.layers {
    if layer.name == layer_name {
      layer.shapes.push(shape)
      return
    }
  }
  self.layers.push({
    name: layer_name,
    kind: if layer_name.to_upper().contains("DRILL") {
      Drill
    } else {
      Copper
    },
    unit: Millimeter,
    shapes: [shape],
  })
}

///|
pub fn BoardBuilder::finish(self : BoardBuilder) -> Board {
  board_from_layers(self.layers)
}

///|
pub fn fixture_layer(name : String, kind : LayerKind) -> Layer {
  { name, kind, unit: Millimeter, shapes: [] }
}

///|
pub fn fixture_rectangle_layer(
  name : String,
  kind : LayerKind,
  width : Double,
  height : Double,
  trace_width? : Double = 0.2,
) -> Layer {
  let layer = fixture_layer(name, kind)
  let w = if trace_width <= 0.0 { 0.2 } else { trace_width }
  layer.shapes.append(
    outline_to_segments(
      outline_from_rectangle(
        rect2(min_x=0.0, min_y=0.0, max_x=width, max_y=height),
      ),
      width=w,
    )[:],
  )
  layer
}

///|
pub fn fixture_gerber(size : FixtureSize, seed? : UInt64 = 42) -> String {
  let count = fixture_size_count(size)
  let rng = fixture_rng(seed)
  let mut text = "%FSLAX24Y24*%MOMM*%ADD10C,0.20*%D10*"
  for index in 0..<count {
    let x = (index % 14).to_double() * 2.5 + 1.0
    let y = (index / 14).to_double() * 2.5 + 1.0
    let dx = rng.between(-0.7, 0.7)
    let dy = rng.between(-0.7, 0.7)
    text += "X\{(x * 100.0).to_int()}Y\{(y * 100.0).to_int()}D02*"
    text += "X\{((x + dx) * 100.0).to_int()}Y\{((y + dy) * 100.0).to_int()}D01*"
    if index % 5 == 0 {
      text += "X\{(x * 100.0).to_int()}Y\{(y * 100.0).to_int()}D03*"
    }
  }
  text + "M02*"
}

///|
pub fn fixture_excellon(size : FixtureSize) -> String {
  let count = fixture_size_count(size)
  let mut text = "M48\nMETRIC,TZ\nT1C0.8\n%\nT1\n"
  for index in 0..<count {
    let x = index % 14 * 25 + 10
    let y = index / 14 * 25 + 10
    text += "X\{x}Y\{y}\n"
  }
  text + "M30\n"
}

///|
pub fn fixture_board(size : FixtureSize, seed? : UInt64 = 42) -> Board {
  let count = fixture_size_count(size)
  let rng = fixture_rng(seed)
  let copper = fixture_layer("F.Cu", Copper)
  let drills = fixture_layer("PTH.drl", Drill)
  let outline = fixture_rectangle_layer("Edge.Cuts", Mechanical, 40.0, 40.0)
  for index in 0..<count {
    let x = (index % 14).to_double() * 2.5 + 1.0
    let y = (index / 14).to_double() * 2.5 + 1.0
    let offset = rng.between(-0.25, 0.25)
    copper.shapes.push(
      Segment(
        x1=x,
        y1=y,
        x2=x + 1.0 + offset,
        y2=y + 0.2,
        width=if index % 13 == 0 { 0.05 } else { 0.2 },
      ),
    )
    if index % 4 == 0 {
      copper.shapes.push(Pad(x=x + 1.0, y=y + 0.2, diameter=0.8))
    }
    if index % 3 == 0 {
      drills.shapes.push(
        DrillHit(
          x=x + 1.0,
          y=y + 0.2,
          diameter=if index % 17 == 0 { 0.1 } else { 0.3 },
        ),
      )
    }
  }
  board_from_layers([copper, drills, outline])
}

///|
pub fn board_translate(board : Board, offset : Point2) -> Board {
  board_from_layers(
    board.layers.map(layer => {
      name: layer.name,
      kind: layer.kind,
      unit: layer.unit,
      shapes: layer.shapes.map(shape => shape_translate(shape, offset)),
    }),
  )
}

///|
pub fn board_scale(board : Board, factor : Double) -> Board {
  board_from_layers(
    board.layers.map(layer => {
      name: layer.name,
      kind: layer.kind,
      unit: layer.unit,
      shapes: layer.shapes.map(shape => shape_scale(shape, factor)),
    }),
  )
}

///|
pub fn shape_translate(shape : Shape, offset : Point2) -> Shape {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) =>
      Segment(
        x1=x1 + offset.x,
        y1=y1 + offset.y,
        x2=x2 + offset.x,
        y2=y2 + offset.y,
        width~,
      )
    Pad(x~, y~, diameter~) => Pad(x=x + offset.x, y=y + offset.y, diameter~)
    Flash(x~, y~, aperture~) => Flash(x=x + offset.x, y=y + offset.y, aperture~)
    DrillHit(x~, y~, diameter~) =>
      DrillHit(x=x + offset.x, y=y + offset.y, diameter~)
    Region(points~) =>
      Region(points=points.map(pair => (pair.0 + offset.x, pair.1 + offset.y)))
  }
}

///|
pub fn shape_scale(shape : Shape, factor : Double) -> Shape {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) =>
      Segment(
        x1=x1 * factor,
        y1=y1 * factor,
        x2=x2 * factor,
        y2=y2 * factor,
        width=width * factor,
      )
    Pad(x~, y~, diameter~) =>
      Pad(x=x * factor, y=y * factor, diameter=diameter * factor)
    Flash(x~, y~, aperture~) => Flash(x=x * factor, y=y * factor, aperture~)
    DrillHit(x~, y~, diameter~) =>
      DrillHit(x=x * factor, y=y * factor, diameter=diameter * factor)
    Region(points~) =>
      Region(points=points.map(pair => (pair.0 * factor, pair.1 * factor)))
  }
}

///|
pub fn board_shape_count(board : Board) -> Int {
  board.layers.fold(init=0, (sum, layer) => sum + layer.shapes.length())
}

///|
pub fn board_layer_named(board : Board, name : String) -> Layer? {
  for layer in board.layers {
    if layer.name == name {
      return Some(layer)
    }
  }
  None
}

///|
pub fn board_without_empty_layers(board : Board) -> Board {
  board_from_layers(board.layers.filter(layer => layer.shapes.length() > 0))
}

///|
pub fn merge_layers(
  left : Layer,
  right : Layer,
  name? : String = left.name,
) -> Layer {
  {
    name,
    kind: left.kind,
    unit: left.unit,
    shapes: left.shapes.add(right.shapes),
  }
}

///|
pub fn board_merge(board : Board, other : Board) -> Board {
  let builder = board_builder()
  for layer in board.layers {
    builder.add_layer(layer)
  }
  for layer in other.layers {
    match board_layer_named(board, layer.name) {
      Some(_) =>
        for existing_index, existing in builder.layers {
          if existing.name == layer.name {
            builder.layers[existing_index] = merge_layers(existing, layer)
          }
        }
      None => builder.add_layer(layer)
    }
  }
  builder.finish()
}

///|
pub fn fixture_json_board(size : FixtureSize) -> String {
  report_to_json(report(fixture_board(size)), include_shapes=true)
}
