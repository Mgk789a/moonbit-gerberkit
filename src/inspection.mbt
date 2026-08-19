///|
/// Board acceptance gates that combine geometric DFM, fabrication capability,
/// connectivity, netlist inference, and machine-tool safety into one
/// deterministic report.
pub enum InspectionStatus {
  InspectionPass
  InspectionWarn
  InspectionFail
} derive(Debug, Eq)

///|
pub enum InspectionRule {
  DfmGate
  FabricationGate
  ConnectivityGate
  NetlistGate
  ToolpathGate
  BoardSizeGate
  CopperDensityGate
  DrillCountGate
  ProductionReadinessGate
} derive(Debug, Eq)

///|
pub struct InspectionProfile {
  name : String
  dfm_config : DfmConfig
  fabrication_profile : FabricationProfile
  machine_profile : ToolMachineProfile
  tolerance : Double
  require_dfm_pass : Bool
  require_fabrication_pass : Bool
  require_connected : Bool
  require_named_nets : Bool
  require_safe_toolpaths : Bool
  max_warnings : Int
  min_fabrication_score : Double
  max_board_area : Double
  min_copper_density : Double
  max_drills : Int
} derive(Debug)

///|
pub struct InspectionFinding {
  rule : InspectionRule
  status : InspectionStatus
  message : String
  measured : Double?
  limit : Double?
  location : Point2?
} derive(Debug)

///|
pub struct InspectionGate {
  name : String
  status : InspectionStatus
  findings : Array[InspectionFinding]
} derive(Debug)

///|
pub struct InspectionReport {
  profile : InspectionProfile
  status : InspectionStatus
  gates : Array[InspectionGate]
  findings : Array[InspectionFinding]
  dfm : DfmReport
  fabrication : FabricationAssessment
  connectivity : ConnectivityGraph
  netlist : Netlist
  toolpaths : ToolpathPlan
  metrics : BoardMetrics
} derive(Debug)

///|
pub struct InspectionDelta {
  previous_status : InspectionStatus
  current_status : InspectionStatus
  new_failures : Int
  resolved_failures : Int
  changed_rules : Array[String]
} derive(Debug)

///|
pub fn inspection_status_name(value : InspectionStatus) -> String {
  match value {
    InspectionPass => "pass"
    InspectionWarn => "warning"
    InspectionFail => "fail"
  }
}

///|
pub fn inspection_rule_name(value : InspectionRule) -> String {
  match value {
    DfmGate => "dfm"
    FabricationGate => "fabrication"
    ConnectivityGate => "connectivity"
    NetlistGate => "netlist"
    ToolpathGate => "toolpath"
    BoardSizeGate => "board-size"
    CopperDensityGate => "copper-density"
    DrillCountGate => "drill-count"
    ProductionReadinessGate => "production-readiness"
  }
}

///|
pub fn inspection_delta(
  previous_status : InspectionStatus,
  current_status : InspectionStatus,
  new_failures : Int,
  resolved_failures : Int,
  changed_rules : Array[String],
) -> InspectionDelta {
  {
    previous_status,
    current_status,
    new_failures: if new_failures < 0 {
      0
    } else {
      new_failures
    },
    resolved_failures: if resolved_failures < 0 {
      0
    } else {
      resolved_failures
    },
    changed_rules: changed_rules.copy(),
  }
}

///|
pub fn InspectionDelta::summary(self : InspectionDelta) -> String {
  "status=\{inspection_status_name(self.previous_status)} -> \{inspection_status_name(self.current_status)}, new_failures=\{self.new_failures}, resolved=\{self.resolved_failures}, changed=\{self.changed_rules.length()}"
}

///|
pub fn default_inspection_profile() -> InspectionProfile {
  {
    name: "standard-production",
    dfm_config: default_dfm_config(),
    fabrication_profile: standard_fabrication_profile(),
    machine_profile: default_tool_machine_profile(),
    tolerance: 0.001,
    require_dfm_pass: true,
    require_fabrication_pass: true,
    require_connected: false,
    require_named_nets: false,
    require_safe_toolpaths: true,
    max_warnings: 20,
    min_fabrication_score: 80.0,
    max_board_area: 250000.0,
    min_copper_density: 0.0,
    max_drills: 10000,
  }
}

