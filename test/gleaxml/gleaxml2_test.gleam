import gleam/dict
import gleam/list
import gleaxml/gleaxml2
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn self_closing_tag_test() {
  let self_closing_xml = "<br/>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) =
    gleaxml2.parse(self_closing_xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "br"
  assert attrs == dict.new()
  assert children == []
}

pub fn simple_tag_test() {
  let simple_tag_xml = "<greeting>Hello, world!</greeting>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) =
    gleaxml2.parse(simple_tag_xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "greeting"
  assert attrs == dict.new()
  let assert [gleaxml2.Text(content)] = children
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

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) =
    gleaxml2.parse(simple_xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "note"
  assert attrs == dict.new()

  assert children
    == [
      gleaxml2.Text(" "),
      gleaxml2.Element("to", dict.new(), [gleaxml2.Text("Tove")]),
      gleaxml2.Text(" "),
      gleaxml2.Element("from", dict.new(), [gleaxml2.Text("Jani")]),
      gleaxml2.Text(" "),
      gleaxml2.Element("heading", dict.new(), [gleaxml2.Text("Reminder")]),
      gleaxml2.Text(" "),
      gleaxml2.Element("body", dict.new(), [
        gleaxml2.Text("Don't forget me this weekend!"),
      ]),
      gleaxml2.Text(" "),
    ]
}

pub fn self_closing_with_attrs_test() {
  let xml = "<img src=\"image.png\" alt=\"An image\"/>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "img"
  assert attrs == dict.from_list([#("src", "image.png"), #("alt", "An image")])
  assert children == []
}

pub fn simple_test_with_attrs_test() {
  let xml = "<a href=\"https://example.com\">Link</a>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "a"
  assert attrs == dict.from_list([#("href", "https://example.com")])
  assert children == [gleaxml2.Text("Link")]
}

pub fn xml_with_text_and_children_test() {
  let xml = "<div>Hello <b>World</b>!</div>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "div"
  assert attrs == dict.new()
  assert children
    == [
      gleaxml2.Text("Hello "),
      gleaxml2.Element("b", dict.new(), [gleaxml2.Text("World")]),
      gleaxml2.Text("!"),
    ]
}

pub fn xml_with_comments_test() {
  let xml = "<tag><!-- This is a comment -->Content</tag>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "tag"
  assert children
    == [gleaxml2.Comment(" This is a comment "), gleaxml2.Text("Content")]
}

pub fn comment_with_hyphens_test() {
  let xml = "<tag><!-- Comment with - hyphens --></tag>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "tag"
  assert children == [gleaxml2.Comment(" Comment with - hyphens ")]
}

pub fn comment_with_double_hyphens_fails_test() {
  let xml = "<tag><!-- Comment with -- hyphens --></tag>"

  let assert Error(_) = gleaxml2.parse(xml)
}

pub fn fail_if_closing_tag_mismatch_test() {
  let xml = "<a>Content</b>"

  let assert Error(_) = gleaxml2.parse(xml)
}

pub fn quote_in_attribute_value_test() {
  let xml = "<tag attr='Value with \"quotes\"'/>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "tag"
  assert attrs == dict.from_list([#("attr", "Value with \"quotes\"")])
  assert children == []
}

pub fn cdata_section_test() {
  let xml = "<data><![CDATA[Some <unescaped> & data]]></data>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "data"
  assert children == [gleaxml2.Text("Some <unescaped> & data")]
}

pub fn cdata_with_brackets_test() {
  let xml = "<data><![CDATA[Some ]] tricky data]]></data>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "data"
  assert children == [gleaxml2.Text("Some ]] tricky data")]
}

pub fn entity_reference_test() {
  let xml = "<text>this is a &quot;quoted&quot; text</text>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "text"
  assert children == [gleaxml2.Text("this is a \"quoted\" text")]
}

pub fn char_reference_test() {
  let xml = "<text>&#91; a &#x5c; b &#93;</text>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "text"
  assert children == [gleaxml2.Text("[ a \\ b ]")]
}

pub fn reference_in_attribute_value_test() {
  let xml = "<tag attr=\"Value with &lt; &amp; &gt;\"/>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, attrs, children) = node
  assert name == "tag"
  assert attrs == dict.from_list([#("attr", "Value with < & >")])
  assert children == []
}

pub fn text_with_newlines_test() {
  let xml =
    "<text>this
  is a
  multiline
  text</text>"

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "text"
  assert children == [gleaxml2.Text("this is a multiline text")]
}

pub fn multiline_content_test() {
  let xml =
    "
<parent>
  Test
  <child>hello</child>
</parent>
  "

  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)
  let assert gleaxml2.Element(name, _attrs, children) = node
  assert name == "parent"
  assert children
    == [
      gleaxml2.Text(" Test "),
      gleaxml2.Element("child", dict.new(), [gleaxml2.Text("hello")]),
      gleaxml2.Text(" "),
    ]
}

pub fn doc_with_no_xml_declaration_test() {
  let xml = "<root><child>Content</child></root>"

  let assert Ok(gleaxml2.XmlDocument(version, encoding, standalone, _)) =
    gleaxml2.parse(xml)
  assert version == "1.0"
  assert encoding == "UTF-8"
  assert standalone == True
}

pub fn doc_with_xml_declaration_test() {
  let xml =
    "<?xml version=\"1.1\" encoding=\"ISO-8859-1\" standalone=\"no\"?>
<root><child>Content</child></root>"

  let assert Ok(gleaxml2.XmlDocument(version, encoding, standalone, _)) =
    gleaxml2.parse(xml)
  assert version == "1.1"
  assert encoding == "ISO-8859-1"
  assert standalone == False
}

pub fn get_nodes_test() {
  let xml =
    "<root><child id=\"1\">First</child><child id=\"2\">Second</child></root>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, root)) = gleaxml2.parse(xml)

  let nodes = gleaxml2.get_nodes(root, ["root", "child"])
  assert nodes |> list.length() == 2
}

pub fn get_node_test() {
  let xml =
    "<root><child id=\"1\">First</child><child id=\"2\">Second</child></root>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, root)) = gleaxml2.parse(xml)

  let assert Ok(first_child) = gleaxml2.get_node(root, ["root", "child"])
  let assert gleaxml2.Element(name, attrs, _) = first_child
  assert name == "child"
  assert attrs == dict.from_list([#("id", "1")])

  let assert Error(msg) = gleaxml2.get_node(root, ["root", "nonexistent"])
  assert msg == "No node found at path root/nonexistent"
}

pub fn get_attribute_test() {
  let xml = "<element attr1=\"value1\" attr2=\"value2\"/>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let assert Ok(attr1) = gleaxml2.get_attribute(node, "attr1")
  let assert Ok(attr2) = gleaxml2.get_attribute(node, "attr2")
  assert attr1 == "value1"
  assert attr2 == "value2"

  let assert Error(msg) = gleaxml2.get_attribute(node, "nonexistent")
  assert msg == "No attribute with name nonexistent"
}

pub fn get_texts_test() {
  let xml = "<element>Text1<b>Bold</b>Text2<!-- Comment -->Text3</element>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let texts = gleaxml2.get_texts(node)
  assert texts == ["Text1", "Text2", "Text3"]
}

pub fn get_texts_with_newlines_test() {
  let xml =
    "<element>
  <b>Bold</b>
  Text1
  Text2
  <!-- Comment -->
  Text3
</element>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let texts = gleaxml2.get_texts(node)
  assert texts == [" ", " Text1 Text2 ", " Text3 "]
}

pub fn get_nonempty_texts_test() {
  let xml =
    "<element>
  <b>Bold</b>
  mytext
</element>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let texts = gleaxml2.get_nonempty_texts(node)
  assert texts == [" mytext "]
}

pub fn no_nonempty_texts_test() {
  let xml = "<element><b>Bold</b><!-- Comment --></element>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let texts = gleaxml2.get_nonempty_texts(node)
  assert texts == []
}

pub fn get_comments_test() {
  let xml = "<element><!-- Comment1 --><b>Bold</b><!-- Comment2 --></element>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let comments = gleaxml2.get_comments(node)
  assert comments == [" Comment1 ", " Comment2 "]
}

pub fn no_comments_test() {
  let xml = "<element><b>Bold</b>Text</element>"
  let assert Ok(gleaxml2.XmlDocument(_, _, _, node)) = gleaxml2.parse(xml)

  let comments = gleaxml2.get_comments(node)
  assert comments == []
}
