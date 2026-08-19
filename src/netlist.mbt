///|
/// Geometric netlist inference for Gerber-only projects. A Gerber set does
/// not carry schematic connectivity in a portable way, so this module makes
/// the inference assumptions explicit: same-layer terminals join within a
/// tolerance, and caller-provided labels anchor component names.
pub enum NetTerminalKind {
  NetTraceEndpoint
  NetPad
  NetVia
  NetRegion
  NetDrill
} derive(Debug, Eq)

///|
pub enum NetIssueSeverity {
  NetInfo
  NetWarning
  NetError
} derive(Debug, Eq)

///|
pub enum NetIssueRule {
  UnnamedComponent
  FloatingTerminal
  UnconnectedNet
  UnexpectedCrossLayerJoin
  NetShortCandidate
  DuplicateLabel
  MissingReference
  EmptyNetlist
} derive(Debug, Eq)

///|
pub struct NetTerminal {
  id : Int
  node_id : Int
  layer_index : Int
  layer_name : String
  shape_index : Int
  kind : NetTerminalKind
  point : Point2
  net_name : String?
} derive(Debug)

///|
pub struct NetLink {
  from : Int
  to : Int
  distance : Double
  layer_index : Int
  geometric : Bool
} derive(Debug)

///|
pub struct NetDefinition {
  name : String
  class_name : String
  expected_terminals : Int
  max_length : Double?
  min_clearance : Double
  reference_net : Bool
} derive(Debug)

///|
pub struct NetIssue {
  rule : NetIssueRule
  severity : NetIssueSeverity
  net_name : String
  message : String
  terminal_id : Int?
  location : Point2?
  measured : Double?
  limit : Double?
} derive(Debug)

///|
pub struct NetComponent {
  id : Int
  terminal_ids : Array[Int]
  net_name : String?
  layer_count : Int
  length : Double
  bounds : Rect2?
} derive(Debug)

///|
pub struct Netlist {
  terminals : Array[NetTerminal]
  links : Array[NetLink]
  components : Array[NetComponent]
  definitions : Array[NetDefinition]
  issues : Array[NetIssue]
  tolerance : Double
} derive(Debug)

///|
pub struct NetLabel {
  name : String
  layer_index : Int
  point : Point2
  radius : Double
} derive(Debug)

///|
pub struct NetStatistics {
  net_count : Int
  terminal_count : Int
  component_count : Int
  named_terminal_count : Int
  floating_terminal_count : Int
  longest_net : Double
  average_terminals : Double
} derive(Debug)

///|
pub fn net_terminal_kind_name(value : NetTerminalKind) -> String {
  match value {
    NetTraceEndpoint => "trace-endpoint"
    NetPad => "pad"
    NetVia => "via"
    NetRegion => "region"
    NetDrill => "drill"
  }
}

///|
pub fn net_drill_terminal_kind() -> NetTerminalKind {
  NetDrill
}

///|
pub fn net_issue_severity_name(value : NetIssueSeverity) -> String {
  match value {
    NetInfo => "info"
    NetWarning => "warning"
    NetError => "error"
  }
}

///|
pub fn net_issue_rule_name(value : NetIssueRule) -> String {
  match value {
    UnnamedComponent => "unnamed-component"
    FloatingTerminal => "floating-terminal"
    UnconnectedNet => "unconnected-net"
    UnexpectedCrossLayerJoin => "unexpected-cross-layer-join"
    NetShortCandidate => "net-short-candidate"
    DuplicateLabel => "duplicate-label"
    MissingReference => "missing-reference"
    EmptyNetlist => "empty-netlist"
  }
}

///|
pub fn net_definition(
  name~ : String,
  class_name~ : String,
  expected_terminals~ : Int,
  max_length~ : Double?,
  min_clearance~ : Double,
  reference_net~ : Bool,
) -> NetDefinition {
  {
    name,
    class_name,
    expected_terminals: if expected_terminals < 0 {
      0
    } else {
      expected_terminals
    },
    max_length,
    min_clearance: if min_clearance < 0.0 {
      0.0
    } else {
      min_clearance
    },
    reference_net,
  }
}

