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
  let assert parser.Element(name, attrs, children) = node
  assert name == "note"
  assert attrs == dict.new()

  assert children
    == [
      parser.Element("to", dict.new(), [parser.Text("Tove")]),
      parser.Element("from", dict.new(), [parser.Text("Jani")]),
      parser.Element("heading", dict.new(), [parser.Text("Reminder")]),
      parser.Element("body", dict.new(), [
        parser.Text("Don't forget me this weekend!"),
      ]),
    ]
}

pub fn self_closing_with_attrs_test() {
  let xml = "<img src=\"image.png\" alt=\"An image\"/>"

  let assert Ok(node) = gleaxml.parse(xml)
  let assert parser.Element(name, attrs, children) = node
  assert name == "img"
  assert attrs == dict.from_list([#("src", "image.png"), #("alt", "An image")])
  assert children == []
}

pub fn simple_test_with_attrs_test() {
  let xml = "<a href=\"https://example.com\">Link</a>"

  let assert Ok(node) = gleaxml.parse(xml)
  let assert parser.Element(name, attrs, children) = node
  assert name == "a"
  assert attrs == dict.from_list([#("href", "https://example.com")])
  assert children == [parser.Text("Link")]
}

pub fn xml_with_text_and_children_test() {
  let xml = "<div>Hello <b>World</b>!</div>"

  let assert Ok(node) = gleaxml.parse(xml)
  let assert parser.Element(name, attrs, children) = node
  assert name == "div"
  assert attrs == dict.new()
  assert children
    == [
      parser.Text("Hello "),
      parser.Element("b", dict.new(), [parser.Text("World")]),
      parser.Text("!"),
    ]
}

pub fn xml_with_comments_test() {
  let xml = "<tag><!-- This is a comment -->Content</tag>"

  let assert Ok(node) = gleaxml.parse(xml)
  let assert parser.Element(name, _attrs, children) = node
  assert name == "tag"
  assert children
    == [parser.Comment(" This is a comment "), parser.Text("Content")]
}

pub fn comment_with_hyphens_test() {
  let xml = "<tag><!-- Comment with - hyphens --></tag>"

  let assert Ok(node) = gleaxml.parse(xml)
  let assert parser.Element(name, _attrs, children) = node
  assert name == "tag"
  assert children == [parser.Comment(" Comment with - hyphens ")]
}

pub fn comment_with_double_hyphens_fails_test() {
  let xml = "<tag><!-- Comment with -- hyphens --></tag>"

  let assert Error(_) = gleaxml.parse(xml)
}

pub fn fail_if_closing_tag_mismatch_test() {
  let xml = "<a>Content</b>"

  let assert Error(_) = gleaxml.parse(xml)
}

pub fn quote_in_attribute_value_test() {
  let xml = "<tag attr='Value with \"quotes\"'/>"

  let assert Ok(node) = gleaxml.parse(xml)
  let assert parser.Element(name, attrs, children) = node
  assert name == "tag"
  assert attrs == dict.from_list([#("attr", "Value with \"quotes\"")])
  assert children == []
}
