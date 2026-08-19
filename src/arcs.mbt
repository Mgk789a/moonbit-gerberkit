///|
pub enum ArcDirection {
  ClockwiseArc
  CounterClockwiseArc
} derive(Debug, Eq)

///|
pub fn clockwise_arc_direction() -> ArcDirection {
  ClockwiseArc
}

///|
pub fn counter_clockwise_arc_direction() -> ArcDirection {
  CounterClockwiseArc
}

///|
pub struct Arc2 {
  center : Point2
  start : Point2
  end : Point2
  radius : Double
  direction : ArcDirection
  full_circle : Bool
} derive(Debug)

///|
pub fn arc2(
  center~ : Point2,
  start~ : Point2,
  end~ : Point2,
  direction~ : ArcDirection,
  full_circle? : Bool = false,
) -> Arc2 {
  { center, start, end, radius: center.distance(start), direction, full_circle }
}

///|
pub fn Arc2::sweep_angle(self : Arc2) -> Double {
  if self.full_circle {
    2.0 * 3.141592653589793
  } else {
    let a = approximate_angle(self.start.sub(self.center))
    let b = approximate_angle(self.end.sub(self.center))
    let two_pi = 2.0 * 3.141592653589793
    match self.direction {
      CounterClockwiseArc => {
        let raw = b - a
        if raw < 0.0 {
          raw + two_pi
        } else {
          raw
        }
      }
      ClockwiseArc => {
        let raw = a - b
        if raw < 0.0 {
          raw + two_pi
        } else {
          raw
        }
      }
    }
  }
}

///|
pub fn Arc2::length(self : Arc2) -> Double {
  self.radius * self.sweep_angle()
}

///|
pub fn Arc2::point_at(self : Arc2, fraction : Double) -> Point2 {
  let start_angle = approximate_angle(self.start.sub(self.center))
  let delta = match self.direction {
    CounterClockwiseArc => self.sweep_angle()
    ClockwiseArc => -self.sweep_angle()
  }
  let angle = start_angle + delta * clamp(fraction, low=0.0, high=1.0)
  point2(
    x=self.center.x + self.radius * approximate_cosine(angle),
    y=self.center.y + self.radius * approximate_sine(angle),
  )
}

///|
pub fn Arc2::point_count(self : Arc2, maximum_step? : Double = 0.25) -> Int {
  if self.radius <= 0.0 {
    1
  } else {
    let estimated = (self.length() / maximum_step).ceil().to_int()
    if estimated < 2 {
      2
    } else if estimated > 4096 {
      4096
    } else {
      estimated
    }
  }
}

///|
pub fn Arc2::sample(
  self : Arc2,
  maximum_step? : Double = 0.25,
) -> Array[Point2] {
  let count = self.point_count(maximum_step~)
  let points : Array[Point2] = []
  for index in 0..<=count {
    points.push(self.point_at(index.to_double() / count.to_double()))
  }
  points
}

///|
pub fn Arc2::bounds(self : Arc2) -> Rect2 {
  let points = self.sample()
  let result = rect2(
    min_x=points[0].x,
    min_y=points[0].y,
    max_x=points[0].x,
    max_y=points[0].y,
  )
  let mut bounds = result
  for point in points {
    bounds = bounds.include_point(point)
  }
  for cardinal in [0.0, 1.5707963267948966, 3.141592653589793, 4.71238898038469] {
    let candidate = point2(
      x=self.center.x + self.radius * approximate_cosine(cardinal),
      y=self.center.y + self.radius * approximate_sine(cardinal),
    )
    if arc_contains_angle(self, cardinal) {
      bounds = bounds.include_point(candidate)
    }
  }
  bounds
}

///|
pub fn Arc2::to_segments(self : Arc2, width : Double) -> Array[Shape] {
  let points = self.sample()
  let segments : Array[Shape] = []
  for index in 1..<points.length() {
    let a = points[index - 1]
    let b = points[index]
    if !a.near(b) {
      segments.push(Segment(x1=a.x, y1=a.y, x2=b.x, y2=b.y, width~))
    }
  }
  segments
}

///|
pub fn arc_from_offsets(
  start : Point2,
  end : Point2,
  i : Double,
  j : Double,
  direction : ArcDirection,
) -> Arc2 {
  let center = point2(x=start.x + i, y=start.y + j)
  arc2(center~, start~, end~, direction~)
}

