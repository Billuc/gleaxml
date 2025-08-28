import gleam/list
import gleam/set
import gleam/string
import nibble/lexer

type TestToken {
  Open(name: String)
  Close(name: String)
}

fn lexer() {
  lexer.simple([
    lexer.identifier("</[a-zA-Z:_]", "[a-zA-Z0-9:_\\-\\.]", set.new(), fn(s) {
      Close(s |> string.drop_start(2))
    }),
    lexer.identifier("<[a-zA-Z:_]", "[a-zA-Z0-9:_\\-\\.]", set.new(), fn(s) {
      Open(s |> string.drop_start(1))
    }),
  ])
}

pub fn lexer_identifier_test() {
  let assert Ok(tokens) = lexer.run("<azer", lexer())
  assert tokens |> list.map(fn(t) { t.value }) == [Open("azer")]

  let assert Ok(tokens) = lexer.run("</foo", lexer())
  assert tokens |> list.map(fn(t) { t.value }) == [Close("foo")]
}

pub fn string_split_test() {
  assert string.split("'test'", "'") == ["", "test", ""]
  assert string.split("a", "a") == ["", ""]
}
