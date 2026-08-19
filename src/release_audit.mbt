///|
/// Release audit and reproducibility gates for manufacturing handoff.
/// The audit composes the geometric, fabrication, thermal, constraint, and
/// provenance services into one deterministic decision with evidence that can
/// be archived alongside a board revision.
pub enum ReleaseArtifactKind {
  ReleaseGerber
  ReleaseExcellon
  ReleaseOutline
  ReleaseReport
  ReleaseManifest
  ReleaseDerived
} derive(Debug, Eq)

///|
pub enum ReleaseDecision {
  ReleaseReady
  ReleaseReview
  ReleaseBlocked
} derive(Debug, Eq)

///|
pub enum ReleaseChangeKind {
  ReleaseAdded
  ReleaseRemoved
  ReleaseModified
  ReleaseUnchanged
} derive(Debug, Eq)

///|
pub enum ReleaseSeverity {
  ReleaseNotice
  ReleaseRisk
  ReleaseBlocker
} derive(Debug, Eq)

///|
pub struct ReleaseArtifact {
  path : String
  kind : ReleaseArtifactKind
  digest : String
  bytes : Int
  required : Bool
  present : Bool
  description : String
} derive(Debug)

///|
pub struct ReleaseManifest {
  project : String
  revision : String
  artifacts : Array[ReleaseArtifact]
  declared_checks : Array[String]
  notes : Array[String]
} derive(Debug)

///|
pub struct ReleasePolicy {
  name : String
  minimum_score : Double
  maximum_warnings : Int
  maximum_missing_artifacts : Int
  maximum_changes : Int
  require_inspection_ready : Bool
  require_thermal_pass : Bool
  require_constraints_pass : Bool
  require_provenance : Bool
  compare_area_tolerance : Double
} derive(Debug)

///|
pub struct ReleaseGate {
  name : String
  decision : ReleaseDecision
  severity : ReleaseSeverity
  measured : Double?
  limit : Double?
  evidence : String
  remediation : String
} derive(Debug)

///|
pub struct ReleaseChange {
  path : String
  kind : ReleaseChangeKind
  previous_digest : String?
  current_digest : String?
  size_delta : Int
  risk : ReleaseSeverity
  rationale : String
} derive(Debug)

///|
pub struct ReleaseAudit {
  manifest : ReleaseManifest
  policy : ReleasePolicy
  decision : ReleaseDecision
  score : Double
  gates : Array[ReleaseGate]
  changes : Array[ReleaseChange]
  inspection : InspectionReport
  thermal : ThermalReport
  constraints : ConstraintReport
  provenance : SourceIndex
  metrics : BoardMetrics
} derive(Debug)

///|
pub struct ReleaseDelta {
  previous_decision : ReleaseDecision
  current_decision : ReleaseDecision
  previous_score : Double
  current_score : Double
  score_delta : Double
  added : Int
  removed : Int
  modified : Int
  resolved_gates : Int
  new_blockers : Int
  improved : Bool
} derive(Debug)

///|
pub fn release_artifact_kind_name(value : ReleaseArtifactKind) -> String {
  match value {
    ReleaseGerber => "gerber"
    ReleaseExcellon => "excellon"
    ReleaseOutline => "outline"
    ReleaseReport => "report"
    ReleaseManifest => "manifest"
    ReleaseDerived => "derived"
  }
}

///|
pub fn release_decision_name(value : ReleaseDecision) -> String {
  match value {
    ReleaseReady => "ready"
    ReleaseReview => "review"
    ReleaseBlocked => "blocked"
  }
}

///|
pub fn release_change_name(value : ReleaseChangeKind) -> String {
  match value {
    ReleaseAdded => "added"
    ReleaseRemoved => "removed"
    ReleaseModified => "modified"
    ReleaseUnchanged => "unchanged"
  }
}

///|
pub fn release_severity_name(value : ReleaseSeverity) -> String {
  match value {
    ReleaseNotice => "notice"
    ReleaseRisk => "risk"
    ReleaseBlocker => "blocker"
  }
}

