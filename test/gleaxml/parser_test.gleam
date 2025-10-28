import gleaxml/parser
import splitter

pub type TestMode {
  A
  B
}

pub fn splitter_a() -> splitter.Splitter {
  splitter.new([" "])
}

pub fn splitter_b() -> splitter.Splitter {
  splitter.new([","])
}

pub fn parse(
  parser: parser.Parser(a, TestMode),
  input: String,
  mode: TestMode,
) -> Result(a, String) {
  parser.runner(parser, mode)
  |> parser.register(A, splitter_a())
  |> parser.register(B, splitter_b())
  |> parser.run(input)
}

pub fn all_input_consumed_test() {
  let parser_all = {
    use before_space <- parser.do(parser.expect(" "))
    use after_space <- parser.do(parser.next_split())
    parser.return([before_space, after_space])
  }
  let parser_not_all = {
    use before_space <- parser.do(parser.expect(" "))
    parser.return([before_space])
  }

  let assert Ok(result) = parse(parser_all, "some input", A)
  assert result == ["some", "input"]
  let assert Error(_) = parse(parser_not_all, "some input", A)
}
