import gleam/set
import gleam/string
import nibble/lexer

pub type XmlToken {
  TagOpen(name: String)
  TagClose
  TagSelfClose
  TagEnd(name: String)
  Text(String)
  Equals
  CommentStart
  CommentEnd
  Quote(quote: String)
}

pub type Mode {
  StartTag
  EndTag
  Content
  Comment
  AttrValue(quote: String)
}

pub fn lexer() {
  lexer.advanced(fn(mode: Mode) {
    case mode {
      StartTag -> [
        lexer.token("=", Equals),
        lexer.token("/>", TagSelfClose) |> lexer.into(fn(_) { Content }),
        lexer.token(">", TagClose) |> lexer.into(fn(_) { Content }),
        lexer.token("'", Quote("'")) |> lexer.into(fn(_) { AttrValue("'") }),
        lexer.token("\"", Quote("\"")) |> lexer.into(fn(_) { AttrValue("\"") }),
        name_matcher() |> lexer.map(fn(name) { Text(name) }),
        lexer.token("\n", Nil) |> lexer.ignore(),
        lexer.whitespace(Nil) |> lexer.ignore(),
      ]
      EndTag -> [
        lexer.token(">", TagClose) |> lexer.into(fn(_) { Content }),
        lexer.token("\n", Nil) |> lexer.ignore(),
        lexer.whitespace(Nil) |> lexer.ignore(),
      ]
      Comment -> [
        lexer.token("-->", CommentEnd) |> lexer.into(fn(_) { Content }),
        lexer.identifier("[^\\-]", "[^\\-]", set.new(), Text),
        lexer.keyword("-", "[^-]", Text("-")),
      ]
      Content -> [
        lexer.token("<!--", CommentStart) |> lexer.into(fn(_) { Comment }),
        name_with_prefix("</")
          |> lexer.map(fn(name) { TagEnd(name:) })
          |> lexer.into(fn(_) { EndTag }),
        name_with_prefix("<")
          |> lexer.map(fn(name) { TagOpen(name:) })
          |> lexer.into(fn(_) { StartTag }),
        lexer.whitespace(Nil) |> lexer.ignore(),
        lexer.token("\n", Nil) |> lexer.ignore(),
        lexer.identifier("[^<&]", "[^<&]", set.new(), Text),
      ]
      AttrValue(quote:) -> [
        lexer.identifier(
          "[^<&" <> quote <> "]",
          "[^<&" <> quote <> "]",
          set.new(),
          Text,
        ),
        lexer.token(quote, Quote(quote)) |> lexer.into(fn(_) { StartTag }),
      ]
    }
  })
}

fn name_with_prefix(prefix: String) -> lexer.Matcher(String, mode) {
  lexer.identifier(
    prefix <> "[a-zA-Z:_]",
    "[a-zA-Z0-9:_\\-\\.]",
    set.new(),
    fn(s) { s |> string.drop_start(string.length(prefix)) },
  )
}

fn name_matcher() -> lexer.Matcher(String, mode) {
  lexer.identifier("[a-zA-Z:_]", "[a-zA-Z0-9:_\\-\\.]", set.new(), fn(s) { s })
}

pub fn get_tokens(
  input: String,
) -> Result(List(lexer.Token(XmlToken)), lexer.Error) {
  lexer.run_advanced(input, Content, lexer())
}

pub fn print_token(tok: XmlToken) -> String {
  case tok {
    Text(s) -> s
    Equals -> "="
    TagOpen(name:) -> "<" <> name
    TagEnd(name:) -> "</" <> name
    TagClose -> ">"
    TagSelfClose -> "/>"
    Quote(quote:) -> quote
    CommentEnd -> "-->"
    CommentStart -> "<!--"
  }
}