///|
pub fn release_artifact_kind_from_path(path : String) -> ReleaseArtifactKind {
  let upper = path.to_upper()
  if upper.contains(".DRL") || upper.contains(".TXT") {
    ReleaseExcellon
  } else if upper.contains(".GKO") || upper.contains("OUTLINE") {
    ReleaseOutline
  } else if upper.contains(".GBR") ||
    upper.contains(".GTL") ||
    upper.contains(".GBS") ||
    upper.contains(".GTO") {
    ReleaseGerber
  } else if upper.contains("MANIFEST") || upper.contains(".JSON") {
    ReleaseManifest
  } else if upper.contains("REPORT") || upper.contains(".SARIF") {
    ReleaseReport
  } else {
    ReleaseDerived
  }
}

///|
pub fn release_artifact(
  path~ : String,
  kind~ : ReleaseArtifactKind,
  content~ : String,
  required~ : Bool,
  present~ : Bool,
  description~ : String,
) -> ReleaseArtifact {
  {
    path,
    kind,
    digest: source_hash(content),
    bytes: content.length(),
    required,
    present,
    description,
  }
}

///|
pub fn ReleaseArtifact::is_missing(self : ReleaseArtifact) -> Bool {
  self.required && !self.present
}

///|
pub fn ReleaseArtifact::summary(self : ReleaseArtifact) -> String {
  "\{release_artifact_kind_name(self.kind)} \{self.path}: \{self.bytes} bytes \{self.digest}"
}

///|
pub fn ReleaseManifest::artifact_count(self : ReleaseManifest) -> Int {
  self.artifacts.length()
}

///|
pub fn ReleaseManifest::required_count(self : ReleaseManifest) -> Int {
  self.artifacts.filter(artifact => artifact.required).length()
}

///|
pub fn ReleaseManifest::missing_count(self : ReleaseManifest) -> Int {
  self.artifacts.filter(ReleaseArtifact::is_missing).length()
}

///|
pub fn ReleaseManifest::digest(self : ReleaseManifest) -> String {
  let mut text = self.project + "|" + self.revision
  for artifact in self.artifacts {
    text += "|" + artifact.path + "|" + artifact.digest
  }
  source_hash(text)
}

///|
pub fn ReleaseManifest::summary(self : ReleaseManifest) -> String {
  "project=\{self.project}, revision=\{self.revision}, artifacts=\{self.artifact_count()}, required=\{self.required_count()}, missing=\{self.missing_count()}, digest=\{self.digest()}"
}

///|
pub fn ReleaseManifest::artifact(
  self : ReleaseManifest,
  path : String,
) -> ReleaseArtifact? {
  for artifact in self.artifacts {
    if artifact.path == path {
      return Some(artifact)
    }
  }
  None
}

///|
pub fn ReleaseManifest::has_check(
  self : ReleaseManifest,
  name : String,
) -> Bool {
  self.declared_checks.contains(name)
}

///|
pub fn ReleaseManifest::with_note(
  self : ReleaseManifest,
  note : String,
) -> ReleaseManifest {
  let notes = self.notes.copy()
  notes.push(note)
  {
    project: self.project,
    revision: self.revision,
    artifacts: self.artifacts,
    declared_checks: self.declared_checks,
    notes,
  }
}

///|
pub fn ReleaseManifest::with_check(
  self : ReleaseManifest,
  check : String,
) -> ReleaseManifest {
  let checks = self.declared_checks.copy()
  if !checks.contains(check) {
    checks.push(check)
  }
  {
    project: self.project,
    revision: self.revision,
    artifacts: self.artifacts,
    declared_checks: checks,
    notes: self.notes,
  }
}

