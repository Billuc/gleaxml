import gleam/bool
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleaxml/parser
import splitter

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
  CDATAOpen
  CDATAClose
  ReferenceStart
  ReferenceName(name: String)
  ReferenceCode(code: String)
  ReferenceHexCode(code: String)
  ReferenceEnd
  XmlDeclarationStart
  XmlDeclarationEnd
}

pub type Mode {
  Root
  StartTag
  EndTag
  // Content
  // Comment
  AttrValue
  // CDATA
  // Reference(parent: Mode)
  // XmlDecl
}

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
  // Text(content: String)
  // Comment(content: String)
}

pub fn parse(input: String) -> Result(XmlDocument, String) {
  parser.runner(parse_xml_document(), Root)
  |> parser.register(Root, root_splitter())
  |> parser.register(StartTag, start_tag_splitter())
  |> parser.register(EndTag, end_tag_splitter())
  |> parser.register(AttrValue, attr_value_splitter())
  |> parser.run(input)
}

fn parse_xml_document() -> parser.Parser(XmlDocument, Mode) {
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use _, delim <- parser.do_delim(parser.next_split())

  case delim {
    "<" -> {
      // todo as "XML declaration"
      use root_element <- parser.do(parse_start_tag())
      // todo as "content"
      // todo as "EOF"
      parser.return(XmlDocument("1.0", "UTF-8", True, root_element))
    }
    _ -> parser.fail("Expected '<' at start of XML document")
  }
}

fn parse_start_tag() -> parser.Parser(XmlNode, Mode) {
  use <- parser.with_mode(StartTag)
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use tag_name, delim <- parser.do_delim(parser.next_split())

  case delim {
    "/>" ->
      parser.return(Element(name: tag_name, attrs: dict.new(), children: []))
    ">" -> {
      todo as "children"
      todo as "closing tag"
    }
    _ -> {
      use attributes, delim <- parser.do_delim(parse_attributes())

      case delim {
        "/>" ->
          parser.return(
            Element(name: tag_name, attrs: attributes, children: []),
          )
        ">" -> {
          todo as "children"
          todo as "closing tag"
        }
        _ -> parser.fail("Expected '>' or '/>' after attributes")
      }
    }
  }
}

fn parse_attributes() {
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use attrs <- parser.do(
    parser.until(
      {
        use attr <- parser.do(parse_attribute())
        use _ <- parser.do(parser.expect_one_of([" ", "\r", "\n", "/>", ">"]))
        parser.return(attr)
      },
      fn(delim) { delim != "/>" && delim != ">" },
    ),
  )
  parser.return(attrs |> dict.from_list())
}

fn parse_attribute() {
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use attr_name <- parser.do(parser.expect("="))
  use _, quote <- parser.do_delim(parser.expect_one_of(["\"", "'"]))
  use attr_value <- parser.do(parse_attribute_value(quote))

  parser.return(#(attr_name, attr_value))
}

fn parse_attribute_value(quote: String) {
  use <- parser.with_mode(AttrValue)
  use attr_value <- parser.do(parser.keep_until(quote))
  parser.return(attr_value)
}

fn echo_state(state: parser.State(m)) {
  io.println("State: " <> string.inspect(state) <> "\n")
}

fn root_splitter() {
  splitter.new(["<", "\r", "\n", " "])
}

fn attr_value_splitter() {
  splitter.new(["\"", "'"])
}

fn start_tag_splitter() {
  splitter.new(["/>", ">", "=", "\"", "'", "\r", "\n", " "])
}

fn end_tag_splitter() {
  splitter.new([">", "\r", " ", "\n"])
}

fn content_splitter() {
  splitter.new(["</", "<"])
}
