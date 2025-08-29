import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleaxml/lexer
import nibble
import nibble/lexer as nlexer

pub type XmlDocument {
  XmlDocument(
    version: String,
    encoding: String,
    standalone: Bool,
    root_element: XmlNode,
  )
}

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

fn text() -> nibble.Parser(XmlNode, lexer.XmlToken, m) {
  {
    use texts <- nibble.loop([])
    use s <- nibble.do(
      nibble.optional(nibble.one_of([text_content(), reference()])),
    )

    case s, texts {
      option.None, [] -> nibble.fail("No text")
      option.None, _ -> nibble.Break(texts |> list.reverse) |> nibble.return
      option.Some(t), _ -> nibble.Continue([t, ..texts]) |> nibble.return
    }
  }
  |> nibble.then(fn(texts) {
    let content = texts |> string.join("")
    nibble.return(Text(content))
  })
}

fn text_content() -> nibble.Parser(String, lexer.XmlToken, e) {
  use tok <- nibble.take_map("text content")

  case tok {
    lexer.Text(content) -> option.Some(content)
    _ -> option.None
  }
}

fn reference() -> nibble.Parser(String, lexer.XmlToken, l) {
  use _ <- nibble.do(nibble.token(lexer.ReferenceStart))
  use reftext <- nibble.do(
    nibble.take_map("a reference", fn(tok) {
      case tok {
        lexer.ReferenceHexCode(code:) ->
          code
          |> int.base_parse(16)
          |> result.try(string.utf_codepoint)
          |> result.map(fn(code) {
            string.from_utf_codepoints([code]) |> option.Some
          })
          |> result.unwrap(option.None)
        lexer.ReferenceCode(code:) ->
          code
          |> int.base_parse(10)
          |> result.try(string.utf_codepoint)
          |> result.map(fn(code) {
            string.from_utf_codepoints([code]) |> option.Some
          })
          |> result.unwrap(option.None)
        lexer.ReferenceName("amp") -> option.Some("&")
        lexer.ReferenceName("quot") -> option.Some("\"")
        lexer.ReferenceName("apos") -> option.Some("'")
        lexer.ReferenceName("lt") -> option.Some("<")
        lexer.ReferenceName("gt") -> option.Some(">")
        lexer.ReferenceName(name) -> option.Some("&" <> name <> ";")
        _ -> option.None
      }
    }),
  )
  use _ <- nibble.do(nibble.token(lexer.ReferenceEnd))

  nibble.return(reftext)
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
    nibble.optional(nibble.one_of([tag(), text(), comment(), cdata()])),
  )

  case el {
    option.Some(a) -> nibble.Continue([a, ..state]) |> nibble.return
    option.None -> nibble.Break(state |> list.reverse) |> nibble.return
  }
}

fn tag_end(name: String) -> nibble.Parser(Nil, lexer.XmlToken, g) {
  use _ <- nibble.do(nibble.take_while(fn(t) { t == lexer.Text(" ") }))
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

fn xml_declaration() -> nibble.Parser(
  #(String, option.Option(String), option.Option(Bool)),
  lexer.XmlToken,
  n,
) {
  use _ <- nibble.do(nibble.token(lexer.XmlDeclarationStart))
  use attrs <- nibble.do(attributes())
  use _ <- nibble.do(nibble.token(lexer.XmlDeclarationEnd))

  let attr_list = dict.to_list(attrs)
  let #(version, attr_list) = pop_attr(attr_list, "version")
  let #(encoding, attr_list) = pop_attr(attr_list, "encoding")
  let #(standalone, attr_list) = pop_attr(attr_list, "standalone")

  case version, attr_list {
    option.None, _ -> nibble.fail("Version is required")
    _, [el, ..] -> nibble.fail("Incorrect attribute: " <> el.0)
    option.Some(v), [] ->
      nibble.return(#(
        v,
        encoding,
        standalone |> option.map(fn(s) { s == "yes" }),
      ))
  }
}

fn pop_attr(
  attrs: List(#(String, String)),
  attr: String,
) -> #(option.Option(String), List(#(String, String))) {
  case list.key_pop(attrs, attr) {
    Error(Nil) -> #(option.None, attrs)
    Ok(#(value, new_attrs)) -> #(option.Some(value), new_attrs)
  }
}

pub fn parser() -> nibble.Parser(XmlDocument, lexer.XmlToken, i) {
  use _ <- nibble.do(nibble.take_while(fn(t) { t == lexer.Text(" ") }))
  use xml_decl_info <- nibble.do(nibble.optional(xml_declaration()))
  use _ <- nibble.do(nibble.take_while(fn(t) { t == lexer.Text(" ") }))
  use node <- nibble.do(tag())
  use _ <- nibble.do(nibble.take_while(fn(t) { t == lexer.Text(" ") }))

  case xml_decl_info {
    option.None -> nibble.return(XmlDocument("1.0", "UTF-8", True, node))
    option.Some(#(v, e, s)) ->
      nibble.return(XmlDocument(
        v,
        e |> option.unwrap("UTF-8"),
        s |> option.unwrap(True),
        node,
      ))
  }
}

pub fn parse(
  tokens: List(nlexer.Token(lexer.XmlToken)),
) -> Result(XmlDocument, List(nibble.DeadEnd(lexer.XmlToken, f))) {
  nibble.run(tokens, parser())
}
