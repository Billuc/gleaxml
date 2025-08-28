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
  Comment(content: String)
}

fn tag() -> nibble.Parser(XmlNode, lexer.XmlToken, b) {
  use name <- nibble.do(tag_open())
  use attrs <- nibble.do(attributes())
  use children <- nibble.do(
    nibble.one_of([simple_tag(name), self_closing_tag()]),
  )

  nibble.return(Element(name:, attrs:, children:))
}

fn tag_open() -> nibble.Parser(String, lexer.XmlToken, h) {
  use tok <- nibble.take_map("an opening tag")

  case tok {
    lexer.TagOpen(name) -> option.Some(name)
    _ -> option.None
  }
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

  use children <- nibble.do(children())
  use _ <- nibble.do(tag_end(name))

  nibble.return(children)
}

fn self_closing_tag() -> nibble.Parser(List(XmlNode), lexer.XmlToken, d) {
  use _ <- nibble.do(nibble.token(lexer.TagSelfClose))

  nibble.return([])
}

fn attributes() -> nibble.Parser(dict.Dict(String, String), lexer.XmlToken, a) {
  use state <- nibble.loop(dict.new())
  use attr <- nibble.do(nibble.optional(attribute()))

  case attr {
    option.Some(a) -> {
      case dict.has_key(state, a.0) {
        True -> nibble.fail("Duplicate attribute name: " <> a.0)
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
  use start_quote <- nibble.do(
    nibble.one_of([
      nibble.token(lexer.Quote("'")) |> nibble.replace("'"),
      nibble.token(lexer.Quote("\"")) |> nibble.replace("\""),
    ]),
  )
  use value <- nibble.do(
    nibble.take_map("an attribute value", fn(tok) {
      case tok {
        lexer.Text(v) -> option.Some(v)
        _ -> option.None
      }
    }),
  )
  use end_quote <- nibble.do(
    nibble.one_of([
      nibble.token(lexer.Quote("'")) |> nibble.replace("'"),
      nibble.token(lexer.Quote("\"")) |> nibble.replace("\""),
    ]),
  )

  case start_quote == end_quote {
    True -> nibble.return(value)
    False -> nibble.fail("Expected " <> start_quote <> ", got " <> end_quote)
  }
}

fn children() -> nibble.Parser(List(XmlNode), lexer.XmlToken, c) {
  use state <- nibble.loop([])
  use el <- nibble.do(
    nibble.optional(nibble.one_of([tag(), text_content(), comment(), cdata()])),
  )

  case el {
    option.Some(a) -> nibble.Continue([a, ..state]) |> nibble.return
    option.None -> nibble.Break(state |> list.reverse) |> nibble.return
  }
}

fn tag_end(name: String) -> nibble.Parser(Nil, lexer.XmlToken, g) {
  use _ <- nibble.do(nibble.token(lexer.TagEnd(name:)))
  use _ <- nibble.do(nibble.token(lexer.TagClose))

  nibble.return(Nil)
}

fn comment() -> nibble.Parser(XmlNode, lexer.XmlToken, k) {
  use _ <- nibble.do(nibble.token(lexer.CommentStart))
  use values <- nibble.do(
    nibble.take_map_while(fn(tok) {
      case tok {
        lexer.Text(v) -> option.Some(v)
        _ -> option.None
      }
    }),
  )
  use _ <- nibble.do(nibble.token(lexer.CommentEnd))

  nibble.return(Comment(string.join(values, "")))
}

fn cdata() -> nibble.Parser(XmlNode, lexer.XmlToken, j) {
  use _ <- nibble.do(nibble.token(lexer.CDATAOpen))
  use values <- nibble.do(
    nibble.take_map_while(fn(tok) {
      case tok {
        lexer.Text(v) -> option.Some(v)
        _ -> option.None
      }
    }),
  )
  use _ <- nibble.do(nibble.token(lexer.CDATAClose))

  nibble.return(Text(string.join(values, "")))
}

pub fn parser() -> nibble.Parser(XmlNode, lexer.XmlToken, i) {
  tag()
}

pub fn parse(
  tokens: List(nlexer.Token(lexer.XmlToken)),
) -> Result(XmlNode, List(nibble.DeadEnd(lexer.XmlToken, f))) {
  nibble.run(tokens, parser())
}
