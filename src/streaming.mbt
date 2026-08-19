///|
/// Incremental record processing for large Gerber and Excellon jobs. The
/// scanner keeps record boundaries across chunks, tracks source locations, and
/// exposes bounded diagnostics without requiring the complete input in memory.
pub enum StreamDocumentKind {
  StreamGerber
  StreamExcellon
  StreamUnknown
} derive(Debug, Eq)

///|
pub enum StreamPhase {
  StreamCreated
  StreamReceiving
  StreamFinished
  StreamFailed
} derive(Debug, Eq)

///|
pub enum StreamDiagnosticSeverity {
  StreamNote
  StreamWarning
  StreamError
} derive(Debug, Eq)

///|
pub struct StreamRecord {
  index : Int
  text : String
  start_offset : Int
  end_offset : Int
  line : Int
  column : Int
  terminator : Char
} derive(Debug)

///|
pub struct StreamDiagnostic {
  severity : StreamDiagnosticSeverity
  code : String
  message : String
  record_index : Int?
  offset : Int
  line : Int
} derive(Debug)

///|
pub struct StreamStats {
  byte_count : Int
  record_count : Int
  line_count : Int
  max_record_length : Int
  star_terminated : Int
  newline_terminated : Int
  empty_records : Int
  coordinate_records : Int
  comment_records : Int
} derive(Debug)

///|
pub struct IncrementalDocument {
  kind : StreamDocumentKind
  phase : StreamPhase
  pending : String
  records : Array[StreamRecord]
  diagnostics : Array[StreamDiagnostic]
  stats : StreamStats
  max_record_length : Int
  max_diagnostics : Int
  offset : Int
  line : Int
  column : Int
} derive(Debug)

///|
pub fn stream_kind_name(value : StreamDocumentKind) -> String {
  match value {
    StreamGerber => "gerber"
    StreamExcellon => "excellon"
    StreamUnknown => "unknown"
  }
}

///|
pub fn stream_phase_name(value : StreamPhase) -> String {
  match value {
    StreamCreated => "created"
    StreamReceiving => "receiving"
    StreamFinished => "finished"
    StreamFailed => "failed"
  }
}

///|
pub fn stream_severity_name(value : StreamDiagnosticSeverity) -> String {
  match value {
    StreamNote => "note"
    StreamWarning => "warning"
    StreamError => "error"
  }
}

///|
pub fn stream_kind_from_name(value : String) -> StreamDocumentKind {
  let upper = value.to_upper()
  if upper.contains("EXCELLON") ||
    upper.contains(".DRL") ||
    upper.contains(".TXT") {
    StreamExcellon
  } else if upper.contains("GERBER") ||
    upper.contains(".GBR") ||
    upper.contains(".GTL") ||
    upper.contains(".GKO") {
    StreamGerber
  } else {
    StreamUnknown
  }
}

///|
pub fn new_incremental_document(
  kind? : StreamDocumentKind = StreamUnknown,
  max_record_length? : Int = 4096,
  max_diagnostics? : Int = 200,
) -> IncrementalDocument {
  {
    kind,
    phase: StreamCreated,
    pending: "",
    records: [],
    diagnostics: [],
    stats: {
      byte_count: 0,
      record_count: 0,
      line_count: 1,
      max_record_length: 0,
      star_terminated: 0,
      newline_terminated: 0,
      empty_records: 0,
      coordinate_records: 0,
      comment_records: 0,
    },
    max_record_length: if max_record_length < 1 {
      1
    } else {
      max_record_length
    },
    max_diagnostics: if max_diagnostics < 0 {
      0
    } else {
      max_diagnostics
    },
    offset: 0,
    line: 1,
    column: 1,
  }
}

///|
pub fn IncrementalDocument::record_count(self : IncrementalDocument) -> Int {
  self.records.length()
}

///|
pub fn IncrementalDocument::diagnostic_count(self : IncrementalDocument) -> Int {
  self.diagnostics.length()
}

///|
pub fn IncrementalDocument::is_finished(self : IncrementalDocument) -> Bool {
  self.phase is StreamFinished
}

///|
pub fn IncrementalDocument::has_errors(self : IncrementalDocument) -> Bool {
  self.phase is StreamFailed ||
  self.diagnostics.any(item => item.severity is StreamError)
}

///|
pub fn IncrementalDocument::records(
  self : IncrementalDocument,
) -> Array[StreamRecord] {
  self.records.copy()
}

///|
pub fn IncrementalDocument::diagnostics(
  self : IncrementalDocument,
) -> Array[StreamDiagnostic] {
  self.diagnostics.copy()
}

