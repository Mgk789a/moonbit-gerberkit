///|
/// Deterministic polygon and segment algorithms used by DFM, inspection, and
/// toolpath planning. All routines are tolerance-aware and keep caller data
/// immutable from the API point of view.
pub enum GeometryBoundary {
  BoundaryOutside
  BoundaryInside
  BoundaryOn
} derive(Debug, Eq)

///|
pub enum SegmentIntersectionKind {
  NoIntersection
  ProperIntersection
  EndpointIntersection
  CollinearOverlap
} derive(Debug, Eq)

///|
pub struct SegmentIntersection {
  kind : SegmentIntersectionKind
  point : Point2?
  overlap_start : Point2?
  overlap_end : Point2?
  parameter_a : Double?
  parameter_b : Double?
} derive(Debug)

///|
pub struct Ring2 {
  points : Array[Point2]
  closed : Bool
} derive(Debug)

///|
pub struct Polygon2 {
  outer : Ring2
  holes : Array[Ring2]
} derive(Debug)

///|
pub struct GeometryTolerance {
  distance : Double
  angle : Double
  area : Double
} derive(Debug)

///|
pub struct PolygonMeasure {
  area : Double
  signed_area : Double
  perimeter : Double
  centroid : Point2?
  bounds : Rect2?
  vertices : Int
  holes : Int
} derive(Debug)

///|
pub struct RasterCell {
  row : Int
  column : Int
  center : Point2
  covered : Bool
  coverage : Double
} derive(Debug)

///|
pub struct ScanlineSpan {
  y : Double
  start_x : Double
  end_x : Double
  winding : Int
} derive(Debug)

///|
pub fn geometry_boundary_name(value : GeometryBoundary) -> String {
  match value {
    BoundaryOutside => "outside"
    BoundaryInside => "inside"
    BoundaryOn => "boundary"
  }
}

///|
pub fn intersection_kind_name(value : SegmentIntersectionKind) -> String {
  match value {
    NoIntersection => "none"
    ProperIntersection => "proper"
    EndpointIntersection => "endpoint"
    CollinearOverlap => "collinear-overlap"
  }
}

///|
pub fn geometry_tolerance(
  distance? : Double = 0.000001,
  angle? : Double = 0.000001,
  area? : Double = 0.000000001,
) -> GeometryTolerance {
  {
    distance: if distance < 0.0 {
      -distance
    } else {
      distance
    },
    angle: if angle < 0.0 {
      -angle
    } else {
      angle
    },
    area: if area < 0.0 {
      -area
    } else {
      area
    },
  }
}

///|
pub fn ring2(points~ : Array[Point2], closed? : Bool = true) -> Ring2 {
  { points: points.copy(), closed }
}

///|
pub fn polygon2(outer~ : Ring2, holes? : Array[Ring2] = []) -> Polygon2 {
  { outer, holes: holes.copy() }
}

///|
pub fn Ring2::points(self : Ring2) -> Array[Point2] {
  self.points.copy()
}

///|
pub fn Ring2::point_count(self : Ring2) -> Int {
  self.points.length()
}

///|
pub fn Ring2::is_closed(self : Ring2) -> Bool {
  self.closed
}

///|
pub fn Ring2::is_empty(self : Ring2) -> Bool {
  self.points.length() == 0
}

///|
pub fn Ring2::first(self : Ring2) -> Point2? {
  self.points.get(0)
}

///|
pub fn Ring2::last(self : Ring2) -> Point2? {
  if self.points.length() == 0 {
    None
  } else {
    Some(self.points[self.points.length() - 1])
  }
}

///|
pub fn Ring2::at(self : Ring2, index : Int) -> Point2? {
  self.points.get(index)
}

///|
pub fn Ring2::closed_points(self : Ring2) -> Array[Point2] {
  let result = self.points.copy()
  if self.closed &&
    result.length() > 1 &&
    !result[0].near(result[result.length() - 1]) {
    result.push(result[0])
  }
  result
}

///|
pub fn Ring2::signed_area(self : Ring2) -> Double {
  let points = self.closed_points()
  if points.length() < 3 {
    return 0.0
  }
  let mut sum = 0.0
  for index in 0..<(points.length() - 1) {
    sum += points[index].cross(points[index + 1])
  }
  sum / 2.0
}

///|
pub fn Ring2::area(self : Ring2) -> Double {
  self.signed_area().abs()
}