///|
pub fn ReleaseManifest::add_artifact(
  self : ReleaseManifest,
  artifact : ReleaseArtifact,
) -> ReleaseManifest {
  let artifacts = self.artifacts.copy()
  let mut replaced = false
  for index in 0..<artifacts.length() {
    if artifacts[index].path == artifact.path {
      artifacts[index] = artifact
      replaced = true
    }
  }
  if !replaced {
    artifacts.push(artifact)
  }
  {
    project: self.project,
    revision: self.revision,
    artifacts,
    declared_checks: self.declared_checks,
    notes: self.notes,
  }
}

///|
pub fn new_release_manifest(
  project~ : String,
  revision~ : String,
) -> ReleaseManifest {
  { project, revision, artifacts: [], declared_checks: [], notes: [] }
}

///|
pub fn release_manifest_for_board(
  board : Board,
  project? : String = "moonbit-gerberkit",
  revision? : String = "local",
) -> ReleaseManifest {
  let mut manifest = new_release_manifest(project~, revision~)
  manifest = manifest.add_artifact(
    release_artifact(
      path="board.json",
      kind=ReleaseManifest,
      content=board_to_json(board, include_shapes=true),
      required=true,
      present=true,
      description="canonical board geometry",
    ),
  )
  let metrics = board_metrics(board)
  if metrics.layers.any(layer => layer.kind is Copper) {
    manifest = manifest.add_artifact(
      release_artifact(
        path="copper.gbr",
        kind=ReleaseGerber,
        content=metrics.summary(),
        required=true,
        present=true,
        description="copper manufacturing input",
      ),
    )
  }
  if metrics.layers.any(layer => layer.kind is Drill) {
    manifest = manifest.add_artifact(
      release_artifact(
        path="drill.drl",
        kind=ReleaseExcellon,
        content=metrics.summary(),
        required=true,
        present=true,
        description="drill manufacturing input",
      ),
    )
  }
  manifest
}

///|
pub fn ReleasePolicy::summary(self : ReleasePolicy) -> String {
  "\{self.name}: score>=\{self.minimum_score}, warnings<=\{self.maximum_warnings}, missing<=\{self.maximum_missing_artifacts}, changes<=\{self.maximum_changes}"
}

///|
pub fn standard_release_policy() -> ReleasePolicy {
  {
    name: "standard-release",
    minimum_score: 85.0,
    maximum_warnings: 20,
    maximum_missing_artifacts: 0,
    maximum_changes: 1000000,
    require_inspection_ready: true,
    require_thermal_pass: false,
    require_constraints_pass: true,
    require_provenance: true,
    compare_area_tolerance: 0.05,
  }
}

///|
pub fn prototype_release_policy() -> ReleasePolicy {
  {
    name: "prototype-release",
    minimum_score: 65.0,
    maximum_warnings: 50,
    maximum_missing_artifacts: 1,
    maximum_changes: 1000000,
    require_inspection_ready: false,
    require_thermal_pass: false,
    require_constraints_pass: false,
    require_provenance: false,
    compare_area_tolerance: 0.15,
  }
}

///|
pub fn strict_release_policy() -> ReleasePolicy {
  {
    name: "strict-release",
    minimum_score: 95.0,
    maximum_warnings: 5,
    maximum_missing_artifacts: 0,
    maximum_changes: 500000,
    require_inspection_ready: true,
    require_thermal_pass: true,
    require_constraints_pass: true,
    require_provenance: true,
    compare_area_tolerance: 0.02,
  }
}

///|
pub fn ReleaseGate::is_passed(self : ReleaseGate) -> Bool {
  self.decision is ReleaseReady
}

///|
pub fn ReleaseGate::summary(self : ReleaseGate) -> String {
  "\{release_severity_name(self.severity)} \{self.name}: \{release_decision_name(self.decision)} \{self.evidence}"
}

///|
fn release_gate(
  name : String,
  decision : ReleaseDecision,
  severity : ReleaseSeverity,
  measured : Double?,
  limit : Double?,
  evidence : String,
  remediation : String,
) -> ReleaseGate {
  { name, decision, severity, measured, limit, evidence, remediation }
}