///|
pub fn prototype_inspection_profile() -> InspectionProfile {
  {
    name: "prototype-review",
    dfm_config: default_dfm_config(),
    fabrication_profile: prototype_fabrication_profile(),
    machine_profile: default_tool_machine_profile(),
    tolerance: 0.002,
    require_dfm_pass: false,
    require_fabrication_pass: false,
    require_connected: false,
    require_named_nets: false,
    require_safe_toolpaths: true,
    max_warnings: 50,
    min_fabrication_score: 60.0,
    max_board_area: 90000.0,
    min_copper_density: 0.0,
    max_drills: 5000,
  }
}

///|
pub fn strict_inspection_profile() -> InspectionProfile {
  {
    name: "strict-production",
    dfm_config: strict_dfm_config(),
    fabrication_profile: fine_pitch_fabrication_profile(),
    machine_profile: fine_tool_machine_profile(),
    tolerance: 0.0005,
    require_dfm_pass: true,
    require_fabrication_pass: true,
    require_connected: true,
    require_named_nets: true,
    require_safe_toolpaths: true,
    max_warnings: 5,
    min_fabrication_score: 95.0,
    max_board_area: 160000.0,
    min_copper_density: 0.005,
    max_drills: 2000,
  }
}

///|
pub fn InspectionProfile::with_name(
  self : InspectionProfile,
  name : String,
) -> InspectionProfile {
  {
    name,
    dfm_config: self.dfm_config,
    fabrication_profile: self.fabrication_profile,
    machine_profile: self.machine_profile,
    tolerance: self.tolerance,
    require_dfm_pass: self.require_dfm_pass,
    require_fabrication_pass: self.require_fabrication_pass,
    require_connected: self.require_connected,
    require_named_nets: self.require_named_nets,
    require_safe_toolpaths: self.require_safe_toolpaths,
    max_warnings: self.max_warnings,
    min_fabrication_score: self.min_fabrication_score,
    max_board_area: self.max_board_area,
    min_copper_density: self.min_copper_density,
    max_drills: self.max_drills,
  }
}

///|
pub fn InspectionProfile::with_machine(
  self : InspectionProfile,
  machine : ToolMachineProfile,
) -> InspectionProfile {
  {
    name: self.name,
    dfm_config: self.dfm_config,
    fabrication_profile: self.fabrication_profile,
    machine_profile: machine,
    tolerance: self.tolerance,
    require_dfm_pass: self.require_dfm_pass,
    require_fabrication_pass: self.require_fabrication_pass,
    require_connected: self.require_connected,
    require_named_nets: self.require_named_nets,
    require_safe_toolpaths: self.require_safe_toolpaths,
    max_warnings: self.max_warnings,
    min_fabrication_score: self.min_fabrication_score,
    max_board_area: self.max_board_area,
    min_copper_density: self.min_copper_density,
    max_drills: self.max_drills,
  }
}

///|
pub fn InspectionProfile::with_gates(
  self : InspectionProfile,
  require_dfm : Bool,
  require_fabrication : Bool,
  require_connected : Bool,
  require_named_nets : Bool,
  require_safe_toolpaths : Bool,
) -> InspectionProfile {
  {
    name: self.name,
    dfm_config: self.dfm_config,
    fabrication_profile: self.fabrication_profile,
    machine_profile: self.machine_profile,
    tolerance: self.tolerance,
    require_dfm_pass: require_dfm,
    require_fabrication_pass: require_fabrication,
    require_connected,
    require_named_nets,
    require_safe_toolpaths,
    max_warnings: self.max_warnings,
    min_fabrication_score: self.min_fabrication_score,
    max_board_area: self.max_board_area,
    min_copper_density: self.min_copper_density,
    max_drills: self.max_drills,
  }
}

///|
pub fn inspection_finding(
  rule : InspectionRule,
  status : InspectionStatus,
  message : String,
  measured : Double?,
  limit : Double?,
  location : Point2?,
) -> InspectionFinding {
  { rule, status, message, measured, limit, location }
}

