///|
pub enum ShapeClass {
  TraceShape
  PadShape
  FlashShape
  DrillShape
  RegionShape
} derive(Debug, Eq)

///|
pub struct ShapeMetrics {
  class : ShapeClass
  length : Double
  area : Double
  bounds : Rect2?
  vertices : Int
} derive(Debug)

///|
pub struct LayerMetrics {
  name : String
  kind : LayerKind
  shape_count : Int
  trace_length : Double
  copper_area : Double
  drill_area : Double
  bounds : Rect2?
  classes : Map[String, Int]
} derive(Debug)

///|
pub struct BoardMetrics {
  layers : Array[LayerMetrics]
  shape_count : Int
  total_trace_length : Double
  total_copper_area : Double
  total_drill_area : Double
  bounds : Rect2?
} derive(Debug)

///|
pub fn shape_class_name(class : ShapeClass) -> String {
  match class {
    TraceShape => "trace"
    PadShape => "pad"
    FlashShape => "flash"
    DrillShape => "drill"
    RegionShape => "region"
  }
}

///|
fn shape_metrics(shape : Shape) -> ShapeMetrics {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) => {
      let start = point2(x=x1, y=y1)
      let end = point2(x=x2, y=y2)
      {
        class: TraceShape,
        length: start.distance(end),
        area: start.distance(end) * width,
        bounds: shape_box(shape),
        vertices: 2,
      }
    }
    Pad(diameter~, ..) =>
      {
        class: PadShape,
        length: 0.0,
        area: 3.141592653589793 * (diameter / 2.0) * (diameter / 2.0),
        bounds: shape_box(shape),
        vertices: 1,
      }
    Flash(..) =>
      {
        class: FlashShape,
        length: 0.0,
        area: 0.0,
        bounds: shape_box(shape),
        vertices: 1,
      }
    DrillHit(diameter~, ..) =>
      {
        class: DrillShape,
        length: 0.0,
        area: 3.141592653589793 * (diameter / 2.0) * (diameter / 2.0),
        bounds: shape_box(shape),
        vertices: 1,
      }
    Region(points~) => {
      let converted = points.map(pair => point2(x=pair.0, y=pair.1))
      {
        class: RegionShape,
        length: polyline(converted, closed=true).length(),
        area: polyline(converted, closed=true).area(),
        bounds: shape_box(shape),
        vertices: points.length(),
      }
    }
  }
}

///|
pub fn shape_class(shape : Shape) -> ShapeClass {
  shape_metrics(shape).class
}

///|
pub fn shape_length(shape : Shape) -> Double {
  shape_metrics(shape).length
}

///|
pub fn shape_area(shape : Shape) -> Double {
  shape_metrics(shape).area
}

///|
pub fn layer_metrics(layer : Layer) -> LayerMetrics {
  let classes : Map[String, Int] = Map([])
  let mut trace_length = 0.0
  let mut copper_area = 0.0
  let mut drill_area = 0.0
  let mut bounds : Rect2? = None
  for shape in layer.shapes {
    let metrics = shape_metrics(shape)
    let class_name = shape_class_name(metrics.class)
    classes.update_or_default(class_name, 0, value => value + 1)
    trace_length += metrics.length
    if layer.kind is Drill {
      drill_area += metrics.area
    } else {
      copper_area += metrics.area
    }
    match (bounds, metrics.bounds) {
      (None, Some(value)) => bounds = Some(value)
      (Some(old), Some(value)) => bounds = Some(old.union(value))
      _ => ()
    }
  }
  {
    name: layer.name,
    kind: layer.kind,
    shape_count: layer.shapes.length(),
    trace_length,
    copper_area,
    drill_area,
    bounds,
    classes,
  }
}

///|
pub fn board_metrics(board : Board) -> BoardMetrics {
  let layers = board.layers.map(layer_metrics)
  let mut trace_length = 0.0
  let mut copper_area = 0.0
  let mut drill_area = 0.0
  let mut bounds : Rect2? = None
  for metrics in layers {
    trace_length += metrics.trace_length
    copper_area += metrics.copper_area
    drill_area += metrics.drill_area
    match (bounds, metrics.bounds) {
      (None, Some(value)) => bounds = Some(value)
      (Some(old), Some(value)) => bounds = Some(old.union(value))
      _ => ()
    }
  }
  {
    layers,
    shape_count: board_shape_count(board),
    total_trace_length: trace_length,
    total_copper_area: copper_area,
    total_drill_area: drill_area,
    bounds,
  }
}

///|
pub fn LayerMetrics::class_count(
  self : LayerMetrics,
  class : ShapeClass,
) -> Int {
  self.classes.get(shape_class_name(class)).unwrap_or(0)
}

///|
pub fn LayerMetrics::density(self : LayerMetrics) -> Double {
  match self.bounds {
    Some(bounds) if bounds.area() > 0.0 => self.copper_area / bounds.area()
    _ => 0.0
  }
}

///|
pub fn BoardMetrics::layer(self : BoardMetrics, name : String) -> LayerMetrics? {
  for layer in self.layers {
    if layer.name == name {
      return Some(layer)
    }
  }
  None
}

///|
pub fn BoardMetrics::density(self : BoardMetrics) -> Double {
  match self.bounds {
    Some(bounds) if bounds.area() > 0.0 =>
      self.total_copper_area / bounds.area()
    _ => 0.0
  }
}

///|
pub fn BoardMetrics::summary(self : BoardMetrics) -> String {
  "layers=\{self.layers.length()}, shapes=\{self.shape_count}, trace_length=\{self.total_trace_length}, copper_area=\{self.total_copper_area}, drill_area=\{self.total_drill_area}, density=\{self.density()}"
}

///|
pub fn BoardMetrics::to_json(self : BoardMetrics) -> String {
  let layers = self.layers
    .map(layer => {
      "{\"name\":\{json_string(layer.name)},\"kind\":\{json_string(kind_to_string(layer.kind))},\"shape_count\":\{layer.shape_count},\"trace_length\":\{layer.trace_length},\"copper_area\":\{layer.copper_area},\"drill_area\":\{layer.drill_area},\"density\":\{layer.density()}}"
    })
    .join(",")
  "{\"summary\":\{json_string(self.summary())},\"shape_count\":\{self.shape_count},\"layers\":[\{layers}]}"
}

///|
pub fn shape_histogram(board : Board) -> Map[String, Int] {
  let result : Map[String, Int] = Map([])
  for layer in board.layers {
    for shape in layer.shapes {
      let name = shape_class_name(shape_class(shape))
      result.update_or_default(name, 0, value => value + 1)
    }
  }
  result
}

///|
pub fn total_segment_length(board : Board) -> Double {
  board.layers.fold(init=0.0, (layer_sum, layer) => {
    layer_sum +
    layer.shapes.fold(init=0.0, (shape_sum, shape) => {
      shape_sum + shape_length(shape)
    })
  })
}

///|
pub fn total_pad_area(board : Board) -> Double {
  board.layers.fold(init=0.0, (layer_sum, layer) => {
    layer_sum +
    layer.shapes.fold(init=0.0, (shape_sum, shape) => {
      match shape {
        Pad(..) => shape_sum + shape_area(shape)
        _ => shape_sum
      }
    })
  })
}