///|
pub fn Ring2::clockwise(self : Ring2) -> Bool {
  self.signed_area() < 0.0
}

///|
pub fn Ring2::counter_clockwise(self : Ring2) -> Bool {
  self.signed_area() > 0.0
}

///|
pub fn Ring2::perimeter(self : Ring2) -> Double {
  let points = self.closed_points()
  if points.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  for index in 0..<(points.length() - 1) {
    total += points[index].distance(points[index + 1])
  }
  if !self.closed && points.length() > 1 {
    total -= points[0].distance(points[points.length() - 1])
  }
  total
}

///|
pub fn Ring2::bounds(self : Ring2) -> Rect2? {
  match self.points.get(0) {
    None => None
    Some(first) => {
      let initial = rect2(
        min_x=first.x,
        min_y=first.y,
        max_x=first.x,
        max_y=first.y,
      )
      Some(
        self.points.fold(init=initial, (bounds, point) => {
          bounds.include_point(point)
        }),
      )
    }
  }
}

///|
pub fn Ring2::centroid(self : Ring2) -> Point2? {
  let points = self.closed_points()
  if points.length() < 3 {
    return None
  }
  let mut cross_sum = 0.0
  let mut x_sum = 0.0
  let mut y_sum = 0.0
  for index in 0..<(points.length() - 1) {
    let left = points[index]
    let right = points[index + 1]
    let cross = left.cross(right)
    cross_sum += cross
    x_sum += (left.x + right.x) * cross
    y_sum += (left.y + right.y) * cross
  }
  if cross_sum.abs() <= 0.000000000001 {
    None
  } else {
    Some(point2(x=x_sum / (3.0 * cross_sum), y=y_sum / (3.0 * cross_sum)))
  }
}

///|
pub fn Ring2::reversed(self : Ring2) -> Ring2 {
  ring2(points=self.points.rev(), closed=self.closed)
}

///|
pub fn Ring2::oriented(self : Ring2, clockwise : Bool) -> Ring2 {
  if self.clockwise() == clockwise {
    self
  } else {
    self.reversed()
  }
}

///|
pub fn Ring2::translated(self : Ring2, offset : Point2) -> Ring2 {
  ring2(points=self.points.map(point => point.add(offset)), closed=self.closed)
}

///|
pub fn Ring2::scaled(
  self : Ring2,
  factor : Double,
  origin? : Point2 = point2(x=0.0, y=0.0),
) -> Ring2 {
  ring2(
    points=self.points.map(point => origin.add(point.sub(origin).scale(factor))),
    closed=self.closed,
  )
}

///|
pub fn Ring2::deduplicated(
  self : Ring2,
  tolerance? : Double = 0.000001,
) -> Ring2 {
  let result : Array[Point2] = []
  for point in self.points {
    match result.last() {
      Some(previous) if previous.near(point, epsilon=tolerance) => ()
      _ => result.push(point)
    }
  }
  if result.length() > 1 &&
    self.closed &&
    result[0].near(result[result.length() - 1], epsilon=tolerance) {
    ignore(result.pop())
  }
  ring2(points=result, closed=self.closed)
}

///|
pub fn Ring2::simplified(self : Ring2, tolerance? : Double = 0.000001) -> Ring2 {
  let clean = self.deduplicated(tolerance~)
  if clean.points.length() < 3 {
    return clean
  }
  let result : Array[Point2] = []
  let count = clean.points.length()
  for index in 0..<count {
    let previous = clean.points[(index + count - 1) % count]
    let current = clean.points[index]
    let next = clean.points[(index + 1) % count]
    let first = current.sub(previous)
    let second = next.sub(current)
    if first.length() > tolerance &&
      second.length() > tolerance &&
      first.cross(second).abs() <=
      tolerance * (first.length() + second.length()) {
      ()
    } else {
      result.push(current)
    }
  }
  ring2(points=result, closed=clean.closed)
}

///|
pub fn Polygon2::outer_ring(self : Polygon2) -> Ring2 {
  self.outer
}

///|
pub fn Polygon2::hole_count(self : Polygon2) -> Int {
  self.holes.length()
}

///|
pub fn Polygon2::holes(self : Polygon2) -> Array[Ring2] {
  self.holes.copy()
}