///|
fn inspection_gate(
  name : String,
  findings : Array[InspectionFinding],
) -> InspectionGate {
  let status = if findings.any(finding => finding.status is InspectionFail) {
    InspectionFail
  } else if findings.any(finding => finding.status is InspectionWarn) {
    InspectionWarn
  } else {
    InspectionPass
  }
  { name, status, findings }
}

///|
fn inspection_finding_status(
  passed : Bool,
  required : Bool,
  warning_message : String,
  failure_message : String,
) -> (InspectionStatus, String) {
  if passed {
    (InspectionPass, "gate passed")
  } else if required {
    (InspectionFail, failure_message)
  } else {
    (InspectionWarn, warning_message)
  }
}

///|
fn inspection_board_area(metrics : BoardMetrics) -> Double {
  match metrics.bounds {
    Some(value) => value.area()
    None => 0.0
  }
}

///|
fn inspection_dfm_gate(
  report : DfmReport,
  profile : InspectionProfile,
) -> InspectionGate {
  let status_message = inspection_finding_status(
    report.passed(),
    profile.require_dfm_pass,
    "DFM findings require review",
    "DFM contains errors",
  )
  let findings : Array[InspectionFinding] = [
    inspection_finding(
      DfmGate,
      status_message.0,
      status_message.1,
      Some(report.error_count().to_double()),
      Some(0.0),
      None,
    ),
  ]
  for finding in report.findings {
    let state = if finding.severity is DfmError {
      InspectionFail
    } else if finding.severity is DfmWarning {
      InspectionWarn
    } else {
      InspectionPass
    }
    findings.push(
      inspection_finding(
        DfmGate,
        state,
        finding.message,
        finding.measured,
        finding.limit,
        finding.location,
      ),
    )
  }
  inspection_gate("dfm", findings)
}

///|
fn inspection_fabrication_gate(
  assessment : FabricationAssessment,
  profile : InspectionProfile,
) -> InspectionGate {
  let state = inspection_finding_status(
    assessment.passed && assessment.score >= profile.min_fabrication_score,
    profile.require_fabrication_pass,
    "fabrication profile has non-fatal checks",
    "fabrication profile is not satisfied",
  )
  let findings : Array[InspectionFinding] = [
    inspection_finding(
      FabricationGate,
      state.0,
      state.1,
      Some(assessment.score),
      Some(profile.min_fabrication_score),
      None,
    ),
  ]
  for check in assessment.checks {
    findings.push(
      inspection_finding(
        FabricationGate,
        if check.passed {
          InspectionPass
        } else if profile.require_fabrication_pass {
          InspectionFail
        } else {
          InspectionWarn
        },
        check.message,
        check.measured,
        check.limit,
        None,
      ),
    )
  }
  inspection_gate("fabrication", findings)
}

///|
fn inspection_connectivity_gate(
  graph : ConnectivityGraph,
  profile : InspectionProfile,
) -> InspectionGate {
  let connected = !graph.has_open_trace_endpoints()
  let state = inspection_finding_status(
    connected,
    profile.require_connected,
    "open geometric endpoints require review",
    "open geometric endpoints found",
  )
  inspection_gate("connectivity", [
    inspection_finding(
      ConnectivityGate,
      state.0,
      state.1,
      Some(graph.isolated_node_count().to_double()),
      Some(0.0),
      None,
    ),
  ])
}

///|
fn inspection_netlist_gate(
  netlist : Netlist,
  profile : InspectionProfile,
) -> InspectionGate {
  let named = netlist.named_terminal_count() > 0 ||
    netlist.terminal_count() == 0
  let status = inspection_finding_status(
    named,
    profile.require_named_nets,
    "net labels are incomplete",
    "no named nets were found",
  )
  let findings : Array[InspectionFinding] = [
    inspection_finding(
      NetlistGate,
      status.0,
      status.1,
      Some(netlist.label_coverage()),
      Some(if profile.require_named_nets { 1.0 } else { 0.0 }),
      None,
    ),
  ]
  for issue in netlist.issues {
    if issue.severity is NetError {
      findings.push(
        inspection_finding(
          NetlistGate,
          InspectionFail,
          issue.message,
          issue.measured,
          issue.limit,
          issue.location,
        ),
      )
    } else if issue.severity is NetWarning {
      findings.push(
        inspection_finding(
          NetlistGate,
          InspectionWarn,
          issue.message,
          issue.measured,
          issue.limit,
          issue.location,
        ),
      )
    }
  }
  inspection_gate("netlist", findings)
}

