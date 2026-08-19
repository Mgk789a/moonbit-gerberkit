///|
pub enum GerberTokenKind {
  ParameterStart
  ParameterEnd
  Command
  Coordinate
  Attribute
  Comment
  EndOfFile
  Unknown
} derive(Debug, Eq)

///|
pub struct GerberToken {
  kind : GerberTokenKind
  text : String
  line : Int
  column : Int
} derive(Debug)

///|
pub fn gerber_token(
  kind~ : GerberTokenKind,
  text~ : String,
  line~ : Int,
  column~ : Int,
) -> GerberToken {
  { kind, text, line, column }
}

///|
pub fn GerberToken::is_command(self : GerberToken) -> Bool {
  self.kind is Command
}

///|
pub fn GerberToken::is_coordinate(self : GerberToken) -> Bool {
  self.kind is Coordinate
}

///|
pub fn GerberToken::location(self : GerberToken) -> String {
  "\{self.line}:\{self.column}"
}

///|
pub fn GerberToken::display(self : GerberToken) -> String {
  "\{self.location()} \{token_kind_name(self.kind)} \{self.text}"
}

///|
pub fn token_kind_name(kind : GerberTokenKind) -> String {
  match kind {
    ParameterStart => "parameter-start"
    ParameterEnd => "parameter-end"
    Command => "command"
    Coordinate => "coordinate"
    Attribute => "attribute"
    Comment => "comment"
    EndOfFile => "eof"
    Unknown => "unknown"
  }
}

///|
fn lexer_token_kind(text : String) -> GerberTokenKind {
  if text.has_prefix("G04") {
    Comment
  } else if text.has_prefix("TF") ||
    text.has_prefix("TA") ||
    text.has_prefix("TO") {
    Attribute
  } else if text.has_prefix("G") ||
    text.has_prefix("D") ||
    text.has_prefix("M") ||
    text.has_prefix("FS") ||
    text.has_prefix("MO") ||
    text.has_prefix("AD") {
    Command
  } else if text.has_prefix("X") ||
    text.has_prefix("Y") ||
    text.has_prefix("I") ||
    text.has_prefix("J") {
    Coordinate
  } else {
    Unknown
  }
}

///|
fn lexer_push_record(
  tokens : Array[GerberToken],
  record : String,
  line : Int,
  column : Int,
) -> Unit {
  let text = record.trim().to_owned()
  if text != "" {
    tokens.push(
      gerber_token(kind=lexer_token_kind(text), text~, line~, column~),
    )
  }
}

///|
pub fn tokenize_gerber(text : String) -> Array[GerberToken] {
  let tokens : Array[GerberToken] = []
  let mut line = 1
  let mut column = 1
  let mut record = ""
  let mut parameter_mode = false
  for character in text {
    if character == '%' {
      lexer_push_record(tokens, record, line, column)
      record = ""
      if parameter_mode {
        tokens.push(gerber_token(kind=ParameterEnd, text="%", line~, column~))
      } else {
        tokens.push(gerber_token(kind=ParameterStart, text="%", line~, column~))
      }
      parameter_mode = !parameter_mode
      column += 1
    } else if character == '*' {
      lexer_push_record(tokens, record, line, column)
      record = ""
      column += 1
    } else if character == '\n' {
      lexer_push_record(tokens, record, line, column)
      record = ""
      line += 1
      column = 1
    } else {
      record = record + character.to_string()
      column += 1
    }
  }
  lexer_push_record(tokens, record, line, column)
  tokens.push(gerber_token(kind=EndOfFile, text="", line~, column~))
  tokens
}

///|
pub fn tokenize_records(text : String) -> Array[String] {
  tokenize_gerber(text).filter_map(token => {
    match token.kind {
      ParameterStart | ParameterEnd | EndOfFile => None
      _ => Some(token.text)
    }
  })
}

///|
pub fn strip_gerber_comments(text : String) -> String {
  let records = tokenize_gerber(text).filter_map(token => {
    match token.kind {
      Comment => None
      ParameterStart => Some("%")
      ParameterEnd => Some("%")
      EndOfFile => None
      _ => Some(token.text + "*")
    }
  })
  records.join("")
}

///|
pub fn record_has_code(record : String, code : StringView) -> Bool {
  record.contains(code)
}

///|
pub fn record_code_value(record : String, code : StringView) -> Int? {
  match record.find(code) {
    None => None
    Some(start) => {
      let view = record[start + code.length():]
      let mut digits = ""
      for character in view {
        if character >= '0' && character <= '9' {
          digits = digits + character.to_string()
        } else {
          break
        }
      }
      if digits == "" {
        None
      } else {
        parse_decimal(digits[:]).map(value => value.to_int())
      }
    }
  }
}

///|
pub fn record_coordinate(record : String, axis : Char) -> String? {
  let key = axis.to_string()
  match record.find(key[:]) {
    None => None
    Some(start) => {
      let value = record[start + 1:]
      let mut result = ""
      for character in value {
        if (character >= '0' && character <= '9') ||
          character == '-' ||
          character == '+' ||
          character == '.' {
          result = result + character.to_string()
        } else {
          break
        }
      }
      if result == "" {
        None
      } else {
        Some(result)
      }
    }
  }
}

///|
pub fn record_coordinate_number(record : String, axis : Char) -> Double? {
  record_coordinate(record, axis).map(value => {
    parse_decimal(value[:]).unwrap_or(0.0)
  })
}

