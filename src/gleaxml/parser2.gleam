import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import splitter

pub type State(tokens) {
  State(
    splitter: Splitter(tokens),
    input: String,
    delimiter: option.Option(tokens),
    delimiter_string: String,
    errors: List(ErrorContext),
  )
}

pub type ParserReturn(return, tokens) {
  ParserReturn(data: return, state: State(tokens))
}

pub type ErrorContext {
  ErrorContext(error: ParserError, input: String)
}

pub type ParserError {
  EndOfInput
  RemainingInput(input: String)
  UnexpectedToken(token: String, expected: String)
  ExpectedOneOfToken(token: String, expected: List(String))
  UnknownToken(token: String)
}

pub type Splitter(tokens) {
  Splitter(splitter: splitter.Splitter, token_dict: dict.Dict(String, tokens))
}

pub type SplitterBuilder(tokens) {
  SplitterBuilder(tokens: List(String), token_dict: dict.Dict(String, tokens))
}

pub fn splitter() -> SplitterBuilder(a) {
  SplitterBuilder([], dict.new())
}

pub fn add_token(
  builder: SplitterBuilder(tokens),
  token: String,
  value: tokens,
) -> SplitterBuilder(tokens) {
  SplitterBuilder(
    tokens: [token, ..builder.tokens],
    token_dict: dict.insert(builder.token_dict, token, value),
  )
}

pub fn build(builder: SplitterBuilder(tokens)) -> Splitter(tokens) {
  let splitter = splitter.new(builder.tokens)
  Splitter(splitter, builder.token_dict)
}

pub fn init_state(splitter: Splitter(tokens), input: String) -> State(tokens) {
  State(
    splitter: splitter,
    input: input,
    delimiter: option.None,
    delimiter_string: "",
    errors: [],
  )
}

pub fn any(state: State(tokens)) -> ParserReturn(String, tokens) {
  case state.input {
    "" ->
      ParserReturn(
        "",
        State(..state, delimiter: option.None, delimiter_string: "", errors: [
          ErrorContext(EndOfInput, ""),
          ..state.errors
        ]),
      )
    _ -> {
      let #(before, delim, after) =
        splitter.split(state.splitter.splitter, state.input)

      let delimiter = dict.get(state.splitter.token_dict, delim)

      case delimiter {
        Error(_) -> {
          let new_state =
            State(
              ..state,
              input: after,
              delimiter: option.None,
              delimiter_string: delim,
              errors: [
                ErrorContext(UnknownToken(delim), state.input),
                ..state.errors
              ],
            )
          ParserReturn(before, new_state)
        }
        Ok(delimiter) -> {
          ParserReturn(
            before,
            State(
              ..state,
              input: after,
              delimiter: option.Some(delimiter),
              delimiter_string: delim,
            ),
          )
        }
      }
    }
  }
}

pub fn eof(state: State(tokens)) -> ParserReturn(Nil, tokens) {
  case state.input {
    "" -> ParserReturn(Nil, state)
    _ ->
      ParserReturn(
        Nil,
        State(..state, errors: [
          ErrorContext(RemainingInput(state.input), state.input),
          ..state.errors
        ]),
      )
  }
}

pub fn keep_until(
  state: State(tokens),
  stop_fn: fn(tokens) -> Bool,
) -> ParserReturn(String, tokens) {
  do_keep_until(state, stop_fn, "")
}

fn do_keep_until(
  state: State(tokens),
  stop_fn: fn(tokens) -> Bool,
  acc: String,
) -> ParserReturn(String, tokens) {
  let ParserReturn(result, new_state) = any(state)

  case new_state.delimiter {
    option.None -> ParserReturn("", new_state)
    option.Some(delim) -> {
      case stop_fn(delim) {
        True -> ParserReturn(acc <> result, new_state)
        False ->
          do_keep_until(
            new_state,
            stop_fn,
            acc <> result <> new_state.delimiter_string,
          )
      }
    }
  }
}

pub fn expect(
  state: State(tokens),
  expected: tokens,
) -> ParserReturn(String, tokens) {
  let ParserReturn(result, new_state) = any(state)

  case new_state.delimiter {
    option.None -> ParserReturn("", new_state)
    option.Some(delim) ->
      case delim == expected {
        True -> ParserReturn(result, new_state)
        False ->
          ParserReturn(
            "",
            State(..new_state, errors: [
              ErrorContext(
                UnexpectedToken(string.inspect(delim), string.inspect(expected)),
                new_state.input,
              ),
              ..new_state.errors
            ]),
          )
      }
  }
}

pub fn expect_one_of(
  state: State(tokens),
  expected: List(tokens),
) -> ParserReturn(String, tokens) {
  let ParserReturn(result, new_state) = any(state)

  case new_state.delimiter {
    option.None -> ParserReturn("", new_state)
    option.Some(delim) ->
      case list.contains(expected, delim) {
        True -> ParserReturn(result, new_state)
        False ->
          ParserReturn(
            "",
            State(..new_state, errors: [
              ErrorContext(
                ExpectedOneOfToken(
                  string.inspect(delim),
                  expected |> list.map(string.inspect),
                ),
                new_state.input,
              ),
              ..new_state.errors
            ]),
          )
      }
  }
}

pub fn do_while(
  state: State(tokens),
  continue_fn: fn(tokens) -> Bool,
) -> ParserReturn(List(String), tokens) {
  do_do_while(state, continue_fn, [])
}

pub fn do_do_while(
  state: State(tokens),
  continue_fn: fn(tokens) -> Bool,
  accumulator: List(String),
) -> ParserReturn(List(String), tokens) {
  let ParserReturn(result, new_state) = any(state)

  case new_state.delimiter {
    option.None -> ParserReturn([], new_state)
    option.Some(delim) ->
      case continue_fn(delim) {
        False -> ParserReturn(list.reverse(accumulator), state)
        True -> do_do_while(new_state, continue_fn, [result, ..accumulator])
      }
  }
}

pub fn drop_while(
  state: State(tokens),
  continue_fn: fn(tokens) -> Bool,
) -> ParserReturn(Nil, tokens) {
  let ParserReturn(result, new_state) = any(state)

  case new_state.delimiter {
    option.None -> ParserReturn(Nil, new_state)
    option.Some(delim) ->
      case continue_fn(delim) {
        False -> ParserReturn(Nil, state)
        True -> drop_while(new_state, continue_fn)
      }
  }
}

pub fn drop(state: State(tokens)) -> ParserReturn(Nil, tokens) {
  let ParserReturn(_, new_state) = any(state)
  ParserReturn(Nil, new_state)
}

pub fn with_splitter(
  state: State(tokens),
  splitter: Splitter(other_tokens),
) -> State(other_tokens) {
  State(..state, splitter: splitter, delimiter: option.None)
}
