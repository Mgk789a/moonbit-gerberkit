///|
pub fn json_escape(value : String) -> String {
  let mut result = ""
  for character in value {
    if character == '"' {
      result += "\\\""
    } else if character == '\\' {
      result += "\\\\"
    } else if character == '\n' {
      result += "\\n"
    } else if character == '\r' {
      result += "\\r"
    } else if character == '\t' {
      result += "\\t"
    } else {
      result += character.to_string()
    }
  }
  result
}

///|
pub fn json_string(value : String) -> String {
  "\"" + json_escape(value) + "\""
}

///|
fn optional_json_number(value : Double?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}

///|
fn optional_json_point(value : Point2?) -> String {
  match value {
    Some(point) =>
      "{\"x\":" + point.x.to_string() + ",\"y\":" + point.y.to_string() + "}"
    None => "null"
  }
}

///|
pub fn shape_to_json(shape : Shape) -> String {
  match shape {
    Segment(x1~, y1~, x2~, y2~, width~) =>
      "{\"type\":\"segment\",\"x1\":\{x1},\"y1\":\{y1},\"x2\":\{x2},\"y2\":\{y2},\"width\":\{width}}"
    Pad(x~, y~, diameter~) =>
      "{\"type\":\"pad\",\"x\":\{x},\"y\":\{y},\"diameter\":\{diameter}}"
    Flash(x~, y~, aperture~) =>
      "{\"type\":\"flash\",\"x\":\{x},\"y\":\{y},\"aperture\":\{aperture}}"
    DrillHit(x~, y~, diameter~) =>
      "{\"type\":\"drill-hit\",\"x\":\{x},\"y\":\{y},\"diameter\":\{diameter}}"
    Region(points~) => {
      let coordinates = points.map(pair => "[\{pair.0},\{pair.1}]").join(",")
      "{\"type\":\"region\",\"points\":[\{coordinates}]}"
    }
  }
}

///|
pub fn layer_to_json(layer : Layer, include_shapes? : Bool = true) -> String {
  let shapes = if include_shapes {
    layer.shapes.map(shape_to_json).join(",")
  } else {
    ""
  }
  let shape_field = if include_shapes {
    ",\"shapes\":[" + shapes + "]"
  } else {
    ""
  }
  "{\"name\":\{json_string(layer.name)},\"kind\":\{json_string(kind_to_string(layer.kind))},\"unit\":\{json_string(unit_to_string(layer.unit))},\"shape_count\":\{layer.shapes.length()}\{shape_field}}"
}

///|
pub fn board_to_json(board : Board, include_shapes? : Bool = true) -> String {
  "{\"layers\":[" +
  board.layers.map(layer => layer_to_json(layer, include_shapes~)).join(",") +
  "]}"
}

///|
pub fn report_to_json(
  report : Report,
  include_shapes? : Bool = false,
) -> String {
  let issues = report.issues
    .map(issue => {
      "{\"rule\":\{json_string(issue.rule)},\"severity\":\{json_string(issue.severity)},\"message\":\{json_string(issue.message)},\"layer\":\{json_string(issue.layer)}}"
    })
    .join(",")
  let bounds = match report.bbox {
    Some(value) =>
      "{\"min_x\":\{value.min_x},\"min_y\":\{value.min_y},\"max_x\":\{value.max_x},\"max_y\":\{value.max_y}}"
    None => "null"
  }
  "{\"board\":\{board_to_json(report.board, include_shapes~)},\"bbox\":\{bounds},\"issues\":[\{issues}]}"
}

///|
pub fn dfm_finding_to_json(finding : DfmFinding) -> String {
  let shape_index = match finding.shape_index {
    Some(index) => index.to_string()
    None => "null"
  }
  "{\"rule\":\{json_string(finding.rule_name())},\"severity\":\{json_string(finding.severity_name())},\"message\":\{json_string(finding.message)},\"layer\":\{json_string(finding.layer)},\"shape_index\":\{shape_index},\"location\":\{optional_json_point(finding.location)},\"measured\":\{optional_json_number(finding.measured)},\"limit\":\{optional_json_number(finding.limit)}}"
}

///|
pub fn dfm_report_to_json(report : DfmReport) -> String {
  "{\"summary\":\{json_string(report.summary())},\"config\":{\"min_width\":\{report.config.min_width},\"min_drill\":\{report.config.min_drill},\"min_clearance\":\{report.config.min_clearance},\"min_annular_ring\":\{report.config.min_annular_ring}},\"findings\":[\{report.findings.map(dfm_finding_to_json).join(",")}]}"
}

