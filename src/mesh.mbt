///|
/// Lightweight polygon triangulation and mesh inspection for copper pour,
/// raster export, and downstream manufacturing consumers.
pub enum MeshIssueKind {
  MeshTooFewVertices
  MeshDegenerateTriangle
  MeshDuplicateVertex
  MeshInvertedTriangle
  MeshBoundaryMismatch
  MeshHoleUnrepresented
  MeshNonFiniteVertex
} derive(Debug, Eq)

///|
pub struct MeshVertex {
  id : Int
  point : Point2
  boundary : Bool
} derive(Debug)

///|
pub struct MeshTriangle {
  id : Int
  a : Int
  b : Int
  c : Int
  area : Double
  centroid : Point2
  clockwise : Bool
} derive(Debug)

///|
pub struct Mesh2 {
  vertices : Array[MeshVertex]
  triangles : Array[MeshTriangle]
  source_area : Double
  source_holes : Int
} derive(Debug)

///|
pub struct MeshIssue {
  kind : MeshIssueKind
  triangle_id : Int?
  vertex_id : Int?
  message : String
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct MeshValidation {
  valid : Bool
  issues : Array[MeshIssue]
  vertex_count : Int
  triangle_count : Int
  mesh_area : Double
  source_area : Double
  area_error : Double
} derive(Debug)

///|
pub struct MeshStatistics {
  vertex_count : Int
  triangle_count : Int
  boundary_vertices : Int
  area : Double
  min_triangle_area : Double
  max_triangle_area : Double
  average_triangle_area : Double
  bounds : Rect2?
} derive(Debug)

///|
pub fn mesh_issue_name(value : MeshIssueKind) -> String {
  match value {
    MeshTooFewVertices => "too-few-vertices"
    MeshDegenerateTriangle => "degenerate-triangle"
    MeshDuplicateVertex => "duplicate-vertex"
    MeshInvertedTriangle => "inverted-triangle"
    MeshBoundaryMismatch => "boundary-mismatch"
    MeshHoleUnrepresented => "hole-unrepresented"
    MeshNonFiniteVertex => "non-finite-vertex"
  }
}

///|
pub fn mesh_vertex(id : Int, point : Point2, boundary : Bool) -> MeshVertex {
  { id, point, boundary }
}

///|
pub fn MeshVertex::location(self : MeshVertex) -> Point2 {
  self.point
}

///|
pub fn MeshVertex::is_boundary(self : MeshVertex) -> Bool {
  self.boundary
}

///|
pub fn MeshTriangle::vertices(self : MeshTriangle) -> (Int, Int, Int) {
  (self.a, self.b, self.c)
}

///|
pub fn MeshTriangle::is_degenerate(self : MeshTriangle) -> Bool {
  self.area <= 0.000000000001
}

///|
pub fn MeshTriangle::contains_point(
  self : MeshTriangle,
  mesh : Mesh2,
  point : Point2,
) -> Bool {
  let a = mesh.vertices[self.a].point
  let b = mesh.vertices[self.b].point
  let c = mesh.vertices[self.c].point
  let first = gk_cross(a, b, point)
  let second = gk_cross(b, c, point)
  let third = gk_cross(c, a, point)
  (first >= 0.0 && second >= 0.0 && third >= 0.0) ||
  (first <= 0.0 && second <= 0.0 && third <= 0.0)
}

///|
pub fn Mesh2::vertex_count(self : Mesh2) -> Int {
  self.vertices.length()
}

///|
pub fn Mesh2::triangle_count(self : Mesh2) -> Int {
  self.triangles.length()
}

///|
pub fn Mesh2::area(self : Mesh2) -> Double {
  self.triangles.fold(init=0.0, (sum, triangle) => sum + triangle.area)
}

///|
pub fn Mesh2::bounds(self : Mesh2) -> Rect2? {
  match self.vertices.get(0) {
    None => None
    Some(first) => {
      let initial = rect2(
        min_x=first.point.x,
        min_y=first.point.y,
        max_x=first.point.x,
        max_y=first.point.y,
      )
      Some(
        self.vertices.fold(init=initial, (value, vertex) => {
          value.include_point(vertex.point)
        }),
      )
    }
  }
}

///|
pub fn Mesh2::triangle(self : Mesh2, index : Int) -> MeshTriangle? {
  self.triangles.get(index)
}

///|
pub fn Mesh2::vertex(self : Mesh2, index : Int) -> MeshVertex? {
  self.vertices.get(index)
}

///|
pub fn Mesh2::statistics(self : Mesh2) -> MeshStatistics {
  let mut min_area = 1000000000.0
  let mut max_area = 0.0
  for triangle in self.triangles {
    if triangle.area < min_area {
      min_area = triangle.area
    }
    if triangle.area > max_area {
      max_area = triangle.area
    }
  }
  if self.triangles.length() == 0 {
    min_area = 0.0
  }
  {
    vertex_count: self.vertices.length(),
    triangle_count: self.triangles.length(),
    boundary_vertices: self.vertices.filter(vertex => vertex.boundary).length(),
    area: self.area(),
    min_triangle_area: min_area,
    max_triangle_area: max_area,
    average_triangle_area: if self.triangles.length() == 0 {
      0.0
    } else {
      self.area() / self.triangles.length().to_double()
    },
    bounds: self.bounds(),
  }
}

///|
pub fn mesh_to_points(mesh : Mesh2, triangle : MeshTriangle) -> Array[Point2] {
  [
    mesh.vertices[triangle.a].point,
    mesh.vertices[triangle.b].point,
    mesh.vertices[triangle.c].point,
  ]
}

///|
fn mesh_triangle(
  vertices : Array[MeshVertex],
  a : Int,
  b : Int,
  c : Int,
) -> MeshTriangle {
  let first = vertices[a].point
  let second = vertices[b].point
  let third = vertices[c].point
  let signed = gk_cross(first, second, third) / 2.0
  let area = signed.abs()
  {
    id: 0,
    a,
    b,
    c,
    area,
    centroid: point2(
      x=(first.x + second.x + third.x) / 3.0,
      y=(first.y + second.y + third.y) / 3.0,
    ),
    clockwise: signed < 0.0,
  }
}

///|
fn mesh_find_ear(
  ring : Array[Int],
  vertices : Array[MeshVertex],
  tolerance : Double,
) -> (Int, Int, Int)? {
  if ring.length() < 3 {
    return None
  }
  for index in 0..<ring.length() {
    let previous = ring[(index + ring.length() - 1) % ring.length()]
    let current = ring[index]
    let next = ring[(index + 1) % ring.length()]
    let a = vertices[previous].point
    let b = vertices[current].point
    let c = vertices[next].point
    if gk_cross(a, b, c) <= tolerance {
      continue
    }
    let mut contains = false
    for candidate in ring {
      if candidate != previous && candidate != current && candidate != next {
        let point = vertices[candidate].point
        let first = gk_cross(a, b, point)
        let second = gk_cross(b, c, point)
        let third = gk_cross(c, a, point)
        if first >= -tolerance && second >= -tolerance && third >= -tolerance {
          contains = true
        }
      }
    }
    if !contains {
      return Some((previous, current, next))
    }
  }
  None
}

///|
fn mesh_vertices_for_ring(
  ring : Ring2,
  tolerance : Double,
) -> Array[MeshVertex] {
  let points = ring.deduplicated(tolerance~).closed_points()
  let result : Array[MeshVertex] = []
  let count = if points.length() > 0 { points.length() - 1 } else { 0 }
  for index in 0..<count {
    result.push(mesh_vertex(index, points[index], true))
  }
  result
}

///|
pub fn triangulate_ring(ring : Ring2, tolerance? : Double = 0.000001) -> Mesh2 {
  let vertices = mesh_vertices_for_ring(ring, tolerance)
  let active : Array[Int] = []
  for index in 0..<vertices.length() {
    active.push(index)
  }
  let triangles : Array[MeshTriangle] = []
  let guard_limit = vertices.length() * vertices.length() + 1
  let mut attempts = 0
  while active.length() >= 3 && attempts < guard_limit {
    match mesh_find_ear(active, vertices, tolerance) {
      Some(ear) => {
        let triangle = mesh_triangle(vertices, ear.0, ear.1, ear.2)
        let id = triangles.length()
        triangles.push({
          id,
          a: triangle.a,
          b: triangle.b,
          c: triangle.c,
          area: triangle.area,
          centroid: triangle.centroid,
          clockwise: triangle.clockwise,
        })
        let mut remove_index : Int? = None
        for active_index, value in active {
          if value == ear.1 {
            remove_index = Some(active_index)
          }
        }
        match remove_index {
          Some(value) => ignore(active.remove(value))
          None => ()
        }
      }
      None => break
    }
    attempts += 1
  }
  { vertices, triangles, source_area: ring.area(), source_holes: 0 }
}

///|
pub fn triangulate_polygon(
  polygon : Polygon2,
  tolerance? : Double = 0.000001,
) -> Mesh2 {
  let base = triangulate_ring(polygon.outer, tolerance~)
  let triangles = base.triangles.filter(triangle => {
    polygon.holes.all(hole => {
      point_in_ring(triangle.centroid, hole, tolerance~) is BoundaryOutside
    })
  })
  {
    vertices: base.vertices,
    triangles,
    source_area: polygon.area(),
    source_holes: polygon.holes.length(),
  }
}

///|
pub fn validate_mesh(
  mesh : Mesh2,
  tolerance? : Double = 0.000001,
) -> MeshValidation {
  let issues : Array[MeshIssue] = []
  if mesh.vertices.length() < 3 {
    issues.push({
      kind: MeshTooFewVertices,
      triangle_id: None,
      vertex_id: None,
      message: "mesh has fewer than three vertices",
      measured: Some(mesh.vertices.length().to_double()),
      limit: Some(3.0),
    })
  }
  let seen : Array[Point2] = []
  for vertex in mesh.vertices {
    if vertex.point.x.is_nan() || vertex.point.y.is_nan() {
      issues.push({
        kind: MeshNonFiniteVertex,
        triangle_id: None,
        vertex_id: Some(vertex.id),
        message: "mesh vertex is not finite",
        measured: None,
        limit: None,
      })
    }
    if seen.any(point => point.near(vertex.point, epsilon=tolerance)) {
      issues.push({
        kind: MeshDuplicateVertex,
        triangle_id: None,
        vertex_id: Some(vertex.id),
        message: "mesh contains duplicate vertices",
        measured: None,
        limit: Some(tolerance),
      })
    }
    seen.push(vertex.point)
  }
  for triangle in mesh.triangles {
    if triangle.is_degenerate() || triangle.area <= tolerance {
      issues.push({
        kind: MeshDegenerateTriangle,
        triangle_id: Some(triangle.id),
        vertex_id: None,
        message: "triangle area is below tolerance",
        measured: Some(triangle.area),
        limit: Some(tolerance),
      })
    }
    if triangle.clockwise {
      issues.push({
        kind: MeshInvertedTriangle,
        triangle_id: Some(triangle.id),
        vertex_id: None,
        message: "triangle winding is clockwise",
        measured: Some(triangle.area),
        limit: Some(0.0),
      })
    }
  }
  if mesh.source_holes > 0 {
    issues.push({
      kind: MeshHoleUnrepresented,
      triangle_id: None,
      vertex_id: None,
      message: "hole-aware triangulation uses centroid filtering; verify boundary closure",
      measured: Some(mesh.source_holes.to_double()),
      limit: Some(0.0),
    })
  }
  let area_error = (mesh.area() - mesh.source_area).abs()
  if area_error > tolerance * (1.0 + mesh.source_area.abs()) {
    issues.push({
      kind: MeshBoundaryMismatch,
      triangle_id: None,
      vertex_id: None,
      message: "mesh area differs from source polygon",
      measured: Some(area_error),
      limit: Some(tolerance),
    })
  }
  {
    valid: issues.all(issue => {
      issue.kind is MeshHoleUnrepresented || issue.kind is MeshInvertedTriangle
    }),
    issues,
    vertex_count: mesh.vertices.length(),
    triangle_count: mesh.triangles.length(),
    mesh_area: mesh.area(),
    source_area: mesh.source_area,
    area_error,
  }
}

///|
pub fn MeshValidation::error_count(self : MeshValidation) -> Int {
  self.issues
  .filter(issue => {
    issue.kind is MeshTooFewVertices ||
    issue.kind is MeshDegenerateTriangle ||
    issue.kind is MeshDuplicateVertex ||
    issue.kind is MeshNonFiniteVertex ||
    issue.kind is MeshBoundaryMismatch
  })
  .length()
}

///|
pub fn MeshValidation::warning_count(self : MeshValidation) -> Int {
  self.issues.length() - self.error_count()
}

///|
pub fn MeshValidation::is_valid(self : MeshValidation) -> Bool {
  self.valid && self.error_count() == 0
}

///|
pub fn MeshValidation::summary(self : MeshValidation) -> String {
  "valid=\{self.is_valid()}, vertices=\{self.vertex_count}, triangles=\{self.triangle_count}, mesh_area=\{self.mesh_area}, source_area=\{self.source_area}, area_error=\{self.area_error}, errors=\{self.error_count()}, warnings=\{self.warning_count()}"
}

///|
pub fn Mesh2::reoriented(self : Mesh2) -> Mesh2 {
  let triangles = self.triangles.map(triangle => {
    if triangle.clockwise {
      {
        id: triangle.id,
        a: triangle.c,
        b: triangle.b,
        c: triangle.a,
        area: triangle.area,
        centroid: triangle.centroid,
        clockwise: false,
      }
    } else {
      triangle
    }
  })
  {
    vertices: self.vertices,
    triangles,
    source_area: self.source_area,
    source_holes: self.source_holes,
  }
}

///|
pub fn Mesh2::translated(self : Mesh2, offset : Point2) -> Mesh2 {
  let vertices = self.vertices.map(vertex => {
    mesh_vertex(vertex.id, vertex.point.add(offset), vertex.boundary)
  })
  {
    vertices,
    triangles: self.triangles,
    source_area: self.source_area,
    source_holes: self.source_holes,
  }
}

///|
pub fn Mesh2::scaled(
  self : Mesh2,
  factor : Double,
  origin? : Point2 = point2(x=0.0, y=0.0),
) -> Mesh2 {
  let vertices = self.vertices.map(vertex => {
    mesh_vertex(
      vertex.id,
      origin.add(vertex.point.sub(origin).scale(factor)),
      vertex.boundary,
    )
  })
  let triangles = self.triangles.map(triangle => {
    let points = [
      vertices[triangle.a].point,
      vertices[triangle.b].point,
      vertices[triangle.c].point,
    ]
    let area = gk_cross(points[0], points[1], points[2]).abs() / 2.0
    {
      id: triangle.id,
      a: triangle.a,
      b: triangle.b,
      c: triangle.c,
      area,
      centroid: point2(
        x=(points[0].x + points[1].x + points[2].x) / 3.0,
        y=(points[0].y + points[1].y + points[2].y) / 3.0,
      ),
      clockwise: gk_cross(points[0], points[1], points[2]) < 0.0,
    }
  })
  {
    vertices,
    triangles,
    source_area: self.source_area * factor.abs() * factor.abs(),
    source_holes: self.source_holes,
  }
}

///|
pub fn mesh_to_obj(mesh : Mesh2) -> String {
  let mut output = "# moonbit-gerberkit mesh\n"
  for vertex in mesh.vertices {
    output += "v \{vertex.point.x} \{vertex.point.y} 0\n"
  }
  for triangle in mesh.triangles {
    output += "f \{triangle.a + 1} \{triangle.b + 1} \{triangle.c + 1}\n"
  }
  output
}

///|
pub fn mesh_vertex_to_json(value : MeshVertex) -> String {
  "{\"id\":\{value.id},\"x\":\{value.point.x},\"y\":\{value.point.y},\"boundary\":\{value.boundary}}"
}

///|
pub fn mesh_triangle_to_json(value : MeshTriangle) -> String {
  "{\"id\":\{value.id},\"a\":\{value.a},\"b\":\{value.b},\"c\":\{value.c},\"area\":\{value.area},\"centroid\":{\"x\":\{value.centroid.x},\"y\":\{value.centroid.y}},\"clockwise\":\{value.clockwise}}"
}

///|
pub fn mesh_to_json(mesh : Mesh2, include_triangles? : Bool = true) -> String {
  let triangles = if include_triangles {
    mesh.triangles.map(mesh_triangle_to_json).join(",")
  } else {
    ""
  }
  let vertices = mesh.vertices.map(mesh_vertex_to_json).join(",")
  "{\"vertex_count\":\{mesh.vertex_count()},\"triangle_count\":\{mesh.triangle_count()},\"area\":\{mesh.area()},\"source_area\":\{mesh.source_area},\"vertices\":[\{vertices}],\"triangles\":[\{triangles}]}"
}

///|
pub fn mesh_issue_to_json(issue : MeshIssue) -> String {
  let triangle = issue.triangle_id
    .map(value => value.to_string())
    .unwrap_or("null")
  let vertex = issue.vertex_id.map(value => value.to_string()).unwrap_or("null")
  let measured = issue.measured
    .map(value => value.to_string())
    .unwrap_or("null")
  let limit = issue.limit.map(value => value.to_string()).unwrap_or("null")
  "{\"kind\":\{json_string(mesh_issue_name(issue.kind))},\"triangle_id\":\{triangle},\"vertex_id\":\{vertex},\"message\":\{json_string(issue.message)},\"measured\":\{measured},\"limit\":\{limit}}"
}

///|
pub fn mesh_validation_to_json(value : MeshValidation) -> String {
  let issues = value.issues.map(mesh_issue_to_json).join(",")
  "{\"valid\":\{value.is_valid()},\"summary\":\{json_string(value.summary())},\"vertex_count\":\{value.vertex_count},\"triangle_count\":\{value.triangle_count},\"mesh_area\":\{value.mesh_area},\"source_area\":\{value.source_area},\"area_error\":\{value.area_error},\"issues\":[\{issues}]}"
}
