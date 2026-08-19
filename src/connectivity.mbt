///|
/// Lightweight board connectivity analysis.
///
/// Gerber files describe geometry rather than nets. This module therefore
/// reports geometric connectivity: segment endpoints, pads, flashes, drills,
/// and region terminals are connected when they share a shape or fall within
/// a caller-selected tolerance on the same layer. It is intentionally
/// deterministic and does not pretend to recover schematic net names.
pub enum ConnectivityNodeKind {
  TraceEndpoint
  PadTerminal
  DrillTerminal
  RegionTerminal
} derive(Debug, Eq)

///|
pub struct ConnectivityNode {
  id : Int
  layer_index : Int
  shape_index : Int
  point : Point2
  kind : ConnectivityNodeKind
} derive(Debug)

///|
pub struct ConnectivityLink {
  from : Int
  to : Int
  distance : Double
  internal : Bool
} derive(Debug)

///|
pub struct ConnectivityGraph {
  nodes : Array[ConnectivityNode]
  links : Array[ConnectivityLink]
  tolerance : Double
  component_count : Int
  total_length : Double
} derive(Debug)

///|
pub fn connectivity_kind_name(value : ConnectivityNodeKind) -> String {
  match value {
    TraceEndpoint => "trace-endpoint"
    PadTerminal => "pad-terminal"
    DrillTerminal => "drill-terminal"
    RegionTerminal => "region-terminal"
  }
}

///|
pub fn ConnectivityNode::kind_name(self : ConnectivityNode) -> String {
  connectivity_kind_name(self.kind)
}

///|
pub fn ConnectivityNode::is_drill(self : ConnectivityNode) -> Bool {
  self.kind is DrillTerminal
}

///|
pub fn ConnectivityNode::location(self : ConnectivityNode) -> Point2 {
  self.point
}

///|
pub fn ConnectivityLink::is_internal(self : ConnectivityLink) -> Bool {
  self.internal
}

///|
pub fn ConnectivityLink::format(self : ConnectivityLink) -> String {
  let relation = if self.internal { "internal" } else { "geometric" }
  "\{self.from}->\{self.to} \{relation} distance=\{self.distance}"
}

///|
pub fn ConnectivityGraph::node_count(self : ConnectivityGraph) -> Int {
  self.nodes.length()
}

///|
pub fn ConnectivityGraph::link_count(self : ConnectivityGraph) -> Int {
  self.links.length()
}

///|
pub fn ConnectivityGraph::component_count(self : ConnectivityGraph) -> Int {
  self.component_count
}

///|
pub fn ConnectivityGraph::isolated_node_count(self : ConnectivityGraph) -> Int {
  let mut count = 0
  for node in self.nodes {
    let mut degree = 0
    for link in self.links {
      if link.from == node.id || link.to == node.id {
        degree += 1
      }
    }
    if degree == 0 {
      count += 1
    }
  }
  count
}

///|
pub fn ConnectivityGraph::trace_endpoint_count(self : ConnectivityGraph) -> Int {
  self.nodes.filter(node => node.kind is TraceEndpoint).length()
}

///|
pub fn ConnectivityGraph::drill_terminal_count(self : ConnectivityGraph) -> Int {
  self.nodes.filter(node => node.kind is DrillTerminal).length()
}

///|
pub fn ConnectivityGraph::geometric_link_count(self : ConnectivityGraph) -> Int {
  self.links.filter(link => !link.internal).length()
}

///|
pub fn ConnectivityGraph::internal_link_count(self : ConnectivityGraph) -> Int {
  self.links.filter(link => link.internal).length()
}

///|
pub fn ConnectivityGraph::has_open_trace_endpoints(
  self : ConnectivityGraph,
) -> Bool {
  for node in self.nodes {
    if node.kind is TraceEndpoint {
      let mut degree = 0
      for link in self.links {
        if link.from == node.id || link.to == node.id {
          degree += 1
        }
      }
      if degree == 0 {
        return true
      }
    }
  }
  false
}

///|
pub fn ConnectivityGraph::summary(self : ConnectivityGraph) -> String {
  "nodes=\{self.node_count()}, links=\{self.link_count()}, components=\{self.component_count}, isolated=\{self.isolated_node_count()}, trace_endpoints=\{self.trace_endpoint_count()}, drills=\{self.drill_terminal_count()}, geometric_links=\{self.geometric_link_count()}, length=\{self.total_length}, tolerance=\{self.tolerance}"
}

///|
pub fn ConnectivityGraph::nodes(
  self : ConnectivityGraph,
) -> Array[ConnectivityNode] {
  self.nodes.copy()
}

///|
pub fn ConnectivityGraph::links(
  self : ConnectivityGraph,
) -> Array[ConnectivityLink] {
  self.links.copy()
}

///|
fn connectivity_shape_points(
  shape : Shape,
) -> (ConnectivityNodeKind, Array[Point2]) {
  match shape {
    Segment(x1~, y1~, x2~, y2~, ..) =>
      (TraceEndpoint, [point2(x=x1, y=y1), point2(x=x2, y=y2)])
    Pad(x~, y~, ..) | Flash(x~, y~, ..) => (PadTerminal, [point2(x~, y~)])
    DrillHit(x~, y~, ..) => (DrillTerminal, [point2(x~, y~)])
    Region(points~) =>
      match points.get(0) {
        Some(pair) => (RegionTerminal, [point2(x=pair.0, y=pair.1)])
        None => (RegionTerminal, [])
      }
  }
}