///|
pub fn net_label(
  name~ : String,
  layer_index~ : Int,
  point~ : Point2,
  radius? : Double = 0.001,
) -> NetLabel {
  {
    name,
    layer_index,
    point,
    radius: if radius < 0.0 {
      -radius
    } else {
      radius
    },
  }
}

///|
pub fn NetLabel::matches(
  self : NetLabel,
  layer_index : Int,
  point : Point2,
) -> Bool {
  self.layer_index == layer_index && self.point.distance(point) <= self.radius
}

///|
pub fn NetLabel::is_reference(self : NetLabel) -> Bool {
  self.name == "GND" ||
  self.name == "VSS" ||
  self.name == "AGND" ||
  self.name == "PGND"
}

///|
pub fn NetTerminal::kind_name(self : NetTerminal) -> String {
  net_terminal_kind_name(self.kind)
}

///|
pub fn NetTerminal::is_named(self : NetTerminal) -> Bool {
  self.net_name is Some(_)
}

///|
pub fn NetTerminal::name(self : NetTerminal) -> String {
  self.net_name.unwrap_or("")
}

///|
pub fn NetTerminal::location(self : NetTerminal) -> Point2 {
  self.point
}

///|
pub fn NetLink::is_cross_layer(
  self : NetLink,
  terminals : Array[NetTerminal],
) -> Bool {
  terminals[self.from].layer_index != terminals[self.to].layer_index
}

///|
pub fn NetComponent::terminal_count(self : NetComponent) -> Int {
  self.terminal_ids.length()
}

///|
pub fn NetComponent::is_named(self : NetComponent) -> Bool {
  self.net_name is Some(_)
}

///|
pub fn NetComponent::name(self : NetComponent) -> String {
  self.net_name.unwrap_or("")
}

///|
pub fn NetComponent::is_floating(self : NetComponent) -> Bool {
  self.terminal_ids.length() <= 1
}

///|
pub fn Netlist::terminal_count(self : Netlist) -> Int {
  self.terminals.length()
}

///|
pub fn Netlist::link_count(self : Netlist) -> Int {
  self.links.length()
}

///|
pub fn Netlist::component_count(self : Netlist) -> Int {
  self.components.length()
}

///|
pub fn Netlist::named_terminal_count(self : Netlist) -> Int {
  self.terminals.filter(terminal => terminal.is_named()).length()
}

///|
pub fn Netlist::error_count(self : Netlist) -> Int {
  self.issues.filter(issue => issue.severity is NetError).length()
}

///|
pub fn Netlist::warning_count(self : Netlist) -> Int {
  self.issues.filter(issue => issue.severity is NetWarning).length()
}

///|
pub fn Netlist::is_valid(self : Netlist) -> Bool {
  self.error_count() == 0
}

///|
pub fn Netlist::statistics(self : Netlist) -> NetStatistics {
  let names : Array[String] = []
  let mut longest = 0.0
  let mut total_terminals = 0
  for component in self.components {
    if component.name() != "" && !names.contains(component.name()) {
      names.push(component.name())
    }
    if component.length > longest {
      longest = component.length
    }
    total_terminals += component.terminal_count()
  }
  let named = self.named_terminal_count()
  {
    net_count: names.length(),
    terminal_count: self.terminals.length(),
    component_count: self.components.length(),
    named_terminal_count: named,
    floating_terminal_count: self.components
    .filter(component => component.is_floating())
    .length(),
    longest_net: longest,
    average_terminals: if self.components.length() == 0 {
      0.0
    } else {
      total_terminals.to_double() / self.components.length().to_double()
    },
  }
}

///|
pub fn Netlist::summary(self : Netlist) -> String {
  let stats = self.statistics()
  "nets=\{stats.net_count}, terminals=\{stats.terminal_count}, components=\{stats.component_count}, named=\{stats.named_terminal_count}, floating=\{stats.floating_terminal_count}, errors=\{self.error_count()}, warnings=\{self.warning_count()}"
}

