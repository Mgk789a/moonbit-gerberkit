///|
pub enum InputKind {
  GerberInput
  ExcellonInput
  UnknownInput
} derive(Debug, Eq)

///|
pub enum PipelineFormat {
  JsonOutput
  SvgOutput
  AsciiOutput
  SarifOutput
  CsvOutput
  TextOutput
  HtmlOutput
} derive(Debug, Eq)

///|
pub struct PipelineOptions {
  dfm : DfmConfig
  validation : ValidationOptions
  format : PipelineFormat
  include_shapes : Bool
  analyze_outline : Bool
} derive(Debug)

///|
pub fn default_pipeline_options() -> PipelineOptions {
  {
    dfm: default_dfm_config(),
    validation: default_validation_options(),
    format: JsonOutput,
    include_shapes: false,
    analyze_outline: true,
  }
}

///|
pub fn pipeline_format_name(format : PipelineFormat) -> String {
  match format {
    JsonOutput => "json"
    SvgOutput => "svg"
    AsciiOutput => "ascii"
    SarifOutput => "sarif"
    CsvOutput => "csv"
    TextOutput => "text"
    HtmlOutput => "html"
  }
}

///|
pub fn json_pipeline_format() -> PipelineFormat {
  JsonOutput
}

///|
pub fn svg_pipeline_format() -> PipelineFormat {
  SvgOutput
}

///|
pub fn ascii_pipeline_format() -> PipelineFormat {
  AsciiOutput
}

///|
pub fn sarif_pipeline_format() -> PipelineFormat {
  SarifOutput
}

///|
pub fn csv_pipeline_format() -> PipelineFormat {
  CsvOutput
}

///|
pub fn text_pipeline_format() -> PipelineFormat {
  TextOutput
}

///|
pub fn html_pipeline_format() -> PipelineFormat {
  HtmlOutput
}

///|
pub enum ParsedInput {
  GerberParsed(document~ : GerberDocument)
  ExcellonParsed(document~ : ExcellonDocument)
  UnknownParsed(text~ : String)
} derive(Debug)

///|
pub struct PipelineResult {
  input_kind : InputKind
  source_name : String
  input_size : Int
  parsed : ParsedInput
  board : Board
  validation : ValidationResult
  dfm : DfmReport
  outline : OutlineAnalysis?
} derive(Debug)

///|
pub fn PipelineResult::passed(self : PipelineResult) -> Bool {
  self.validation.is_valid() && self.dfm.passed()
}

///|
pub fn PipelineResult::error_count(self : PipelineResult) -> Int {
  self.validation.error_count() + self.dfm.error_count()
}

///|
pub fn PipelineResult::summary(self : PipelineResult) -> String {
  "source=\{self.source_name}, kind=\{input_kind_name(self.input_kind)}, bytes=\{self.input_size}, validation=(\{self.validation.summary()}), dfm=(\{self.dfm.summary()})"
}

///|
pub fn input_kind_name(kind : InputKind) -> String {
  match kind {
    GerberInput => "gerber"
    ExcellonInput => "excellon"
    UnknownInput => "unknown"
  }
}

///|
pub fn detect_input_kind(text : String) -> InputKind {
  if text.contains("M48") ||
    text.contains("METRIC") ||
    text.contains("INCH") ||
    text.contains("T1C") {
    ExcellonInput
  } else if text.contains("%") ||
    text.contains("D01") ||
    text.contains("D02") ||
    text.contains("D03") {
    GerberInput
  } else {
    UnknownInput
  }
}

///|
fn input_layer(parsed : ParsedInput) -> Layer {
  match parsed {
    GerberParsed(document~) => document.layer
    ExcellonParsed(document~) => document.layer
    UnknownParsed(text~) =>
      {
        name: "unknown",
        kind: Unknown,
        unit: Millimeter,
        shapes: if text == "" {
          []
        } else {
          [Flash(x=0.0, y=0.0, aperture=0)]
        },
      }
  }
}

///|
fn input_validation(
  parsed : ParsedInput,
  text : String,
  options : ValidationOptions,
) -> ValidationResult {
  match parsed {
    GerberParsed(..) => validate_gerber(text, options~)
    ExcellonParsed(..) => validate_excellon(text, options~)
    UnknownParsed(..) =>
      validation_result(
        [
          validation_issue(
            "unknown-format",
            "input did not match Gerber or Excellon signatures",
            DfmWarning,
            None,
            None,
          ),
        ],
        0,
        0,
        false,
      )
  }
}

