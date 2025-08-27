import gleam/set
import nibble/lexer

pub type XmlToken {
  TagOpen
  TagClose
  TagEnd
  Text(String)
  Value(String)
  SingleQuote
  DoubleQuote
  Equals
}

pub fn lexer() {
  lexer.simple([
    lexer.token("<", TagOpen),
    lexer.token(">", TagClose),
    lexer.token("/", TagEnd),
    lexer.token("'", SingleQuote),
    lexer.token("\"", DoubleQuote),
    lexer.token("=", Equals),
    lexer.token("\n", Nil) |> lexer.ignore(),
    lexer.whitespace(Nil) |> lexer.ignore(),
    lexer.identifier("[^/<>]", "[^/<>]", set.new(), Text),
    lexer.identifier("[^'\"]", "[^'\"]", set.new(), Value),
  ])
}

pub fn get_tokens(
  input: String,
) -> Result(List(lexer.Token(XmlToken)), lexer.Error) {
  lexer.run(input, lexer())
}

pub fn print_token(tok: XmlToken) -> String {
  case tok {
    Text(s) -> s
    Value(s) -> s
    DoubleQuote -> "\""
    Equals -> "="
    SingleQuote -> "'"
    TagOpen -> "<"
    TagClose -> ">"
    TagEnd -> "/"
  }
}
