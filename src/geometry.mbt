///|
fn abs(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn shape_bounds(shape : Shape) -> BoundingBox? {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) => {
      let r = width / 2.0
      Some({
        min_x: (if x1 < x2 { x1 } else { x2 }) - r,
        min_y: (if y1 < y2 { y1 } else { y2 }) - r,
        max_x: (if x1 > x2 { x1 } else { x2 }) + r,
        max_y: (if y1 > y2 { y1 } else { y2 }) + r,
      })
    }
    Pad(x~, y~, diameter~) => {
      let r = diameter / 2.0
      Some({ min_x: x - r, min_y: y - r, max_x: x + r, max_y: y + r })
    }
    Flash(x~, y~, ..) => Some({ min_x: x, min_y: y, max_x: x, max_y: y })
    DrillHit(x~, y~, diameter~) => {
      let r = diameter / 2.0
      Some({ min_x: x - r, min_y: y - r, max_x: x + r, max_y: y + r })
    }
    Region(points~) =>
      if points.length() == 0 {
        None
      } else {
        let (x0, y0) = points[0]
        let b : BoundingBox = { min_x: x0, min_y: y0, max_x: x0, max_y: y0 }
        Some(
          points.fold(init=b, (acc, p) => {
            let (x, y) = p
            {
              min_x: if x < acc.min_x {
                x
              } else {
                acc.min_x
              },
              min_y: if y < acc.min_y {
                y
              } else {
                acc.min_y
              },
              max_x: if x > acc.max_x {
                x
              } else {
                acc.max_x
              },
              max_y: if y > acc.max_y {
                y
              } else {
                acc.max_y
              },
            }
          }),
        )
      }
  }
}

///|
pub fn board_bounds(board : Board) -> BoundingBox? {
  let all : Array[BoundingBox] = []
  for layer in board.layers {
    for shape in layer.shapes {
      match shape_bounds(shape) {
        Some(b) => all.push(b)
        None => ()
      }
    }
  }
  if all.length() == 0 {
    None
  } else {
    Some(
      all.fold(init=all[0], (acc, b) => {
        min_x: if b.min_x < acc.min_x {
          b.min_x
        } else {
          acc.min_x
        },
        min_y: if b.min_y < acc.min_y {
          b.min_y
        } else {
          acc.min_y
        },
        max_x: if b.max_x > acc.max_x {
          b.max_x
        } else {
          acc.max_x
        },
        max_y: if b.max_y > acc.max_y {
          b.max_y
        } else {
          acc.max_y
        },
      }),
    )
  }
}

///|
pub fn convert(value : Double, from~ : LengthUnit, to~ : LengthUnit) -> Double {
  value * from.scale_to_mm() / to.scale_to_mm()
}