///|
pub fn document_to_json(
  document : GerberDocument,
  include_shapes? : Bool = false,
) -> String {
  let diagnostics = document.diagnostics
    .map(item => {
      "{\"severity\":\{json_string(item.severity_name())},\"code\":\{json_string(item.code)},\"message\":\{json_string(item.message)},\"line\":\{item.line},\"column\":\{item.column}}"
    })
    .join(",")
  "{\"summary\":\{json_string(document.summary())},\"layer\":\{layer_to_json(document.layer, include_shapes~)},\"diagnostics\":[\{diagnostics}],\"aperture_count\":\{document.apertures.count()}}"
}

///|
pub fn excellon_to_json(
  document : ExcellonDocument,
  include_shapes? : Bool = false,
) -> String {
  let tools = document.tools
    .map(tool => "{\"code\":\{tool.code},\"diameter\":\{tool.diameter}}")
    .join(",")
  let diagnostics = document.diagnostics
    .map(item => {
      "{\"severity\":\{json_string(item.severity_name())},\"code\":\{json_string(item.code)},\"message\":\{json_string(item.message)},\"line\":\{item.line}}"
    })
    .join(",")
  "{\"summary\":\{json_string(document.summary())},\"layer\":\{layer_to_json(document.layer, include_shapes~)},\"tools\":[\{tools}],\"diagnostics\":[\{diagnostics}]}"
}

///|
pub fn dfm_to_sarif(
  report : DfmReport,
  tool_name? : String = "moonbit-gerberkit",
) -> String {
  let rules : Array[String] = []
  for finding in report.findings {
    let rule = finding.rule_name()
    if !rules.contains(rule) {
      rules.push(rule)
    }
  }
  let rule_json = rules
    .map(rule => "{\"id\":\{json_string(rule)},\"name\":\{json_string(rule)}}")
    .join(",")
  let result_json = report.findings
    .map(finding => {
      let level = if finding.severity is DfmError {
        "error"
      } else if finding.severity is DfmWarning {
        "warning"
      } else {
        "note"
      }
      let location = match finding.location {
        Some(point) =>
          ",\"locations\":[{\"physicalLocation\":{\"artifactLocation\":{\"uri\":\"board\"},\"region\":{\"startLine\":1,\"startColumn\":1,\"snippet\":{\"text\":\{json_string("\{point.x},\{point.y}")}}}}}]"
        None => ""
      }
      "{\"ruleId\":\{json_string(finding.rule_name())},\"level\":\{json_string(level)},\"message\":{\"text\":\{json_string(finding.message)}}\{location}}"
    })
    .join(",")
  "{\"version\":\"2.1.0\",\"$schema\":\"https://json.schemastore.org/sarif-2.1.0.json\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\{json_string(tool_name)},\"rules\":[\{rule_json}]}},\"results\":[\{result_json}]}]}"
}

///|
pub fn dfm_to_csv(report : DfmReport) -> String {
  let mut result = "severity,rule,layer,message,shape_index,measured,limit\n"
  for finding in report.findings {
    let shape_index = finding.shape_index
      .map(value => value.to_string())
      .unwrap_or("")
    let measured = finding.measured
      .map(value => value.to_string())
      .unwrap_or("")
    let limit = finding.limit.map(value => value.to_string()).unwrap_or("")
    result += json_escape(finding.severity_name()) +
      "," +
      json_escape(finding.rule_name()) +
      "," +
      json_escape(finding.layer) +
      "," +
      json_escape(finding.message) +
      "," +
      shape_index +
      "," +
      measured +
      "," +
      limit +
      "\n"
  }
  result
}

///|
pub fn dfm_to_text(report : DfmReport) -> String {
  let mut result = report.summary() + "\n"
  if report.findings.length() == 0 {
    result += "No findings.\n"
  } else {
    for index, finding in report.findings {
      result += "\{index + 1}. \{finding.format()}\n"
    }
  }
  result
}

///|
pub fn dfm_to_github_annotations(report : DfmReport) -> String {
  let mut result = ""
  for finding in report.findings {
    let command = if finding.severity is DfmError {
      "::error"
    } else if finding.severity is DfmWarning {
      "::warning"
    } else {
      "::notice"
    }
    result += command +
      "::" +
      finding.message +
      " [\{" + finding.rule_name() + "}]\n"
  }
  result
}

///|
pub fn board_to_html(board : Board, report? : DfmReport) -> String {
  let title = "<title>moonbit-gerberkit board report</title>"
  let header = "<h1>Board report</h1><p>layers=\{board.layers.length()}</p>"
  let issues = match report {
    Some(value) => "<pre>" + json_escape(dfm_to_text(value)) + "</pre>"
    None => ""
  }
  "<!doctype html><html><head>\{title}</head><body>\{header}\{issues}<pre>\{json_escape(board_to_json(board, include_shapes=true))}</pre></body></html>"
}
