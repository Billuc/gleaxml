import gleam/dict
import gleaxml
import gleaxml/parser
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn self_closing_tag_test() {
  let self_closing_xml = "<br/>"

  let assert Ok(node) = gleaxml.parse(self_closing_xml)
  let assert parser.Element(name, attrs, children) = node
  assert name == "br"
  assert attrs == dict.new()
  assert children == []
}

pub fn simple_tag_test() {
  let simple_tag_xml = "<greeting>Hello, world!</greeting>"

  let assert Ok(node) = gleaxml.parse(simple_tag_xml)
  let assert parser.Element(name, attrs, children) = node
  assert name == "greeting"
  assert attrs == dict.new()
  let assert [parser.Text(content)] = children
  assert content == "Hello, world!"
}

pub fn simple_xml_test() {
  let simple_xml =
    "
  <note>
    <to>Tove</to>
    <from>Jani</from>
    <heading>Reminder</heading>
    <body>Don't forget me this weekend!</body>
  </note>
  "

  let assert Ok(node) = gleaxml.parse(simple_xml)
}