///|
pub fn IncrementalDocument::stats(self : IncrementalDocument) -> StreamStats {
  self.stats
}

///|
fn stream_replace(
  document : IncrementalDocument,
  phase : StreamPhase,
  pending : String,
  records : Array[StreamRecord],
  diagnostics : Array[StreamDiagnostic],
  stats : StreamStats,
  offset : Int,
  line : Int,
  column : Int,
) -> IncrementalDocument {
  {
    kind: document.kind,
    phase,
    pending,
    records,
    diagnostics,
    stats,
    max_record_length: document.max_record_length,
    max_diagnostics: document.max_diagnostics,
    offset,
    line,
    column,
  }
}

///|
fn stream_add_diagnostic(
  document : IncrementalDocument,
  severity : StreamDiagnosticSeverity,
  code : String,
  message : String,
  record_index : Int?,
) -> IncrementalDocument {
  let diagnostics = document.diagnostics.copy()
  if diagnostics.length() < document.max_diagnostics {
    diagnostics.push({
      severity,
      code,
      message,
      record_index,
      offset: document.offset,
      line: document.line,
    })
  }
  stream_replace(
    document,
    document.phase,
    document.pending,
    document.records,
    diagnostics,
    document.stats,
    document.offset,
    document.line,
    document.column,
  )
}

///|
fn stream_record_is_coordinate(text : String) -> Bool {
  text.contains("X") ||
  text.contains("Y") ||
  text.contains("I") ||
  text.contains("J") ||
  text.contains("G01") ||
  text.contains("G02") ||
  text.contains("G03")
}

///|
fn stream_record_is_comment(text : String) -> Bool {
  text.has_prefix(";") ||
  text.has_prefix("(") ||
  text.has_prefix("G04") ||
  text.has_prefix("COMMENT")
}

///|
fn stream_update_stats(
  stats : StreamStats,
  text : String,
  terminator : Char,
) -> StreamStats {
  let stars = if terminator == '*' { 1 } else { 0 }
  let newlines = if terminator == '\n' || terminator == '\r' { 1 } else { 0 }
  let empty = if text.trim().to_owned() == "" { 1 } else { 0 }
  let coordinates = if stream_record_is_coordinate(text) { 1 } else { 0 }
  let comments = if stream_record_is_comment(text) { 1 } else { 0 }
  {
    byte_count: stats.byte_count,
    record_count: stats.record_count + 1,
    line_count: stats.line_count,
    max_record_length: if text.length() > stats.max_record_length {
      text.length()
    } else {
      stats.max_record_length
    },
    star_terminated: stats.star_terminated + stars,
    newline_terminated: stats.newline_terminated + newlines,
    empty_records: stats.empty_records + empty,
    coordinate_records: stats.coordinate_records + coordinates,
    comment_records: stats.comment_records + comments,
  }
}

///|
fn stream_emit_record(
  document : IncrementalDocument,
  text : String,
  terminator : Char,
) -> IncrementalDocument {
  let clean = text.trim().to_owned()
  let start_offset = document.offset - text.length()
  let diagnostics = document.diagnostics.copy()
  let mut phase = document.phase
  if clean.length() > document.max_record_length {
    if diagnostics.length() < document.max_diagnostics {
      diagnostics.push({
        severity: StreamError,
        code: "record-too-long",
        message: "record exceeds configured maximum length",
        record_index: Some(document.records.length()),
        offset: document.offset,
        line: document.line,
      })
    }
    phase = StreamFailed
  }
  let records = document.records.copy()
  let record = {
    index: document.records.length(),
    text: clean,
    start_offset,
    end_offset: document.offset,
    line: document.line,
    column: if document.column > text.length() {
      document.column - text.length()
    } else {
      1
    },
    terminator,
  }
  records.push(record)
  stream_replace(
    document,
    phase,
    document.pending,
    records,
    diagnostics,
    stream_update_stats(document.stats, clean, terminator),
    document.offset,
    document.line,
    document.column,
  )
}

///|
fn stream_consume_character(
  document : IncrementalDocument,
  character : Char,
) -> IncrementalDocument {
  let offset = document.offset + 1
  let line = if character == '\n' { document.line + 1 } else { document.line }
  let column = if character == '\n' { 1 } else { document.column + 1 }
  stream_replace(
    document,
    document.phase,
    document.pending,
    document.records,
    document.diagnostics,
    document.stats,
    offset,
    line,
    column,
  )
}

