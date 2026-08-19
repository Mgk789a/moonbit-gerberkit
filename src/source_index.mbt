///|
/// Source provenance and cross-reference indexing for production PCB data.
/// Every indexed record keeps a stable source span, artifact identity, layer
/// association, and semantic label so diagnostics can be mapped back to the
/// original file without reparsing the complete job.
pub enum SourceArtifactKind {
  SourceGerberArtifact
  SourceExcellonArtifact
  SourceBoardArtifact
  SourceDerivedArtifact
  SourceUnknownArtifact
} derive(Debug, Eq)

///|
pub enum SourceEntryKind {
  SourceRecordEntry
  SourceShapeEntry
  SourceDiagnosticEntry
  SourceLayerEntry
  SourceDerivedEntry
} derive(Debug, Eq)

///|
pub enum SourceRelation {
  SourceContains
  SourceDerivedFrom
  SourceOverlaps
  SourceMatches
  SourceConflicts
} derive(Debug, Eq)

///|
pub struct ProvenanceSpan {
  offset_start : Int
  offset_end : Int
  line_start : Int
  line_end : Int
  column_start : Int
  column_end : Int
} derive(Debug, Eq)

///|
pub struct SourceArtifact {
  id : Int
  path : String
  kind : SourceArtifactKind
  layer : String?
  digest : String
  byte_count : Int
  record_count : Int
  shape_count : Int
} derive(Debug)

///|
pub struct SourceIndexEntry {
  id : Int
  artifact_id : Int
  ordinal : Int
  kind : SourceEntryKind
  label : String
  semantic : String
  span : ProvenanceSpan?
  layer : String?
  shape_index : Int?
  checksum : String
} derive(Debug)

///|
pub struct SourceCrossReference {
  left_entry : Int
  right_entry : Int
  relation : SourceRelation
  confidence : Double
  rationale : String
} derive(Debug)

///|
pub struct SourceIndex {
  artifacts : Array[SourceArtifact]
  entries : Array[SourceIndexEntry]
  relations : Array[SourceCrossReference]
  warnings : Array[String]
} derive(Debug)

///|
pub struct SourceSummary {
  artifact_count : Int
  entry_count : Int
  relation_count : Int
  source_bytes : Int
  covered_bytes : Int
  coverage : Double
  layer_count : Int
  warning_count : Int
  shape_entries : Int
  record_entries : Int
} derive(Debug)

///|
pub struct SourceQuery {
  text : String?
  kind : SourceEntryKind?
  layer : String?
  min_line : Int?
  max_line : Int?
} derive(Debug)

///|
pub struct SourceTimelinePoint {
  entry_id : Int
  line : Int
  offset : Int
  label : String
  layer : String?
} derive(Debug)

///|
pub fn source_artifact_kind_name(value : SourceArtifactKind) -> String {
  match value {
    SourceGerberArtifact => "gerber"
    SourceExcellonArtifact => "excellon"
    SourceBoardArtifact => "board"
    SourceDerivedArtifact => "derived"
    SourceUnknownArtifact => "unknown"
  }
}

///|
pub fn source_entry_kind_name(value : SourceEntryKind) -> String {
  match value {
    SourceRecordEntry => "record"
    SourceShapeEntry => "shape"
    SourceDiagnosticEntry => "diagnostic"
    SourceLayerEntry => "layer"
    SourceDerivedEntry => "derived"
  }
}

///|
pub fn source_relation_name(value : SourceRelation) -> String {
  match value {
    SourceContains => "contains"
    SourceDerivedFrom => "derived-from"
    SourceOverlaps => "overlaps"
    SourceMatches => "matches"
    SourceConflicts => "conflicts"
  }
}

///|
pub fn provenance_span(
  offset_start~ : Int,
  offset_end~ : Int,
  line_start~ : Int,
  line_end~ : Int,
  column_start~ : Int,
  column_end~ : Int,
) -> ProvenanceSpan {
  {
    offset_start: if offset_start < 0 {
      0
    } else {
      offset_start
    },
    offset_end: if offset_end < offset_start {
      offset_start
    } else {
      offset_end
    },
    line_start: if line_start < 1 {
      1
    } else {
      line_start
    },
    line_end: if line_end < line_start {
      line_start
    } else {
      line_end
    },
    column_start: if column_start < 1 {
      1
    } else {
      column_start
    },
    column_end: if column_end < column_start {
      column_start
    } else {
      column_end
    },
  }
}