///|
fn inspection_toolpath_gate(
  plan : ToolpathPlan,
  profile : InspectionProfile,
) -> InspectionGate {
  let safe = plan.is_valid() && plan.all_paths_use_safe_height()
  let status = inspection_finding_status(
    safe,
    profile.require_safe_toolpaths,
    "toolpath has review findings",
    "toolpath safety checks failed",
  )
  let findings : Array[InspectionFinding] = [
    inspection_finding(
      ToolpathGate,
      status.0,
      status.1,
      Some(plan.error_count().to_double()),
      Some(0.0),
      None,
    ),
  ]
  for issue in plan.issues {
    if issue.severity is ToolpathError {
      findings.push(
        inspection_finding(
          ToolpathGate,
          InspectionFail,
          issue.message,
          issue.measured,
          issue.limit,
          issue.location,
        ),
      )
    } else if issue.severity is ToolpathWarning {
      findings.push(
        inspection_finding(
          ToolpathGate,
          InspectionWarn,
          issue.message,
          issue.measured,
          issue.limit,
          issue.location,
        ),
      )
    }
  }
  inspection_gate("toolpath", findings)
}

///|
fn inspection_board_gate(
  metrics : BoardMetrics,
  profile : InspectionProfile,
) -> InspectionGate {
  let area = inspection_board_area(metrics)
  let passed = area > 0.0 && area <= profile.max_board_area
  let state = if passed { InspectionPass } else { InspectionFail }
  inspection_gate("board-size", [
    inspection_finding(
      BoardSizeGate,
      state,
      if passed {
        "board size is within profile"
      } else {
        "board is empty or exceeds area profile"
      },
      Some(area),
      Some(profile.max_board_area),
      metrics.bounds.map(value => value.center()),
    ),
  ])
}

///|
fn inspection_density_gate(
  metrics : BoardMetrics,
  profile : InspectionProfile,
) -> InspectionGate {
  let density = metrics.density()
  let passed = density >= profile.min_copper_density
  inspection_gate("copper-density", [
    inspection_finding(
      CopperDensityGate,
      if passed {
        InspectionPass
      } else {
        InspectionWarn
      },
      if passed {
        "copper density is within profile"
      } else {
        "copper density is below profile"
      },
      Some(density),
      Some(profile.min_copper_density),
      None,
    ),
  ])
}

///|
fn inspection_drill_gate(
  metrics : BoardMetrics,
  profile : InspectionProfile,
) -> InspectionGate {
  let count = metrics.layers.fold(init=0, (total, layer) => {
    total + layer.class_count(DrillShape)
  })
  let passed = count <= profile.max_drills
  inspection_gate("drills", [
    inspection_finding(
      DrillCountGate,
      if passed {
        InspectionPass
      } else {
        InspectionFail
      },
      if passed {
        "drill count is within profile"
      } else {
        "drill count exceeds profile"
      },
      Some(count.to_double()),
      Some(profile.max_drills.to_double()),
      None,
    ),
  ])
}

///|
fn inspection_overall_status(gates : Array[InspectionGate]) -> InspectionStatus {
  if gates.any(gate => gate.status is InspectionFail) {
    InspectionFail
  } else if gates.any(gate => gate.status is InspectionWarn) {
    InspectionWarn
  } else {
    InspectionPass
  }
}

///|
fn inspection_findings(
  gates : Array[InspectionGate],
) -> Array[InspectionFinding] {
  let result : Array[InspectionFinding] = []
  for gate in gates {
    result.append(gate.findings)
  }
  result
}