///|
fn release_gate_bool(
  name : String,
  passed : Bool,
  required : Bool,
  evidence : String,
  remediation : String,
) -> ReleaseGate {
  if passed {
    release_gate(
      name,
      ReleaseReady,
      ReleaseNotice,
      Some(1.0),
      Some(1.0),
      evidence,
      remediation,
    )
  } else if required {
    release_gate(
      name,
      ReleaseBlocked,
      ReleaseBlocker,
      Some(0.0),
      Some(1.0),
      evidence,
      remediation,
    )
  } else {
    release_gate(
      name,
      ReleaseReview,
      ReleaseRisk,
      Some(0.0),
      Some(1.0),
      evidence,
      remediation,
    )
  }
}

///|
fn release_score(gates : Array[ReleaseGate]) -> Double {
  if gates.length() == 0 {
    100.0
  } else {
    let mut total = 0.0
    for gate in gates {
      total += match gate.decision {
        ReleaseReady => 100.0
        ReleaseReview => 60.0
        ReleaseBlocked => 0.0
      }
    }
    total / gates.length().to_double()
  }
}

///|
fn release_decision(gates : Array[ReleaseGate]) -> ReleaseDecision {
  if gates.any(gate => gate.decision is ReleaseBlocked) {
    ReleaseBlocked
  } else if gates.any(gate => gate.decision is ReleaseReview) {
    ReleaseReview
  } else {
    ReleaseReady
  }
}

///|
fn release_manifest_gate(
  manifest : ReleaseManifest,
  policy : ReleasePolicy,
) -> ReleaseGate {
  let missing = manifest.missing_count()
  if missing <= policy.maximum_missing_artifacts {
    release_gate(
      "manifest",
      ReleaseReady,
      ReleaseNotice,
      Some(missing.to_double()),
      Some(policy.maximum_missing_artifacts.to_double()),
      "all required release artifacts are present",
      "add the missing manufacturing artifact",
    )
  } else {
    release_gate(
      "manifest",
      ReleaseBlocked,
      ReleaseBlocker,
      Some(missing.to_double()),
      Some(policy.maximum_missing_artifacts.to_double()),
      "required release artifacts are missing",
      "complete the release bundle before handoff",
    )
  }
}

///|
fn release_inspection_gate(
  inspection : InspectionReport,
  policy : ReleasePolicy,
) -> ReleaseGate {
  release_gate_bool(
    "inspection",
    inspection.is_release_ready(),
    policy.require_inspection_ready,
    inspection.summary(),
    "resolve DFM, fabrication, or toolpath failures",
  )
}

///|
fn release_thermal_gate(
  thermal : ThermalReport,
  policy : ReleasePolicy,
) -> ReleaseGate {
  release_gate_bool(
    "thermal",
    thermal.is_valid(),
    policy.require_thermal_pass,
    thermal.summary(),
    "increase copper spreading or revise thermal limits",
  )
}

///|
fn release_constraint_gate(
  constraints : ConstraintReport,
  policy : ReleasePolicy,
) -> ReleaseGate {
  release_gate_bool(
    "constraints",
    constraints.is_valid(),
    policy.require_constraints_pass,
    constraints.summary(),
    "resolve the failing manufacturing constraint",
  )
}

///|
fn release_provenance_gate(
  provenance : SourceIndex,
  policy : ReleasePolicy,
) -> ReleaseGate {
  let healthy = source_index_health(provenance)
  release_gate_bool(
    "provenance",
    healthy,
    policy.require_provenance,
    provenance.summary().summary(),
    "index source files and retain diagnostic spans",
  )
}

///|
fn release_warning_gate(
  inspection : InspectionReport,
  thermal : ThermalReport,
  policy : ReleasePolicy,
) -> ReleaseGate {
  let warnings = inspection.warning_count() + thermal.warning_count()
  release_gate(
    "warnings",
    if warnings <= policy.maximum_warnings {
      ReleaseReady
    } else {
      ReleaseReview
    },
    if warnings <= policy.maximum_warnings {
      ReleaseNotice
    } else {
      ReleaseRisk
    },
    Some(warnings.to_double()),
    Some(policy.maximum_warnings.to_double()),
    "\{warnings} review warnings were produced",
    "review warnings before production handoff",
  )
}

