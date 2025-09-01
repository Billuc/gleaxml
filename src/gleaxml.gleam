import gleam/dict
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
    "Parser error at position "
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

pub fn get_nodes(
  root: parser.XmlNode,
  path: List(String),
) -> List(parser.XmlNode) {
  case path, root {
    [name, ..rest], parser.Element(n, _, _) if n == name ->
      do_get_nodes(rest, [root])
    _, _ -> []
  }
}

fn do_get_nodes(
  path: List(String),
  nodes: List(parser.XmlNode),
) -> List(parser.XmlNode) {
  case path {
    [] -> nodes
    ["*", ..rest] -> {
      let children =
        nodes
        |> list.flat_map(fn(node) {
          case node {
            parser.Element(_, _, children) -> children
            _ -> []
          }
        })
      do_get_nodes(rest, children)
    }
    [name, ..rest] -> {
      let children =
        nodes
        |> list.flat_map(fn(node) {
          case node {
            parser.Element(_, _, children) -> {
              children
              |> list.filter_map(fn(child) {
                case child {
                  parser.Element(n, _, _) if n == name -> Ok(child)
                  _ -> Error(Nil)
                }
              })
            }
            _ -> []
          }
        })
      do_get_nodes(rest, children)
    }
  }
}

pub fn get_attribute(
  node: parser.XmlNode,
  name: String,
) -> Result(String, String) {
  case node {
    parser.Element(_, attrs, _) -> {
      attrs
      |> dict.get(name)
      |> result.replace_error("No attribute with name " <> name)
    }
    _ -> Error("Node is not an element")
  }
}

pub fn get_text(node: parser.XmlNode) -> List(String) {
  case node {
    parser.Element(_, _, children) ->
      children
      |> list.filter_map(fn(child) {
        case child {
          parser.Text(text) -> Ok(text)
          _ -> Error(Nil)
        }
      })
    parser.Comment(comment) -> [comment]
    parser.Text(content:) -> [content]
  }
}