///|
pub fn Polygon2::area(self : Polygon2) -> Double {
  let hole_area = self.holes.fold(init=0.0, (sum, hole) => sum + hole.area())
  let value = self.outer.area() - hole_area
  if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
pub fn Polygon2::perimeter(self : Polygon2) -> Double {
  self.outer.perimeter() +
  self.holes.fold(init=0.0, (sum, hole) => sum + hole.perimeter())
}

///|
pub fn Polygon2::bounds(self : Polygon2) -> Rect2? {
  self.outer.bounds()
}

///|
pub fn Polygon2::measure(self : Polygon2) -> PolygonMeasure {
  {
    area: self.area(),
    signed_area: self.outer.signed_area(),
    perimeter: self.perimeter(),
    centroid: self.outer.centroid(),
    bounds: self.bounds(),
    vertices: self.outer.point_count(),
    holes: self.holes.length(),
  }
}

///|
fn gk_cross(a : Point2, b : Point2, c : Point2) -> Double {
  b.sub(a).cross(c.sub(a))
}

///|
fn gk_clamp(value : Double, low : Double, high : Double) -> Double {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn gk_between(
  value : Double,
  low : Double,
  high : Double,
  epsilon : Double,
) -> Bool {
  value >= low - epsilon && value <= high + epsilon
}

///|
pub fn classify_point_on_segment(
  point : Point2,
  start : Point2,
  end : Point2,
  tolerance? : Double = 0.000001,
) -> GeometryBoundary {
  let vector = end.sub(start)
  let length = vector.length()
  if length <= tolerance {
    if point.distance(start) <= tolerance {
      BoundaryOn
    } else {
      BoundaryOutside
    }
  } else if gk_cross(start, end, point).abs() > tolerance * length {
    BoundaryOutside
  } else if gk_between(
      point.x,
      if start.x < end.x {
        start.x
      } else {
        end.x
      },
      if start.x > end.x {
        start.x
      } else {
        end.x
      },
      tolerance,
    ) &&
    gk_between(
      point.y,
      if start.y < end.y {
        start.y
      } else {
        end.y
      },
      if start.y > end.y {
        start.y
      } else {
        end.y
      },
      tolerance,
    ) {
    BoundaryOn
  } else {
    BoundaryOutside
  }
}

///|
pub fn segment_intersection(
  a_start : Point2,
  a_end : Point2,
  b_start : Point2,
  b_end : Point2,
  tolerance? : Double = 0.000001,
) -> SegmentIntersection {
  let r = a_end.sub(a_start)
  let s = b_end.sub(b_start)
  let denominator = r.cross(s)
  let difference = b_start.sub(a_start)
  if denominator.abs() <= tolerance {
    if difference.cross(r).abs() > tolerance {
      return {
        kind: NoIntersection,
        point: None,
        overlap_start: None,
        overlap_end: None,
        parameter_a: None,
        parameter_b: None,
      }
    }
    let rr = r.dot(r)
    if rr <= tolerance * tolerance {
      if a_start.distance(b_start) <= tolerance {
        return {
          kind: EndpointIntersection,
          point: Some(a_start),
          overlap_start: None,
          overlap_end: None,
          parameter_a: Some(0.0),
          parameter_b: Some(0.0),
        }
      }
      return {
        kind: NoIntersection,
        point: None,
        overlap_start: None,
        overlap_end: None,
        parameter_a: None,
        parameter_b: None,
      }
    }
    let t0 = difference.dot(r) / rr
    let t1 = b_end.sub(a_start).dot(r) / rr
    let low = if t0 < t1 { t0 } else { t1 }
    let high = if t0 > t1 { t0 } else { t1 }
    let overlap_low = if low > 0.0 { low } else { 0.0 }
    let overlap_high = if high < 1.0 { high } else { 1.0 }
    if overlap_low > overlap_high + tolerance {
      {
        kind: NoIntersection,
        point: None,
        overlap_start: None,
        overlap_end: None,
        parameter_a: None,
        parameter_b: None,
      }
    } else if (overlap_high - overlap_low).abs() <= tolerance {
      let point = a_start.add(r.scale(overlap_low))
      {
        kind: EndpointIntersection,
        point: Some(point),
        overlap_start: None,
        overlap_end: None,
        parameter_a: Some(overlap_low),
        parameter_b: None,
      }
    } else {
      {
        kind: CollinearOverlap,
        point: None,
        overlap_start: Some(a_start.add(r.scale(overlap_low))),
        overlap_end: Some(a_start.add(r.scale(overlap_high))),
        parameter_a: Some(overlap_low),
        parameter_b: Some(overlap_high),
      }
    }
  } else {
    let t = difference.cross(s) / denominator
    let u = difference.cross(r) / denominator
    if t < -tolerance ||
      t > 1.0 + tolerance ||
      u < -tolerance ||
      u > 1.0 + tolerance {
      {
        kind: NoIntersection,
        point: None,
        overlap_start: None,
        overlap_end: None,
        parameter_a: None,
        parameter_b: None,
      }
    } else {
      let point = a_start.add(r.scale(t))
      let endpoint = t <= tolerance ||
        t >= 1.0 - tolerance ||
        u <= tolerance ||
        u >= 1.0 - tolerance
      {
        kind: if endpoint {
          EndpointIntersection
        } else {
          ProperIntersection
        },
        point: Some(point),
        overlap_start: None,
        overlap_end: None,
        parameter_a: Some(t),
        parameter_b: Some(u),
      }
    }
  }
}

///|
pub fn gk_segment_distance(
  point : Point2,
  start : Point2,
  end : Point2,
) -> Double {
  let vector = end.sub(start)
  let length_squared = vector.length_squared()
  if length_squared <= 0.000000000001 {
    point.distance(start)
  } else {
    let t = gk_clamp(point.sub(start).dot(vector) / length_squared, 0.0, 1.0)
    point.distance(start.add(vector.scale(t)))
  }
}

///|
pub fn point_in_ring(
  point : Point2,
  ring : Ring2,
  tolerance? : Double = 0.000001,
) -> GeometryBoundary {
  let points = ring.closed_points()
  if points.length() < 3 {
    return BoundaryOutside
  }
  for index in 0..<(points.length() - 1) {
    if classify_point_on_segment(
        point,
        points[index],
        points[index + 1],
        tolerance~,
      )
      is BoundaryOn {
      return BoundaryOn
    }
  }
  let mut inside = false
  for index in 0..<(points.length() - 1) {
    let a = points[index]
    let b = points[index + 1]
    if (a.y > point.y) != (b.y > point.y) {
      let x_at_y = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
      if point.x < x_at_y {
        inside = !inside
      }
    }
  }
  if inside {
    BoundaryInside
  } else {
    BoundaryOutside
  }
}

///|
pub fn point_in_polygon(
  point : Point2,
  polygon : Polygon2,
  tolerance? : Double = 0.000001,
) -> GeometryBoundary {
  let outer = point_in_ring(point, polygon.outer, tolerance~)
  if outer is BoundaryOutside {
    return BoundaryOutside
  }
  if outer is BoundaryOn {
    return BoundaryOn
  }
  for hole in polygon.holes {
    let state = point_in_ring(point, hole, tolerance~)
    if state is BoundaryOn {
      return BoundaryOn
    }
    if state is BoundaryInside {
      return BoundaryOutside
    }
  }
  BoundaryInside
}

///|
pub fn polygon_contains_point(point : Point2, polygon : Polygon2) -> Bool {
  point_in_polygon(point, polygon) is BoundaryInside
}

///|
pub fn ring_offset(
  ring : Ring2,
  distance : Double,
  tolerance? : Double = 0.000001,
) -> Ring2 {
  let points = ring.points
  let count = points.length()
  if count < 3 || distance.abs() <= tolerance {
    return ring
  }
  let orientation = if ring.signed_area() >= 0.0 { 1.0 } else { -1.0 }
  let result : Array[Point2] = []
  for index in 0..<count {
    let previous = points[(index + count - 1) % count]
    let current = points[index]
    let next = points[(index + 1) % count]
    let first = current.sub(previous)
    let second = next.sub(current)
    let first_length = first.length()
    let second_length = second.length()
    if first_length <= tolerance || second_length <= tolerance {
      result.push(current)
    } else {
      let first_normal = point2(
        x=orientation * first.y / first_length,
        y=orientation * -first.x / first_length,
      )
      let second_normal = point2(
        x=orientation * second.y / second_length,
        y=orientation * -second.x / second_length,
      )
      let normal = first_normal.add(second_normal)
      let normal_length = normal.length()
      let safe_normal = if normal_length <= tolerance {
        first_normal
      } else {
        normal.scale(1.0 / normal_length)
      }
      let denominator = safe_normal.dot(first_normal)
      let scale = if denominator.abs() <= tolerance {
        distance
      } else {
        distance / denominator
      }
      result.push(current.add(safe_normal.scale(scale)))
    }
  }
  ring2(points=result, closed=ring.closed)
}

///|
pub fn ring_inset(ring : Ring2, distance : Double) -> Ring2 {
  ring_offset(ring, -distance)
}

///|
pub fn ring_bounding_box(ring : Ring2) -> Rect2? {
  ring.bounds()
}

///|
pub fn rect_to_ring(value : Rect2) -> Ring2 {
  ring2(points=[
    point2(x=value.min_x, y=value.min_y),
    point2(x=value.max_x, y=value.min_y),
    point2(x=value.max_x, y=value.max_y),
    point2(x=value.min_x, y=value.max_y),
  ])
}

///|
pub fn convex_hull(
  points : Array[Point2],
  tolerance? : Double = 0.000001,
) -> Ring2 {
  let sorted = points.copy()
  for i in 1..<sorted.length() {
    let value = sorted[i]
    let mut j = i
    while j > 0 &&
          (
            sorted[j - 1].x > value.x ||
            (sorted[j - 1].x == value.x && sorted[j - 1].y > value.y)
          ) {
      sorted[j] = sorted[j - 1]
      j -= 1
    }
    sorted[j] = value
  }
  let unique : Array[Point2] = []
  for point in sorted {
    match unique.last() {
      Some(previous) if previous.near(point, epsilon=tolerance) => ()
      _ => unique.push(point)
    }
  }
  if unique.length() <= 2 {
    return ring2(points=unique)
  }
  let lower : Array[Point2] = []
  for point in unique {
    while lower.length() >= 2 &&
          gk_cross(lower[lower.length() - 2], lower[lower.length() - 1], point) <=
          tolerance {
      ignore(lower.pop())
    }
    lower.push(point)
  }
  let upper : Array[Point2] = []
  let mut index = unique.length() - 1
  while index >= 0 {
    let point = unique[index]
    while upper.length() >= 2 &&
          gk_cross(upper[upper.length() - 2], upper[upper.length() - 1], point) <=
          tolerance {
      ignore(upper.pop())
    }
    upper.push(point)
    index -= 1
  }
  ignore(lower.pop())
  ignore(upper.pop())
  lower.append(upper)
  ring2(points=lower)
}

///|
fn gk_inside_edge(
  point : Point2,
  edge : Int,
  bounds : Rect2,
  tolerance : Double,
) -> Bool {
  match edge {
    0 => point.x >= bounds.min_x - tolerance
    1 => point.x <= bounds.max_x + tolerance
    2 => point.y >= bounds.min_y - tolerance
    _ => point.y <= bounds.max_y + tolerance
  }
}

///|
fn gk_interpolate_to_edge(
  a : Point2,
  b : Point2,
  edge : Int,
  bounds : Rect2,
) -> Point2 {
  match edge {
    0 => {
      let t = (bounds.min_x - a.x) / (b.x - a.x)
      point2(x=bounds.min_x, y=a.y + (b.y - a.y) * t)
    }
    1 => {
      let t = (bounds.max_x - a.x) / (b.x - a.x)
      point2(x=bounds.max_x, y=a.y + (b.y - a.y) * t)
    }
    2 => {
      let t = (bounds.min_y - a.y) / (b.y - a.y)
      point2(x=a.x + (b.x - a.x) * t, y=bounds.min_y)
    }
    _ => {
      let t = (bounds.max_y - a.y) / (b.y - a.y)
      point2(x=a.x + (b.x - a.x) * t, y=bounds.max_y)
    }
  }
}

///|
pub fn clip_ring_to_rect(
  ring : Ring2,
  bounds : Rect2,
  tolerance? : Double = 0.000001,
) -> Ring2 {
  let mut subject = ring.closed_points()
  if subject.length() > 1 {
    ignore(subject.pop())
  }
  for edge in 0..<4 {
    if subject.length() == 0 {
      break
    }
    let input = subject
    subject = []
    let mut previous = input[input.length() - 1]
    for current in input {
      let current_inside = gk_inside_edge(current, edge, bounds, tolerance)
      let previous_inside = gk_inside_edge(previous, edge, bounds, tolerance)
      if current_inside {
        if !previous_inside {
          subject.push(gk_interpolate_to_edge(previous, current, edge, bounds))
        }
        subject.push(current)
      } else if previous_inside {
        subject.push(gk_interpolate_to_edge(previous, current, edge, bounds))
      }
      previous = current
    }
  }
  ring2(points=subject, closed=ring.closed)
}

///|
pub fn clip_polygon_to_rect(polygon : Polygon2, bounds : Rect2) -> Polygon2? {
  let outer = clip_ring_to_rect(polygon.outer, bounds)
  if outer.point_count() < 3 || outer.area() <= 0.0 {
    return None
  }
  let holes : Array[Ring2] = []
  for hole in polygon.holes {
    let clipped = clip_ring_to_rect(hole, bounds)
    if clipped.point_count() >= 3 && clipped.area() > 0.0 {
      match clipped.centroid() {
        Some(center) if point_in_ring(center, outer) is BoundaryInside =>
          holes.push(clipped)
        _ => ()
      }
    }
  }
  Some(polygon2(outer~, holes~))
}

///|
pub fn polygon_to_scanlines(
  polygon : Polygon2,
  y_step : Double,
  bounds : Rect2?,
) -> Array[ScanlineSpan] {
  let step = if y_step <= 0.0 { 0.1 } else { y_step }
  let limits = match bounds {
    Some(value) => value
    None =>
      match polygon.bounds() {
        Some(value) => value
        None => return []
      }
  }
  let result : Array[ScanlineSpan] = []
  let mut y = limits.min_y + step / 2.0
  while y < limits.max_y {
    let intersections : Array[(Double, Int)] = []
    let rings : Array[Ring2] = [polygon.outer]
    rings.append(polygon.holes)
    for ring in rings {
      let points = ring.closed_points()
      if points.length() > 1 {
        for index in 0..<(points.length() - 1) {
          let a = points[index]
          let b = points[index + 1]
          if (a.y > y) != (b.y > y) {
            let x = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
            let direction = if b.y > a.y { 1 } else { -1 }
            intersections.push((x, direction))
          }
        }
      }
    }
    for i in 1..<intersections.length() {
      let value = intersections[i]
      let mut j = i
      while j > 0 && intersections[j - 1].0 > value.0 {
        intersections[j] = intersections[j - 1]
        j -= 1
      }
      intersections[j] = value
    }
    let mut index = 0
    while index + 1 < intersections.length() {
      let start = intersections[index].0
      let finish = intersections[index + 1].0
      if finish > start {
        result.push({
          y,
          start_x: start,
          end_x: finish,
          winding: intersections[index].1 + intersections[index + 1].1,
        })
      }
      index += 2
    }
    y += step
  }
  result
}

///|
pub fn rasterize_polygon(
  polygon : Polygon2,
  cell_width : Double,
  cell_height : Double,
  bounds : Rect2,
) -> Array[RasterCell] {
  let width = if cell_width <= 0.0 { 1.0 } else { cell_width }
  let height = if cell_height <= 0.0 { 1.0 } else { cell_height }
  let columns = (bounds.width() / width).ceil().to_int()
  let rows = (bounds.height() / height).ceil().to_int()
  let result : Array[RasterCell] = []
  for row in 0..<rows {
    for column in 0..<columns {
      let center = point2(
        x=bounds.min_x + (column.to_double() + 0.5) * width,
        y=bounds.min_y + (row.to_double() + 0.5) * height,
      )
      let state = point_in_polygon(center, polygon)
      let covered = state is BoundaryInside || state is BoundaryOn
      result.push({
        row,
        column,
        center,
        covered,
        coverage: if covered {
          1.0
        } else {
          0.0
        },
      })
    }
  }
  result
}

///|
pub fn polygon_to_json(polygon : Polygon2) -> String {
  let points = polygon.outer.points
    .map(point => "[\{point.x},\{point.y}]")
    .join(",")
  let holes = polygon.holes
    .map(hole => {
      "[" + hole.points.map(point => "[\{point.x},\{point.y}]").join(",") + "]"
    })
    .join(",")
  "{\"outer\":[\{points}],\"holes\":[\{holes}],\"area\":\{polygon.area()},\"perimeter\":\{polygon.perimeter()}}"
}

///|
pub fn ring_to_wkt(ring : Ring2) -> String {
  let coordinates = ring
    .closed_points()
    .map(point => "\{point.x} \{point.y}")
    .join(", ")
  "POLYGON ((\{coordinates}))"
}

///|
pub fn intersection_to_json(value : SegmentIntersection) -> String {
  let point = match value.point {
    Some(p) => "{\"x\":\{p.x},\"y\":\{p.y}}"
    None => "null"
  }
  let start = match value.overlap_start {
    Some(p) => "{\"x\":\{p.x},\"y\":\{p.y}}"
    None => "null"
  }
  let end = match value.overlap_end {
    Some(p) => "{\"x\":\{p.x},\"y\":\{p.y}}"
    None => "null"
  }
  "{\"kind\":\{json_string(intersection_kind_name(value.kind))},\"point\":\{point},\"overlap_start\":\{start},\"overlap_end\":\{end}}"
}

///|
pub fn polygon_measure_to_json(value : PolygonMeasure) -> String {
  let centroid = match value.centroid {
    Some(point) => "{\"x\":\{point.x},\"y\":\{point.y}}"
    None => "null"
  }
  "{\"area\":\{value.area},\"signed_area\":\{value.signed_area},\"perimeter\":\{value.perimeter},\"centroid\":\{centroid},\"vertices\":\{value.vertices},\"holes\":\{value.holes}}"
}

///|
pub fn scanline_to_csv(spans : Array[ScanlineSpan]) -> String {
  let mut output = "y,start_x,end_x,winding\n"
  for span in spans {
    output += "\{span.y},\{span.start_x},\{span.end_x},\{span.winding}\n"
  }
  output
}

///|
pub fn raster_cell_count(
  cells : Array[RasterCell],
  covered? : Bool = true,
) -> Int {
  cells.filter(cell => cell.covered == covered).length()
}

///|
pub fn raster_coverage(cells : Array[RasterCell]) -> Double {
  if cells.length() == 0 {
    0.0
  } else {
    cells.fold(init=0.0, (sum, cell) => sum + cell.coverage) /
    cells.length().to_double()
  }
}

///|
pub fn polygon_is_valid(
  polygon : Polygon2,
  tolerance? : GeometryTolerance = geometry_tolerance(),
) -> Bool {
  let outer = polygon.outer
  if outer.point_count() < 3 || outer.area() <= tolerance.area {
    return false
  }
  if polygon_self_intersections(outer, tolerance=tolerance.distance).length() >
    0 {
    return false
  }
  for hole in polygon.holes {
    if hole.point_count() < 3 || hole.area() <= tolerance.area {
      return false
    }
    match hole.centroid() {
      Some(point) if point_in_ring(point, outer, tolerance=tolerance.distance)
        is BoundaryOutside => return false
      _ => ()
    }
  }
  true
}

///|
pub fn polygon_self_intersections(
  ring : Ring2,
  tolerance? : Double = 0.000001,
) -> Array[SegmentIntersection] {
  let points = ring.closed_points()
  let result : Array[SegmentIntersection] = []
  if points.length() < 4 {
    return result
  }
  for i in 0..<(points.length() - 1) {
    for j in (i + 1)..<(points.length() - 1) {
      if j == i + 1 || (i == 0 && j == points.length() - 2) {
        continue
      }
      let hit = segment_intersection(
        points[i],
        points[i + 1],
        points[j],
        points[j + 1],
        tolerance~,
      )
      if hit.kind is ProperIntersection || hit.kind is CollinearOverlap {
        result.push(hit)
      }
    }
  }
  result
}

///|
pub fn polygon_distance_to_point(polygon : Polygon2, point : Point2) -> Double {
  let mut best = 1000000000.0
  let rings : Array[Ring2] = [polygon.outer]
  rings.append(polygon.holes)
  for ring in rings {
    let points = ring.closed_points()
    if points.length() > 1 {
      for index in 0..<(points.length() - 1) {
        let distance = gk_segment_distance(
          point,
          points[index],
          points[index + 1],
        )
        if distance < best {
          best = distance
        }
      }
    }
  }
  best
}

///|
pub fn polygon_clearance(a : Polygon2, b : Polygon2) -> Double {
  let mut best = 1000000000.0
  let arings : Array[Ring2] = [a.outer]
  arings.append(a.holes)
  for ring in arings {
    for point in ring.points {
      let distance = polygon_distance_to_point(b, point)
      if distance < best {
        best = distance
      }
    }
  }
  let brings : Array[Ring2] = [b.outer]
  brings.append(b.holes)
  for ring in brings {
    for point in ring.points {
      let distance = polygon_distance_to_point(a, point)
      if distance < best {
        best = distance
      }
    }
  }
  best
}