///|
fn release_score_gate(score : Double, policy : ReleasePolicy) -> ReleaseGate {
  release_gate(
    "score",
    if score >= policy.minimum_score {
      ReleaseReady
    } else {
      ReleaseReview
    },
    if score >= policy.minimum_score {
      ReleaseNotice
    } else {
      ReleaseRisk
    },
    Some(score),
    Some(policy.minimum_score),
    "composite release score=\{score}",
    "raise the lowest gates before release",
  )
}

///|
pub fn audit_release(
  board : Board,
  manifest : ReleaseManifest,
  policy : ReleasePolicy,
) -> ReleaseAudit {
  let inspection = inspect_board(board)
  let thermal = analyze_thermal(board)
  let constraints = evaluate_constraints(board, standard_constraint_set())
  let provenance = source_index_from_board(board, path="release-board.json")
  let metrics = board_metrics(board)
  let gates : Array[ReleaseGate] = []
  gates.push(release_manifest_gate(manifest, policy))
  gates.push(release_inspection_gate(inspection, policy))
  gates.push(release_thermal_gate(thermal, policy))
  gates.push(release_constraint_gate(constraints, policy))
  gates.push(release_provenance_gate(provenance, policy))
  gates.push(release_warning_gate(inspection, thermal, policy))
  let preliminary_score = release_score(gates)
  gates.push(release_score_gate(preliminary_score, policy))
  {
    manifest,
    policy,
    decision: release_decision(gates),
    score: release_score(gates),
    gates,
    changes: [],
    inspection,
    thermal,
    constraints,
    provenance,
    metrics,
  }
}

///|
pub fn audit_release_default(board : Board) -> ReleaseAudit {
  let manifest = release_manifest_for_board(board)
  audit_release(board, manifest, standard_release_policy())
}

///|
pub fn ReleaseAudit::is_ready(self : ReleaseAudit) -> Bool {
  self.decision is ReleaseReady
}

///|
pub fn ReleaseAudit::blocked_count(self : ReleaseAudit) -> Int {
  self.gates.filter(gate => gate.decision is ReleaseBlocked).length()
}

///|
pub fn ReleaseAudit::review_count(self : ReleaseAudit) -> Int {
  self.gates.filter(gate => gate.decision is ReleaseReview).length()
}

///|
pub fn ReleaseAudit::summary(self : ReleaseAudit) -> String {
  "release=\{release_decision_name(self.decision)}, score=\{self.score}, gates=\{self.gates.length()}, blocked=\{self.blocked_count()}, review=\{self.review_count()}, inspection=\{self.inspection.is_release_ready()}, thermal=\{self.thermal.is_valid()}, constraints=\{self.constraints.is_valid()}, provenance=\{source_index_health(self.provenance)}"
}

///|
fn release_change(
  path : String,
  kind : ReleaseChangeKind,
  previous_digest : String?,
  current_digest : String?,
  size_delta : Int,
  risk : ReleaseSeverity,
  rationale : String,
) -> ReleaseChange {
  { path, kind, previous_digest, current_digest, size_delta, risk, rationale }
}

