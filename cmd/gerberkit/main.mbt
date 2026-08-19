///|
fn usage() -> Unit {
  println("moonbit-gerberkit 0.2.0")
  println("Usage: moon run --target native cmd/gerberkit [file] [options]")
  println("  --format json|svg|ascii|text|csv|sarif|html|fabrication")
  println("  --check              print the legacy issue count")
  println("  --connectivity       print geometric connectivity JSON")
  println("  --bench --fixture tiny|small|medium|large")
  println("Input files are detected as Gerber or Excellon by their headers.")
}

///|
fn demo_input() -> String {
  "%FSLAX24Y24*%MOMM*%ADD10C,0.3*%D10*X010000Y010000D02*X080000Y010000D01*X080000Y050000D01*X040000Y030000D03*"
}

///|
fn read_input(path : String) -> String raise {
  @fs.read_file_to_string(path)
}

///|
fn main raise {
  let args = @env.args()
  let mut path : String? = None
  let mut format = "json"
  let mut run_check = false
  let mut show_help = false
  let mut run_benchmark = false
  let mut show_connectivity = false
  let mut fixture_name = "small"
  for index in 1..<args.length() {
    let arg = args[index]
    if arg == "--help" || arg == "-h" {
      show_help = true
    } else if arg == "--check" {
      run_check = true
    } else if arg == "--bench" {
      run_benchmark = true
    } else if arg == "--connectivity" {
      show_connectivity = true
    } else if arg.has_prefix("--fixture=") {
      fixture_name = arg[10:].to_owned()
    } else if arg.has_prefix("--format=") {
      format = arg[9:].to_owned()
    } else if arg == "--format" && index + 1 < args.length() {
      format = args[index + 1]
    } else if !arg.has_prefix("-") && path is None {
      path = Some(arg)
    }
  }
  if show_help {
    usage()
  } else if run_benchmark {
    let fixture = if fixture_name == "tiny" {
      @lib.tiny_fixture()
    } else if fixture_name == "medium" {
      @lib.medium_fixture()
    } else if fixture_name == "large" {
      @lib.large_fixture()
    } else {
      @lib.small_fixture()
    }
    println(@lib.run_benchmark_suite(fixture, iterations=3).to_markdown())
  } else {
    let text = match path {
      Some(file) => read_input(file)
      None => demo_input()
    }
    let name = path.unwrap_or("demo")
    let layer = @lib.parse_auto(text, name~)
    let board = @lib.board_from_layers([layer])
    let summary = @lib.report(board)
    let dfm = @lib.run_dfm(board)
    if run_check {
      let errors = @lib.issue_count(summary, severity="error")
      println("issues=\{errors}")
    } else if show_connectivity {
      println(@lib.connectivity_from_board(board).to_json())
    } else if format == "svg" {
      println(@lib.to_svg(board))
    } else if format == "ascii" {
      println(@lib.to_ascii(board))
    } else if format == "text" {
      println(@lib.dfm_to_text(dfm))
    } else if format == "csv" {
      println(@lib.dfm_to_csv(dfm))
    } else if format == "sarif" {
      println(@lib.dfm_to_sarif(dfm))
    } else if format == "html" {
      println(@lib.board_to_html(board, report=dfm))
    } else if format == "fabrication" {
      println(@lib.assess_fabrication(board).to_json())
    } else {
      println(@lib.to_json(summary))
    }
  }
}
