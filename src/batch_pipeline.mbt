///|
/// Deterministic batch execution for multi-board manufacturing jobs. A batch
/// keeps each board's release audit independent, aggregates failures without
/// losing per-job evidence, and emits stable summaries for CI artifacts.
pub enum BatchJobKind {
  BatchGerberJob
  BatchExcellonJob
  BatchBoardJob
  BatchReleaseJob
} derive(Debug, Eq)

///|
pub enum BatchStatus {
  BatchQueued
  BatchRunning
  BatchPassed
  BatchReview
  BatchFailed
  BatchCancelled
} derive(Debug, Eq)

///|
pub enum BatchFailurePolicy {
  BatchContinue
  BatchStopOnFailure
  BatchKeepReviews
} derive(Debug, Eq)

///|
pub struct BatchJob {
  id : Int
  name : String
  kind : BatchJobKind
  board : Board
  manifest : ReleaseManifest
  policy : ReleasePolicy
  tags : Array[String]
  enabled : Bool
} derive(Debug)

///|
pub struct BatchResult {
  job_id : Int
  name : String
  status : BatchStatus
  audit : ReleaseAudit
  elapsed_ticks : UInt64
  output_digest : String
  errors : Array[String]
  warnings : Array[String]
} derive(Debug)

///|
pub struct BatchRun {
  name : String
  policy : BatchFailurePolicy
  status : BatchStatus
  jobs : Array[BatchJob]
  results : Array[BatchResult]
  started_ticks : UInt64
  finished_ticks : UInt64
  run_digest : String
} derive(Debug)

///|
pub struct BatchSummary {
  total_jobs : Int
  passed_jobs : Int
  review_jobs : Int
  failed_jobs : Int
  skipped_jobs : Int
  total_shapes : Int
  total_copper_area : Double
  average_score : Double
  elapsed_ticks : UInt64
  healthy : Bool
} derive(Debug)

///|
pub struct BatchComparison {
  previous_digest : String
  current_digest : String
  added_jobs : Int
  removed_jobs : Int
  changed_jobs : Int
  improved_jobs : Int
  regressed_jobs : Int
  unchanged_jobs : Int
  improved : Bool
} derive(Debug)

///|
pub struct BatchQueue {
  jobs : Array[BatchJob]
  next_id : Int
  duplicate_names : Int
} derive(Debug)

///|
pub fn batch_job_kind_name(value : BatchJobKind) -> String {
  match value {
    BatchGerberJob => "gerber"
    BatchExcellonJob => "excellon"
    BatchBoardJob => "board"
    BatchReleaseJob => "release"
  }
}

///|
pub fn batch_status_name(value : BatchStatus) -> String {
  match value {
    BatchQueued => "queued"
    BatchRunning => "running"
    BatchPassed => "passed"
    BatchReview => "review"
    BatchFailed => "failed"
    BatchCancelled => "cancelled"
  }
}

///|
pub fn batch_failure_policy_name(value : BatchFailurePolicy) -> String {
  match value {
    BatchContinue => "continue"
    BatchStopOnFailure => "stop-on-failure"
    BatchKeepReviews => "keep-reviews"
  }
}

///|
pub fn batch_job_kind_for_path(path : String) -> BatchJobKind {
  let upper = path.to_upper()
  if upper.contains(".GBR") || upper.contains(".GTL") {
    BatchGerberJob
  } else if upper.contains(".DRL") || upper.contains(".TXT") {
    BatchExcellonJob
  } else if upper.contains("RELEASE") {
    BatchReleaseJob
  } else {
    BatchBoardJob
  }
}

///|
pub fn batch_job(
  id : Int,
  name : String,
  kind : BatchJobKind,
  board : Board,
  manifest : ReleaseManifest,
  policy : ReleasePolicy,
) -> BatchJob {
  { id, name, kind, board, manifest, policy, tags: [], enabled: true }
}

///|
pub fn BatchJob::with_tag(self : BatchJob, tag : String) -> BatchJob {
  let tags = self.tags.copy()
  if tag != "" && !tags.contains(tag) {
    tags.push(tag)
  }
  {
    id: self.id,
    name: self.name,
    kind: self.kind,
    board: self.board,
    manifest: self.manifest,
    policy: self.policy,
    tags,
    enabled: self.enabled,
  }
}