///|
pub fn ProvenanceSpan::length(self : ProvenanceSpan) -> Int {
  self.offset_end - self.offset_start
}

///|
pub fn ProvenanceSpan::line_count(self : ProvenanceSpan) -> Int {
  self.line_end - self.line_start + 1
}

///|
pub fn ProvenanceSpan::contains_offset(
  self : ProvenanceSpan,
  offset : Int,
) -> Bool {
  offset >= self.offset_start && offset <= self.offset_end
}

///|
pub fn ProvenanceSpan::contains_line(self : ProvenanceSpan, line : Int) -> Bool {
  line >= self.line_start && line <= self.line_end
}

///|
pub fn ProvenanceSpan::overlaps(
  self : ProvenanceSpan,
  other : ProvenanceSpan,
) -> Bool {
  self.offset_start <= other.offset_end && other.offset_start <= self.offset_end
}

///|
pub fn ProvenanceSpan::merge(
  self : ProvenanceSpan,
  other : ProvenanceSpan,
) -> ProvenanceSpan {
  provenance_span(
    offset_start=if self.offset_start < other.offset_start {
      self.offset_start
    } else {
      other.offset_start
    },
    offset_end=if self.offset_end > other.offset_end {
      self.offset_end
    } else {
      other.offset_end
    },
    line_start=if self.line_start < other.line_start {
      self.line_start
    } else {
      other.line_start
    },
    line_end=if self.line_end > other.line_end {
      self.line_end
    } else {
      other.line_end
    },
    column_start=if self.line_start <= other.line_start {
      self.column_start
    } else {
      other.column_start
    },
    column_end=if self.line_end >= other.line_end {
      self.column_end
    } else {
      other.column_end
    },
  )
}

///|
pub fn ProvenanceSpan::summary(self : ProvenanceSpan) -> String {
  "offset=\{self.offset_start}..\{self.offset_end}, line=\{self.line_start}..\{self.line_end}, column=\{self.column_start}..\{self.column_end}"
}

///|
pub fn source_artifact(
  id : Int,
  path : String,
  kind : SourceArtifactKind,
  layer : String?,
  digest : String,
  byte_count : Int,
  record_count : Int,
  shape_count : Int,
) -> SourceArtifact {
  {
    id,
    path,
    kind,
    layer,
    digest,
    byte_count: if byte_count < 0 {
      0
    } else {
      byte_count
    },
    record_count: if record_count < 0 {
      0
    } else {
      record_count
    },
    shape_count: if shape_count < 0 {
      0
    } else {
      shape_count
    },
  }
}

///|
pub fn SourceArtifact::summary(self : SourceArtifact) -> String {
  let layer = match self.layer {
    Some(value) => value
    None => "-"
  }
  "\{self.path} [\{source_artifact_kind_name(self.kind)}] layer=\{layer} bytes=\{self.byte_count} records=\{self.record_count} shapes=\{self.shape_count}"
}

///|
pub fn SourceArtifact::has_layer(self : SourceArtifact, layer : String) -> Bool {
  match self.layer {
    Some(value) => value == layer
    None => false
  }
}

///|
pub fn source_index_entry(
  id : Int,
  artifact_id : Int,
  ordinal : Int,
  kind : SourceEntryKind,
  label : String,
  semantic : String,
  span : ProvenanceSpan?,
  layer : String?,
  shape_index : Int?,
  checksum : String,
) -> SourceIndexEntry {
  {
    id,
    artifact_id,
    ordinal,
    kind,
    label,
    semantic,
    span,
    layer,
    shape_index,
    checksum,
  }
}

///|
pub fn SourceIndexEntry::has_span(self : SourceIndexEntry) -> Bool {
  match self.span {
    Some(_) => true
    None => false
  }
}

///|
pub fn SourceIndexEntry::line(self : SourceIndexEntry) -> Int? {
  match self.span {
    Some(value) => Some(value.line_start)
    None => None
  }
}

///|
pub fn SourceIndexEntry::is_shape(self : SourceIndexEntry) -> Bool {
  self.kind is SourceShapeEntry
}