///|
pub fn record_axes(record : String) -> Array[Char] {
  let result : Array[Char] = []
  for axis in ['X', 'Y', 'I', 'J', 'A', 'B', 'C'] {
    if record_coordinate(record, axis) is Some(_) {
      result.push(axis)
    }
  }
  result
}

///|
pub struct SourceSpan {
  start_line : Int
  start_column : Int
  end_line : Int
  end_column : Int
} derive(Debug)

///|
pub fn source_span(
  start_line~ : Int,
  start_column~ : Int,
  end_line~ : Int,
  end_column~ : Int,
) -> SourceSpan {
  { start_line, start_column, end_line, end_column }
}

///|
pub fn SourceSpan::contains(
  self : SourceSpan,
  line~ : Int,
  column~ : Int,
) -> Bool {
  let after_start = line > self.start_line ||
    (line == self.start_line && column >= self.start_column)
  let before_end = line < self.end_line ||
    (line == self.end_line && column <= self.end_column)
  after_start && before_end
}

///|
pub fn SourceSpan::to_string(self : SourceSpan) -> String {
  "\{self.start_line}:\{self.start_column}-\{self.end_line}:\{self.end_column}"
}

///|
pub enum DiagnosticSeverity {
  InfoDiagnostic
  WarningDiagnostic
  ErrorDiagnostic
} derive(Debug, Eq)

///|
pub fn info_diagnostic() -> DiagnosticSeverity {
  InfoDiagnostic
}

///|
pub fn warning_diagnostic() -> DiagnosticSeverity {
  WarningDiagnostic
}

///|
pub fn error_diagnostic() -> DiagnosticSeverity {
  ErrorDiagnostic
}

///|
pub struct ParseDiagnostic {
  severity : DiagnosticSeverity
  code : String
  message : String
  line : Int
  column : Int
  record : String
} derive(Debug)

///|
pub fn diagnostic(
  severity~ : DiagnosticSeverity,
  code~ : String,
  message~ : String,
  line~ : Int,
  column~ : Int,
  record~ : String,
) -> ParseDiagnostic {
  { severity, code, message, line, column, record }
}

///|
pub fn ParseDiagnostic::is_error(self : ParseDiagnostic) -> Bool {
  self.severity is ErrorDiagnostic
}

///|
pub fn ParseDiagnostic::severity_name(self : ParseDiagnostic) -> String {
  match self.severity {
    InfoDiagnostic => "info"
    WarningDiagnostic => "warning"
    ErrorDiagnostic => "error"
  }
}

///|
pub fn ParseDiagnostic::format(self : ParseDiagnostic) -> String {
  let shown_record = if self.record.length() > 64 {
    self.record[:64].to_owned() + "..."
  } else {
    self.record
  }
  "\{self.severity_name()} [\{self.code}] \{self.line}:\{self.column}: \{self.message} (\{shown_record})"
}

///|
pub struct TokenStream {
  tokens : Array[GerberToken]
  mut index : Int
} derive(Debug)

///|
pub fn token_stream(tokens : Array[GerberToken]) -> TokenStream {
  { tokens, index: 0 }
}

///|
pub fn TokenStream::peek(self : TokenStream) -> GerberToken? {
  self.tokens.get(self.index)
}

///|
pub fn TokenStream::take(self : TokenStream) -> GerberToken? {
  let result = self.tokens.get(self.index)
  if result is Some(_) {
    self.index += 1
  }
  result
}

///|
pub fn TokenStream::at_end(self : TokenStream) -> Bool {
  match self.peek() {
    Some(token) => token.kind is EndOfFile
    None => true
  }
}

///|
pub fn TokenStream::skip_until(
  self : TokenStream,
  kind : GerberTokenKind,
) -> Int {
  let mut skipped = 0
  while !self.at_end() {
    match self.peek() {
      Some(token) if token.kind == kind => break
      Some(_) => {
        ignore(self.take())
        skipped += 1
      }
      None => break
    }
  }
  skipped
}

///|
pub fn tokenize_excellon(text : String) -> Array[String] {
  let records : Array[String] = []
  for line in text.split("\n") {
    let clean = line.trim().to_owned()
    if clean != "" && !clean.has_prefix(";") {
      records.push(clean)
    }
  }
  records
}

///|
pub fn line_numbered_records(text : String) -> Array[(Int, String)] {
  let result : Array[(Int, String)] = []
  let mut line = 1
  for raw in text.split("\n") {
    result.push((line, raw.to_owned()))
    line += 1
  }
  result
}

///|
pub fn normalize_record(record : String) -> String {
  record.trim().to_owned().replace(old=" ", new="").replace(old="\t", new="")
}

///|
pub fn checksum_records(records : Array[String]) -> Int {
  let mut checksum = 0
  for record in records {
    for character in record {
      checksum = (checksum + character.to_int()) % 65521
    }
  }
  checksum
}

///|
pub fn is_parameter_record(record : String) -> Bool {
  record.has_prefix("FS") ||
  record.has_prefix("MO") ||
  record.has_prefix("AD") ||
  record.has_prefix("AM") ||
  record.has_prefix("TF") ||
  record.has_prefix("TA") ||
  record.has_prefix("TO") ||
  record.has_prefix("TD") ||
  record.has_prefix("IF")
}

///|
pub fn is_motion_record(record : String) -> Bool {
  record.contains("D01") ||
  record.contains("D02") ||
  record.contains("D03") ||
  record.has_prefix("G01") ||
  record.has_prefix("G02") ||
  record.has_prefix("G03")
}

///|
pub fn is_end_record(record : String) -> Bool {
  record == "M02" || record == "M30" || record == "%"
}
