///|
/// A two-dimensional point in the board coordinate system.
pub struct Point2 {
  x : Double
  y : Double
} derive(Debug, Eq)

///|
pub fn point2(x~ : Double, y~ : Double) -> Point2 {
  { x, y }
}

///|
pub fn Point2::add(self : Point2, other : Point2) -> Point2 {
  { x: self.x + other.x, y: self.y + other.y }
}

///|
pub fn Point2::sub(self : Point2, other : Point2) -> Point2 {
  { x: self.x - other.x, y: self.y - other.y }
}

///|
pub fn Point2::scale(self : Point2, factor : Double) -> Point2 {
  { x: self.x * factor, y: self.y * factor }
}

///|
pub fn Point2::dot(self : Point2, other : Point2) -> Double {
  self.x * other.x + self.y * other.y
}

///|
pub fn Point2::cross(self : Point2, other : Point2) -> Double {
  self.x * other.y - self.y * other.x
}

///|
pub fn Point2::length_squared(self : Point2) -> Double {
  self.dot(self)
}

///|
pub fn Point2::length(self : Point2) -> Double {
  self.length_squared().sqrt()
}

///|
pub fn Point2::distance_squared(self : Point2, other : Point2) -> Double {
  self.sub(other).length_squared()
}

///|
pub fn Point2::distance(self : Point2, other : Point2) -> Double {
  self.distance_squared(other).sqrt()
}

///|
pub fn Point2::lerp(self : Point2, other : Point2, t : Double) -> Point2 {
  { x: self.x + (other.x - self.x) * t, y: self.y + (other.y - self.y) * t }
}

///|
pub fn Point2::near(
  self : Point2,
  other : Point2,
  epsilon? : Double = 0.000001,
) -> Bool {
  self.distance_squared(other) <= epsilon * epsilon
}

///|
pub struct Rect2 {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Debug)

///|
pub fn rect2(
  min_x~ : Double,
  min_y~ : Double,
  max_x~ : Double,
  max_y~ : Double,
) -> Rect2 {
  {
    min_x: if min_x <= max_x {
      min_x
    } else {
      max_x
    },
    min_y: if min_y <= max_y {
      min_y
    } else {
      max_y
    },
    max_x: if min_x <= max_x {
      max_x
    } else {
      min_x
    },
    max_y: if min_y <= max_y {
      max_y
    } else {
      min_y
    },
  }
}

///|
pub fn Rect2::empty(self : Rect2) -> Bool {
  self.max_x <= self.min_x || self.max_y <= self.min_y
}

///|
pub fn Rect2::width(self : Rect2) -> Double {
  self.max_x - self.min_x
}

///|
pub fn Rect2::height(self : Rect2) -> Double {
  self.max_y - self.min_y
}

///|
pub fn Rect2::area(self : Rect2) -> Double {
  if self.empty() {
    0.0
  } else {
    self.width() * self.height()
  }
}

///|
pub fn Rect2::perimeter(self : Rect2) -> Double {
  2.0 * (self.width() + self.height())
}

///|
pub fn Rect2::center(self : Rect2) -> Point2 {
  { x: (self.min_x + self.max_x) / 2.0, y: (self.min_y + self.max_y) / 2.0 }
}

///|
pub fn Rect2::contains(self : Rect2, point : Point2) -> Bool {
  point.x >= self.min_x &&
  point.x <= self.max_x &&
  point.y >= self.min_y &&
  point.y <= self.max_y
}

///|
pub fn Rect2::contains_rect(self : Rect2, other : Rect2) -> Bool {
  other.min_x >= self.min_x &&
  other.max_x <= self.max_x &&
  other.min_y >= self.min_y &&
  other.max_y <= self.max_y
}

///|
pub fn Rect2::intersects(self : Rect2, other : Rect2) -> Bool {
  self.min_x <= other.max_x &&
  self.max_x >= other.min_x &&
  self.min_y <= other.max_y &&
  self.max_y >= other.min_y
}

