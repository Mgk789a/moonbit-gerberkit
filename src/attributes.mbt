///|
pub enum GerberAttributeScope {
  FileAttribute
  ApertureAttribute
  ObjectAttribute
  DeleteAttribute
} derive(Debug, Eq)

///|
pub struct GerberAttribute {
  scope : GerberAttributeScope
  name : String
  values : Array[String]
  record : String
} derive(Debug)

///|
pub struct GerberAttributes {
  items : Array[GerberAttribute]
  fields : Map[String, Array[String]]
} derive(Debug)

///|
pub fn new_gerber_attributes() -> GerberAttributes {
  { items: [], fields: Map([]) }
}

///|
pub fn attribute_scope_name(scope : GerberAttributeScope) -> String {
  match scope {
    FileAttribute => "file"
    ApertureAttribute => "aperture"
    ObjectAttribute => "object"
    DeleteAttribute => "delete"
  }
}

///|
pub fn attribute_scope_prefix(scope : GerberAttributeScope) -> String {
  match scope {
    FileAttribute => "TF"
    ApertureAttribute => "TA"
    ObjectAttribute => "TO"
    DeleteAttribute => "TD"
  }
}

///|
pub fn GerberAttribute::scope_name(self : GerberAttribute) -> String {
  attribute_scope_name(self.scope)
}

///|
pub fn GerberAttribute::value(self : GerberAttribute, index : Int) -> String? {
  self.values.get(index)
}

///|
pub fn GerberAttribute::to_record(self : GerberAttribute) -> String {
  attribute_scope_prefix(self.scope) + self.name + "," + self.values.join(",")
}

///|
fn attribute_parse_scope(record : String) -> GerberAttributeScope? {
  if record.has_prefix("TF") {
    Some(FileAttribute)
  } else if record.has_prefix("TA") {
    Some(ApertureAttribute)
  } else if record.has_prefix("TO") {
    Some(ObjectAttribute)
  } else if record.has_prefix("TD") {
    Some(DeleteAttribute)
  } else {
    None
  }
}

///|
fn attribute_parse_name(
  record : String,
  scope : GerberAttributeScope,
) -> (String, String) {
  let prefix = attribute_scope_prefix(scope)
  let raw_rest = record[prefix.length():].to_owned()
  let rest = if raw_rest.has_prefix(".") {
    raw_rest[1:].to_owned()
  } else {
    raw_rest
  }
  match rest.find(",") {
    Some(index) => (rest[:index].to_owned(), rest[index + 1:].to_owned())
    None => (rest, "")
  }
}

///|
pub fn parse_attribute_record(record : String) -> GerberAttribute? {
  let clean = normalize_record(record)
  match attribute_parse_scope(clean) {
    Some(scope) => {
      let (name, value_text) = attribute_parse_name(clean, scope)
      let values = if value_text == "" {
        []
      } else {
        value_text.split(",").to_array().map(item => item.to_owned())
      }
      Some({ scope, name, values, record: clean })
    }
    None => None
  }
}

///|
pub fn GerberAttributes::add(
  self : GerberAttributes,
  attribute : GerberAttribute,
) -> Unit {
  self.items.push(attribute)
  self.fields.update(attribute.name, values => {
    match values {
      Some(old) => {
        old.append(attribute.values[:])
        Some(old)
      }
      None => Some(attribute.values.copy())
    }
  })
}

///|
pub fn GerberAttributes::parse(text : String) -> GerberAttributes {
  let result = new_gerber_attributes()
  for record in tokenize_records(text) {
    match parse_attribute_record(record) {
      Some(attribute) => result.add(attribute)
      None => ()
    }
  }
  result
}

///|
pub fn GerberAttributes::count(self : GerberAttributes) -> Int {
  self.items.length()
}

///|
pub fn GerberAttributes::all(self : GerberAttributes) -> Array[GerberAttribute] {
  self.items.copy()
}

