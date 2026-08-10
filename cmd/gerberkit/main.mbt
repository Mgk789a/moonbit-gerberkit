///|
fn main {
  println("moonbit-gerberkit 0.1.0")
  println(
    "Library API: parse_gerber, parse_excellon, report, to_json, to_svg, to_ascii",
  )
  let sample = "%MOMM*%ADD10C,0.3*%X1Y1D02*X8Y1D01*X8Y5D01*X4Y3D03*"
  let layer = @lib.parse_gerber(sample, name="demo-F_Cu")
  let board = @lib.board_from_layers([layer])
  let r = @lib.report(board)
  println(@lib.to_json(r))
  println(@lib.to_ascii(board))
}