///|
fn nl_kind(shape : Shape) -> NetTerminalKind {
  match shape {
    Segment(..) => NetTraceEndpoint
    Pad(..) | Flash(..) => NetPad
    DrillHit(..) => NetVia
    Region(..) => NetRegion
  }
}

///|
fn nl_points(shape : Shape) -> Array[Point2] {
  match shape {
    Segment(x1~, y1~, x2~, y2~, ..) => [point2(x=x1, y=y1), point2(x=x2, y=y2)]
    Pad(x~, y~, ..) | Flash(x~, y~, ..) | DrillHit(x~, y~, ..) =>
      [point2(x~, y~)]
    Region(points~) => points.map(pair => point2(x=pair.0, y=pair.1))
  }
}

///|
fn nl_make_terminals(board : Board) -> Array[NetTerminal] {
  let result : Array[NetTerminal] = []
  let mut node_id = 0
  for layer_index, layer in board.layers {
    for shape_index, shape in layer.shapes {
      let kind = nl_kind(shape)
      let points = nl_points(shape)
      for point in points {
        result.push({
          id: result.length(),
          node_id,
          layer_index,
          layer_name: layer.name,
          shape_index,
          kind,
          point,
          net_name: None,
        })
        node_id += 1
      }
    }
  }
  result
}

///|
fn nl_link_terminals(
  terminals : Array[NetTerminal],
  tolerance : Double,
) -> Array[NetLink] {
  let links : Array[NetLink] = []
  for i in 0..<terminals.length() {
    for j in (i + 1)..<terminals.length() {
      let first = terminals[i]
      let second = terminals[j]
      if first.layer_index == second.layer_index &&
        first.shape_index != second.shape_index &&
        first.point.distance(second.point) <= tolerance {
        links.push({
          from: i,
          to: j,
          distance: first.point.distance(second.point),
          layer_index: first.layer_index,
          geometric: true,
        })
      }
    }
  }
  links
}

///|
fn nl_find(parent : Array[Int], value : Int) -> Int {
  let mut current = value
  while parent[current] != current {
    current = parent[current]
  }
  current
}

///|
fn nl_union(parent : Array[Int], first : Int, second : Int) -> Unit {
  let left = nl_find(parent, first)
  let right = nl_find(parent, second)
  if left != right {
    parent[right] = left
  }
}

///|
fn nl_components(
  terminals : Array[NetTerminal],
  links : Array[NetLink],
) -> Array[NetComponent] {
  let parent : Array[Int] = []
  for index in 0..<terminals.length() {
    parent.push(index)
  }
  for link in links {
    nl_union(parent, link.from, link.to)
  }
  let groups : Map[Int, Array[Int]] = Map([])
  for terminal in terminals {
    let root = nl_find(parent, terminal.id)
    groups.update(root, values => {
      match values {
        Some(old) => {
          old.push(terminal.id)
          Some(old)
        }
        None => Some([terminal.id])
      }
    })
  }
  let components : Array[NetComponent] = []
  for entry in groups {
    let terminal_ids = entry.1
    let layer_names : Array[Int] = []
    let mut length = 0.0
    let mut bounds : Rect2? = None
    for id in terminal_ids {
      let terminal = terminals[id]
      if !layer_names.contains(terminal.layer_index) {
        layer_names.push(terminal.layer_index)
      }
      match bounds {
        None =>
          bounds = Some(
            rect2(
              min_x=terminal.point.x,
              min_y=terminal.point.y,
              max_x=terminal.point.x,
              max_y=terminal.point.y,
            ),
          )
        Some(old) => bounds = Some(old.include_point(terminal.point))
      }
    }
    for link in links {
      if terminal_ids.contains(link.from) && terminal_ids.contains(link.to) {
        length += link.distance
      }
    }
    components.push({
      id: components.length(),
      terminal_ids,
      net_name: None,
      layer_count: layer_names.length(),
      length,
      bounds,
    })
  }
  components
}

///|
fn nl_label_terminal(
  terminal : NetTerminal,
  labels : Array[NetLabel],
) -> String? {
  for label in labels {
    if label.matches(terminal.layer_index, terminal.point) {
      return Some(label.name)
    }
  }
  None
}