///|
fn release_manifest_changes(
  previous : ReleaseManifest,
  current : ReleaseManifest,
) -> Array[ReleaseChange] {
  let changes : Array[ReleaseChange] = []
  for artifact in previous.artifacts {
    match current.artifact(artifact.path) {
      None =>
        changes.push(
          release_change(
            artifact.path,
            ReleaseRemoved,
            Some(artifact.digest),
            None,
            -artifact.bytes,
            if artifact.required {
              ReleaseBlocker
            } else {
              ReleaseRisk
            },
            "artifact was removed from the current manifest",
          ),
        )
      Some(next) if next.digest != artifact.digest =>
        changes.push(
          release_change(
            artifact.path,
            ReleaseModified,
            Some(artifact.digest),
            Some(next.digest),
            next.bytes - artifact.bytes,
            if artifact.required {
              ReleaseRisk
            } else {
              ReleaseNotice
            },
            "artifact content digest changed",
          ),
        )
      Some(_) =>
        changes.push(
          release_change(
            artifact.path,
            ReleaseUnchanged,
            Some(artifact.digest),
            Some(artifact.digest),
            0,
            ReleaseNotice,
            "artifact digest is unchanged",
          ),
        )
    }
  }
  for artifact in current.artifacts {
    match previous.artifact(artifact.path) {
      None =>
        changes.push(
          release_change(
            artifact.path,
            ReleaseAdded,
            None,
            Some(artifact.digest),
            artifact.bytes,
            if artifact.required {
              ReleaseNotice
            } else {
              ReleaseRisk
            },
            "artifact was added to the current manifest",
          ),
        )
      Some(_) => ()
    }
  }
  changes
}

///|
pub fn release_compare_manifests(
  previous : ReleaseManifest,
  current : ReleaseManifest,
) -> Array[ReleaseChange] {
  release_manifest_changes(previous, current)
}

///|
fn release_metric_change(
  previous : BoardMetrics,
  current : BoardMetrics,
  tolerance : Double,
) -> ReleaseChange {
  let previous_area = match previous.bounds {
    Some(bounds) => bounds.area()
    None => 0.0
  }
  let current_area = match current.bounds {
    Some(bounds) => bounds.area()
    None => 0.0
  }
  let delta = current_area - previous_area
  let ratio = if previous_area <= 0.0 {
    if current_area == 0.0 {
      0.0
    } else {
      1.0
    }
  } else {
    delta / previous_area
  }
  release_change(
    "board-metrics",
    if ratio.abs() <= tolerance {
      ReleaseUnchanged
    } else {
      ReleaseModified
    },
    Some(source_hash(previous.summary())),
    Some(source_hash(current.summary())),
    current.shape_count - previous.shape_count,
    if ratio.abs() > tolerance * 2.0 {
      ReleaseRisk
    } else {
      ReleaseNotice
    },
    "board geometry metrics were compared against the area tolerance",
  )
}

///|
pub fn compare_boards(
  previous : Board,
  current : Board,
  tolerance? : Double = 0.05,
) -> Array[ReleaseChange] {
  [
    release_metric_change(
      board_metrics(previous),
      board_metrics(current),
      tolerance,
    ),
  ]
}

///|
pub fn ReleaseAudit::with_changes(
  self : ReleaseAudit,
  changes : Array[ReleaseChange],
) -> ReleaseAudit {
  let gates = self.gates.copy()
  let change_count = changes
    .filter(change => {
      change.kind is ReleaseModified ||
      change.kind is ReleaseAdded ||
      change.kind is ReleaseRemoved
    })
    .length()
  if change_count > self.policy.maximum_changes {
    gates.push(
      release_gate(
        "change-budget",
        ReleaseBlocked,
        ReleaseBlocker,
        Some(change_count.to_double()),
        Some(self.policy.maximum_changes.to_double()),
        "release change count exceeds the policy budget",
        "split the release or update the review plan",
      ),
    )
  }
  {
    manifest: self.manifest,
    policy: self.policy,
    decision: release_decision(gates),
    score: release_score(gates),
    gates,
    changes,
    inspection: self.inspection,
    thermal: self.thermal,
    constraints: self.constraints,
    provenance: self.provenance,
    metrics: self.metrics,
  }
}