///|
pub fn GerberAttributes::get(
  self : GerberAttributes,
  name : String,
) -> Array[String] {
  self.fields.get(name).unwrap_or([])
}

///|
pub fn GerberAttributes::first(
  self : GerberAttributes,
  name : String,
) -> String? {
  self.get(name).get(0)
}

///|
pub fn GerberAttributes::file_function(self : GerberAttributes) -> String? {
  self.first("FileFunction")
}

///|
pub fn GerberAttributes::part(self : GerberAttributes) -> String? {
  self.first("Part")
}

///|
pub fn GerberAttributes::generation_software(
  self : GerberAttributes,
) -> String? {
  self.first("GenerationSoftware")
}

///|
pub fn GerberAttributes::has(self : GerberAttributes, name : String) -> Bool {
  self.fields.contains(name)
}

///|
pub fn GerberAttributes::to_json(self : GerberAttributes) -> String {
  let attributes = self.items
    .map(attribute => {
      "{\"scope\":\{json_string(attribute.scope_name())},\"name\":\{json_string(attribute.name)},\"values\":[\{attribute.values.map(json_string).join(",")}]}"
    })
    .join(",")
  "{\"attributes\":[\{attributes}]}"
}

///|
pub enum LayerRole {
  TopCopperRole
  BottomCopperRole
  InnerCopperRole
  SolderMaskRole
  SilkscreenRole
  DrillRole
  OutlineRole
  DocumentationRole
  UnknownRole
} derive(Debug, Eq)

///|
pub fn layer_role_from_attributes(attributes : GerberAttributes) -> LayerRole {
  let function = attributes.get("FileFunction").join(",").to_upper()
  if function.contains("COPPER") && function.contains("TOP") {
    TopCopperRole
  } else if function.contains("COPPER") &&
    (function.contains("BOTTOM") || function.contains("BOT")) {
    BottomCopperRole
  } else if function.contains("COPPER") {
    InnerCopperRole
  } else if function.contains("MASK") {
    SolderMaskRole
  } else if function.contains("SILK") {
    SilkscreenRole
  } else if function.contains("DRILL") {
    DrillRole
  } else if function.contains("PROFILE") || function.contains("OUTLINE") {
    OutlineRole
  } else if function.contains("DOC") {
    DocumentationRole
  } else {
    UnknownRole
  }
}

///|
pub fn layer_role_name(role : LayerRole) -> String {
  match role {
    TopCopperRole => "top-copper"
    BottomCopperRole => "bottom-copper"
    InnerCopperRole => "inner-copper"
    SolderMaskRole => "solder-mask"
    SilkscreenRole => "silkscreen"
    DrillRole => "drill"
    OutlineRole => "outline"
    DocumentationRole => "documentation"
    UnknownRole => "unknown"
  }
}

///|
pub fn layer_kind_from_role(role : LayerRole) -> LayerKind {
  match role {
    TopCopperRole | BottomCopperRole | InnerCopperRole => Copper
    SolderMaskRole => SolderMask
    SilkscreenRole => Silkscreen
    DrillRole => Drill
    OutlineRole => Mechanical
    DocumentationRole | UnknownRole => Unknown
  }
}

///|
pub struct LayerMetadata {
  name : String
  role : LayerRole
  kind : LayerKind
  attributes : GerberAttributes
} derive(Debug)

///|
pub fn layer_metadata(name : String, text : String) -> LayerMetadata {
  let attributes = GerberAttributes::parse(text)
  let role = layer_role_from_attributes(attributes)
  { name, role, kind: layer_kind_from_role(role), attributes }
}

///|
pub fn LayerMetadata::to_json(self : LayerMetadata) -> String {
  "{\"name\":\{json_string(self.name)},\"role\":\{json_string(layer_role_name(self.role))},\"kind\":\{json_string(kind_to_string(self.kind))},\"attributes\":\{self.attributes.to_json()}}"
}