///|
pub fn BatchJob::disabled(self : BatchJob) -> BatchJob {
  {
    id: self.id,
    name: self.name,
    kind: self.kind,
    board: self.board,
    manifest: self.manifest,
    policy: self.policy,
    tags: self.tags,
    enabled: false,
  }
}

///|
pub fn BatchJob::shape_count(self : BatchJob) -> Int {
  board_shape_count(self.board)
}

///|
pub fn BatchJob::summary(self : BatchJob) -> String {
  "job=\{self.id} \{self.name} kind=\{batch_job_kind_name(self.kind)} enabled=\{self.enabled}, shapes=\{self.shape_count()}, manifest=\{self.manifest.digest()}"
}

///|
pub fn BatchResult::is_passed(self : BatchResult) -> Bool {
  self.status is BatchPassed
}

///|
pub fn BatchResult::is_failed(self : BatchResult) -> Bool {
  self.status is BatchFailed
}

///|
pub fn BatchResult::is_review(self : BatchResult) -> Bool {
  self.status is BatchReview
}

///|
pub fn BatchResult::summary(self : BatchResult) -> String {
  "\{self.name}: \{batch_status_name(self.status)}, score=\{self.audit.score}, elapsed=\{self.elapsed_ticks}, errors=\{self.errors.length()}, warnings=\{self.warnings.length()}"
}

///|
pub fn BatchRun::job_count(self : BatchRun) -> Int {
  self.jobs.length()
}

///|
pub fn BatchRun::result_count(self : BatchRun) -> Int {
  self.results.length()
}

///|
pub fn BatchRun::is_complete(self : BatchRun) -> Bool {
  self.status is BatchPassed ||
  self.status is BatchReview ||
  self.status is BatchFailed ||
  self.status is BatchCancelled
}

///|
pub fn BatchRun::failed_count(self : BatchRun) -> Int {
  self.results.filter(result => result.status is BatchFailed).length()
}

///|
pub fn BatchRun::review_count(self : BatchRun) -> Int {
  self.results.filter(result => result.status is BatchReview).length()
}

///|
pub fn BatchRun::passed_count(self : BatchRun) -> Int {
  self.results.filter(result => result.status is BatchPassed).length()
}

///|
pub fn BatchRun::summary(self : BatchRun) -> String {
  "batch=\{self.name}, status=\{batch_status_name(self.status)}, jobs=\{self.job_count()}, results=\{self.result_count()}, passed=\{self.passed_count()}, review=\{self.review_count()}, failed=\{self.failed_count()}, digest=\{self.run_digest}"
}

///|
pub fn new_batch_queue() -> BatchQueue {
  { jobs: [], next_id: 0, duplicate_names: 0 }
}

///|
pub fn BatchQueue::job_count(self : BatchQueue) -> Int {
  self.jobs.length()
}

///|
pub fn BatchQueue::duplicate_count(self : BatchQueue) -> Int {
  self.duplicate_names
}

///|
pub fn BatchQueue::has_name(self : BatchQueue, name : String) -> Bool {
  self.jobs.any(job => job.name == name)
}

///|
pub fn BatchQueue::enqueue(
  self : BatchQueue,
  name : String,
  kind : BatchJobKind,
  board : Board,
  manifest : ReleaseManifest,
  policy : ReleasePolicy,
) -> BatchQueue {
  if self.has_name(name) {
    {
      jobs: self.jobs,
      next_id: self.next_id,
      duplicate_names: self.duplicate_names + 1,
    }
  } else {
    let jobs = self.jobs.copy()
    jobs.push(batch_job(self.next_id, name, kind, board, manifest, policy))
    { jobs, next_id: self.next_id + 1, duplicate_names: self.duplicate_names }
  }
}

///|
pub fn BatchQueue::enqueue_board(
  self : BatchQueue,
  name : String,
  board : Board,
  policy? : ReleasePolicy = standard_release_policy(),
) -> BatchQueue {
  self.enqueue(
    name,
    BatchBoardJob,
    board,
    release_manifest_for_board(board, revision=name),
    policy,
  )
}

///|
pub fn BatchQueue::job(self : BatchQueue, index : Int) -> BatchJob? {
  self.jobs.get(index)
}

///|
pub fn BatchQueue::jobs(self : BatchQueue) -> Array[BatchJob] {
  self.jobs.copy()
}