///|
pub fn compare_release_audits(
  previous : ReleaseAudit,
  current : ReleaseAudit,
) -> ReleaseDelta {
  let changes = current.changes
  let added = changes.filter(change => change.kind is ReleaseAdded).length()
  let removed = changes.filter(change => change.kind is ReleaseRemoved).length()
  let modified = changes
    .filter(change => change.kind is ReleaseModified)
    .length()
  let previous_blocked = previous.blocked_count()
  let current_blocked = current.blocked_count()
  {
    previous_decision: previous.decision,
    current_decision: current.decision,
    previous_score: previous.score,
    current_score: current.score,
    score_delta: current.score - previous.score,
    added,
    removed,
    modified,
    resolved_gates: if previous_blocked > current_blocked {
      previous_blocked - current_blocked
    } else {
      0
    },
    new_blockers: if current_blocked > previous_blocked {
      current_blocked - previous_blocked
    } else {
      0
    },
    improved: current.score >= previous.score &&
    current_blocked <= previous_blocked,
  }
}

///|
pub fn ReleaseDelta::summary(self : ReleaseDelta) -> String {
  "release=\{release_decision_name(self.previous_decision)} -> \{release_decision_name(self.current_decision)}, score_delta=\{self.score_delta}, added=\{self.added}, removed=\{self.removed}, modified=\{self.modified}, resolved=\{self.resolved_gates}, new_blockers=\{self.new_blockers}, improved=\{self.improved}"
}

///|
fn release_optional_string(value : String?) -> String {
  match value {
    Some(text) => json_string(text)
    None => "null"
  }
}

///|
fn release_optional_number(value : Double?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}

///|
pub fn ReleaseArtifact::to_json(self : ReleaseArtifact) -> String {
  "{\"path\":\{json_string(self.path)},\"kind\":\{json_string(release_artifact_kind_name(self.kind))},\"digest\":\{json_string(self.digest)},\"bytes\":\{self.bytes},\"required\":\{self.required},\"present\":\{self.present},\"description\":\{json_string(self.description)}}"
}

///|
pub fn ReleaseManifest::to_json(self : ReleaseManifest) -> String {
  let artifacts = self.artifacts.map(ReleaseArtifact::to_json).join(",")
  let checks = self.declared_checks.map(json_string).join(",")
  let notes = self.notes.map(json_string).join(",")
  "{\"project\":\{json_string(self.project)},\"revision\":\{json_string(self.revision)},\"digest\":\{json_string(self.digest())},\"artifacts\":[\{artifacts}],\"checks\":[\{checks}],\"notes\":[\{notes}]}"
}

///|
pub fn ReleaseGate::to_json(self : ReleaseGate) -> String {
  "{\"name\":\{json_string(self.name)},\"decision\":\{json_string(release_decision_name(self.decision))},\"severity\":\{json_string(release_severity_name(self.severity))},\"measured\":\{release_optional_number(self.measured)},\"limit\":\{release_optional_number(self.limit)},\"evidence\":\{json_string(self.evidence)},\"remediation\":\{json_string(self.remediation)}}"
}

///|
pub fn ReleaseChange::to_json(self : ReleaseChange) -> String {
  "{\"path\":\{json_string(self.path)},\"kind\":\{json_string(release_change_name(self.kind))},\"previous\":\{release_optional_string(self.previous_digest)},\"current\":\{release_optional_string(self.current_digest)},\"size_delta\":\{self.size_delta},\"risk\":\{json_string(release_severity_name(self.risk))},\"rationale\":\{json_string(self.rationale)}}"
}

///|
pub fn ReleaseAudit::to_json(self : ReleaseAudit) -> String {
  let gates = self.gates.map(ReleaseGate::to_json).join(",")
  let changes = self.changes.map(ReleaseChange::to_json).join(",")
  "{\"summary\":\{json_string(self.summary())},\"manifest\":\{self.manifest.to_json()},\"policy\":\{json_string(self.policy.summary())},\"decision\":\{json_string(release_decision_name(self.decision))},\"score\":\{self.score},\"gates\":[\{gates}],\"changes\":[\{changes}],\"inspection\":\{inspection_report_to_json(self.inspection)},\"thermal\":\{self.thermal.to_json()},\"constraints\":\{constraint_report_to_json(self.constraints)},\"provenance\":\{self.provenance.to_json()},\"metrics\":\{self.metrics.to_json()}}"
}