///|
pub fn SourceIndexEntry::matches(
  self : SourceIndexEntry,
  query : SourceQuery,
) -> Bool {
  let text_matches = match query.text {
    None => true
    Some(value) =>
      self.label.contains(value) ||
      self.semantic.contains(value) ||
      self.checksum.contains(value)
  }
  let kind_matches = match query.kind {
    Some(value) => self.kind == value
    None => true
  }
  let layer_matches = match query.layer {
    Some(value) =>
      match self.layer {
        Some(layer) => layer == value
        None => false
      }
    None => true
  }
  let min_matches = match (query.min_line, self.line()) {
    (None, _) => true
    (Some(_), None) => false
    (Some(minimum), Some(line)) => line >= minimum
  }
  let max_matches = match (query.max_line, self.line()) {
    (None, _) => true
    (Some(_), None) => false
    (Some(maximum), Some(line)) => line <= maximum
  }
  text_matches && kind_matches && layer_matches && min_matches && max_matches
}

///|
pub fn source_cross_reference(
  left_entry : Int,
  right_entry : Int,
  relation : SourceRelation,
  confidence : Double,
  rationale : String,
) -> SourceCrossReference {
  {
    left_entry,
    right_entry,
    relation,
    confidence: if confidence < 0.0 {
      0.0
    } else if confidence > 1.0 {
      1.0
    } else {
      confidence
    },
    rationale,
  }
}

///|
pub fn SourceCrossReference::summary(self : SourceCrossReference) -> String {
  "\{self.left_entry} \{source_relation_name(self.relation)} \{self.right_entry} confidence=\{self.confidence}: \{self.rationale}"
}

///|
pub fn new_source_index() -> SourceIndex {
  { artifacts: [], entries: [], relations: [], warnings: [] }
}

///|
fn source_hash(text : String) -> String {
  let mut value = 216613621
  for character in text {
    value = (value * 16777619 + character.to_int()) % 2147483629
  }
  "h\{if value < 0 { -value } else { value }}"
}

///|
fn source_shape_semantic(shape : Shape) -> String {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) =>
      "trace \{x1},\{y1} -> \{x2},\{y2} width=\{width}"
    Pad(x~, y~, diameter~) => "pad \{x},\{y} diameter=\{diameter}"
    Flash(x~, y~, aperture~) => "flash \{x},\{y} aperture=\{aperture}"
    DrillHit(x~, y~, diameter~) => "drill \{x},\{y} diameter=\{diameter}"
    Region(points~) => "region vertices=\{points.length()}"
  }
}

///|
fn source_shape_label(shape : Shape, index : Int) -> String {
  match shape {
    Segment(..) => "segment-\{index}"
    Pad(..) => "pad-\{index}"
    Flash(..) => "flash-\{index}"
    DrillHit(..) => "drill-\{index}"
    Region(..) => "region-\{index}"
  }
}

///|
fn source_shape_span(shape : Shape, index : Int) -> ProvenanceSpan? {
  match shape {
    Segment(..) | Pad(..) | Flash(..) | DrillHit(..) =>
      Some(
        provenance_span(
          offset_start=index,
          offset_end=index + 1,
          line_start=index + 1,
          line_end=index + 1,
          column_start=1,
          column_end=1,
        ),
      )
    Region(points~) =>
      Some(
        provenance_span(
          offset_start=index,
          offset_end=index + points.length(),
          line_start=index + 1,
          line_end=index + 1,
          column_start=1,
          column_end=points.length() + 1,
        ),
      )
  }
}

///|
fn source_empty_span(line : Int, offset : Int) -> ProvenanceSpan {
  provenance_span(
    offset_start=offset,
    offset_end=offset,
    line_start=line,
    line_end=line,
    column_start=1,
    column_end=1,
  )
}

///|
pub fn SourceIndex::artifact_count(self : SourceIndex) -> Int {
  self.artifacts.length()
}

///|
pub fn SourceIndex::entry_count(self : SourceIndex) -> Int {
  self.entries.length()
}

///|
pub fn SourceIndex::relation_count(self : SourceIndex) -> Int {
  self.relations.length()
}

///|
pub fn SourceIndex::warning_count(self : SourceIndex) -> Int {
  self.warnings.length()
}

///|
pub fn SourceIndex::artifacts(self : SourceIndex) -> Array[SourceArtifact] {
  self.artifacts.copy()
}

///|
pub fn SourceIndex::entries(self : SourceIndex) -> Array[SourceIndexEntry] {
  self.entries.copy()
}

///|
pub fn SourceIndex::relations(
  self : SourceIndex,
) -> Array[SourceCrossReference] {
  self.relations.copy()
}

///|
pub fn SourceIndex::artifact(self : SourceIndex, id : Int) -> SourceArtifact? {
  self.artifacts.get(id)
}

///|
pub fn SourceIndex::entry(self : SourceIndex, id : Int) -> SourceIndexEntry? {
  self.entries.get(id)
}