///|
fn nl_labeled_terminals(
  terminals : Array[NetTerminal],
  labels : Array[NetLabel],
) -> Array[NetTerminal] {
  terminals.map(terminal => {
    id: terminal.id,
    node_id: terminal.node_id,
    layer_index: terminal.layer_index,
    layer_name: terminal.layer_name,
    shape_index: terminal.shape_index,
    kind: terminal.kind,
    point: terminal.point,
    net_name: nl_label_terminal(terminal, labels),
  })
}

///|
fn nl_labeled_components(
  terminals : Array[NetTerminal],
  components : Array[NetComponent],
) -> Array[NetComponent] {
  components.map(component => {
    let names : Array[String] = []
    for id in component.terminal_ids {
      match terminals[id].net_name {
        Some(name) if !names.contains(name) => names.push(name)
        _ => ()
      }
    }
    let name = if names.length() == 1 { Some(names[0]) } else { None }
    {
      id: component.id,
      terminal_ids: component.terminal_ids,
      net_name: name,
      layer_count: component.layer_count,
      length: component.length,
      bounds: component.bounds,
    }
  })
}

///|
fn nl_issue(
  rule : NetIssueRule,
  severity : NetIssueSeverity,
  net_name : String,
  message : String,
  terminal_id : Int?,
  location : Point2?,
  measured : Double?,
  limit : Double?,
) -> NetIssue {
  { rule, severity, net_name, message, terminal_id, location, measured, limit }
}

///|
fn nl_validate(
  terminals : Array[NetTerminal],
  components : Array[NetComponent],
  definitions : Array[NetDefinition],
  labels : Array[NetLabel],
) -> Array[NetIssue] {
  let issues : Array[NetIssue] = []
  if labels.length() > 0 {
    issues.push(
      nl_issue(
        NetShortCandidate,
        NetInfo,
        "",
        "geometric labels were applied with tolerance matching",
        None,
        None,
        Some(labels.length().to_double()),
        None,
      ),
    )
  }
  if terminals.length() == 0 {
    issues.push(
      nl_issue(
        EmptyNetlist,
        NetError,
        "",
        "board contains no net terminals",
        None,
        None,
        None,
        None,
      ),
    )
    return issues
  }
  for component in components {
    if component.is_floating() {
      let point = terminals[component.terminal_ids[0]].point
      issues.push(
        nl_issue(
          FloatingTerminal,
          NetWarning,
          component.name(),
          "component has one or fewer geometric terminals",
          Some(component.terminal_ids[0]),
          Some(point),
          Some(component.terminal_count().to_double()),
          Some(2.0),
        ),
      )
    }
    if !component.is_named() {
      issues.push(
        nl_issue(
          UnnamedComponent,
          NetWarning,
          "",
          "geometric component has no unique label",
          None,
          component.bounds.map(value => value.center()),
          None,
          None,
        ),
      )
    }
    let component_names : Array[String] = []
    for id in component.terminal_ids {
      match terminals[id].net_name {
        Some(name) if !component_names.contains(name) =>
          component_names.push(name)
        _ => ()
      }
    }
    if component_names.length() > 1 {
      issues.push(
        nl_issue(
          NetShortCandidate,
          NetError,
          component_names.join("|"),
          "one geometric component carries multiple labels",
          None,
          component.bounds.map(value => value.center()),
          None,
          None,
        ),
      )
    }
  }
  for label in labels {
    let mut count = 0
    for terminal in terminals {
      if label.matches(terminal.layer_index, terminal.point) {
        count += 1
      }
    }
    if count == 0 {
      issues.push(
        nl_issue(
          UnconnectedNet,
          NetWarning,
          label.name,
          "label does not match any geometric terminal",
          None,
          Some(label.point),
          Some(0.0),
          Some(1.0),
        ),
      )
    }
  }
  let names : Array[String] = []
  for label in labels {
    if names.contains(label.name) {
      issues.push(
        nl_issue(
          DuplicateLabel,
          NetWarning,
          label.name,
          "net label appears more than once",
          None,
          Some(label.point),
          None,
          None,
        ),
      )
    } else {
      names.push(label.name)
    }
  }
  for definition in definitions {
    let mut found : NetComponent? = None
    for component in components {
      if component.name() == definition.name {
        found = Some(component)
      }
    }
    match found {
      None =>
        issues.push(
          nl_issue(
            MissingReference,
            NetError,
            definition.name,
            "defined net is absent from geometry",
            None,
            None,
            None,
            None,
          ),
        )
      Some(component) => {
        if definition.expected_terminals > 0 &&
          component.terminal_count() != definition.expected_terminals {
          issues.push(
            nl_issue(
              UnconnectedNet,
              NetError,
              definition.name,
              "terminal count differs from net definition",
              None,
              component.bounds.map(value => value.center()),
              Some(component.terminal_count().to_double()),
              Some(definition.expected_terminals.to_double()),
            ),
          )
        }
        match definition.max_length {
          Some(limit) if component.length > limit =>
            issues.push(
              nl_issue(
                UnconnectedNet,
                NetWarning,
                definition.name,
                "net length exceeds definition",
                None,
                component.bounds.map(value => value.center()),
                Some(component.length),
                Some(limit),
              ),
            )
          _ => ()
        }
      }
    }
  }
  if definitions.any(definition => definition.reference_net) &&
    !components.any(component => {
      component.name() == "GND" || component.name() == "VSS"
    }) {
    issues.push(
      nl_issue(
        MissingReference,
        NetWarning,
        "GND",
        "no reference net was found",
        None,
        None,
        None,
        None,
      ),
    )
  }
  issues
}

