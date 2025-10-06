import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import splitter

pub opaque type Parser(return, mode) {
  Parser(fn(State(mode)) -> Result(ParserReturn(return), String))
}

pub opaque type State(mode) {
  State(
    input: String,
    splitters: dict.Dict(mode, splitter.Splitter),
    mode: mode,
  )
}

pub opaque type ParserReturn(return) {
  ParserReturn(data: return, delimiter: String, remaining: String)
}

pub type Runner(return, mode) {
  Runner(
    parser: Parser(return, mode),
    initial_mode: mode,
    splitters: dict.Dict(mode, splitter.Splitter),
  )
}

pub fn runner(
  parser: Parser(return, mode),
  initial_mode: mode,
) -> Runner(return, mode) {
  Runner(parser, initial_mode, dict.new())
}

pub fn register(
  runner: Runner(return, mode),
  mode: mode,
  splitter: splitter.Splitter,
) -> Runner(return, mode) {
  Runner(
    runner.parser,
    runner.initial_mode,
    dict.insert(runner.splitters, mode, splitter),
  )
}

pub fn run(
  runner: Runner(return, mode),
  input: String,
) -> Result(return, String) {
  let initial_state = State(input, runner.splitters, runner.initial_mode)
  let Parser(parse) = runner.parser

  use ret <- result.try(parse(initial_state))
  case ret.remaining == "" {
    True -> Ok(ret.data)
    False -> Error("Parser did not consume all input")
  }
}

pub fn return(return_value: return) -> Parser(return, m) {
  use state <- Parser
  Ok(ParserReturn(return_value, "", state.input))
}

pub fn fail(message: String) -> Parser(r, m) {
  use _ <- Parser
  Error(message)
}

pub fn next_split() -> Parser(String, m) {
  use state <- Parser

  case state.splitters |> dict.get(state.mode) {
    Ok(splitter) -> {
      let #(data, delim, after) = splitter.split(splitter, state.input)
      Ok(ParserReturn(data, delim, after))
    }
    Error(_) -> Error("Current mode isn't registered !")
  }
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

pub fn while(
  parser: Parser(r, m),
  continue_fn: fn(r, String) -> Bool,
) -> Parser(List(r), m) {
  use state <- Parser

  loop_while(state, parser, continue_fn, [])
}

fn loop_while(
  state: State(m),
  parser: Parser(r, m),
  continue_fn: fn(r, String) -> Bool,
  results: List(r),
) {
  let Parser(parse) = parser
  use ret <- result.try(parse(state))

  case continue_fn(ret.data, ret.delimiter) {
    True ->
      loop_while(State(..state, input: ret.remaining), parser, continue_fn, [
        ret.data,
        ..results
      ])
    False ->
      Ok(ParserReturn(results |> list.reverse(), ret.delimiter, ret.remaining))
  }
}

pub fn until(stop_string: String) -> Parser(String, m) {
  use state <- Parser
  do_until(state, next_split(), stop_string, "")
}

fn do_until(
  state: State(m),
  parser: Parser(String, m),
  stop_string: String,
  accumulator: String,
) {
  let Parser(parse) = parser
  use ret <- result.try(parse(state))

  case ret.delimiter == stop_string {
    True ->
      Ok(ParserReturn(accumulator <> ret.data, ret.delimiter, ret.remaining))
    False ->
      do_until(
        State(..state, input: ret.remaining),
        parser,
        stop_string,
        accumulator <> ret.data <> ret.delimiter,
      )
  }
}

pub fn expect(expected_split: String) -> Parser(String, m) {
  use state <- Parser
  let Parser(parse) = next_split()

  use ret <- result.try(parse(state))

  case ret.delimiter == expected_split {
    True -> Ok(ret)
    False ->
      Error(
        "Expected '" <> expected_split <> "' but got '" <> ret.delimiter <> "'",
      )
  }
}

pub fn expect_one_of(expected_splits: List(String)) -> Parser(String, m) {
  use state <- Parser
  let Parser(parse) = next_split()

  use ret <- result.try(parse(state))

  case expected_splits |> list.contains(ret.delimiter) {
    True -> Ok(ret)
    False ->
      Error(
        "Expected one of '"
        <> expected_splits |> string.join("', '")
        <> "' but got '"
        <> ret.delimiter
        <> "'",
      )
  }
}

pub fn optional(parser: Parser(r, m)) -> Parser(option.Option(r), m) {
  use state <- Parser
  let Parser(parse) = parser

  case parse(state) {
    Ok(ret) ->
      Ok(ParserReturn(option.Some(ret.data), ret.delimiter, ret.remaining))
    Error(_) -> Ok(ParserReturn(option.None, "", state.input))
  }
}

pub fn drop_while(is_to_drop: fn(String, String) -> Bool) -> Parser(Nil, m) {
  use state <- Parser
  do_drop_while(state, is_to_drop)
}

fn do_drop_while(state: State(m), is_to_drop: fn(String, String) -> Bool) {
  let Parser(parse) = next_split()
  use ret <- result.try(parse(state))

  case is_to_drop(ret.data, ret.delimiter) {
    True -> do_drop_while(State(..state, input: ret.remaining), is_to_drop)
    False -> Ok(ParserReturn(Nil, "", state.input))
  }
}

pub fn drop() -> Parser(Nil, m) {
  use _ <- do(next_split())
  return(Nil)
}

pub fn drop_chars(chars: List(String)) -> Parser(Nil, m) {
  drop_while(fn(before, delim) { before == "" && list.contains(chars, delim) })
}

pub fn with_mode(new_mode: m, parser: fn() -> Parser(r, m)) -> Parser(r, m) {
  use state <- Parser
  let new_state = State(..state, mode: new_mode)

  let Parser(parse) = parser()
  parse(new_state)
}