///|
pub fn SourceIndex::add_artifact(
  self : SourceIndex,
  path~ : String,
  kind~ : SourceArtifactKind,
  layer~ : String?,
  content~ : String,
  record_count~ : Int,
  shape_count~ : Int,
) -> SourceIndex {
  let artifact = source_artifact(
    self.artifacts.length(),
    path,
    kind,
    layer,
    source_hash(content),
    content.length(),
    record_count,
    shape_count,
  )
  let artifacts = self.artifacts.copy()
  artifacts.push(artifact)
  {
    artifacts,
    entries: self.entries,
    relations: self.relations,
    warnings: self.warnings,
  }
}

///|
pub fn SourceIndex::add_empty_artifact(
  self : SourceIndex,
  path~ : String,
  kind~ : SourceArtifactKind,
  layer~ : String?,
) -> SourceIndex {
  self.add_artifact(
    path~,
    kind~,
    layer~,
    content="",
    record_count=0,
    shape_count=0,
  )
}

///|
fn SourceIndex::source_with_warning(
  self : SourceIndex,
  warning : String,
) -> SourceIndex {
  let warnings = self.warnings.copy()
  warnings.push(warning)
  {
    artifacts: self.artifacts,
    entries: self.entries,
    relations: self.relations,
    warnings,
  }
}

///|
pub fn SourceIndex::add_entry(
  self : SourceIndex,
  artifact_id : Int,
  kind~ : SourceEntryKind,
  label~ : String,
  semantic~ : String,
  span~ : ProvenanceSpan?,
  layer~ : String?,
  shape_index~ : Int?,
) -> SourceIndex {
  if artifact_id < 0 || artifact_id >= self.artifacts.length() {
    return self.source_with_warning(
      "entry references missing artifact \{artifact_id}",
    )
  }
  let checksum = source_hash(label + "|" + semantic)
  let entry = source_index_entry(
    self.entries.length(),
    artifact_id,
    self.entries.length(),
    kind,
    label,
    semantic,
    span,
    layer,
    shape_index,
    checksum,
  )
  let entries = self.entries.copy()
  entries.push(entry)
  {
    artifacts: self.artifacts,
    entries,
    relations: self.relations,
    warnings: self.warnings,
  }
}

///|
pub fn SourceIndex::add_relation(
  self : SourceIndex,
  left_entry : Int,
  right_entry : Int,
  relation~ : SourceRelation,
  confidence~ : Double,
  rationale~ : String,
) -> SourceIndex {
  if left_entry < 0 ||
    right_entry < 0 ||
    left_entry >= self.entries.length() ||
    right_entry >= self.entries.length() {
    return self.source_with_warning("relation references missing entry")
  }
  let relation_value = source_cross_reference(
    left_entry, right_entry, relation, confidence, rationale,
  )
  let relations = self.relations.copy()
  relations.push(relation_value)
  {
    artifacts: self.artifacts,
    entries: self.entries,
    relations,
    warnings: self.warnings,
  }
}

///|
pub fn SourceIndex::index_stream_document(
  self : SourceIndex,
  input : String,
  path~ : String,
  kind~ : SourceDocumentKind,
  layer~ : String?,
) -> SourceIndex {
  let stream_kind = match kind {
    SourceGerberDocument => StreamGerber
    SourceExcellonDocument => StreamExcellon
    SourceUnknownDocument => StreamUnknown
  }
  let document = stream_records(input, kind=stream_kind)
  let mut result = self.add_artifact(
    path~,
    kind=match kind {
      SourceGerberDocument => SourceGerberArtifact
      SourceExcellonDocument => SourceExcellonArtifact
      SourceUnknownDocument => SourceUnknownArtifact
    },
    layer~,
    content=input,
    record_count=document.record_count(),
    shape_count=0,
  )
  let artifact_id = result.artifacts.length() - 1
  for record in document.records() {
    result = result.add_entry(
      artifact_id,
      kind=SourceRecordEntry,
      label="record-\{record.index}",
      semantic=record.text,
      span=Some(
        provenance_span(
          offset_start=record.start_offset,
          offset_end=record.end_offset,
          line_start=record.line,
          line_end=record.line,
          column_start=record.column,
          column_end=record.column + record.text.length(),
        ),
      ),
      layer~,
      shape_index=None,
    )
  }
  for diagnostic in document.diagnostics() {
    result = result.add_entry(
      artifact_id,
      kind=SourceDiagnosticEntry,
      label=diagnostic.code,
      semantic=diagnostic.message,
      span=Some(source_empty_span(diagnostic.line, diagnostic.offset)),
      layer~,
      shape_index=None,
    )
  }
  result
}

