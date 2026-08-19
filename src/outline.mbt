///|
pub enum OutlineKind {
  OuterOutline
  InnerCutout
  OpenContour
  InvalidContour
} derive(Debug, Eq)

///|
pub struct OutlineLoop {
  points : Array[Point2]
  closed : Bool
  kind : OutlineKind
} derive(Debug)

///|
pub fn outline_loop(
  points : Array[Point2],
  closed~ : Bool,
  kind~ : OutlineKind,
) -> OutlineLoop {
  { points, closed, kind }
}

///|
pub fn OutlineLoop::perimeter(self : OutlineLoop) -> Double {
  polyline(self.points, closed=self.closed).length()
}

///|
pub fn OutlineLoop::signed_area(self : OutlineLoop) -> Double {
  polyline(self.points, closed=self.closed).signed_area()
}

///|
pub fn OutlineLoop::area(self : OutlineLoop) -> Double {
  self.signed_area().abs()
}

///|
pub fn OutlineLoop::bounds(self : OutlineLoop) -> Rect2? {
  polyline(self.points, closed=self.closed).bounds()
}

///|
pub fn OutlineLoop::contains(self : OutlineLoop, point : Point2) -> Bool {
  self.closed && polygon_contains(self.points, point)
}

///|
pub fn OutlineLoop::kind_name(self : OutlineLoop) -> String {
  match self.kind {
    OuterOutline => "outer"
    InnerCutout => "cutout"
    OpenContour => "open"
    InvalidContour => "invalid"
  }
}

///|
pub fn OutlineLoop::reversed(self : OutlineLoop) -> OutlineLoop {
  { points: self.points.rev(), closed: self.closed, kind: self.kind }
}

///|
pub struct OutlineAnalysis {
  loops : Array[OutlineLoop]
  bounds : Rect2?
  total_perimeter : Double
  outer_area : Double
  cutout_area : Double
  is_valid : Bool
  warnings : Array[String]
} derive(Debug)

///|
pub fn OutlineAnalysis::loop_count(self : OutlineAnalysis) -> Int {
  self.loops.length()
}

///|
pub fn OutlineAnalysis::summary(self : OutlineAnalysis) -> String {
  "loops=\{self.loops.length()}, perimeter=\{self.total_perimeter}, outer_area=\{self.outer_area}, cutout_area=\{self.cutout_area}, valid=\{self.is_valid}"
}

///|
fn outline_segment_endpoints(shape : Shape) -> (Point2, Point2)? {
  match shape {
    Segment(x1~, y1~, x2~, y2~, ..) =>
      Some((point2(x=x1, y=y1), point2(x=x2, y=y2)))
    _ => None
  }
}

///|
fn outline_segment_candidates(board : Board) -> Array[(Point2, Point2)] {
  let result : Array[(Point2, Point2)] = []
  for layer in board.layers {
    if layer.kind is Mechanical ||
      layer.name.to_upper().contains("OUTLINE") ||
      layer.name.to_upper().contains("EDGE") {
      for shape in layer.shapes {
        match outline_segment_endpoints(shape) {
          Some(pair) => result.push(pair)
          None =>
            match shape {
              Region(points~) => {
                let converted = points.map(pair => point2(x=pair.0, y=pair.1))
                for index in 0..<converted.length() {
                  result.push(
                    (
                      converted[index],
                      converted[(index + 1) % converted.length()],
                    ),
                  )
                }
              }
              _ => ()
            }
        }
      }
    }
  }
  result
}

///|
fn outline_take_next(
  remaining : Array[(Point2, Point2)],
  end : Point2,
  epsilon : Double,
) -> (Int, Point2)? {
  for index, pair in remaining {
    if pair.0.near(end, epsilon~) {
      return Some((index, pair.1))
    } else if pair.1.near(end, epsilon~) {
      return Some((index, pair.0))
    }
  }
  None
}

///|
fn outline_build_loops(
  segments : Array[(Point2, Point2)],
  epsilon : Double,
) -> Array[OutlineLoop] {
  let remaining = segments.copy()
  let loops : Array[OutlineLoop] = []
  while remaining.length() > 0 {
    let first = remaining.pop().unwrap()
    let points : Array[Point2] = [first.0, first.1]
    let mut closed = false
    let mut searching = true
    while searching {
      match outline_take_next(remaining, points[points.length() - 1], epsilon) {
        Some((index, next)) => {
          ignore(remaining.remove(index))
          if next.near(points[0], epsilon~) {
            closed = true
            searching = false
          } else {
            points.push(next)
          }
        }
        None => searching = false
      }
    }
    let kind = if !closed {
      OpenContour
    } else if points.length() < 3 || polygon_self_intersects(points) {
      InvalidContour
    } else {
      OuterOutline
    }
    loops.push(outline_loop(points, closed~, kind~))
  }
  loops
}