///|
pub fn build_netlist(
  board : Board,
  labels? : Array[NetLabel] = [],
  definitions? : Array[NetDefinition] = [],
  tolerance? : Double = 0.001,
) -> Netlist {
  let safe_tolerance = if tolerance < 0.0 { -tolerance } else { tolerance }
  let raw_terminals = nl_make_terminals(board)
  let links = nl_link_terminals(raw_terminals, safe_tolerance)
  let raw_components = nl_components(raw_terminals, links)
  let terminals = nl_labeled_terminals(raw_terminals, labels)
  let components = nl_labeled_components(terminals, raw_components)
  let issues = nl_validate(terminals, components, definitions, labels)
  {
    terminals,
    links,
    components,
    definitions,
    issues,
    tolerance: safe_tolerance,
  }
}

///|
pub fn netlist_from_board(
  board : Board,
  tolerance? : Double = 0.001,
) -> Netlist {
  build_netlist(board, tolerance~)
}

///|
pub fn Netlist::with_labels(
  self : Netlist,
  labels : Array[NetLabel],
) -> Netlist {
  let terminals = nl_labeled_terminals(self.terminals, labels)
  let components = nl_labeled_components(terminals, self.components)
  let issues = nl_validate(terminals, components, self.definitions, labels)
  {
    terminals,
    links: self.links,
    components,
    definitions: self.definitions,
    issues,
    tolerance: self.tolerance,
  }
}

///|
pub fn Netlist::with_definitions(
  self : Netlist,
  definitions : Array[NetDefinition],
) -> Netlist {
  let issues = nl_validate(self.terminals, self.components, definitions, [])
  {
    terminals: self.terminals,
    links: self.links,
    components: self.components,
    definitions,
    issues,
    tolerance: self.tolerance,
  }
}

///|
pub fn Netlist::terminal(self : Netlist, id : Int) -> NetTerminal? {
  self.terminals.get(id)
}

///|
pub fn Netlist::component(self : Netlist, id : Int) -> NetComponent? {
  self.components.get(id)
}

///|
pub fn Netlist::find_net(self : Netlist, name : String) -> Array[NetTerminal] {
  self.terminals.filter(terminal => terminal.name() == name)
}

///|
pub fn Netlist::net_names(self : Netlist) -> Array[String] {
  let names : Array[String] = []
  for terminal in self.terminals {
    match terminal.net_name {
      Some(name) if !names.contains(name) => names.push(name)
      _ => ()
    }
  }
  names
}