///|
pub fn BatchQueue::enabled_jobs(self : BatchQueue) -> Array[BatchJob] {
  self.jobs.filter(job => job.enabled)
}

///|
pub fn BatchQueue::disable(self : BatchQueue, name : String) -> BatchQueue {
  let jobs = self.jobs.copy()
  for index in 0..<jobs.length() {
    if jobs[index].name == name {
      jobs[index] = jobs[index].disabled()
    }
  }
  { jobs, next_id: self.next_id, duplicate_names: self.duplicate_names }
}

///|
pub fn BatchQueue::tag(
  self : BatchQueue,
  name : String,
  tag : String,
) -> BatchQueue {
  let jobs = self.jobs.copy()
  for index in 0..<jobs.length() {
    if jobs[index].name == name {
      jobs[index] = jobs[index].with_tag(tag)
    }
  }
  { jobs, next_id: self.next_id, duplicate_names: self.duplicate_names }
}

///|
fn batch_result_status(audit : ReleaseAudit) -> BatchStatus {
  match audit.decision {
    ReleaseReady => BatchPassed
    ReleaseReview => BatchReview
    ReleaseBlocked => BatchFailed
  }
}

///|
fn batch_result_errors(audit : ReleaseAudit) -> Array[String] {
  audit.gates
  .filter(gate => gate.decision is ReleaseBlocked)
  .map(gate => gate.name + ": " + gate.evidence)
}

///|
fn batch_result_warnings(audit : ReleaseAudit) -> Array[String] {
  audit.gates
  .filter(gate => gate.decision is ReleaseReview)
  .map(gate => gate.name + ": " + gate.evidence)
}

///|
fn batch_result_for_job(
  job : BatchJob,
  audit : ReleaseAudit,
  elapsed : UInt64,
) -> BatchResult {
  {
    job_id: job.id,
    name: job.name,
    status: batch_result_status(audit),
    audit,
    elapsed_ticks: elapsed,
    output_digest: source_hash(audit.to_json()),
    errors: batch_result_errors(audit),
    warnings: batch_result_warnings(audit),
  }
}

///|
fn batch_run_status(
  results : Array[BatchResult],
  policy : BatchFailurePolicy,
) -> BatchStatus {
  if results.length() == 0 {
    BatchQueued
  } else if results.any(result => result.status is BatchFailed) {
    BatchFailed
  } else if results.any(result => result.status is BatchReview) {
    if policy is BatchKeepReviews {
      BatchReview
    } else {
      BatchReview
    }
  } else {
    BatchPassed
  }
}

///|
fn batch_run_digest(name : String, results : Array[BatchResult]) -> String {
  let mut input = name
  for result in results {
    input += "|" + result.name + "|" + result.output_digest
  }
  source_hash(input)
}

///|
pub fn run_batch(
  name : String,
  queue : BatchQueue,
  policy? : BatchFailurePolicy = BatchContinue,
) -> BatchRun {
  let started = @env.now()
  let results : Array[BatchResult] = []
  let jobs = queue.jobs
  let mut stop = false
  for job in jobs {
    if stop {
      continue
    }
    if !job.enabled {
      continue
    }
    let before = @env.now()
    let audit = audit_release(job.board, job.manifest, job.policy)
    let after = @env.now()
    let result = batch_result_for_job(
      job,
      audit,
      if after >= before {
        after - before
      } else {
        0
      },
    )
    results.push(result)
    if policy is BatchStopOnFailure && results[results.length() - 1].is_failed() {
      stop = true
    }
  }
  let finished = @env.now()
  {
    name,
    policy,
    status: batch_run_status(results, policy),
    jobs,
    results,
    started_ticks: started,
    finished_ticks: finished,
    run_digest: batch_run_digest(name, results),
  }
}

///|
pub fn run_batch_default(name : String, boards : Array[Board]) -> BatchRun {
  let mut queue : BatchQueue = new_batch_queue()
  for index in 0..<boards.length() {
    let board_name = "\{name}-\{index + 1}"
    queue = queue.enqueue_board(board_name, boards[index])
  }
  run_batch(name, queue)
}