///|
pub enum SourceDocumentKind {
  SourceGerberDocument
  SourceExcellonDocument
  SourceUnknownDocument
} derive(Debug, Eq)

///|
pub fn source_document_kind_name(value : SourceDocumentKind) -> String {
  match value {
    SourceGerberDocument => "gerber"
    SourceExcellonDocument => "excellon"
    SourceUnknownDocument => "unknown"
  }
}

///|
pub fn source_document_kind(value : String) -> SourceDocumentKind {
  let upper = value.to_upper()
  if upper.contains("GERBER") || upper.contains(".GBR") {
    SourceGerberDocument
  } else if upper.contains("EXCELLON") || upper.contains(".DRL") {
    SourceExcellonDocument
  } else {
    SourceUnknownDocument
  }
}

///|
pub fn SourceIndex::index_board(
  self : SourceIndex,
  board : Board,
  path~ : String,
) -> SourceIndex {
  let mut result = self.add_artifact(
    path~,
    kind=SourceBoardArtifact,
    layer=None,
    content=board_to_json(board, include_shapes=true),
    record_count=0,
    shape_count=board_shape_count(board),
  )
  let artifact_id = result.artifacts.length() - 1
  for layer in board.layers {
    let layer_entry = result.entries.length()
    result = result.add_entry(
      artifact_id,
      kind=SourceDerivedEntry,
      label=layer.name,
      semantic="layer kind=\{kind_to_string(layer.kind)} shapes=\{layer.shapes.length()}",
      span=None,
      layer=Some(layer.name),
      shape_index=None,
    )
    for index in 0..<layer.shapes.length() {
      let shape = layer.shapes[index]
      result = result.add_entry(
        artifact_id,
        kind=SourceShapeEntry,
        label=source_shape_label(shape, index),
        semantic=source_shape_semantic(shape),
        span=source_shape_span(shape, index),
        layer=Some(layer.name),
        shape_index=Some(index),
      )
      let shape_entry = result.entries.length() - 1
      result = result.add_relation(
        layer_entry,
        shape_entry,
        relation=SourceContains,
        confidence=1.0,
        rationale="shape belongs to indexed board layer",
      )
    }
  }
  result
}

///|
pub fn SourceIndex::index_gerber(
  self : SourceIndex,
  document : GerberDocument,
  path~ : String,
) -> SourceIndex {
  let layer = document_layer(document)
  let content = document.summary()
  let mut result = self.add_artifact(
    path~,
    kind=SourceGerberArtifact,
    layer=Some(layer.name),
    content~,
    record_count=document.records,
    shape_count=layer.shapes.length(),
  )
  let artifact_id = result.artifacts.length() - 1
  for index in 0..<layer.shapes.length() {
    let shape = layer.shapes[index]
    result = result.add_entry(
      artifact_id,
      kind=SourceShapeEntry,
      label=source_shape_label(shape, index),
      semantic=source_shape_semantic(shape),
      span=source_shape_span(shape, index),
      layer=Some(layer.name),
      shape_index=Some(index),
    )
  }
  if document.has_errors() {
    result = result.source_with_warning(
      "\{path} contains \{document.error_count()} parse errors",
    )
  }
  result
}

///|
pub fn SourceIndex::index_excellon(
  self : SourceIndex,
  document : ExcellonDocument,
  path~ : String,
) -> SourceIndex {
  let layer = document.layer
  let mut result = self.add_artifact(
    path~,
    kind=SourceExcellonArtifact,
    layer=Some(layer.name),
    content=document.summary(),
    record_count=document.records,
    shape_count=layer.shapes.length(),
  )
  let artifact_id = result.artifacts.length() - 1
  for index in 0..<layer.shapes.length() {
    let shape = layer.shapes[index]
    result = result.add_entry(
      artifact_id,
      kind=SourceShapeEntry,
      label=source_shape_label(shape, index),
      semantic=source_shape_semantic(shape),
      span=source_shape_span(shape, index),
      layer=Some(layer.name),
      shape_index=Some(index),
    )
  }
  if document.error_count() > 0 {
    result = result.source_with_warning(
      "\{path} contains \{document.error_count()} drill parse errors",
    )
  }
  result
}