///|
pub fn Netlist::net_length(self : Netlist, name : String) -> Double {
  let ids = self.terminals
    .filter(terminal => terminal.name() == name)
    .map(terminal => terminal.id)
  self.links.fold(init=0.0, (total, link) => {
    if ids.contains(link.from) && ids.contains(link.to) {
      total + link.distance
    } else {
      total
    }
  })
}

///|
pub fn Netlist::net_clearance(
  self : Netlist,
  first : String,
  second : String,
) -> Double {
  let a = self.terminals.filter(terminal => terminal.name() == first)
  let b = self.terminals.filter(terminal => terminal.name() == second)
  let mut best = 1000000000.0
  for left in a {
    for right in b {
      if left.layer_index == right.layer_index {
        let distance = left.point.distance(right.point)
        if distance < best {
          best = distance
        }
      }
    }
  }
  best
}

///|
pub fn Netlist::unconnected_terminals(self : Netlist) -> Array[NetTerminal] {
  let result : Array[NetTerminal] = []
  for component in self.components {
    if component.is_floating() {
      for id in component.terminal_ids {
        result.push(self.terminals[id])
      }
    }
  }
  result
}

///|
pub fn Netlist::named_components(self : Netlist) -> Array[NetComponent] {
  self.components.filter(component => component.is_named())
}

///|
pub fn Netlist::reference_components(self : Netlist) -> Array[NetComponent] {
  self.components.filter(component => {
    component.name() == "GND" ||
    component.name() == "VSS" ||
    component.name() == "AGND"
  })
}

///|
pub fn Netlist::cross_layer_links(self : Netlist) -> Array[NetLink] {
  self.links.filter(link => link.is_cross_layer(self.terminals))
}

///|
pub fn Netlist::max_component_length(self : Netlist) -> Double {
  self.components.fold(init=0.0, (best, component) => {
    if component.length > best {
      component.length
    } else {
      best
    }
  })
}

///|
pub fn Netlist::label_coverage(self : Netlist) -> Double {
  if self.terminals.length() == 0 {
    0.0
  } else {
    self.named_terminal_count().to_double() /
    self.terminals.length().to_double()
  }
}

///|
pub fn net_statistics_to_json(value : NetStatistics) -> String {
  "{\"net_count\":\{value.net_count},\"terminal_count\":\{value.terminal_count},\"component_count\":\{value.component_count},\"named_terminal_count\":\{value.named_terminal_count},\"floating_terminal_count\":\{value.floating_terminal_count},\"longest_net\":\{value.longest_net},\"average_terminals\":\{value.average_terminals}}"
}

///|
pub fn net_issue_to_json(issue : NetIssue) -> String {
  let id = issue.terminal_id.map(value => value.to_string()).unwrap_or("null")
  let location = match issue.location {
    Some(point) => "{\"x\":\{point.x},\"y\":\{point.y}}"
    None => "null"
  }
  let measured = issue.measured
    .map(value => value.to_string())
    .unwrap_or("null")
  let limit = issue.limit.map(value => value.to_string()).unwrap_or("null")
  "{\"rule\":\{json_string(net_issue_rule_name(issue.rule))},\"severity\":\{json_string(net_issue_severity_name(issue.severity))},\"net\":\{json_string(issue.net_name)},\"message\":\{json_string(issue.message)},\"terminal_id\":\{id},\"location\":\{location},\"measured\":\{measured},\"limit\":\{limit}}"
}

///|
pub fn net_terminal_to_json(terminal : NetTerminal) -> String {
  let name = terminal.net_name.map(json_string).unwrap_or("null")
  "{\"id\":\{terminal.id},\"node_id\":\{terminal.node_id},\"layer_index\":\{terminal.layer_index},\"layer\":\{json_string(terminal.layer_name)},\"shape_index\":\{terminal.shape_index},\"kind\":\{json_string(terminal.kind_name())},\"x\":\{terminal.point.x},\"y\":\{terminal.point.y},\"net\":\{name}}"
}

