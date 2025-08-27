import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import gleaxml/lexer
import nibble
import nibble/lexer as nlexer

pub type XmlNode {
  Element(
    name: String,
    attrs: dict.Dict(String, String),
    children: List(XmlNode),
  )
  Text(content: String)
}

fn tag() -> nibble.Parser(XmlNode, lexer.XmlToken, b) {
  use _ <- nibble.do(nibble.token(lexer.TagOpen))
  use name <- nibble.do(tag_name())
  use attrs <- nibble.do(attributes())
  use children <- nibble.do(
    nibble.one_of([simple_tag(name), self_closing_tag()]),
  )

  nibble.return(Element(name:, attrs:, children:))
}

fn text_content() -> nibble.Parser(XmlNode, lexer.XmlToken, e) {
  use tok <- nibble.take_map("text content")

  case tok {
    lexer.Text(content) -> option.Some(Text(content))
    _ -> option.None
  }
}

fn simple_tag(name: String) -> nibble.Parser(List(XmlNode), lexer.XmlToken, c) {
  use _ <- nibble.do(nibble.token(lexer.TagClose))

  use children <- nibble.do(children_and_end(name))

  nibble.return(children)
}

fn self_closing_tag() -> nibble.Parser(List(XmlNode), lexer.XmlToken, d) {
  use _ <- nibble.do(nibble.token(lexer.TagEnd))
  use _ <- nibble.do(nibble.token(lexer.TagClose))

  nibble.return([])
}

fn tag_name() -> nibble.Parser(String, lexer.XmlToken, a) {
  use tok <- nibble.take_map("a tag name")

  case tok {
    lexer.Text(name) -> option.Some(name)
    _ -> option.None
  }
}

fn attributes() -> nibble.Parser(dict.Dict(String, String), lexer.XmlToken, a) {
  use state <- nibble.loop(dict.new())
  use attr <- nibble.do(nibble.optional(attribute()))

  case attr {
    option.Some(a) -> {
      case dict.has_key(state, a.0) {
        True -> nibble.fail("Duplicate attribute name")
        False ->
          nibble.Continue(state |> dict.insert(a.0, a.1)) |> nibble.return
      }
    }
    option.None -> nibble.Break(state) |> nibble.return
  }
}

fn attribute() -> nibble.Parser(#(String, String), lexer.XmlToken, a) {
  use name <- nibble.do(attribute_name())
  use _ <- nibble.do(nibble.token(lexer.Equals))
  use value <- nibble.do(attribute_value())
  nibble.return(#(name, value))
}

fn attribute_name() -> nibble.Parser(String, lexer.XmlToken, a) {
  use tok <- nibble.take_map("an attribute name")

  case tok {
    lexer.Text(name) -> option.Some(name)
    _ -> option.None
  }
}

fn attribute_value() -> nibble.Parser(String, lexer.XmlToken, a) {
  let single_quote_value =
    tokens_between(lexer.SingleQuote, lexer.SingleQuote)
    |> nibble.map(fn(tokens) {
      tokens
      |> list.map(lexer.print_token)
      |> string.join("")
    })
  let double_quote_value =
    tokens_between(lexer.DoubleQuote, lexer.DoubleQuote)
    |> nibble.map(fn(tokens) {
      tokens
      |> list.map(lexer.print_token)
      |> string.join("")
    })
  nibble.one_of([single_quote_value, double_quote_value])
}

fn tokens_between(
  start: lexer.XmlToken,
  end: lexer.XmlToken,
) -> nibble.Parser(List(lexer.XmlToken), lexer.XmlToken, a) {
  use _ <- nibble.do(nibble.token(start))
  use tokens <- nibble.do(nibble.take_until(fn(tok) { tok == end }))
  use _ <- nibble.do(nibble.token(end))
  nibble.return(tokens)
}

fn children_and_end(
  parent_name: String,
) -> nibble.Parser(List(XmlNode), lexer.XmlToken, c) {
  use state <- nibble.loop([])
  use el <- nibble.do(
    nibble.one_of([
      nibble.backtrackable(tag_end(parent_name)) |> nibble.replace(option.None),
      tag() |> nibble.map(option.Some),
      text_content() |> nibble.map(option.Some),
    ]),
  )

  case el {
    option.Some(a) -> nibble.Continue([a, ..state]) |> nibble.return
    option.None -> nibble.Break(state) |> nibble.return
  }
}

fn tag_end(name: String) -> nibble.Parser(Nil, lexer.XmlToken, g) {
  use _ <- nibble.do(nibble.token(lexer.TagOpen))
  use _ <- nibble.do(nibble.token(lexer.TagEnd))
  use _ <- nibble.do(nibble.token(lexer.Text(name)))
  use _ <- nibble.do(nibble.token(lexer.TagClose))

  nibble.return(Nil)
}

pub fn parser() {
  tag()
}

pub fn parse(
  tokens: List(nlexer.Token(lexer.XmlToken)),
) -> Result(XmlNode, List(nibble.DeadEnd(lexer.XmlToken, f))) {
  nibble.run(tokens, parser())
}
