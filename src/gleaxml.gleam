import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleaxml/lexer
import gleaxml/parser
import nibble
import nibble/lexer as nlexer

pub fn parse(input: String) {
  use tokens <- result.try(
    lexer.get_tokens(input) |> result.map_error(print_lexer_error),
  )
  use xml_node <- result.try(
    parser.parse(tokens) |> result.map_error(print_parser_error),
  )
  Ok(xml_node)
}

fn print_lexer_error(err: nlexer.Error) -> String {
  case err {
    nlexer.NoMatchFound(row:, col:, lexeme:) ->
      "Lexer error at row "
      <> row |> int.to_string()
      <> ", column "
      <> col |> int.to_string()
      <> ": No match found for '"
      <> lexeme
      <> "'"
  }
}

fn print_parser_error(errs: List(nibble.DeadEnd(lexer.XmlToken, a))) -> String {
  {
    use deadend <- list.map(errs)
    "At position "
    <> deadend.pos.row_start |> int.to_string()
    <> ":"
    <> deadend.pos.col_start |> int.to_string()
    <> ": "
    <> print_nibble_error(deadend.problem)
  }
  |> string.join("\n")
}

fn print_nibble_error(err: nibble.Error(lexer.XmlToken)) -> String {
  case err {
    nibble.BadParser(parser) -> "Bad parser: " <> parser
    nibble.Custom(err) -> err
    nibble.EndOfInput -> "Unexpected end of input"
    nibble.Expected(expected, got:) ->
      "Expected " <> expected <> ", got " <> lexer.print_token(got)
    nibble.Unexpected(unexpected) ->
      "Unexpected token: " <> lexer.print_token(unexpected)
  }
}