///|
pub fn Rect2::intersection(self : Rect2, other : Rect2) -> Rect2? {
  if self.intersects(other) {
    Some(
      rect2(
        min_x=max(self.min_x, other.min_x),
        min_y=max(self.min_y, other.min_y),
        max_x=min(self.max_x, other.max_x),
        max_y=min(self.max_y, other.max_y),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Rect2::include_point(self : Rect2, point : Point2) -> Rect2 {
  {
    min_x: min(self.min_x, point.x),
    min_y: min(self.min_y, point.y),
    max_x: max(self.max_x, point.x),
    max_y: max(self.max_y, point.y),
  }
}

///|
pub fn Rect2::union(self : Rect2, other : Rect2) -> Rect2 {
  {
    min_x: min(self.min_x, other.min_x),
    min_y: min(self.min_y, other.min_y),
    max_x: max(self.max_x, other.max_x),
    max_y: max(self.max_y, other.max_y),
  }
}

///|
pub fn Rect2::expand(self : Rect2, amount : Double) -> Rect2 {
  {
    min_x: self.min_x - amount,
    min_y: self.min_y - amount,
    max_x: self.max_x + amount,
    max_y: self.max_y + amount,
  }
}

///|
pub fn Rect2::translate(self : Rect2, offset : Point2) -> Rect2 {
  {
    min_x: self.min_x + offset.x,
    min_y: self.min_y + offset.y,
    max_x: self.max_x + offset.x,
    max_y: self.max_y + offset.y,
  }
}

///|
pub struct Polyline {
  points : Array[Point2]
  closed : Bool
} derive(Debug)

///|
pub fn polyline(points : Array[Point2], closed? : Bool = false) -> Polyline {
  { points, closed }
}

///|
pub fn Polyline::is_empty(self : Polyline) -> Bool {
  self.points.length() == 0
}

///|
pub fn Polyline::point_count(self : Polyline) -> Int {
  self.points.length()
}

///|
pub fn Polyline::length(self : Polyline) -> Double {
  if self.points.length() < 2 {
    0.0
  } else {
    let mut total = 0.0
    for i in 1..<self.points.length() {
      total += self.points[i - 1].distance(self.points[i])
    }
    if self.closed {
      total + self.points[self.points.length() - 1].distance(self.points[0])
    } else {
      total
    }
  }
}

///|
pub fn Polyline::signed_area(self : Polyline) -> Double {
  if !self.closed || self.points.length() < 3 {
    0.0
  } else {
    let mut area = 0.0
    for i in 0..<self.points.length() {
      let a = self.points[i]
      let b = self.points[(i + 1) % self.points.length()]
      area += a.cross(b)
    }
    area / 2.0
  }
}

///|
pub fn Polyline::area(self : Polyline) -> Double {
  self.signed_area().abs()
}

///|
pub fn Polyline::clockwise(self : Polyline) -> Bool {
  self.signed_area() < 0.0
}

///|
pub fn Polyline::bounds(self : Polyline) -> Rect2? {
  if self.points.length() == 0 {
    None
  } else {
    let first = self.points[0]
    let mut result = rect2(
      min_x=first.x,
      min_y=first.y,
      max_x=first.x,
      max_y=first.y,
    )
    for point in self.points {
      result = result.include_point(point)
    }
    Some(result)
  }
}

///|
pub fn Polyline::reversed(self : Polyline) -> Polyline {
  { points: self.points.rev(), closed: self.closed }
}

///|
pub struct Circle2 {
  center : Point2
  radius : Double
} derive(Debug)

///|
pub fn circle2(center : Point2, radius : Double) -> Circle2 {
  { center, radius: if radius < 0.0 { -radius } else { radius } }
}

///|
pub fn Circle2::contains(self : Circle2, point : Point2) -> Bool {
  self.center.distance_squared(point) <= self.radius * self.radius
}

///|
pub fn Circle2::bounds(self : Circle2) -> Rect2 {
  rect2(
    min_x=self.center.x - self.radius,
    min_y=self.center.y - self.radius,
    max_x=self.center.x + self.radius,
    max_y=self.center.y + self.radius,
  )
}

///|
pub struct DoubleRange {
  start : Double
  end : Double
} derive(Debug)

///|
pub fn double_range(start~ : Double, end~ : Double) -> DoubleRange {
  { start, end }
}

///|
pub fn DoubleRange::length(self : DoubleRange) -> Double {
  (self.end - self.start).abs()
}

///|
pub fn DoubleRange::contains(self : DoubleRange, value : Double) -> Bool {
  let low = min(self.start, self.end)
  let high = max(self.start, self.end)
  value >= low && value <= high
}

///|
pub fn DoubleRange::clamp(self : DoubleRange, value : Double) -> Double {
  if value < min(self.start, self.end) {
    min(self.start, self.end)
  } else if value > max(self.start, self.end) {
    max(self.start, self.end)
  } else {
    value
  }
}

///|
pub fn min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn clamp(value : Double, low~ : Double, high~ : Double) -> Double {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
pub fn approx_equal(
  a : Double,
  b : Double,
  epsilon? : Double = 0.000001,
) -> Bool {
  (a - b).abs() <= epsilon
}

///|
pub fn orient(a : Point2, b : Point2, c : Point2) -> Double {
  b.sub(a).cross(c.sub(a))
}

///|
pub fn point_on_segment(
  point : Point2,
  start : Point2,
  end : Point2,
  epsilon? : Double = 0.000001,
) -> Bool {
  let direction = end.sub(start)
  let offset = point.sub(start)
  let cross = direction.cross(offset).abs()
  let dot = offset.dot(point.sub(end))
  cross <= epsilon && dot <= epsilon
}

///|
pub fn segments_intersect(
  a : Point2,
  b : Point2,
  c : Point2,
  d : Point2,
) -> Bool {
  let ab_c = orient(a, b, c)
  let ab_d = orient(a, b, d)
  let cd_a = orient(c, d, a)
  let cd_b = orient(c, d, b)
  if point_on_segment(c, a, b) ||
    point_on_segment(d, a, b) ||
    point_on_segment(a, c, d) ||
    point_on_segment(b, c, d) {
    true
  } else {
    ((ab_c < 0.0 && ab_d > 0.0) || (ab_c > 0.0 && ab_d < 0.0)) &&
    ((cd_a < 0.0 && cd_b > 0.0) || (cd_a > 0.0 && cd_b < 0.0))
  }
}

///|
pub fn polygon_contains(points : Array[Point2], point : Point2) -> Bool {
  if points.length() < 3 {
    false
  } else {
    let mut inside = false
    let mut boundary = false
    for i in 0..<points.length() {
      let j = if i == 0 { points.length() - 1 } else { i - 1 }
      let a = points[i]
      let b = points[j]
      if point_on_segment(point, a, b) {
        boundary = true
      } else if !boundary && (a.y > point.y) != (b.y > point.y) {
        let x = (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
        if point.x < x {
          inside = !inside
        }
      }
    }
    boundary || inside
  }
}

///|
pub fn polygon_self_intersects(points : Array[Point2]) -> Bool {
  if points.length() < 4 {
    false
  } else {
    let mut found = false
    let n = points.length()
    for i in 0..<n {
      let a1 = points[i]
      let a2 = points[(i + 1) % n]
      for j in (i + 1)..<n {
        let adjacent = j == i + 1 || (i == 0 && j == n - 1)
        if !adjacent {
          let b1 = points[j]
          let b2 = points[(j + 1) % n]
          if segments_intersect(a1, a2, b1, b2) {
            found = true
          }
        }
      }
    }
    found
  }
}