///|
fn outline_classify(loops : Array[OutlineLoop]) -> Unit {
  let mut outer_seen = false
  for index, contour in loops {
    if contour.closed && contour.kind is OuterOutline {
      if !outer_seen {
        outer_seen = true
      } else {
        loops[index] = {
          points: contour.points,
          closed: contour.closed,
          kind: InnerCutout,
        }
      }
    }
  }
}

///|
/// Extract manufacturing outline contours from mechanical layers and regions.
pub fn analyze_outline(
  board : Board,
  tolerance? : Double = 0.001,
) -> OutlineAnalysis {
  let loops = outline_build_loops(outline_segment_candidates(board), tolerance)
  outline_classify(loops)
  let mut bounds : Rect2? = None
  let mut total_perimeter = 0.0
  let mut outer_area = 0.0
  let mut cutout_area = 0.0
  let mut valid = loops.length() > 0
  let warnings : Array[String] = []
  for contour in loops {
    total_perimeter += contour.perimeter()
    if contour.kind is InvalidContour {
      valid = false
      warnings.push("outline contour is self-intersecting or too short")
    } else if contour.kind is OpenContour {
      valid = false
      warnings.push("outline contour is open")
    } else if contour.kind is OuterOutline {
      outer_area += contour.area()
    } else if contour.kind is InnerCutout {
      cutout_area += contour.area()
    }
    match (bounds, contour.bounds()) {
      (None, Some(value)) => bounds = Some(value)
      (Some(old), Some(value)) => bounds = Some(old.union(value))
      _ => ()
    }
  }
  if loops.length() == 0 {
    warnings.push("no mechanical outline segments or regions were found")
  }
  {
    loops,
    bounds,
    total_perimeter,
    outer_area,
    cutout_area,
    is_valid: valid,
    warnings,
  }
}

///|
pub fn outline_from_rectangle(bounds : Rect2) -> OutlineLoop {
  outline_loop(
    [
      point2(x=bounds.min_x, y=bounds.min_y),
      point2(x=bounds.max_x, y=bounds.min_y),
      point2(x=bounds.max_x, y=bounds.max_y),
      point2(x=bounds.min_x, y=bounds.max_y),
    ],
    closed=true,
    kind=OuterOutline,
  )
}

///|
pub fn outline_to_region(contour : OutlineLoop) -> Shape {
  Region(points=contour.points.map(point => (point.x, point.y)))
}

///|
pub fn outline_to_segments(
  contour : OutlineLoop,
  width? : Double = 0.1,
) -> Array[Shape] {
  let result : Array[Shape] = []
  if contour.points.length() >= 2 {
    for index in 1..<contour.points.length() {
      let a = contour.points[index - 1]
      let b = contour.points[index]
      result.push(Segment(x1=a.x, y1=a.y, x2=b.x, y2=b.y, width~))
    }
    if contour.closed {
      let a = contour.points[contour.points.length() - 1]
      let b = contour.points[0]
      result.push(Segment(x1=a.x, y1=a.y, x2=b.x, y2=b.y, width~))
    }
  }
  result
}

///|
pub fn OutlineAnalysis::largest_outer(self : OutlineAnalysis) -> OutlineLoop? {
  let mut result : OutlineLoop? = None
  let mut area = 0.0
  for contour in self.loops {
    if contour.kind is OuterOutline && contour.area() > area {
      result = Some(contour)
      area = contour.area()
    }
  }
  result
}

///|
pub fn OutlineAnalysis::cutouts(self : OutlineAnalysis) -> Array[OutlineLoop] {
  self.loops.filter(contour => contour.kind is InnerCutout)
}

///|
pub fn OutlineAnalysis::open_contours(
  self : OutlineAnalysis,
) -> Array[OutlineLoop] {
  self.loops.filter(contour => contour.kind is OpenContour)
}

///|
pub fn OutlineAnalysis::invalid_contours(
  self : OutlineAnalysis,
) -> Array[OutlineLoop] {
  self.loops.filter(contour => contour.kind is InvalidContour)
}

///|
pub fn OutlineAnalysis::area_with_cutouts(self : OutlineAnalysis) -> Double {
  self.outer_area - self.cutout_area
}

///|
pub fn OutlineAnalysis::contains(
  self : OutlineAnalysis,
  point : Point2,
) -> Bool {
  match self.largest_outer() {
    Some(contour) =>
      if contour.contains(point) {
        self.cutouts().all(cutout => !cutout.contains(point))
      } else {
        false
      }
    None => false
  }
}

///|
pub fn OutlineAnalysis::to_json(self : OutlineAnalysis) -> String {
  let loops = self.loops
    .map(contour => {
      let points = contour.points
        .map(point => "[\{point.x},\{point.y}]")
        .join(",")
      "{\"kind\":\{json_string(contour.kind_name())},\"closed\":\{contour.closed},\"area\":\{contour.area()},\"points\":[\{points}]}"
    })
    .join(",")
  "{\"summary\":\{json_string(self.summary())},\"valid\":\{self.is_valid},\"loops\":[\{loops}],\"warnings\":[\{self.warnings.map(json_string).join(",")}]}"
}