///|
pub fn net_component_to_json(component : NetComponent) -> String {
  let name = component.net_name.map(json_string).unwrap_or("null")
  let bounds = match component.bounds {
    Some(value) =>
      "{\"min_x\":\{value.min_x},\"min_y\":\{value.min_y},\"max_x\":\{value.max_x},\"max_y\":\{value.max_y}}"
    None => "null"
  }
  let terminal_ids = component.terminal_ids
    .map(value => value.to_string())
    .join(",")
  "{\"id\":\{component.id},\"terminal_ids\":[\{terminal_ids}],\"net\":\{name},\"layer_count\":\{component.layer_count},\"length\":\{component.length},\"bounds\":\{bounds}}"
}

///|
pub fn netlink_to_json(link : NetLink) -> String {
  "{\"from\":\{link.from},\"to\":\{link.to},\"distance\":\{link.distance},\"layer_index\":\{link.layer_index},\"geometric\":\{link.geometric}}"
}

///|
pub fn netlist_to_json(
  value : Netlist,
  include_terminals? : Bool = true,
  include_links? : Bool = false,
) -> String {
  let terminals = if include_terminals {
    ",\"terminals\":[" +
    value.terminals.map(net_terminal_to_json).join(",") +
    "]"
  } else {
    ""
  }
  let links = if include_links {
    ",\"links\":[" + value.links.map(netlink_to_json).join(",") + "]"
  } else {
    ""
  }
  let components = value.components.map(net_component_to_json).join(",")
  let issues = value.issues.map(net_issue_to_json).join(",")
  "{\"summary\":\{json_string(value.summary())},\"tolerance\":\{value.tolerance},\"statistics\":\{net_statistics_to_json(value.statistics())},\"components\":[\{components}],\"issues\":[\{issues}]\{terminals}\{links}}"
}

///|
pub fn netlist_to_csv(value : Netlist) -> String {
  let mut output = "terminal_id,node_id,layer_index,layer,shape_index,kind,x,y,net\n"
  for terminal in value.terminals {
    output += terminal.id.to_string() +
      "," +
      terminal.node_id.to_string() +
      "," +
      terminal.layer_index.to_string() +
      "," +
      json_escape(terminal.layer_name) +
      "," +
      terminal.shape_index.to_string() +
      "," +
      terminal.kind_name() +
      "," +
      terminal.point.x.to_string() +
      "," +
      terminal.point.y.to_string() +
      "," +
      json_escape(terminal.name()) +
      "\n"
  }
  output
}

///|
pub fn netlist_to_text(value : Netlist) -> String {
  let mut output = value.summary() + "\n"
  output += "label_coverage=\{value.label_coverage()} max_length=\{value.max_component_length()}\n"
  for component in value.components {
    output += "- component \{component.id}: net=\{component.name()}, terminals=\{component.terminal_count()}, layers=\{component.layer_count}, length=\{component.length}\n"
  }
  if value.issues.length() > 0 {
    output += "Issues:\n"
    for issue in value.issues {
      output += "  - \{net_issue_severity_name(issue.severity)} \{net_issue_rule_name(issue.rule)} [\{issue.net_name}]: \{issue.message}\n"
    }
  }
  output
}

///|
pub fn NetDefinition::to_json(self : NetDefinition) -> String {
  let max_length = self.max_length
    .map(value => value.to_string())
    .unwrap_or("null")
  "{\"name\":\{json_string(self.name)},\"class\":\{json_string(self.class_name)},\"expected_terminals\":\{self.expected_terminals},\"max_length\":\{max_length},\"min_clearance\":\{self.min_clearance},\"reference\":\{self.reference_net}}"
}

///|
pub fn Netlist::definition(self : Netlist, name : String) -> NetDefinition? {
  for definition in self.definitions {
    if definition.name == name {
      return Some(definition)
    }
  }
  None
}

///|
pub fn Netlist::net_is_reference(self : Netlist, name : String) -> Bool {
  match self.definition(name) {
    Some(definition) => definition.reference_net
    None => name == "GND" || name == "VSS"
  }
}