///|
pub fn SourceIndex::add_layer_catalog(
  self : SourceIndex,
  board : Board,
) -> SourceIndex {
  let mut result = self
  let mut layer_number = 0
  for layer in board.layers {
    result = result.add_empty_artifact(
      path="layer://\{layer_number}/\{layer.name}",
      kind=SourceDerivedArtifact,
      layer=Some(layer.name),
    )
    let artifact_id = result.artifacts.length() - 1
    result = result.add_entry(
      artifact_id,
      kind=SourceLayerEntry,
      label=layer.name,
      semantic="cataloged layer \{layer_number} kind=\{kind_to_string(layer.kind)}",
      span=None,
      layer=Some(layer.name),
      shape_index=None,
    )
    layer_number += 1
  }
  result
}

///|
pub fn SourceIndex::find(
  self : SourceIndex,
  query : SourceQuery,
) -> Array[SourceIndexEntry] {
  self.entries.filter(entry => entry.matches(query))
}

///|
pub fn SourceIndex::find_text(
  self : SourceIndex,
  text : String,
) -> Array[SourceIndexEntry] {
  self.find({
    text: Some(text),
    kind: None,
    layer: None,
    min_line: None,
    max_line: None,
  })
}

///|
pub fn SourceIndex::find_layer(
  self : SourceIndex,
  layer : String,
) -> Array[SourceIndexEntry] {
  self.find({
    text: None,
    kind: None,
    layer: Some(layer),
    min_line: None,
    max_line: None,
  })
}

///|
pub fn SourceIndex::find_kind(
  self : SourceIndex,
  kind : SourceEntryKind,
) -> Array[SourceIndexEntry] {
  self.find({
    text: None,
    kind: Some(kind),
    layer: None,
    min_line: None,
    max_line: None,
  })
}

///|
pub fn SourceIndex::find_line_range(
  self : SourceIndex,
  minimum : Int,
  maximum : Int,
) -> Array[SourceIndexEntry] {
  self.find({
    text: None,
    kind: None,
    layer: None,
    min_line: Some(minimum),
    max_line: Some(maximum),
  })
}

///|
pub fn SourceIndex::entry_at_offset(
  self : SourceIndex,
  offset : Int,
) -> SourceIndexEntry? {
  for entry in self.entries {
    match entry.span {
      Some(span) if span.contains_offset(offset) => return Some(entry)
      _ => ()
    }
  }
  None
}

///|
pub fn SourceIndex::entries_overlapping(
  self : SourceIndex,
  span : ProvenanceSpan,
) -> Array[SourceIndexEntry] {
  self.entries.filter(entry => {
    match entry.span {
      Some(value) => value.overlaps(span)
      None => false
    }
  })
}

///|
pub fn SourceIndex::timeline(
  self : SourceIndex,
  layer : String?,
) -> Array[SourceTimelinePoint] {
  let points : Array[SourceTimelinePoint] = []
  for entry in self.entries {
    let layer_matches = match (layer, entry.layer) {
      (None, _) => true
      (Some(expected), Some(actual)) => expected == actual
      _ => false
    }
    if layer_matches {
      match entry.span {
        Some(span) =>
          points.push({
            entry_id: entry.id,
            line: span.line_start,
            offset: span.offset_start,
            label: entry.label,
            layer: entry.layer,
          })
        None => ()
      }
    }
  }
  points.sort_by((left, right) => {
    if left.offset == right.offset {
      left.entry_id - right.entry_id
    } else {
      left.offset - right.offset
    }
  })
  points
}

///|
fn SourceIndex::source_unique_layers(self : SourceIndex) -> Array[String] {
  let layers : Array[String] = []
  for entry in self.entries {
    match entry.layer {
      Some(value) if !layers.contains(value) => layers.push(value)
      _ => ()
    }
  }
  layers
}

///|
fn SourceIndex::source_covered_bytes(self : SourceIndex) -> Int {
  let mut covered = 0
  for entry in self.entries {
    match entry.span {
      Some(span) => covered += span.length()
      None => ()
    }
  }
  if covered >
    self.artifacts.fold(init=0, (sum, artifact) => sum + artifact.byte_count) {
    self.artifacts.fold(init=0, (sum, artifact) => sum + artifact.byte_count)
  } else {
    covered
  }
}