///|
fn stream_feed_characters(
  document : IncrementalDocument,
  chunk : String,
) -> IncrementalDocument {
  let mut current = document
  for character in chunk {
    if character == '*' || character == '\n' || character == '\r' {
      current = stream_consume_character(current, character)
      current = stream_emit_record(current, current.pending, character)
      current = stream_replace(
        current,
        current.phase,
        "",
        current.records,
        current.diagnostics,
        current.stats,
        current.offset,
        current.line,
        current.column,
      )
    } else {
      current = stream_replace(
        current,
        current.phase,
        current.pending + character.to_string(),
        current.records,
        current.diagnostics,
        current.stats,
        current.offset,
        current.line,
        current.column,
      )
      current = stream_consume_character(current, character)
    }
  }
  current
}

///|
pub fn IncrementalDocument::feed(
  self : IncrementalDocument,
  chunk : String,
) -> IncrementalDocument {
  if self.phase is StreamFinished || self.phase is StreamFailed {
    return stream_add_diagnostic(
      self,
      StreamError,
      "feed-after-finish",
      "cannot feed a finished stream",
      None,
    )
  }
  let stats = {
    byte_count: self.stats.byte_count + chunk.length(),
    record_count: self.stats.record_count,
    line_count: self.stats.line_count,
    max_record_length: self.stats.max_record_length,
    star_terminated: self.stats.star_terminated,
    newline_terminated: self.stats.newline_terminated,
    empty_records: self.stats.empty_records,
    coordinate_records: self.stats.coordinate_records,
    comment_records: self.stats.comment_records,
  }
  let receiving = stream_replace(
    self,
    StreamReceiving,
    self.pending,
    self.records,
    self.diagnostics,
    stats,
    self.offset,
    self.line,
    self.column,
  )
  stream_feed_characters(receiving, chunk)
}

///|
pub fn IncrementalDocument::finish(
  self : IncrementalDocument,
) -> IncrementalDocument {
  if self.phase is StreamFinished {
    return self
  }
  let mut current = self
  if current.pending.trim().to_owned() != "" {
    current = stream_add_diagnostic(
      current,
      StreamWarning,
      "unterminated-record",
      "input ended before a record terminator",
      Some(current.records.length()),
    )
    current = stream_emit_record(current, current.pending, '*')
    current = stream_replace(
      current,
      current.phase,
      "",
      current.records,
      current.diagnostics,
      current.stats,
      current.offset,
      current.line,
      current.column,
    )
  }
  if current.records.length() == 0 {
    current = stream_add_diagnostic(
      current,
      StreamNote,
      "empty-input",
      "stream completed without records",
      None,
    )
  }
  stream_replace(
    current,
    if current.has_errors() {
      StreamFailed
    } else {
      StreamFinished
    },
    current.pending,
    current.records,
    current.diagnostics,
    current.stats,
    current.offset,
    current.line,
    current.column,
  )
}

///|
pub fn stream_records(
  input : String,
  kind? : StreamDocumentKind = StreamUnknown,
) -> IncrementalDocument {
  new_incremental_document(kind~).feed(input).finish()
}

///|
pub fn stream_chunks(
  chunks : Array[String],
  kind? : StreamDocumentKind = StreamUnknown,
) -> IncrementalDocument {
  let mut document = new_incremental_document(kind~)
  for chunk in chunks {
    document = document.feed(chunk)
  }
  document.finish()
}

///|
pub fn IncrementalDocument::record(
  self : IncrementalDocument,
  index : Int,
) -> StreamRecord? {
  self.records.get(index)
}

///|
pub fn IncrementalDocument::records_containing(
  self : IncrementalDocument,
  token : String,
) -> Array[StreamRecord] {
  self.records.filter(record => record.text.contains(token))
}

///|
pub fn IncrementalDocument::has_record(
  self : IncrementalDocument,
  token : String,
) -> Bool {
  self.records.any(record => record.text.contains(token))
}

///|
pub fn IncrementalDocument::gerber_has_end(self : IncrementalDocument) -> Bool {
  self.records.any(record => record.text.contains("M02"))
}

///|
pub fn IncrementalDocument::excellon_has_end(
  self : IncrementalDocument,
) -> Bool {
  self.records.any(record => record.text.contains("M30"))
}

///|
pub fn IncrementalDocument::coordinate_record_count(
  self : IncrementalDocument,
) -> Int {
  self.stats.coordinate_records
}

///|
pub fn IncrementalDocument::line_count(self : IncrementalDocument) -> Int {
  self.stats.line_count
}

///|
pub fn IncrementalDocument::byte_count(self : IncrementalDocument) -> Int {
  self.stats.byte_count
}

///|
pub fn IncrementalDocument::max_record_length_seen(
  self : IncrementalDocument,
) -> Int {
  self.stats.max_record_length
}
