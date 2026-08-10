///|
fn fmt(v : Double) -> String {
  v.to_string()
}

///|
pub fn to_ascii(board : Board, columns? : Int = 48, rows? : Int = 20) -> String {
  match board_bounds(board) {
    None => "(empty board)"
    Some(b) => {
      let mut out = ""
      for row in 0..<rows {
        for col in 0..<columns {
          let x = b.min_x +
            (b.max_x - b.min_x) * col.to_double() / columns.to_double()
          let y = b.min_y +
            (b.max_y - b.min_y) * row.to_double() / rows.to_double()
          let mut hit = false
          for layer in board.layers {
            for shape in layer.shapes {
              match shape {
                Pad(x=px, y=_, diameter=d) if abs(px - x) < d => hit = true
                DrillHit(x=px, y=py, diameter=d) if abs(px - x) < d &&
                  abs(py - y) < d => hit = true
                _ => ()
              }
            }
          }
          out = out + (if hit { "#" } else { "." })
        }
        out = out + "\n"
      }
      out
    }
  }
}

///|
pub fn to_svg(board : Board) -> String {
  match board_bounds(board) {
    None => "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
    Some(b) => {
      let w = b.max_x - b.min_x
      let h = b.max_y - b.min_y
      let mut out = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 " +
        fmt(w) +
        " " +
        fmt(h) +
        "\">"
      for layer in board.layers {
        for shape in layer.shapes {
          match shape {
            Segment(x1~, y1~, x2~, y2~, width~) =>
              out = out +
                "<line x1=\"" +
                fmt(x1 - b.min_x) +
                "\" y1=\"" +
                fmt(h - y1 + b.min_y) +
                "\" x2=\"" +
                fmt(x2 - b.min_x) +
                "\" y2=\"" +
                fmt(h - y2 + b.min_y) +
                "\" stroke=\"#d97706\" stroke-width=\"" +
                fmt(width) +
                "\"/>"
            Pad(x~, y~, diameter=d) =>
              out = out +
                "<circle cx=\"" +
                fmt(x - b.min_x) +
                "\" cy=\"" +
                fmt(h - y + b.min_y) +
                "\" r=\"" +
                fmt(d / 2.0) +
                "\" fill=\"#b45309\"/>"
            DrillHit(x~, y~, diameter=d) =>
              out = out +
                "<circle cx=\"" +
                fmt(x - b.min_x) +
                "\" cy=\"" +
                fmt(h - y + b.min_y) +
                "\" r=\"" +
                fmt(d / 2.0) +
                "\" fill=\"#fff\" stroke=\"#111\"/>"
            _ => ()
          }
        }
      }
      out + "</svg>"
    }
  }
}

///|
pub fn to_json(report : Report) -> String {
  let mut out = "{\"layers\":["
  for i, layer in report.board.layers {
    if i > 0 {
      out = out + ","
    }
    out = out +
      "{\"name\":\"" +
      layer.name +
      "\",\"kind\":\"" +
      kind_to_string(layer.kind) +
      "\",\"shapes\":" +
      layer.shapes.length().to_string() +
      "}"
  }
  out = out + "],\"issues\":["
  for i, issue in report.issues {
    if i > 0 {
      out = out + ","
    }
    out = out +
      "{\"rule\":\"" +
      issue.rule +
      "\",\"severity\":\"" +
      issue.severity +
      "\",\"layer\":\"" +
      issue.layer +
      "\"}"
  }
  out + "]}"
}