///|
pub fn SourceIndex::summary(self : SourceIndex) -> SourceSummary {
  let mut shape_entries = 0
  let mut record_entries = 0
  for entry in self.entries {
    if entry.kind is SourceShapeEntry {
      shape_entries += 1
    }
    if entry.kind is SourceRecordEntry {
      record_entries += 1
    }
  }
  let source_bytes = self.artifacts.fold(init=0, (sum, artifact) => {
    sum + artifact.byte_count
  })
  let covered_bytes = self.source_covered_bytes()
  {
    artifact_count: self.artifacts.length(),
    entry_count: self.entries.length(),
    relation_count: self.relations.length(),
    source_bytes,
    covered_bytes,
    coverage: if source_bytes == 0 {
      1.0
    } else {
      covered_bytes.to_double() / source_bytes.to_double()
    },
    layer_count: self.source_unique_layers().length(),
    warning_count: self.warnings.length(),
    shape_entries,
    record_entries,
  }
}

///|
pub fn SourceSummary::summary(self : SourceSummary) -> String {
  "artifacts=\{self.artifact_count}, entries=\{self.entry_count}, relations=\{self.relation_count}, bytes=\{self.covered_bytes}/\{self.source_bytes}, coverage=\{self.coverage}, layers=\{self.layer_count}, warnings=\{self.warning_count}"
}

///|
fn source_optional_string(value : String?) -> String {
  match value {
    Some(text) => json_string(text)
    None => "null"
  }
}

///|
fn source_optional_int(value : Int?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}

///|
fn provenance_span_json(value : ProvenanceSpan?) -> String {
  match value {
    Some(span) =>
      "{\"offset_start\":\{span.offset_start},\"offset_end\":\{span.offset_end},\"line_start\":\{span.line_start},\"line_end\":\{span.line_end},\"column_start\":\{span.column_start},\"column_end\":\{span.column_end}}"
    None => "null"
  }
}

///|
pub fn SourceArtifact::to_json(self : SourceArtifact) -> String {
  "{\"id\":\{self.id},\"path\":\{json_string(self.path)},\"kind\":\{json_string(source_artifact_kind_name(self.kind))},\"layer\":\{source_optional_string(self.layer)},\"digest\":\{json_string(self.digest)},\"bytes\":\{self.byte_count},\"records\":\{self.record_count},\"shapes\":\{self.shape_count}}"
}

///|
pub fn SourceIndexEntry::to_json(self : SourceIndexEntry) -> String {
  "{\"id\":\{self.id},\"artifact_id\":\{self.artifact_id},\"ordinal\":\{self.ordinal},\"kind\":\{json_string(source_entry_kind_name(self.kind))},\"label\":\{json_string(self.label)},\"semantic\":\{json_string(self.semantic)},\"span\":\{provenance_span_json(self.span)},\"layer\":\{source_optional_string(self.layer)},\"shape_index\":\{source_optional_int(self.shape_index)},\"checksum\":\{json_string(self.checksum)}}"
}

///|
pub fn SourceCrossReference::to_json(self : SourceCrossReference) -> String {
  "{\"left\":\{self.left_entry},\"right\":\{self.right_entry},\"relation\":\{json_string(source_relation_name(self.relation))},\"confidence\":\{self.confidence},\"rationale\":\{json_string(self.rationale)}}"
}

///|
pub fn SourceIndex::to_json(self : SourceIndex) -> String {
  let artifacts = self.artifacts.map(SourceArtifact::to_json).join(",")
  let entries = self.entries.map(SourceIndexEntry::to_json).join(",")
  let relations = self.relations.map(SourceCrossReference::to_json).join(",")
  let warnings = self.warnings.map(json_string).join(",")
  "{\"summary\":\{json_string(self.summary().summary())},\"artifacts\":[\{artifacts}],\"entries\":[\{entries}],\"relations\":[\{relations}],\"warnings\":[\{warnings}]}"
}

///|
fn source_csv_cell(value : String) -> String {
  if value.contains(",") || value.contains("\"") || value.contains("\n") {
    "\"" + value.replace(old="\"", new="\"\"") + "\""
  } else {
    value
  }
}

///|
pub fn SourceIndex::to_csv(self : SourceIndex) -> String {
  let mut output = "entry_id,artifact_id,kind,label,semantic,layer,line,offset,checksum\n"
  for entry in self.entries {
    let line = match entry.line() {
      Some(value) => value.to_string()
      None => ""
    }
    let offset = match entry.span {
      Some(value) => value.offset_start.to_string()
      None => ""
    }
    let layer = match entry.layer {
      Some(value) => value
      None => ""
    }
    output += "\{entry.id},\{entry.artifact_id},\{source_csv_cell(source_entry_kind_name(entry.kind))},\{source_csv_cell(entry.label)},\{source_csv_cell(entry.semantic)},\{source_csv_cell(layer)},\{line},\{offset},\{entry.checksum}\n"
  }
  output
}

