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
  )
}

pub type ParserReturn(return, tokens) {
  ParserReturn(data: return, state: State(tokens))
}

pub type ParserError {
  EndOfInput
  RemainingInput(input: String)
  UnexpectedToken(token: String, expected: String)
  ExpectedOneOfToken(token: String, expected: List(String))
  UnknownToken(token: String)
  Unreachable
}

pub opaque type Splitter(tokens) {
  Splitter(splitter: splitter.Splitter, token_dict: dict.Dict(String, tokens))
}

pub opaque type SplitterBuilder(tokens) {
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
  )
}

pub fn any(
  state: State(tokens),
) -> Result(ParserReturn(String, tokens), ParserError) {
  case state.input {
    "" -> Error(EndOfInput)
    _ -> {
      let #(before, delim, after) =
        splitter.split(state.splitter.splitter, state.input)

      case dict.get(state.splitter.token_dict, delim) {
        Error(_) -> Error(UnknownToken(delim))
        Ok(delimiter) -> {
          Ok(ParserReturn(
            before,
            State(
              ..state,
              input: after,
              delimiter: option.Some(delimiter),
              delimiter_string: delim,
            ),
          ))
        }
      }
    }
  }
}

pub fn eof(
  state: State(tokens),
) -> Result(ParserReturn(Nil, tokens), ParserError) {
  case state.input {
    "" -> Ok(ParserReturn(Nil, state))
    _ -> Error(RemainingInput(state.input))
  }
}

pub fn keep_until(
  state: State(tokens),
  stop_fn: fn(tokens) -> Bool,
) -> Result(ParserReturn(String, tokens), ParserError) {
  do_keep_until(state, stop_fn, "")
}

fn do_keep_until(
  state: State(tokens),
  stop_fn: fn(tokens) -> Bool,
  acc: String,
) -> Result(ParserReturn(String, tokens), ParserError) {
  case any(state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(result, new_state)) ->
      case new_state.delimiter {
        option.None -> Error(Unreachable)
        option.Some(delim) -> {
          case stop_fn(delim) {
            True -> Ok(ParserReturn(acc <> result, new_state))
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
}

pub fn expect(
  state: State(tokens),
  expected: tokens,
) -> Result(ParserReturn(String, tokens), ParserError) {
  case any(state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(result, new_state)) ->
      case new_state.delimiter {
        option.None -> Error(Unreachable)
        option.Some(delim) ->
          case delim == expected {
            True -> Ok(ParserReturn(result, new_state))
            False ->
              Error(UnexpectedToken(
                string.inspect(delim),
                string.inspect(expected),
              ))
          }
      }
  }
}

pub fn expect_one_of(
  state: State(tokens),
  expected: List(tokens),
) -> Result(ParserReturn(String, tokens), ParserError) {
  case any(state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(result, new_state)) ->
      case new_state.delimiter {
        option.None -> Error(Unreachable)
        option.Some(delim) ->
          case list.contains(expected, delim) {
            True -> Ok(ParserReturn(result, new_state))
            False ->
              Error(ExpectedOneOfToken(
                string.inspect(delim),
                expected |> list.map(string.inspect),
              ))
          }
      }
  }
}

pub fn do_while(
  state: State(tokens),
  continue_fn: fn(tokens) -> Bool,
) -> Result(ParserReturn(List(String), tokens), ParserError) {
  do_do_while(state, continue_fn, [])
}

pub fn do_do_while(
  state: State(tokens),
  continue_fn: fn(tokens) -> Bool,
  accumulator: List(String),
) -> Result(ParserReturn(List(String), tokens), ParserError) {
  case any(state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(result, new_state)) ->
      case new_state.delimiter {
        option.None -> Error(Unreachable)
        option.Some(delim) ->
          case continue_fn(delim) {
            False -> Ok(ParserReturn(list.reverse(accumulator), state))
            True -> do_do_while(new_state, continue_fn, [result, ..accumulator])
          }
      }
  }
}

pub fn drop_while(
  state: State(tokens),
  continue_fn: fn(tokens) -> Bool,
) -> Result(ParserReturn(Nil, tokens), ParserError) {
  case any(state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(_, new_state)) ->
      case new_state.delimiter {
        option.None -> Error(Unreachable)
        option.Some(delim) ->
          case continue_fn(delim) {
            False -> Ok(ParserReturn(Nil, state))
            True -> drop_while(new_state, continue_fn)
          }
      }
  }
}

pub fn drop_tokens(
  state: State(tokens),
  tokens_to_drop: List(tokens),
) -> Result(ParserReturn(Nil, tokens), ParserError) {
  drop_while(state, list.contains(tokens_to_drop, _))
}

pub fn drop(
  state: State(tokens),
) -> Result(ParserReturn(Nil, tokens), ParserError) {
  case any(state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(_, new_state)) -> Ok(ParserReturn(Nil, new_state))
  }
}

pub fn optional(
  state_before: State(tokens),
  result: Result(ParserReturn(return, tokens), error),
) -> ParserReturn(option.Option(return), tokens) {
  case result {
    Error(_) -> ParserReturn(option.None, state_before)
    Ok(ParserReturn(data, new_state)) ->
      ParserReturn(option.Some(data), new_state)
  }
}

pub fn with_splitter(
  state: State(tokens),
  splitter: Splitter(other_tokens),
) -> State(other_tokens) {
  State(..state, splitter: splitter, delimiter: option.None)
}

pub fn use_splitter(
  state: State(tokens_a),
  splitter: Splitter(tokens_b),
  then: fn(State(tokens_b)) -> Result(ParserReturn(return, tokens_b), error),
) -> Result(ParserReturn(return, tokens_a), error) {
  let new_state = with_splitter(state, splitter)
  case then(new_state) {
    Error(e) -> Error(e)
    Ok(ParserReturn(data, returned_state)) -> {
      let restored_state = with_splitter(returned_state, state.splitter)
      Ok(ParserReturn(data, restored_state))
    }
  }
}

pub fn print_error(error: ParserError) -> String {
  case error {
    EndOfInput -> "End of input reached unexpectedly."
    RemainingInput(input) ->
      "Expected end of input, but found remaining input: "
      <> string.inspect(input)
    UnexpectedToken(token, expected) ->
      "Unexpected token " <> token <> ", expected " <> expected <> "."
    ExpectedOneOfToken(token, expected) ->
      "Unexpected token "
      <> token
      <> ", expected one of: "
      <> string.join(expected, ", ")
      <> "."
    UnknownToken(token) ->
      "Unknown token encountered: " <> string.inspect(token) <> "."
    Unreachable -> "Reached unreachable code."
  }
}