///|
pub fn ReleaseAudit::to_text(self : ReleaseAudit) -> String {
  let mut output = "Release audit\n\{self.summary()}\n\{self.policy.summary()}\n"
  output += "Manifest: \{self.manifest.summary()}\n"
  for gate in self.gates {
    output += "  \{gate.summary()}\n"
    if !gate.is_passed() {
      output += "    remediation: \{gate.remediation}\n"
    }
  }
  if self.changes.length() > 0 {
    output += "Changes:\n"
    for change in self.changes {
      output += "  \{release_change_name(change.kind)} \{change.path}: \{change.rationale}\n"
    }
  }
  output
}

///|
pub fn ReleaseAudit::to_csv(self : ReleaseAudit) -> String {
  let mut output = "gate,decision,severity,measured,limit,evidence,remediation\n"
  for gate in self.gates {
    output += "\{gate.name},\{release_decision_name(gate.decision)},\{release_severity_name(gate.severity)},\{release_optional_number(gate.measured)},\{release_optional_number(gate.limit)},\{gate.evidence},\{gate.remediation}\n"
  }
  output
}

///|
pub fn ReleaseAudit::sarif(self : ReleaseAudit) -> String {
  let results = self.gates
    .filter(gate => !gate.is_passed())
    .map(gate => {
      "{\"ruleId\":\{json_string(gate.name)},\"level\":\{json_string(if gate.severity is ReleaseBlocker { "error" } else { "warning" })},\"message\":{\"text\":\{json_string(gate.evidence)}}}"
    })
    .join(",")
  "{\"version\":\"2.1.0\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"moonbit-gerberkit release audit\"}},\"results\":[\{results}]}]}"
}

///|
pub fn release_audit_health(audit : ReleaseAudit) -> Bool {
  audit.score >= audit.policy.minimum_score &&
  audit.blocked_count() == 0 &&
  audit.manifest.missing_count() <= audit.policy.maximum_missing_artifacts
}

///|
pub fn release_change_risk(changes : Array[ReleaseChange]) -> ReleaseSeverity {
  if changes.any(change => change.risk is ReleaseBlocker) {
    ReleaseBlocker
  } else if changes.any(change => change.risk is ReleaseRisk) {
    ReleaseRisk
  } else {
    ReleaseNotice
  }
}

///|
pub fn release_manifest_health(manifest : ReleaseManifest) -> Bool {
  manifest.project != "" &&
  manifest.revision != "" &&
  manifest.artifact_count() > 0 &&
  manifest.missing_count() == 0
}

///|
pub fn release_gate_catalog() -> Array[String] {
  [
    "manifest", "inspection", "thermal", "constraints", "provenance", "warnings",
    "score", "change-budget",
  ]
}

///|
pub fn release_policy_catalog() -> Array[ReleasePolicy] {
  [
    prototype_release_policy(),
    standard_release_policy(),
    strict_release_policy(),
  ]
}

///|
pub fn release_policy_markdown() -> String {
  let mut output = "| Policy | Minimum score | Max warnings | Max missing | Inspection | Thermal | Constraints |\n|---|---:|---:|---:|:---:|:---:|:---:| \n"
  for policy in release_policy_catalog() {
    output += "|\{policy.name}|\{policy.minimum_score}|\{policy.maximum_warnings}|\{policy.maximum_missing_artifacts}|\{policy.require_inspection_ready}|\{policy.require_thermal_pass}|\{policy.require_constraints_pass}|\n"
  }
  output
}

///|
pub fn release_artifact_catalog() -> Array[ReleaseArtifactKind] {
  [
    ReleaseGerber,
    ReleaseExcellon,
    ReleaseOutline,
    ReleaseReport,
    ReleaseManifest,
    ReleaseDerived,
  ]
}