///|
pub fn SourceIndex::to_text(self : SourceIndex) -> String {
  let mut output = "Source index\n\{self.summary().summary()}\n"
  for artifact in self.artifacts {
    output += "  \{artifact.summary()}\n"
  }
  for entry in self.entries {
    let span = match entry.span {
      Some(value) => value.summary()
      None => "no-span"
    }
    output += "  #\{entry.id} \{source_entry_kind_name(entry.kind)} \{entry.label} \{span}\n"
  }
  if self.warnings.length() > 0 {
    output += "Warnings:\n"
    for warning in self.warnings {
      output += "  - \{warning}\n"
    }
  }
  output
}

///|
pub fn source_index_from_board(
  board : Board,
  path? : String = "board.json",
) -> SourceIndex {
  new_source_index().index_board(board, path~)
}

///|
pub fn source_index_from_gerber(
  input : String,
  path? : String = "board.gbr",
) -> SourceIndex {
  new_source_index().index_stream_document(
    input,
    path~,
    kind=SourceGerberDocument,
    layer=None,
  )
}

///|
pub fn source_index_from_excellon(
  input : String,
  path? : String = "board.drl",
) -> SourceIndex {
  new_source_index().index_stream_document(
    input,
    path~,
    kind=SourceExcellonDocument,
    layer=None,
  )
}

///|
pub fn source_index_join(
  left : SourceIndex,
  right : SourceIndex,
) -> SourceIndex {
  let mut result = left
  let artifact_offset = result.artifacts.length()
  for artifact in right.artifacts {
    let artifacts = result.artifacts.copy()
    artifacts.push({
      id: artifact.id + artifact_offset,
      path: artifact.path,
      kind: artifact.kind,
      layer: artifact.layer,
      digest: artifact.digest,
      byte_count: artifact.byte_count,
      record_count: artifact.record_count,
      shape_count: artifact.shape_count,
    })
    result = {
      artifacts,
      entries: result.entries,
      relations: result.relations,
      warnings: result.warnings,
    }
  }
  let entry_offset = result.entries.length()
  for entry in right.entries {
    result = result.add_entry(
      entry.artifact_id + artifact_offset,
      kind=entry.kind,
      label=entry.label,
      semantic=entry.semantic,
      span=entry.span,
      layer=entry.layer,
      shape_index=entry.shape_index,
    )
  }
  for relation in right.relations {
    result = result.add_relation(
      relation.left_entry + entry_offset,
      relation.right_entry + entry_offset,
      relation=relation.relation,
      confidence=relation.confidence,
      rationale=relation.rationale,
    )
  }
  for warning in right.warnings {
    result = result.source_with_warning(warning)
  }
  result
}

///|
pub fn source_index_rebuild_relations(
  index : SourceIndex,
  confidence? : Double = 0.8,
) -> SourceIndex {
  let mut result = index
  for left in index.entries {
    for right in index.entries {
      if left.id >= right.id {
        continue
      }
      let same_layer = match (left.layer, right.layer) {
        (Some(a), Some(b)) => a == b
        _ => false
      }
      let same_checksum = left.checksum == right.checksum
      if same_checksum {
        result = result.add_relation(
          left.id,
          right.id,
          relation=SourceMatches,
          confidence~,
          rationale="identical semantic checksum",
        )
      } else if left.artifact_id != right.artifact_id && same_layer {
        result = result.add_relation(
          left.id,
          right.id,
          relation=SourceDerivedFrom,
          confidence=0.35,
          rationale="entries share a layer across source artifacts",
        )
      } else if left.kind is SourceDiagnosticEntry ||
        right.kind is SourceDiagnosticEntry {
        result = result.add_relation(
          left.id,
          right.id,
          relation=SourceConflicts,
          confidence=0.25,
          rationale="diagnostic entry requires review against neighboring source",
        )
      } else if same_layer &&
        left.kind is SourceShapeEntry &&
        right.kind is SourceShapeEntry {
        result = result.add_relation(
          left.id,
          right.id,
          relation=SourceOverlaps,
          confidence=0.2,
          rationale="same layer requires geometric follow-up",
        )
      }
    }
  }
  result
}

///|
pub fn source_index_health(index : SourceIndex) -> Bool {
  let summary = index.summary()
  summary.artifact_count > 0 &&
  summary.entry_count > 0 &&
  summary.warning_count == 0 &&
  summary.coverage >= 0.0 &&
  summary.coverage <= 1.0
}
