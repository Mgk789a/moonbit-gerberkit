///|
pub struct BenchmarkResult {
  name : String
  input_size : Int
  iterations : Int
  elapsed_ticks : UInt64
  operations : Int
  shapes : Int
} derive(Debug)

///|
pub struct BenchmarkSuite {
  results : Array[BenchmarkResult]
  toolchain : String
  fixture : String
} derive(Debug)

///|
fn benchmark_elapsed(start : UInt64, finish : UInt64) -> UInt64 {
  if finish >= start {
    finish - start
  } else {
    0
  }
}

///|
fn benchmark_result(
  name~ : String,
  input_size~ : Int,
  iterations~ : Int,
  elapsed_ticks~ : UInt64,
  operations~ : Int,
  shapes~ : Int,
) -> BenchmarkResult {
  { name, input_size, iterations, elapsed_ticks, operations, shapes }
}

///|
pub fn BenchmarkResult::ticks_per_operation(self : BenchmarkResult) -> Double {
  if self.operations == 0 {
    0.0
  } else {
    self.elapsed_ticks.to_double() / self.operations.to_double()
  }
}

///|
pub fn BenchmarkResult::operations_per_tick(self : BenchmarkResult) -> Double {
  if self.elapsed_ticks == 0 {
    self.operations.to_double()
  } else {
    self.operations.to_double() / self.elapsed_ticks.to_double()
  }
}

///|
pub fn BenchmarkResult::summary(self : BenchmarkResult) -> String {
  "\{self.name}: input=\{self.input_size}B iterations=\{self.iterations} ticks=\{self.elapsed_ticks} operations=\{self.operations} shapes=\{self.shapes}"
}

///|
pub fn benchmark_parse(
  size : FixtureSize,
  iterations? : Int = 3,
) -> BenchmarkResult {
  let input = fixture_gerber(size)
  let start = @env.now()
  let mut shapes = 0
  let mut operations = 0
  for _ in 0..<iterations {
    let document = parse_gerber_document(input, name="benchmark")
    shapes += document.layer.shapes.length()
    operations += document.records + document.commands
  }
  let finish = @env.now()
  benchmark_result(
    name="gerber-parse",
    input_size=input.length(),
    iterations~,
    elapsed_ticks=benchmark_elapsed(start, finish),
    operations~,
    shapes~,
  )
}

///|
pub fn benchmark_excellon(
  size : FixtureSize,
  iterations? : Int = 3,
) -> BenchmarkResult {
  let input = fixture_excellon(size)
  let start = @env.now()
  let mut shapes = 0
  let mut operations = 0
  for _ in 0..<iterations {
    let document = parse_excellon_document(input, name="benchmark")
    shapes += document.layer.shapes.length()
    operations += document.records + document.hits + document.tool_count()
  }
  let finish = @env.now()
  benchmark_result(
    name="excellon-parse",
    input_size=input.length(),
    iterations~,
    elapsed_ticks=benchmark_elapsed(start, finish),
    operations~,
    shapes~,
  )
}

///|
pub fn benchmark_dfm(
  size : FixtureSize,
  iterations? : Int = 3,
) -> BenchmarkResult {
  let board = fixture_board(size)
  let start = @env.now()
  let mut findings = 0
  let mut operations = 0
  for _ in 0..<iterations {
    let report = run_dfm(board)
    findings += report.findings.length()
    operations += report.shape_count * report.checked_rules
  }
  let finish = @env.now()
  benchmark_result(
    name="dfm-check",
    input_size=board_shape_count(board),
    iterations~,
    elapsed_ticks=benchmark_elapsed(start, finish),
    operations~,
    shapes=findings,
  )
}

///|
pub fn benchmark_render(
  size : FixtureSize,
  iterations? : Int = 3,
) -> BenchmarkResult {
  let board = fixture_board(size)
  let start = @env.now()
  let mut output_size = 0
  let mut operations = 0
  for _ in 0..<iterations {
    output_size += to_svg(board).length()
    output_size += board_to_json(board, include_shapes=true).length()
    output_size += to_ascii(board).length()
    operations += board_shape_count(board)
  }
  let finish = @env.now()
  benchmark_result(
    name="render",
    input_size=board_shape_count(board),
    iterations~,
    elapsed_ticks=benchmark_elapsed(start, finish),
    operations=operations + output_size,
    shapes=output_size,
  )
}

///|
pub fn run_benchmark_suite(
  size : FixtureSize,
  iterations? : Int = 3,
) -> BenchmarkSuite {
  {
    results: [
      benchmark_parse(size, iterations~),
      benchmark_excellon(size, iterations~),
      benchmark_dfm(size, iterations~),
      benchmark_render(size, iterations~),
    ],
    toolchain: "moonbit",
    fixture: fixture_size_name(size),
  }
}

///|
pub fn BenchmarkSuite::total_ticks(self : BenchmarkSuite) -> UInt64 {
  self.results.fold(init=0, (sum, result) => sum + result.elapsed_ticks)
}

///|
pub fn BenchmarkSuite::total_operations(self : BenchmarkSuite) -> Int {
  self.results.fold(init=0, (sum, result) => sum + result.operations)
}

///|
pub fn BenchmarkSuite::summary(self : BenchmarkSuite) -> String {
  let mut output = "fixture=\{self.fixture} total_ticks=\{self.total_ticks()} operations=\{self.total_operations()}\n"
  for result in self.results {
    output += result.summary() + "\n"
  }
  output
}

///|
pub fn BenchmarkSuite::to_json(self : BenchmarkSuite) -> String {
  let results = self.results
    .map(result => {
      "{\"name\":\{json_string(result.name)},\"input_size\":\{result.input_size},\"iterations\":\{result.iterations},\"elapsed_ticks\":\{result.elapsed_ticks},\"operations\":\{result.operations},\"shapes\":\{result.shapes}}"
    })
    .join(",")
  "{\"toolchain\":\{json_string(self.toolchain)},\"fixture\":\{json_string(self.fixture)},\"total_ticks\":\{self.total_ticks()},\"results\":[\{results}]}"
}

///|
pub fn BenchmarkSuite::to_markdown(self : BenchmarkSuite) -> String {
  let mut output = "| Benchmark | Input | Iterations | Ticks | Operations | Shapes |\n|---|---:|---:|---:|---:|---:|\n"
  for result in self.results {
    output += "|\{result.name}|\{result.input_size}|\{result.iterations}|\{result.elapsed_ticks}|\{result.operations}|\{result.shapes}|\n"
  }
  output
}

///|
pub fn benchmark_smoke() -> Bool {
  let suite = run_benchmark_suite(TinyFixture, iterations=1)
  suite.results.length() == 4 && suite.total_operations() > 0
}