///|
fn connectivity_add_node(
  nodes : Array[ConnectivityNode],
  layer_index : Int,
  shape_index : Int,
  kind : ConnectivityNodeKind,
  point : Point2,
) -> Int {
  let id = nodes.length()
  nodes.push({ id, layer_index, shape_index, point, kind })
  id
}

///|
fn connectivity_add_link(
  links : Array[ConnectivityLink],
  from : Int,
  to : Int,
  nodes : Array[ConnectivityNode],
  internal : Bool,
) -> Double {
  let distance = nodes[from].point.distance(nodes[to].point)
  links.push({ from, to, distance, internal })
  distance
}

///|
fn connectivity_same_shape_links(
  nodes : Array[ConnectivityNode],
  links : Array[ConnectivityLink],
  groups : Array[Array[Int]],
) -> Double {
  let mut total = 0.0
  for group in groups {
    if group.length() > 1 {
      for index in 1..<group.length() {
        total += connectivity_add_link(
          links,
          group[index - 1],
          group[index],
          nodes,
          true,
        )
      }
    }
  }
  total
}

///|
fn connectivity_near_links(
  nodes : Array[ConnectivityNode],
  links : Array[ConnectivityLink],
  tolerance : Double,
) -> Double {
  let mut total = 0.0
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      let a = nodes[i]
      let b = nodes[j]
      if a.layer_index == b.layer_index &&
        a.shape_index != b.shape_index &&
        a.point.distance(b.point) <= tolerance {
        total += connectivity_add_link(links, a.id, b.id, nodes, false)
      }
    }
  }
  total
}

///|
fn connectivity_components(
  nodes : Array[ConnectivityNode],
  links : Array[ConnectivityLink],
) -> Int {
  let visited : Array[Bool] = []
  for _ in nodes {
    visited.push(false)
  }
  let mut components = 0
  for start in 0..<nodes.length() {
    if !visited[start] {
      components += 1
      visited[start] = true
      let queue : Array[Int] = [start]
      let mut cursor = 0
      while cursor < queue.length() {
        let current = queue[cursor]
        cursor += 1
        for link in links {
          let next = if link.from == current {
            Some(link.to)
          } else if link.to == current {
            Some(link.from)
          } else {
            None
          }
          match next {
            Some(value) if !visited[value] => {
              visited[value] = true
              queue.push(value)
            }
            _ => ()
          }
        }
      }
    }
  }
  components
}

///|
pub fn build_connectivity(
  board : Board,
  tolerance? : Double = 0.001,
) -> ConnectivityGraph {
  let effective_tolerance = if tolerance < 0.0 { 0.0 } else { tolerance }
  let nodes : Array[ConnectivityNode] = []
  let groups : Array[Array[Int]] = []
  for layer_index, layer in board.layers {
    for shape_index, shape in layer.shapes {
      let (kind, points) = connectivity_shape_points(shape)
      let group : Array[Int] = []
      for point in points {
        group.push(
          connectivity_add_node(nodes, layer_index, shape_index, kind, point),
        )
      }
      if group.length() > 0 {
        groups.push(group)
      }
    }
  }
  let links : Array[ConnectivityLink] = []
  let mut total_length = connectivity_same_shape_links(nodes, links, groups)
  total_length += connectivity_near_links(nodes, links, effective_tolerance)
  {
    nodes,
    links,
    tolerance: effective_tolerance,
    component_count: connectivity_components(nodes, links),
    total_length,
  }
}

///|
pub fn ConnectivityGraph::layer_node_count(
  self : ConnectivityGraph,
  layer_index : Int,
) -> Int {
  self.nodes.filter(node => node.layer_index == layer_index).length()
}

///|
pub fn ConnectivityGraph::layer_link_count(
  self : ConnectivityGraph,
  layer_index : Int,
) -> Int {
  self.links
  .filter(link => {
    self.nodes[link.from].layer_index == layer_index &&
    self.nodes[link.to].layer_index == layer_index
  })
  .length()
}

///|
pub fn ConnectivityGraph::to_json(self : ConnectivityGraph) -> String {
  let nodes = self.nodes
    .map(node => {
      "{\"id\":\{node.id},\"layer\":\{node.layer_index},\"shape\":\{node.shape_index},\"x\":\{node.point.x},\"y\":\{node.point.y},\"kind\":\{json_string(node.kind_name())}}"
    })
    .join(",")
  let links = self.links
    .map(link => {
      "{\"from\":\{link.from},\"to\":\{link.to},\"distance\":\{link.distance},\"internal\":\{link.internal}}"
    })
    .join(",")
  "{\"summary\":\{json_string(self.summary())},\"tolerance\":\{self.tolerance},\"components\":\{self.component_count},\"total_length\":\{self.total_length},\"nodes\":[\{nodes}],\"links\":[\{links}]}"
}

///|
pub fn ConnectivityGraph::to_csv(self : ConnectivityGraph) -> String {
  let mut result = "kind,id,layer,shape,x,y\n"
  for node in self.nodes {
    result += "node,\{node.id},\{node.layer_index},\{node.shape_index},\{node.point.x},\{node.point.y},\{node.kind_name()}\n"
  }
  result += "\nfrom,to,distance,internal\n"
  for link in self.links {
    result += "\{link.from},\{link.to},\{link.distance},\{link.internal}\n"
  }
  result
}

///|
pub fn ConnectivityGraph::layer_summary(
  self : ConnectivityGraph,
  layer_index : Int,
) -> String {
  "layer=\{layer_index}, nodes=\{self.layer_node_count(layer_index)}, links=\{self.layer_link_count(layer_index)}"
}

///|
pub fn connectivity_from_board(board : Board) -> ConnectivityGraph {
  build_connectivity(board, tolerance=0.001)
}