///|
pub fn inspect_board(
  board : Board,
  profile? : InspectionProfile = default_inspection_profile(),
  labels? : Array[NetLabel] = [],
  definitions? : Array[NetDefinition] = [],
) -> InspectionReport {
  let metrics = board_metrics(board)
  let dfm = run_dfm(board, config=profile.dfm_config)
  let fabrication = assess_fabrication(
    board,
    profile=profile.fabrication_profile,
  )
  let connectivity = build_connectivity(board, tolerance=profile.tolerance)
  let netlist = build_netlist(
    board,
    labels~,
    definitions~,
    tolerance=profile.tolerance,
  )
  let toolpaths = plan_board_toolpaths(board, profile=profile.machine_profile)
  let gates : Array[InspectionGate] = []
  gates.push(inspection_dfm_gate(dfm, profile))
  gates.push(inspection_fabrication_gate(fabrication, profile))
  gates.push(inspection_connectivity_gate(connectivity, profile))
  gates.push(inspection_netlist_gate(netlist, profile))
  gates.push(inspection_toolpath_gate(toolpaths, profile))
  gates.push(inspection_board_gate(metrics, profile))
  gates.push(inspection_density_gate(metrics, profile))
  gates.push(inspection_drill_gate(metrics, profile))
  let ready = dfm.passed() && fabrication.passed && toolpaths.is_valid()
  gates.push(
    inspection_gate("production-readiness", [
      inspection_finding(
        ProductionReadinessGate,
        if ready {
          InspectionPass
        } else {
          InspectionFail
        },
        if ready {
          "board is ready for production handoff"
        } else {
          "one or more production gates failed"
        },
        Some(if ready { 1.0 } else { 0.0 }),
        Some(1.0),
        None,
      ),
    ]),
  )
  let status = inspection_overall_status(gates)
  {
    profile,
    status,
    gates,
    findings: inspection_findings(gates),
    dfm,
    fabrication,
    connectivity,
    netlist,
    toolpaths,
    metrics,
  }
}

///|
pub fn InspectionReport::is_passed(self : InspectionReport) -> Bool {
  self.status is InspectionPass
}

///|
pub fn InspectionReport::is_release_ready(self : InspectionReport) -> Bool {
  self.status is InspectionPass &&
  self.dfm.passed() &&
  self.fabrication.passed &&
  self.toolpaths.is_valid()
}

///|
pub fn InspectionReport::error_count(self : InspectionReport) -> Int {
  self.findings.filter(finding => finding.status is InspectionFail).length()
}

///|
pub fn InspectionReport::warning_count(self : InspectionReport) -> Int {
  self.findings.filter(finding => finding.status is InspectionWarn).length()
}

///|
pub fn InspectionReport::pass_count(self : InspectionReport) -> Int {
  self.findings.filter(finding => finding.status is InspectionPass).length()
}

///|
pub fn InspectionReport::gate(
  self : InspectionReport,
  name : String,
) -> InspectionGate? {
  for gate in self.gates {
    if gate.name == name {
      return Some(gate)
    }
  }
  None
}

///|
pub fn InspectionReport::gate_status(
  self : InspectionReport,
  name : String,
) -> InspectionStatus {
  match self.gate(name) {
    Some(gate) => gate.status
    None => InspectionFail
  }
}

///|
pub fn InspectionReport::summary(self : InspectionReport) -> String {
  "status=\{inspection_status_name(self.status)}, release_ready=\{self.is_release_ready()}, gates=\{self.gates.length()}, pass=\{self.pass_count()}, warnings=\{self.warning_count()}, errors=\{self.error_count()}, dfm=\{self.dfm.summary()}, fabrication=\{self.fabrication.summary()}"
}

///|
pub fn InspectionGate::error_count(self : InspectionGate) -> Int {
  self.findings.filter(finding => finding.status is InspectionFail).length()
}

///|
pub fn InspectionGate::warning_count(self : InspectionGate) -> Int {
  self.findings.filter(finding => finding.status is InspectionWarn).length()
}

///|
pub fn InspectionGate::is_passed(self : InspectionGate) -> Bool {
  self.status is InspectionPass
}

///|
pub fn InspectionFinding::is_failure(self : InspectionFinding) -> Bool {
  self.status is InspectionFail
}

///|
pub fn InspectionFinding::format(self : InspectionFinding) -> String {
  let value = match (self.measured, self.limit) {
    (Some(measured), Some(limit)) => " measured=\{measured} limit=\{limit}"
    _ => ""
  }
  "\{inspection_status_name(self.status)} \{inspection_rule_name(self.rule)}: \{self.message}\{value}"
}