///|
pub fn arc_contains_angle(arc : Arc2, angle : Double) -> Bool {
  if arc.full_circle {
    true
  } else {
    let start_angle = approximate_angle(arc.start.sub(arc.center))
    let sweep = arc.sweep_angle()
    let two_pi = 2.0 * 3.141592653589793
    let normalized = normalize_angle(angle)
    let start = normalize_angle(start_angle)
    if arc.direction is CounterClockwiseArc {
      let delta = if normalized < start {
        normalized + two_pi - start
      } else {
        normalized - start
      }
      delta <= sweep + 0.000001
    } else {
      let delta = if start < normalized {
        start + two_pi - normalized
      } else {
        start - normalized
      }
      delta <= sweep + 0.000001
    }
  }
}

///|
fn normalize_angle(value : Double) -> Double {
  let two_pi = 2.0 * 3.141592653589793
  let mut result = value
  while result < 0.0 {
    result += two_pi
  }
  while result >= two_pi {
    result -= two_pi
  }
  result
}

///|
fn approximate_sine(value : Double) -> Double {
  let x = normalize_signed_angle(value)
  let x2 = x * x
  x -
  x * x2 / 6.0 +
  x * x2 * x2 / 120.0 -
  x * x2 * x2 * x2 / 5040.0 +
  x * x2 * x2 * x2 * x2 / 362880.0
}

///|
fn approximate_cosine(value : Double) -> Double {
  let x = normalize_signed_angle(value)
  let x2 = x * x
  1.0 -
  x2 / 2.0 +
  x2 * x2 / 24.0 -
  x2 * x2 * x2 / 720.0 +
  x2 * x2 * x2 * x2 / 40320.0
}

///|
fn normalize_signed_angle(value : Double) -> Double {
  let two_pi = 2.0 * 3.141592653589793
  let mut result = value
  while result > 3.141592653589793 {
    result -= two_pi
  }
  while result < -3.141592653589793 {
    result += two_pi
  }
  result
}

///|
fn approximate_angle(vector : Point2) -> Double {
  if vector.x == 0.0 && vector.y == 0.0 {
    0.0
  } else if vector.x == 0.0 {
    if vector.y > 0.0 {
      1.5707963267948966
    } else {
      -1.5707963267948966
    }
  } else {
    let ratio = vector.y / vector.x
    let base = approximate_atan(ratio)
    if vector.x < 0.0 {
      if vector.y >= 0.0 {
        base + 3.141592653589793
      } else {
        base - 3.141592653589793
      }
    } else {
      base
    }
  }
}

///|
fn approximate_atan(value : Double) -> Double {
  let abs_value = value.abs()
  if abs_value <= 1.0 {
    let x2 = value * value
    value -
    value * x2 / 3.0 +
    value * x2 * x2 / 5.0 -
    value * x2 * x2 * x2 / 7.0 +
    value * x2 * x2 * x2 * x2 / 9.0
  } else if value > 0.0 {
    1.5707963267948966 - approximate_atan(1.0 / value)
  } else {
    -1.5707963267948966 - approximate_atan(1.0 / value)
  }
}

///|
pub struct ArcCollection {
  arcs : Array[Arc2]
} derive(Debug)

///|
pub fn new_arc_collection() -> ArcCollection {
  { arcs: [] }
}

///|
pub fn ArcCollection::push(self : ArcCollection, arc : Arc2) -> Unit {
  self.arcs.push(arc)
}

///|
pub fn ArcCollection::length(self : ArcCollection) -> Double {
  self.arcs.fold(init=0.0, (sum, arc) => sum + arc.length())
}

///|
pub fn ArcCollection::bounds(self : ArcCollection) -> Rect2? {
  if self.arcs.length() == 0 {
    None
  } else {
    let mut result = self.arcs[0].bounds()
    for arc in self.arcs[1:] {
      result = result.union(arc.bounds())
    }
    Some(result)
  }
}

///|
pub fn ArcCollection::flatten(
  self : ArcCollection,
  width : Double,
) -> Array[Shape] {
  let result : Array[Shape] = []
  for arc in self.arcs {
    result.append(arc.to_segments(width))
  }
  result
}
