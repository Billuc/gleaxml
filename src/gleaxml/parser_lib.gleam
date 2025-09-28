import gleam/dict
import gleam/result
import splitter

pub type Parser(return, mode) {
  Parser(fn(State(mode)) -> Result(ParserReturn(return), Nil))
}

pub type State(mode) {
  State(
    input: String,
    splitters: dict.Dict(mode, splitter.Splitter),
    mode: mode,
  )
}

pub type ParserReturn(return) {
  ParserReturn(data: return, delimiter: String, remaining: String)
}

pub fn return(return_value: return) -> Parser(return, m) {
  use state <- Parser
  Ok(ParserReturn(return_value, "", state.input))
}

pub fn next_split() -> Parser(String, m) {
  use state <- Parser

  use splitter <- result.try(state.splitters |> dict.get(state.mode))
  let #(data, delim, after) = splitter.split(splitter, state.input)

  Ok(ParserReturn(data, delim, after))
}

pub fn do(parser: Parser(r, m), then: fn(r) -> Parser(s, m)) -> Parser(s, m) {
  use state <- Parser

  let Parser(parse) = parser
  use ret <- result.try(parse(state))

  let Parser(parse2) = then(ret.data)
  let new_state = State(..state, input: ret.remaining)

  parse2(new_state)
}

pub fn do_delim(
  parser: Parser(r, m),
  then: fn(r, String) -> Parser(s, m),
) -> Parser(s, m) {
  use state <- Parser

  let Parser(parse) = parser
  use ret <- result.try(parse(state))

  let Parser(parse2) = then(ret.data, ret.delimiter)
  let new_state = State(..state, input: ret.remaining)

  parse2(new_state)
}

pub fn expect(expected_split: String) -> Parser(String, m) {
  use state <- Parser
  let Parser(parse) = next_split()

  use ret <- result.try(parse(state))

  case ret.delimiter {
    d if d == expected_split -> Ok(ParserReturn(ret.data, d, ret.remaining))
    _ -> Error(Nil)
  }
}

pub fn one_of()