///|
/// Parse one input, run validation and the manufacturing rule set, and return all evidence.
pub fn process_text(
  text : String,
  source_name? : String = "input",
  options? : PipelineOptions = default_pipeline_options(),
) -> PipelineResult {
  let kind = detect_input_kind(text)
  let parsed = match kind {
    GerberInput =>
      GerberParsed(document=parse_gerber_document(text, name=source_name))
    ExcellonInput =>
      ExcellonParsed(document=parse_excellon_document(text, name=source_name))
    UnknownInput => UnknownParsed(text~)
  }
  let layer = input_layer(parsed)
  let board = board_from_layers([layer])
  let validation = input_validation(parsed, text, options.validation)
  let dfm = run_dfm(board, config=options.dfm)
  let outline = if options.analyze_outline {
    Some(analyze_outline(board))
  } else {
    None
  }
  {
    input_kind: kind,
    source_name,
    input_size: text.length(),
    parsed,
    board,
    validation,
    dfm,
    outline,
  }
}

///|
pub fn process_many(
  inputs : Array[(String, String)],
  options? : PipelineOptions = default_pipeline_options(),
) -> PipelineResult {
  let builder = board_builder()
  let mut first_kind = UnknownInput
  let mut first_name = "batch"
  let mut total_bytes = 0
  let validation_issues : Array[ValidationIssue] = []
  for index, pair in inputs {
    let result = process_text(pair.1, source_name=pair.0, options~)
    if index == 0 {
      first_kind = result.input_kind
      first_name = pair.0
    }
    total_bytes += pair.1.length()
    validation_issues.append(result.validation.issues[:])
    for layer in result.board.layers {
      builder.add_layer(layer)
    }
  }
  let board = builder.finish()
  let validation = validation_result(
    validation_issues,
    inputs.length(),
    board_shape_count(board),
    true,
  )
  let dfm = run_dfm(board, config=options.dfm)
  {
    input_kind: first_kind,
    source_name: first_name,
    input_size: total_bytes,
    parsed: UnknownParsed(text="batch"),
    board,
    validation,
    dfm,
    outline: if options.analyze_outline {
      Some(analyze_outline(board))
    } else {
      None
    },
  }
}

///|
pub fn pipeline_render(
  result : PipelineResult,
  format : PipelineFormat,
) -> String {
  match format {
    JsonOutput => {
      let outline = match result.outline {
        Some(value) => ",\"outline\":" + value.to_json()
        None => ""
      }
      "{\"summary\":\{json_string(result.summary())},\"validation\":\{validation_result_to_json(result.validation)},\"dfm\":\{dfm_report_to_json(result.dfm)},\"board\":\{board_to_json(result.board, include_shapes=true)}\{outline}}"
    }
    SvgOutput => to_svg(result.board)
    AsciiOutput => to_ascii(result.board)
    SarifOutput => dfm_to_sarif(result.dfm)
    CsvOutput => dfm_to_csv(result.dfm)
    TextOutput => result.summary() + "\n" + dfm_to_text(result.dfm)
    HtmlOutput => board_to_html(result.board, report=result.dfm)
  }
}

///|
pub fn PipelineResult::to_json(self : PipelineResult) -> String {
  pipeline_render(self, JsonOutput)
}

///|
pub fn PipelineResult::to_sarif(self : PipelineResult) -> String {
  pipeline_render(self, SarifOutput)
}

///|
pub fn PipelineResult::exit_code(self : PipelineResult) -> Int {
  if self.passed() {
    0
  } else {
    1
  }
}

///|
pub fn PipelineResult::outline_summary(self : PipelineResult) -> String {
  match self.outline {
    Some(value) => value.summary()
    None => "outline analysis disabled"
  }
}

///|
pub fn pipeline_report_many(inputs : Array[(String, String)]) -> String {
  pipeline_render(process_many(inputs), JsonOutput)
}

///|
pub fn pipeline_format_from_name(value : String) -> PipelineFormat {
  match value.to_lower() {
    "svg" => SvgOutput
    "ascii" => AsciiOutput
    "sarif" => SarifOutput
    "csv" => CsvOutput
    "text" => TextOutput
    "html" => HtmlOutput
    _ => JsonOutput
  }
}
