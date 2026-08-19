///|
pub enum ValidationStatus {
  ValidInput
  ValidWithWarnings
  InvalidInput
} derive(Debug, Eq)

///|
pub struct ValidationIssue {
  code : String
  message : String
  severity : DfmSeverity
  line : Int?
  column : Int?
} derive(Debug)

///|
pub struct ValidationResult {
  status : ValidationStatus
  issues : Array[ValidationIssue]
  records : Int
  shapes : Int
  normalized : Bool
} derive(Debug)

///|
pub fn validation_issue(
  code : String,
  message : String,
  severity : DfmSeverity,
  line : Int?,
  column : Int?,
) -> ValidationIssue {
  { code, message, severity, line, column }
}

///|
pub fn ValidationIssue::severity_name(self : ValidationIssue) -> String {
  dfm_severity_name(self.severity)
}

///|
pub fn ValidationIssue::format(self : ValidationIssue) -> String {
  let position = match (self.line, self.column) {
    (Some(line), Some(column)) => " at \{line}:\{column}"
    (Some(line), None) => " at \{line}"
    _ => ""
  }
  "\{self.severity_name()} [\{self.code}]\{position}: \{self.message}"
}

///|
pub fn ValidationResult::is_valid(self : ValidationResult) -> Bool {
  self.status is ValidInput || self.status is ValidWithWarnings
}

///|
pub fn ValidationResult::error_count(self : ValidationResult) -> Int {
  self.issues.filter(issue => issue.severity is DfmError).length()
}

///|
pub fn ValidationResult::warning_count(self : ValidationResult) -> Int {
  self.issues.filter(issue => issue.severity is DfmWarning).length()
}

///|
pub fn ValidationResult::summary(self : ValidationResult) -> String {
  "status=\{validation_status_name(self.status)}, records=\{self.records}, shapes=\{self.shapes}, errors=\{self.error_count()}, warnings=\{self.warning_count()}"
}

///|
pub fn validation_status_name(status : ValidationStatus) -> String {
  match status {
    ValidInput => "valid"
    ValidWithWarnings => "valid-with-warnings"
    InvalidInput => "invalid"
  }
}

///|
pub fn validation_valid_status() -> ValidationStatus {
  ValidInput
}

///|
pub fn validation_warning_status() -> ValidationStatus {
  ValidWithWarnings
}

///|
pub fn validation_invalid_status() -> ValidationStatus {
  InvalidInput
}

///|
pub struct ValidationOptions {
  max_records : Int
  max_shapes : Int
  reject_unknown_records : Bool
  reject_empty_input : Bool
  require_end_record : Bool
  check_coordinates : Bool
} derive(Debug)

///|
pub fn default_validation_options() -> ValidationOptions {
  {
    max_records: 1000000,
    max_shapes: 1000000,
    reject_unknown_records: false,
    reject_empty_input: true,
    require_end_record: false,
    check_coordinates: true,
  }
}

///|
fn validation_add(
  issues : Array[ValidationIssue],
  code : String,
  message : String,
  severity : DfmSeverity,
  line : Int?,
) -> Unit {
  issues.push(validation_issue(code, message, severity, line, None))
}

///|
fn validation_result(
  issues : Array[ValidationIssue],
  records : Int,
  shapes : Int,
  normalized : Bool,
) -> ValidationResult {
  let has_error = issues.any(issue => issue.severity is DfmError)
  let has_warning = issues.any(issue => issue.severity is DfmWarning)
  let status = if has_error {
    InvalidInput
  } else if has_warning {
    ValidWithWarnings
  } else {
    ValidInput
  }
  { status, issues, records, shapes, normalized }
}

///|
pub fn validate_gerber(
  text : String,
  options? : ValidationOptions = default_validation_options(),
) -> ValidationResult {
  let issues : Array[ValidationIssue] = []
  let records = tokenize_records(text)
  if options.reject_empty_input && text.trim().to_owned() == "" {
    validation_add(
      issues,
      "empty-input",
      "Gerber input is empty",
      DfmError,
      None,
    )
  }
  if records.length() > options.max_records {
    validation_add(
      issues,
      "record-limit",
      "Gerber input exceeds the configured record limit",
      DfmError,
      None,
    )
  }
  if options.require_end_record && !records.any(record => is_end_record(record)) {
    validation_add(
      issues,
      "missing-end",
      "Gerber input has no M02 or M30 end record",
      DfmError,
      None,
    )
  }
  for _, pair in line_numbered_records(text) {
    let line = pair.0
    let raw = pair.1
    let clean = normalize_record(raw)
    if clean != "" && clean.length() > 4096 {
      validation_add(
        issues,
        "record-too-long",
        "Gerber record exceeds the safe parser length",
        DfmWarning,
        Some(line),
      )
    }
    if options.reject_unknown_records &&
      clean != "" &&
      !is_parameter_record(clean) &&
      !is_motion_record(clean) &&
      !is_end_record(clean) &&
      !(record_coordinate(clean, 'X') is Some(_)) &&
      !(record_coordinate(clean, 'Y') is Some(_)) {
      validation_add(
        issues,
        "unknown-record",
        "record is not recognized by the strict validation profile",
        DfmError,
        Some(line),
      )
    }
    if options.check_coordinates {
      for axis in ['X', 'Y', 'I', 'J'] {
        if clean.contains(axis.to_string()) {
          match record_coordinate(clean, axis) {
            Some(value) if parse_decimal(value[:]) is None =>
              validation_add(
                issues,
                "invalid-coordinate",
                "coordinate contains no valid numeric payload",
                DfmError,
                Some(line),
              )
            None =>
              validation_add(
                issues,
                "invalid-coordinate",
                "coordinate contains no valid numeric payload",
                DfmError,
                Some(line),
              )
            _ => ()
          }
        }
      }
    }
  }
  let document = parse_gerber_document(text)
  if document.layer.shapes.length() > options.max_shapes {
    validation_add(
      issues,
      "shape-limit",
      "Gerber input exceeds the configured shape limit",
      DfmError,
      None,
    )
  }
  if document.has_errors() {
    for diagnostic in document.diagnostics {
      if diagnostic.is_error() {
        validation_add(
          issues,
          diagnostic.code,
          diagnostic.message,
          DfmError,
          Some(diagnostic.line),
        )
      }
    }
  }
  validation_result(
    issues,
    records.length(),
    document.layer.shapes.length(),
    true,
  )
}