///|
pub fn Netlist::net_passes_length(self : Netlist, name : String) -> Bool {
  match self.definition(name) {
    Some(definition) =>
      match definition.max_length {
        Some(limit) => self.net_length(name) <= limit
        None => true
      }
    None => true
  }
}

///|
pub fn Netlist::nets_by_class(
  self : Netlist,
  class_name : String,
) -> Array[String] {
  let result : Array[String] = []
  for definition in self.definitions {
    if definition.class_name == class_name {
      result.push(definition.name)
    }
  }
  result
}

///|
pub fn Netlist::issue_rules(self : Netlist) -> Array[String] {
  let result : Array[String] = []
  for issue in self.issues {
    let rule = net_issue_rule_name(issue.rule)
    if !result.contains(rule) {
      result.push(rule)
    }
  }
  result
}

///|
pub fn Netlist::component_for_terminal(
  self : Netlist,
  terminal_id : Int,
) -> NetComponent? {
  for component in self.components {
    if component.terminal_ids.contains(terminal_id) {
      return Some(component)
    }
  }
  None
}

///|
pub fn Netlist::connected(self : Netlist, first : Int, second : Int) -> Bool {
  match
    (self.component_for_terminal(first), self.component_for_terminal(second)) {
    (Some(left), Some(right)) => left.id == right.id
    _ => false
  }
}

///|
pub fn Netlist::short_candidates(self : Netlist) -> Array[NetIssue] {
  self.issues.filter(issue => issue.rule is NetShortCandidate)
}

///|
pub fn Netlist::floating_components(self : Netlist) -> Array[NetComponent] {
  self.components.filter(component => component.is_floating())
}

///|
pub fn Netlist::net_count(self : Netlist) -> Int {
  self.net_names().length()
}

///|
pub fn Netlist::layer_names(self : Netlist) -> Array[String] {
  let names : Array[String] = []
  for terminal in self.terminals {
    if !names.contains(terminal.layer_name) {
      names.push(terminal.layer_name)
    }
  }
  names
}

///|
pub fn Netlist::total_geometric_length(self : Netlist) -> Double {
  self.links.fold(init=0.0, (total, link) => total + link.distance)
}

///|
pub fn Netlist::cross_layer_count(self : Netlist) -> Int {
  self.cross_layer_links().length()
}

///|
pub fn Netlist::cross_layer_issue(self : Netlist) -> NetIssue? {
  match self.cross_layer_links().get(0) {
    Some(link) =>
      Some(
        nl_issue(
          UnexpectedCrossLayerJoin,
          NetWarning,
          "",
          "link crosses layers without a named via policy",
          None,
          Some(self.terminals[link.from].point),
          Some(link.distance),
          None,
        ),
      )
    None => None
  }
}

///|
pub fn net_label_to_json(value : NetLabel) -> String {
  "{\"name\":\{json_string(value.name)},\"layer_index\":\{value.layer_index},\"x\":\{value.point.x},\"y\":\{value.point.y},\"radius\":\{value.radius}}"
}

///|
pub fn netlist_with_labels(
  board : Board,
  labels : Array[NetLabel],
  definitions? : Array[NetDefinition] = [],
  tolerance? : Double = 0.001,
) -> Netlist {
  build_netlist(board, labels~, definitions~, tolerance~)
}

///|
pub fn reference_net_definition() -> NetDefinition {
  net_definition(
    name="GND",
    class_name="power",
    expected_terminals=0,
    max_length=None,
    min_clearance=0.15,
    reference_net=true,
  )
}

///|
pub fn power_net_definition(
  name : String,
  expected_terminals : Int,
) -> NetDefinition {
  net_definition(
    name~,
    class_name="power",
    expected_terminals~,
    max_length=None,
    min_clearance=0.2,
    reference_net=false,
  )
}

///|
pub fn differential_net_definition(
  name : String,
  max_length : Double,
) -> NetDefinition {
  net_definition(
    name~,
    class_name="differential",
    expected_terminals=2,
    max_length=Some(max_length),
    min_clearance=0.15,
    reference_net=false,
  )
}
