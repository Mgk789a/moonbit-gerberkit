///|
test "lexer preserves parameter and drawing records" {
  let text = "%FSLAX24Y24*%MOMM*%ADD10C,0.2*%X1Y2D02*X3Y4D01*"
  let tokens = tokenize_gerber(text)
  assert_true(tokens.length() >= 10)
  assert_true(tokens.any(token => token.kind is ParameterStart))
  assert_true(tokens.any(token => token.kind is ParameterEnd))
  assert_true(tokens.any(token => token.kind is Command))
  assert_true(tokens.any(token => token.kind is Coordinate))
  assert_true(tokens.last().unwrap().kind is EndOfFile)
}

///|
test "lexer source locations move across lines" {
  let tokens = tokenize_gerber("G04 first*\nX1Y2D02*\nX3Y4D01*")
  let first = tokens[0]
  assert_true(first.line == 1)
  assert_true(tokens.any(token => token.line == 2))
  assert_true(tokens.any(token => token.line == 3))
  assert_true(first.location().contains("1:"))
}

///|
test "record helpers parse axes and codes" {
  let record = "X-12.50Y3.25I1.0J-2.0D01"
  assert_true(record_has_code(record, "D01"))
  assert_true(record_code_value(record, "D") is Some(1))
  assert_true(record_coordinate(record, 'X') is Some("-12.50"))
  assert_true(record_coordinate(record, 'Y') is Some("3.25"))
  assert_true(record_coordinate_number(record, 'I') is Some(1.0))
  assert_true(record_axes(record).length() == 4)
}

///|
test "token records exclude delimiters" {
  let records = tokenize_records("%MOMM*%X1Y2D02*")
  assert_true(records.contains("MOMM"))
  assert_true(records.contains("X1Y2D02"))
  assert_true(!records.contains("%"))
}

///|
test "comment stripping keeps parameter boundaries" {
  let clean = strip_gerber_comments(
    "%TF.FileFunction,Copper*%G04 ignored*%X1Y2D02*",
  )
  assert_true(clean.contains("TF.FileFunction"))
  assert_true(clean.contains("X1Y2D02"))
  assert_true(!clean.contains("ignored"))
}

///|
test "source span containment is inclusive" {
  let span = source_span(start_line=2, start_column=3, end_line=4, end_column=5)
  assert_true(span.contains(line=2, column=3))
  assert_true(span.contains(line=3, column=1))
  assert_true(span.contains(line=4, column=5))
  assert_true(!span.contains(line=1, column=9))
  assert_true(!span.contains(line=4, column=6))
  assert_true(span.to_string() == "2:3-4:5")
}

///|
test "token stream consumes without skipping eof" {
  let stream = token_stream(tokenize_gerber("X1Y2D02*"))
  assert_true(!stream.at_end())
  let first = stream.take()
  assert_true(first is Some(_))
  ignore(stream.take())
  assert_true(stream.at_end())
  assert_true(stream.skip_until(end_of_file_token_kind()) == 0)
}

///|
test "diagnostics format long records safely" {
  let diagnostic = diagnostic(
    severity=warning_diagnostic(),
    code="long",
    message="record is long",
    line=7,
    column=2,
    record="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz",
  )
  assert_true(!diagnostic.is_error())
  assert_true(diagnostic.format().contains("warning"))
  assert_true(diagnostic.format().contains("7:2"))
}

///|
test "excellon records ignore comments and blank lines" {
  let records = tokenize_excellon("; comment\n\nM48\nMETRIC,TZ\nT1C0.8\n")
  assert_true(records.length() == 3)
  assert_true(records[0] == "M48")
  assert_true(records[2] == "T1C0.8")
}