///|
pub fn validate_excellon(
  text : String,
  options? : ValidationOptions = default_validation_options(),
) -> ValidationResult {
  let issues : Array[ValidationIssue] = []
  let records = tokenize_excellon(text)
  if options.reject_empty_input && text.trim().to_owned() == "" {
    validation_add(
      issues,
      "empty-input",
      "Excellon input is empty",
      DfmError,
      None,
    )
  }
  if records.length() > options.max_records {
    validation_add(
      issues,
      "record-limit",
      "Excellon input exceeds the configured record limit",
      DfmError,
      None,
    )
  }
  if options.require_end_record &&
    !records.any(record => record == "M30" || record == "M00") {
    validation_add(
      issues,
      "missing-end",
      "Excellon input has no M30 end record",
      DfmError,
      None,
    )
  }
  for _, pair in line_numbered_records(text) {
    let line = pair.0
    let raw = pair.1
    let clean = normalize_record(raw)
    if clean.has_prefix("X") || clean.has_prefix("Y") {
      if options.check_coordinates &&
        record_coordinate(clean, 'X') is None &&
        record_coordinate(clean, 'Y') is None {
        validation_add(
          issues,
          "invalid-coordinate",
          "drill record has no X or Y coordinate",
          DfmError,
          Some(line),
        )
      }
    }
  }
  let document = parse_excellon_document(text)
  if document.layer.shapes.length() > options.max_shapes {
    validation_add(
      issues,
      "shape-limit",
      "Excellon input exceeds the configured shape limit",
      DfmError,
      None,
    )
  }
  for diagnostic in document.diagnostics {
    if diagnostic.is_error() {
      validation_add(
        issues,
        diagnostic.code,
        diagnostic.message,
        DfmError,
        Some(diagnostic.line),
      )
    } else if diagnostic.severity is WarningDiagnostic {
      validation_add(
        issues,
        diagnostic.code,
        diagnostic.message,
        DfmWarning,
        Some(diagnostic.line),
      )
    }
  }
  validation_result(
    issues,
    records.length(),
    document.layer.shapes.length(),
    true,
  )
}

///|
pub fn validate_board(
  board : Board,
  options? : DfmConfig = default_dfm_config(),
) -> ValidationResult {
  let report = run_dfm(board, config=options)
  let issues = report.findings.map(finding => {
    validation_issue(
      finding.rule_name(),
      finding.message,
      if finding.severity is DfmError {
        DfmError
      } else if finding.severity is DfmWarning {
        DfmWarning
      } else {
        DfmInfo
      },
      None,
      None,
    )
  })
  validation_result(
    issues,
    board_shape_count(board),
    board_shape_count(board),
    false,
  )
}

///|
pub fn normalize_gerber(text : String) -> String {
  let tokens = tokenize_gerber(strip_gerber_comments(text))
  let mut result = ""
  for token in tokens {
    match token.kind {
      ParameterStart => result += "%"
      ParameterEnd => result += "%"
      EndOfFile => ()
      _ => result += normalize_record(token.text) + "*"
    }
  }
  result
}

///|
pub fn normalize_excellon(text : String) -> String {
  let mut result = ""
  for record in tokenize_excellon(text) {
    result += normalize_record(record) + "\n"
  }
  result
}

///|
pub fn validation_result_to_json(result : ValidationResult) -> String {
  let issues = result.issues
    .map(issue => {
      "{\"code\":\{json_string(issue.code)},\"severity\":\{json_string(issue.severity_name())},\"message\":\{json_string(issue.message)},\"line\":\{issue.line.map(value => value.to_string()).unwrap_or("null")}}"
    })
    .join(",")
  "{\"summary\":\{json_string(result.summary())},\"status\":\{json_string(validation_status_name(result.status))},\"records\":\{result.records},\"shapes\":\{result.shapes},\"issues\":[\{issues}]}"
}