///|
pub fn batch_summary(run : BatchRun) -> BatchSummary {
  let mut shapes = 0
  let mut copper = 0.0
  for result in run.results {
    shapes += result.audit.metrics.shape_count
    copper += result.audit.metrics.total_copper_area
  }
  let count = run.results.length()
  {
    total_jobs: run.jobs.length(),
    passed_jobs: run.passed_count(),
    review_jobs: run.review_count(),
    failed_jobs: run.failed_count(),
    skipped_jobs: run.jobs.length() - run.results.length(),
    total_shapes: shapes,
    total_copper_area: copper,
    average_score: if count == 0 {
      0.0
    } else {
      run.results.fold(init=0.0, (sum, result) => sum + result.audit.score) /
      count.to_double()
    },
    elapsed_ticks: if run.finished_ticks >= run.started_ticks {
      run.finished_ticks - run.started_ticks
    } else {
      0
    },
    healthy: run.failed_count() == 0,
  }
}

///|
pub fn BatchSummary::summary(self : BatchSummary) -> String {
  "jobs=\{self.total_jobs}, passed=\{self.passed_jobs}, review=\{self.review_jobs}, failed=\{self.failed_jobs}, skipped=\{self.skipped_jobs}, shapes=\{self.total_shapes}, copper=\{self.total_copper_area}, average_score=\{self.average_score}, elapsed=\{self.elapsed_ticks}, healthy=\{self.healthy}"
}

///|
pub fn BatchSummary::throughput(self : BatchSummary) -> Double {
  if self.elapsed_ticks == 0 {
    self.total_jobs.to_double()
  } else {
    self.total_jobs.to_double() / self.elapsed_ticks.to_double()
  }
}

///|
pub fn BatchSummary::pass_rate(self : BatchSummary) -> Double {
  if self.total_jobs == 0 {
    1.0
  } else {
    self.passed_jobs.to_double() / self.total_jobs.to_double()
  }
}

///|
pub fn BatchRun::summary_data(self : BatchRun) -> BatchSummary {
  batch_summary(self)
}

///|
fn batch_result_named(
  results : Array[BatchResult],
  name : String,
) -> BatchResult? {
  for result in results {
    if result.name == name {
      return Some(result)
    }
  }
  None
}

///|
pub fn batch_compare(
  previous : BatchRun,
  current : BatchRun,
) -> BatchComparison {
  let added = current.jobs
    .filter(job => !previous.jobs.any(old => old.name == job.name))
    .length()
  let removed = previous.jobs
    .filter(job => !current.jobs.any(next => next.name == job.name))
    .length()
  let changed = current.results
    .filter(result => {
      match batch_result_named(previous.results, result.name) {
        Some(old) => old.output_digest != result.output_digest
        None => false
      }
    })
    .length()
  let improved = current.results
    .filter(result => {
      match batch_result_named(previous.results, result.name) {
        Some(old) => result.audit.score > old.audit.score
        None => false
      }
    })
    .length()
  let regressed = current.results
    .filter(result => {
      match batch_result_named(previous.results, result.name) {
        Some(old) => result.audit.score < old.audit.score
        None => false
      }
    })
    .length()
  let unchanged = current.results
    .filter(result => {
      match batch_result_named(previous.results, result.name) {
        Some(old) => result.output_digest == old.output_digest
        None => false
      }
    })
    .length()
  {
    previous_digest: previous.run_digest,
    current_digest: current.run_digest,
    added_jobs: added,
    removed_jobs: removed,
    changed_jobs: changed,
    improved_jobs: improved,
    regressed_jobs: regressed,
    unchanged_jobs: unchanged,
    improved: regressed == 0 &&
    current.failed_count() <= previous.failed_count(),
  }
}

///|
pub fn BatchComparison::summary(self : BatchComparison) -> String {
  "batch=\{self.previous_digest} -> \{self.current_digest}, added=\{self.added_jobs}, removed=\{self.removed_jobs}, changed=\{self.changed_jobs}, improved=\{self.improved_jobs}, regressed=\{self.regressed_jobs}, unchanged=\{self.unchanged_jobs}, improved=\{self.improved}"
}

///|
pub fn batch_validate_queue(queue : BatchQueue) -> Array[String] {
  let errors : Array[String] = []
  if queue.duplicate_names > 0 {
    errors.push("queue contains duplicate job names")
  }
  for job in queue.jobs {
    if job.name == "" {
      errors.push("job name must not be empty")
    }
    if job.manifest.project == "" {
      errors.push("\{job.name}: manifest project is empty")
    }
    if job.shape_count() == 0 {
      errors.push("\{job.name}: board has no geometry")
    }
  }
  errors
}