///|
pub fn InspectionReport::findings_for(
  self : InspectionReport,
  rule : InspectionRule,
) -> Array[InspectionFinding] {
  self.findings.filter(finding => finding.rule == rule)
}

///|
pub fn InspectionReport::failed_rules(self : InspectionReport) -> Array[String] {
  let result : Array[String] = []
  for finding in self.findings {
    if finding.status is InspectionFail {
      let name = inspection_rule_name(finding.rule)
      if !result.contains(name) {
        result.push(name)
      }
    }
  }
  result
}

///|
pub fn InspectionReport::warning_rules(
  self : InspectionReport,
) -> Array[String] {
  let result : Array[String] = []
  for finding in self.findings {
    if finding.status is InspectionWarn {
      let name = inspection_rule_name(finding.rule)
      if !result.contains(name) {
        result.push(name)
      }
    }
  }
  result
}

///|
pub fn inspection_finding_to_json(value : InspectionFinding) -> String {
  let location = match value.location {
    Some(point) => "{\"x\":\{point.x},\"y\":\{point.y}}"
    None => "null"
  }
  let measured = value.measured
    .map(number => number.to_string())
    .unwrap_or("null")
  let limit = value.limit.map(number => number.to_string()).unwrap_or("null")
  "{\"rule\":\{json_string(inspection_rule_name(value.rule))},\"status\":\{json_string(inspection_status_name(value.status))},\"message\":\{json_string(value.message)},\"measured\":\{measured},\"limit\":\{limit},\"location\":\{location}}"
}

///|
pub fn inspection_gate_to_json(value : InspectionGate) -> String {
  let findings = value.findings.map(inspection_finding_to_json).join(",")
  "{\"name\":\{json_string(value.name)},\"status\":\{json_string(inspection_status_name(value.status))},\"errors\":\{value.error_count()},\"warnings\":\{value.warning_count()},\"findings\":[\{findings}]}"
}

///|
pub fn inspection_report_to_json(value : InspectionReport) -> String {
  let gates = value.gates.map(inspection_gate_to_json).join(",")
  let failures = value.failed_rules().map(json_string).join(",")
  "{\"status\":\{json_string(inspection_status_name(value.status))},\"release_ready\":\{value.is_release_ready()},\"summary\":\{json_string(value.summary())},\"errors\":\{value.error_count()},\"warnings\":\{value.warning_count()},\"failed_rules\":[\{failures}],\"gates\":[\{gates}],\"dfm\":\{dfm_report_to_json(value.dfm)},\"fabrication\":\{value.fabrication.to_json()},\"connectivity\":\{value.connectivity.to_json()},\"netlist\":\{netlist_to_json(value.netlist, include_terminals=false)},\"toolpaths\":\{toolpath_plan_to_json(value.toolpaths)}}"
}

///|
pub fn inspection_report_to_text(value : InspectionReport) -> String {
  let mut output = value.summary() + "\n"
  for gate in value.gates {
    output += "\n[\{inspection_status_name(gate.status)}] \{gate.name}\n"
    for finding in gate.findings {
      output += "  - " + finding.format() + "\n"
    }
  }
  output
}

///|
pub fn inspection_report_to_sarif(value : InspectionReport) -> String {
  let results = value.findings
    .filter(finding => {
      finding.status is InspectionFail || finding.status is InspectionWarn
    })
    .map(finding => {
      let level = if finding.status is InspectionFail {
        "error"
      } else {
        "warning"
      }
      "{\"ruleId\":\{json_string(inspection_rule_name(finding.rule))},\"level\":\{json_string(level)},\"message\":{\"text\":\{json_string(finding.message)}}}"
    })
    .join(",")
  "{\"version\":\"2.1.0\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"moonbit-gerberkit inspection\"}},\"results\":[\{results}]}]}"
}

///|
pub fn InspectionReport::to_json(self : InspectionReport) -> String {
  inspection_report_to_json(self)
}

///|
pub fn InspectionReport::to_text(self : InspectionReport) -> String {
  inspection_report_to_text(self)
}

///|
pub fn InspectionReport::to_sarif(self : InspectionReport) -> String {
  inspection_report_to_sarif(self)
}
