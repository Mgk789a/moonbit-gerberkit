///|
pub struct SpatialEntry {
  layer_index : Int
  shape_index : Int
  bounds : Rect2
} derive(Debug)

///|
pub struct SpatialIndex {
  cell_size : Double
  cells : Map[String, Array[SpatialEntry]]
  entries : Array[SpatialEntry]
} derive(Debug)

///|
pub fn spatial_index(cell_size? : Double = 10.0) -> SpatialIndex {
  {
    cell_size: if cell_size <= 0.0 {
      10.0
    } else {
      cell_size
    },
    cells: {},
    entries: [],
  }
}

///|
fn spatial_floor(value : Double) -> Int {
  value.floor().to_int()
}

///|
fn spatial_cell(value : Double, cell_size : Double) -> Int {
  spatial_floor(value / cell_size)
}

///|
fn spatial_key(x : Int, y : Int) -> String {
  "\{x}:\{y}"
}

///|
fn spatial_cell_range(
  bounds : Rect2,
  cell_size : Double,
) -> (Int, Int, Int, Int) {
  (
    spatial_cell(bounds.min_x, cell_size),
    spatial_cell(bounds.min_y, cell_size),
    spatial_cell(bounds.max_x, cell_size),
    spatial_cell(bounds.max_y, cell_size),
  )
}

///|
fn spatial_add_to_cell(
  index : SpatialIndex,
  key : String,
  entry : SpatialEntry,
) -> Unit {
  match index.cells.get(key) {
    Some(values) => values.push(entry)
    None => index.cells[key] = [entry]
  }
}

///|
pub fn SpatialIndex::insert(
  self : SpatialIndex,
  layer_index : Int,
  shape_index : Int,
  bounds : Rect2,
) -> Unit {
  let entry = { layer_index, shape_index, bounds }
  self.entries.push(entry)
  let (min_x, min_y, max_x, max_y) = spatial_cell_range(bounds, self.cell_size)
  for x in min_x..<=max_x {
    for y in min_y..<=max_y {
      spatial_add_to_cell(self, spatial_key(x, y), entry)
    }
  }
}

///|
pub fn SpatialIndex::insert_board(self : SpatialIndex, board : Board) -> Unit {
  for layer_index, layer in board.layers {
    for shape_index, shape in layer.shapes {
      match shape_box(shape) {
        Some(bounds) => self.insert(layer_index, shape_index, bounds)
        None => ()
      }
    }
  }
}

///|
pub fn SpatialIndex::entry_count(self : SpatialIndex) -> Int {
  self.entries.length()
}

///|
pub fn SpatialIndex::cell_count(self : SpatialIndex) -> Int {
  self.cells.length()
}

///|
pub fn SpatialIndex::query(
  self : SpatialIndex,
  bounds : Rect2,
) -> Array[SpatialEntry] {
  let result : Array[SpatialEntry] = []
  let seen : Map[String, Bool] = Map([])
  let (min_x, min_y, max_x, max_y) = spatial_cell_range(bounds, self.cell_size)
  for x in min_x..<=max_x {
    for y in min_y..<=max_y {
      let key = spatial_key(x, y)
      match self.cells.get(key) {
        Some(values) =>
          for entry in values {
            let entry_key = "\{entry.layer_index}:\{entry.shape_index}"
            if !seen.contains(entry_key) && entry.bounds.intersects(bounds) {
              seen[entry_key] = true
              result.push(entry)
            }
          }
        None => ()
      }
    }
  }
  result
}

///|
pub fn SpatialIndex::query_point(
  self : SpatialIndex,
  point : Point2,
  radius? : Double = 0.0,
) -> Array[SpatialEntry] {
  self.query(
    rect2(
      min_x=point.x - radius,
      min_y=point.y - radius,
      max_x=point.x + radius,
      max_y=point.y + radius,
    ),
  )
}

///|
pub fn SpatialIndex::nearest(
  self : SpatialIndex,
  point : Point2,
  limit? : Int = 8,
) -> Array[SpatialEntry] {
  let candidates = self.query_point(
    point,
    radius=if limit > 0 {
      self.cell_size * limit.to_double()
    } else {
      self.cell_size
    },
  )
  let scored : Array[(Double, SpatialEntry)] = []
  for entry in candidates {
    let center = entry.bounds.center()
    scored.push((center.distance_squared(point), entry))
  }
  scored.sort_by((left, right) => {
    if left.0 < right.0 {
      -1
    } else if left.0 > right.0 {
      1
    } else {
      0
    }
  })
  let count = if limit < scored.length() { limit } else { scored.length() }
  scored[:count].map(item => item.1)
}

///|
pub fn SpatialIndex::clear(self : SpatialIndex) -> Unit {
  self.cells.clear()
  self.entries.clear()
}

///|
pub fn SpatialIndex::rebuild(self : SpatialIndex, board : Board) -> Unit {
  self.clear()
  self.insert_board(board)
}

///|
pub fn SpatialIndex::density(self : SpatialIndex) -> Double {
  if self.cells.length() == 0 {
    0.0
  } else {
    self.entries.length().to_double() / self.cells.length().to_double()
  }
}

///|
pub fn SpatialIndex::occupied_cells(self : SpatialIndex) -> Array[String] {
  let result : Array[String] = []
  for key, values in self.cells {
    if values.length() > 0 {
      result.push(key)
    }
  }
  result
}

///|
pub fn SpatialIndex::layer_query(
  self : SpatialIndex,
  layer_index : Int,
  bounds : Rect2,
) -> Array[SpatialEntry] {
  self.query(bounds).filter(entry => entry.layer_index == layer_index)
}

///|
pub fn SpatialIndex::shape_query(
  self : SpatialIndex,
  layer_index : Int,
  shape_index : Int,
) -> SpatialEntry? {
  for entry in self.entries {
    if entry.layer_index == layer_index && entry.shape_index == shape_index {
      return Some(entry)
    }
  }
  None
}

///|
pub fn SpatialIndex::overlap_pairs(
  self : SpatialIndex,
) -> Array[(SpatialEntry, SpatialEntry)] {
  let result : Array[(SpatialEntry, SpatialEntry)] = []
  let seen : Map[String, Bool] = Map([])
  for entry in self.entries {
    for other in self.query(entry.bounds) {
      if entry.layer_index == other.layer_index &&
        entry.shape_index < other.shape_index {
        let key = "\{entry.layer_index}:\{entry.shape_index}:\{other.shape_index}"
        if !seen.contains(key) {
          seen[key] = true
          result.push((entry, other))
        }
      }
    }
  }
  result
}

///|
pub fn spatial_index_for_board(
  board : Board,
  cell_size? : Double = 10.0,
) -> SpatialIndex {
  let index = spatial_index(cell_size~)
  index.insert_board(board)
  index
}