///|
pub fn batch_queue_health(queue : BatchQueue) -> Bool {
  queue.job_count() > 0 &&
  queue.duplicate_count() == 0 &&
  batch_validate_queue(queue).length() == 0
}

///|
pub fn BatchResult::to_json(self : BatchResult) -> String {
  "{\"job_id\":\{self.job_id},\"name\":\{json_string(self.name)},\"status\":\{json_string(batch_status_name(self.status))},\"elapsed_ticks\":\{self.elapsed_ticks},\"digest\":\{json_string(self.output_digest)},\"errors\":[\{self.errors.map(json_string).join(",")}],\"warnings\":[\{self.warnings.map(json_string).join(",")}],\"audit\":\{self.audit.to_json()}}"
}

///|
pub fn BatchSummary::to_json(self : BatchSummary) -> String {
  "{\"total_jobs\":\{self.total_jobs},\"passed_jobs\":\{self.passed_jobs},\"review_jobs\":\{self.review_jobs},\"failed_jobs\":\{self.failed_jobs},\"skipped_jobs\":\{self.skipped_jobs},\"total_shapes\":\{self.total_shapes},\"total_copper_area\":\{self.total_copper_area},\"average_score\":\{self.average_score},\"elapsed_ticks\":\{self.elapsed_ticks},\"healthy\":\{self.healthy}}"
}

///|
pub fn BatchRun::to_json(self : BatchRun) -> String {
  let results = self.results.map(BatchResult::to_json).join(",")
  "{\"name\":\{json_string(self.name)},\"status\":\{json_string(batch_status_name(self.status))},\"policy\":\{json_string(batch_failure_policy_name(self.policy))},\"digest\":\{json_string(self.run_digest)},\"summary\":\{self.summary_data().to_json()},\"results\":[\{results}]}"
}

///|
pub fn BatchComparison::to_json(self : BatchComparison) -> String {
  "{\"previous\":\{json_string(self.previous_digest)},\"current\":\{json_string(self.current_digest)},\"added\":\{self.added_jobs},\"removed\":\{self.removed_jobs},\"changed\":\{self.changed_jobs},\"improved\":\{self.improved_jobs},\"regressed\":\{self.regressed_jobs},\"unchanged\":\{self.unchanged_jobs},\"is_improved\":\{self.improved}}"
}

///|
pub fn BatchRun::to_text(self : BatchRun) -> String {
  let mut output = "Batch run\n\{self.summary()}\n\{self.summary_data().summary()}\n"
  for result in self.results {
    output += "  \{result.summary()}\n"
    for error in result.errors {
      output += "    error: \{error}\n"
    }
    for warning in result.warnings {
      output += "    warning: \{warning}\n"
    }
  }
  output
}

///|
pub fn BatchRun::to_csv(self : BatchRun) -> String {
  let mut output = "job_id,name,status,score,elapsed_ticks,errors,warnings,digest\n"
  for result in self.results {
    output += "\{result.job_id},\{result.name},\{batch_status_name(result.status)},\{result.audit.score},\{result.elapsed_ticks},\{result.errors.length()},\{result.warnings.length()},\{result.output_digest}\n"
  }
  output
}

///|
pub fn BatchRun::sarif(self : BatchRun) -> String {
  let mut results = ""
  for run in self.results {
    for error in run.errors {
      if results != "" {
        results += ","
      }
      results += "{\"ruleId\":\{json_string(run.name)},\"level\":\"error\",\"message\":{\"text\":\{json_string(error)}}}"
    }
    for warning in run.warnings {
      if results != "" {
        results += ","
      }
      results += "{\"ruleId\":\{json_string(run.name)},\"level\":\"warning\",\"message\":{\"text\":\{json_string(warning)}}}"
    }
  }
  "{\"version\":\"2.1.0\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"moonbit-gerberkit batch\"}},\"results\":[\{results}]}]}"
}

///|
pub fn batch_status_catalog() -> Array[BatchStatus] {
  [
    BatchQueued,
    BatchRunning,
    BatchPassed,
    BatchReview,
    BatchFailed,
    BatchCancelled,
  ]
}

///|
pub fn batch_policy_catalog() -> Array[BatchFailurePolicy] {
  [BatchContinue, BatchStopOnFailure, BatchKeepReviews]
}

///|
pub fn batch_kind_catalog() -> Array[BatchJobKind] {
  [BatchGerberJob, BatchExcellonJob, BatchBoardJob, BatchReleaseJob]
}

///|
pub fn batch_run_health(run : BatchRun) -> Bool {
  run.is_complete() &&
  run.status is BatchPassed &&
  batch_summary(run).healthy &&
  batch_validate_queue({
    jobs: run.jobs,
    next_id: run.jobs.length(),
    duplicate_names: 0,
  }).length() ==
  0
}

///|
pub fn batch_report_markdown(run : BatchRun) -> String {
  let summary = run.summary_data()
  let mut output = "# Batch release report\n\n"
  output += "\{run.summary()}\n\n"
  output += "| Job | Status | Score | Shapes | Copper | Errors | Warnings |\n|---|---|---:|---:|---:|---:|---:|\n"
  for result in run.results {
    output += "|\{result.name}|\{batch_status_name(result.status)}|\{result.audit.score}|\{result.audit.metrics.shape_count}|\{result.audit.metrics.total_copper_area}|\{result.errors.length()}|\{result.warnings.length()}|\n"
  }
  output += "\nOverall: \{summary.summary()}\n"
  output
}

///|
pub fn batch_digest_is_stable(run : BatchRun) -> Bool {
  run.run_digest == batch_run_digest(run.name, run.results) &&
  run.run_digest != ""
}

///|
pub fn BatchRun::failed_names(self : BatchRun) -> Array[String] {
  self.results.filter(result => result.is_failed()).map(result => result.name)
}

///|
pub fn BatchRun::review_names(self : BatchRun) -> Array[String] {
  self.results.filter(result => result.is_review()).map(result => result.name)
}

///|
pub fn BatchRun::passed_names(self : BatchRun) -> Array[String] {
  self.results.filter(result => result.is_passed()).map(result => result.name)
}

///|
pub fn BatchRun::job_names(self : BatchRun) -> Array[String] {
  self.jobs.map(job => job.name)
}

///|
pub fn BatchRun::result(self : BatchRun, job_id : Int) -> BatchResult? {
  for result in self.results {
    if result.job_id == job_id {
      return Some(result)
    }
  }
  None
}

///|
pub fn BatchRun::job(self : BatchRun, job_id : Int) -> BatchJob? {
  for job in self.jobs {
    if job.id == job_id {
      return Some(job)
    }
  }
  None
}

///|
pub fn BatchRun::total_estimated_cost(self : BatchRun) -> Double {
  self.results.fold(init=0.0, (sum, result) => {
    sum + result.audit.inspection.fabrication.estimated_cost
  })
}

///|
pub fn BatchRun::total_estimated_minutes(self : BatchRun) -> Double {
  self.results.fold(init=0.0, (sum, result) => {
    sum + result.audit.inspection.fabrication.estimated_minutes
  })
}

///|
pub fn BatchRun::release_ready(self : BatchRun, name : String) -> Bool {
  match batch_result_named(self.results, name) {
    Some(result) => result.is_passed() && result.audit.is_ready()
    None => false
  }
}

///|
pub fn batch_run_cost_summary(run : BatchRun) -> String {
  "estimated_minutes=\{run.total_estimated_minutes()}, estimated_cost=\{run.total_estimated_cost()}, throughput=\{run.summary_data().throughput()}"
}

///|
pub fn batch_run_health_report(run : BatchRun) -> String {
  let summary = run.summary_data()
  let mut output = run.summary() + "\n" + summary.summary() + "\n"
  output += batch_run_cost_summary(run) + "\n"
  if run.failed_names().length() > 0 {
    output += "failed: " + run.failed_names().join(",") + "\n"
  }
  if run.review_names().length() > 0 {
    output += "review: " + run.review_names().join(",") + "\n"
  }
  output
}

///|
pub fn batch_run_manifest_digests(run : BatchRun) -> Array[String] {
  run.jobs.map(job => job.manifest.digest())
}

///|
pub fn batch_run_has_duplicate_digests(run : BatchRun) -> Bool {
  let digests = batch_run_manifest_digests(run)
  for index in 0..<digests.length() {
    for other in 0..<digests.length() {
      if other > index && digests[index] == digests[other] {
        return true
      }
    }
  }
  false
}
