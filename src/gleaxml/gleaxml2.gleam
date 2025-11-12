import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import gleaxml/parser2.{
  type ParserReturn, type Splitter, type State, ParserReturn,
}

const cdata_start = "<![CDATA["

const cdata_end = "]]>"

const comment_start = "<!--"

const comment_end = "-->"

const xml_decl_start = "<?xml"

const xml_decl_end = "?>"

const hex_char_reference = "&#x"

const dec_char_reference = "&#"

const entity_reference = "&"

const semi_colon = ";"

pub type ReferenceType {
  CharDec
  CharHex
  Entity
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
  Text(content: String)
  Comment(content: String)
}

pub fn parse(input: String) -> Result(XmlDocument, String) {
  let state = parser2.init_state(root_splitter(), input)
  let splitters =
    Splitters(
      root: root_splitter(),
      attr_value: attr_value_splitter(),
      start_tag: start_tag_splitter(),
      end_tag: end_tag_splitter(),
      content: content_splitter(),
      comment_value: comment_value_splitter(),
      cdata: cdata_splitter(),
      xml_decl: xml_decl_splitter(),
      reference: reference_splitter(),
    )

  let ParserReturn(res, state) = parse_xml_document(splitters, state)

  case res {
    Ok(doc) -> Ok(doc)
    Error(_) ->
      Error(
        "XML parsing failed at delimiter '"
        <> state.delimiter_string
        <> "' with remaining input: '"
        <> state.input
        <> "'",
      )
  }
}

type Splitters {
  Splitters(
    root: Splitter(RootToken),
    attr_value: Splitter(AttrValueToken),
    start_tag: Splitter(StartTagToken),
    end_tag: Splitter(EndTagToken),
    content: Splitter(ContentToken),
    comment_value: Splitter(CommentToken),
    cdata: Splitter(CDATAToken),
    xml_decl: Splitter(XmlDeclToken),
    reference: Splitter(ReferenceToken),
  )
}

type RootToken {
  RXmlDeclStart
  RLessThan
  RCarriageReturn
  RNewLine
  RSpace
}

fn root_splitter() {
  parser2.splitter()
  |> parser2.add_token(xml_decl_start, RXmlDeclStart)
  |> parser2.add_token("<", RLessThan)
  |> parser2.add_token("\r", RCarriageReturn)
  |> parser2.add_token("\n", RNewLine)
  |> parser2.add_token(" ", RSpace)
  |> parser2.build()
}

type AttrValueToken {
  AVHexCharReference
  AVDecCharReference
  AVEntityReference
  AVDoubleQuote
  AVSingleQuote
}

fn attr_value_splitter() {
  parser2.splitter()
  |> parser2.add_token(hex_char_reference, AVHexCharReference)
  |> parser2.add_token(dec_char_reference, AVDecCharReference)
  |> parser2.add_token(entity_reference, AVEntityReference)
  |> parser2.add_token("\"", AVDoubleQuote)
  |> parser2.add_token("'", AVSingleQuote)
  |> parser2.build()
}

type StartTagToken {
  STSelfClosingTag
  STGreaterThan
  STEqualSign
  STDoubleQuote
  STSingleQuote
  STCarriageReturn
  STNewLine
  STSpace
}

fn start_tag_splitter() {
  parser2.splitter()
  |> parser2.add_token("/>", STSelfClosingTag)
  |> parser2.add_token(">", STGreaterThan)
  |> parser2.add_token("=", STEqualSign)
  |> parser2.add_token("\"", STDoubleQuote)
  |> parser2.add_token("'", STSingleQuote)
  |> parser2.add_token("\r", STCarriageReturn)
  |> parser2.add_token("\n", STNewLine)
  |> parser2.add_token(" ", STSpace)
  |> parser2.build()
}

type EndTagToken {
  ETGreaterThan
  ETCarriageReturn
  ETNewLine
  ETSpace
}

fn end_tag_splitter() {
  parser2.splitter()
  |> parser2.add_token(">", ETGreaterThan)
  |> parser2.add_token("\r", ETCarriageReturn)
  |> parser2.add_token("\n", ETNewLine)
  |> parser2.add_token(" ", ETSpace)
  |> parser2.build()
}

type ContentToken {
  CEndTagStart
  CHexCharReference
  CDecCharReference
  CEntityReference
  CCommentStart
  CCDataStart
  CLessThan
}

fn content_splitter() {
  parser2.splitter()
  |> parser2.add_token("</", CEndTagStart)
  |> parser2.add_token(hex_char_reference, CHexCharReference)
  |> parser2.add_token(dec_char_reference, CDecCharReference)
  |> parser2.add_token(entity_reference, CEntityReference)
  |> parser2.add_token(comment_start, CCommentStart)
  |> parser2.add_token(cdata_start, CCDataStart)
  |> parser2.add_token("<", CLessThan)
  |> parser2.build()
}

type CommentToken {
  CECommentEnd
  CEDoubleDash
}

fn comment_value_splitter() {
  parser2.splitter()
  |> parser2.add_token(comment_end, CECommentEnd)
  |> parser2.add_token("--", CEDoubleDash)
  |> parser2.build()
}

type CDATAToken {
  CDCEnd
}

fn cdata_splitter() {
  parser2.splitter()
  |> parser2.add_token(cdata_end, CDCEnd)
  |> parser2.build()
}

type XmlDeclToken {
  XDEqual
  XDDoubleQuote
  XDSingleQuote
  XDDeclarationEnd
  XDCarriageReturn
  XDNewLine
  XDSpace
}

fn xml_decl_splitter() {
  parser2.splitter()
  |> parser2.add_token("=", XDEqual)
  |> parser2.add_token("\"", XDDoubleQuote)
  |> parser2.add_token("'", XDSingleQuote)
  |> parser2.add_token(xml_decl_end, XDDeclarationEnd)
  |> parser2.add_token("\r", XDCarriageReturn)
  |> parser2.add_token("\n", XDNewLine)
  |> parser2.add_token(" ", XDSpace)
  |> parser2.build()
}

type ReferenceToken {
  RSemicolon
}

fn reference_splitter() {
  parser2.splitter()
  |> parser2.add_token(semi_colon, RSemicolon)
  |> parser2.build()
}

type XmlParseError {
  NoDelimiter
  UnexpectedDelimiter(delimiter: String, expected: String)
}

fn parse_xml_document(
  splitters: Splitters,
  state: State(RootToken),
) -> ParserReturn(XmlDocument, RootToken) {
  let ParserReturn(_, state) =
    parser2.drop_while(state, fn(t) {
      case t {
        RSpace -> True
        RCarriageReturn -> True
        RNewLine -> True
        _ -> False
      }
    })
  let ParserReturn(_, state) =
    parser2.expect_one_of(state, [RXmlDeclStart, RLessThan])

  case state.delimiter {
    option.Some(RXmlDeclStart) -> {
      let ParserReturn(res, state) = parse_xml_declaration(splitters, state)
    }
    option.Some(RLessThan) -> {
      let ParserReturn(res, state) = parse_start_tag(splitters, state)
    }
    _ ->
      ParserReturn(
        XmlDocument(version, encoding, standalone, root_element),
        state,
      )
  }

  case delim {
    d if d == xml_decl_start -> {
      use #(version, encoding, standalone) <- parser.do(parse_xml_declaration())
      use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
      use _, delim <- parser.do_delim(parser.next_split())

      case delim {
        "<" -> {
          use root_element <- parser.do(parse_start_tag())
          use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
          parser.return(XmlDocument(version, encoding, standalone, root_element))
        }
        _ ->
          parser.fail(
            "Expected '<' at start of root element after XML declaration",
          )
      }
    }
    "<" -> {
      use root_element <- parser.do(parse_start_tag())
      use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
      parser.return(XmlDocument("1.0", "UTF-8", True, root_element))
    }
    _ ->
      parser.fail(
        "Expected '<' or " <> xml_decl_start <> " at start of XML document",
      )
  }
}

fn parse_xml_declaration() -> parser.Parser(#(String, String, Bool), Mode) {
  use <- parser.with_mode(XmlDecl)
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use #(name, value) <- parser.do(parse_attribute())

  case name == "version" {
    False -> parser.fail("Expected 'version' attribute in XML declaration")
    True -> {
      let version = value

      use attr <- parser.do(parser.optional(parse_attribute()))
      case attr {
        option.None -> {
          use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
          use _ <- parser.do(parser.expect(xml_decl_end))
          parser.return(#(version, "UTF-8", True))
        }
        option.Some(#("encoding", encoding)) -> {
          use attr <- parser.do(parser.optional(parse_attribute()))
          case attr {
            option.None -> {
              use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
              use _ <- parser.do(parser.expect(xml_decl_end))
              parser.return(#(version, encoding, True))
            }
            option.Some(#("standalone", standalone)) -> {
              use standalone <- parser.do(parse_standalone(standalone))
              use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
              use _ <- parser.do(parser.expect(xml_decl_end))
              parser.return(#(version, encoding, standalone))
            }
            option.Some(#(name, _)) ->
              parser.fail(
                "Unexpected attribute '" <> name <> "' in XML declaration",
              )
          }
        }
        option.Some(#("standalone", standalone)) -> {
          use standalone <- parser.do(parse_standalone(standalone))
          use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
          use _ <- parser.do(parser.expect(xml_decl_end))
          parser.return(#(version, "UTF-8", standalone))
        }
        option.Some(#(name, _)) ->
          parser.fail(
            "Unexpected attribute '" <> name <> "' in XML declaration",
          )
      }
    }
  }
}

fn parse_standalone(value: String) -> parser.Parser(Bool, Mode) {
  case value {
    "yes" -> parser.return(True)
    "no" -> parser.return(False)
    _ -> parser.fail("Expected 'yes' or 'no' for 'standalone' attribute")
  }
}

fn parse_start_tag() -> parser.Parser(XmlNode, Mode) {
  use <- parser.with_mode(StartTag)
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use tag_name <- parser.do(parser.next_split())
  use attributes, delim <- parser.do_delim(parse_attributes())

  case delim {
    "/>" ->
      parser.return(Element(name: tag_name, attrs: attributes, children: []))
    ">" -> {
      use children <- parser.do(parse_children())
      use _ <- parser.do(parse_closing_tag(tag_name))
      parser.return(Element(
        name: tag_name,
        attrs: attributes,
        children: children,
      ))
    }
    _ -> parser.fail("Expected '>' or '/>' after attributes")
  }
}

fn parse_attributes() {
  use attrs <- parser.do(
    parser.until(
      {
        use attr <- parser.do(parser.optional(parse_attribute()))
        use _ <- parser.do(parser.expect_one_of([" ", "\r", "\n", "/>", ">"]))
        parser.return(attr)
      },
      fn(delim) { delim != "/>" && delim != ">" },
    ),
  )
  parser.return(attrs |> option.values() |> dict.from_list())
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
  use content <- parser.do(
    parser.do_while(
      {
        use value, delim <- parser.do_delim(parser.next_split())
        use complement <- parser.do(case delim {
          d if d == quote -> parser.return("")
          d if d == hex_char_reference -> parse_reference(CharHex)
          d if d == dec_char_reference -> parse_reference(CharDec)
          d if d == entity_reference -> parse_reference(Entity)
          _ -> parser.return(delim)
        })
        parser.return(value <> complement)
      },
      fn(delim) { delim != quote },
    ),
  )
  parser.return(string.join(content, ""))
}

fn parse_reference(reference_type: ReferenceType) -> parser.Parser(String, Mode) {
  use <- parser.with_mode(Reference)
  use reference_content <- parser.do(parser.expect(semi_colon))

  let str_content_res = case reference_type {
    CharDec -> {
      use char_code <- result.try(int.base_parse(reference_content, 10))
      use char_codepoint <- result.try(string.utf_codepoint(char_code))
      Ok(string.from_utf_codepoints([char_codepoint]))
    }
    CharHex -> {
      use char_code <- result.try(int.base_parse(reference_content, 16))
      use char_codepoint <- result.try(string.utf_codepoint(char_code))
      Ok(string.from_utf_codepoints([char_codepoint]))
    }
    Entity ->
      case reference_content {
        "lt" -> Ok("<")
        "gt" -> Ok(">")
        "amp" -> Ok("&")
        "apos" -> Ok("'")
        "quot" -> Ok("\"")
        _ -> Error(Nil)
      }
  }

  case str_content_res {
    Ok(str_content) -> parser.return(str_content)
    Error(_) ->
      parser.fail(
        "Invalid reference "
        <> print_reference(reference_type, reference_content),
      )
  }
}

fn print_reference(reference_type: ReferenceType, content: String) {
  case reference_type {
    CharDec -> "&#" <> content <> ";"
    CharHex -> "&#x" <> content <> ";"
    Entity -> "&" <> content <> ";"
  }
}

fn parse_children() {
  use <- parser.with_mode(Content)
  use children_lists <- parser.do(
    parser.until(parse_child(), fn(delim) { delim != "</" }),
  )
  let children = list.flatten(children_lists)
  let children = merge_text_nodes(children)
  parser.return(children)
}

fn parse_child() -> parser.Parser(List(XmlNode), Mode) {
  use <- parser.with_mode(Content)
  use text, delim <- parser.do_delim(parser.next_split())

  let text_elem = case text {
    "" -> option.None
    _ -> option.Some(Text(fix_text_whitespace(text)))
  }
  case delim {
    "</" -> parser.return([text_elem] |> option.values())
    "<" -> {
      use child <- parser.do(parse_start_tag())
      parser.return([text_elem, option.Some(child)] |> option.values())
    }
    d if d == comment_start -> {
      use comment <- parser.do(parse_comment())
      parser.return([text_elem, option.Some(comment)] |> option.values())
    }
    d if d == cdata_start -> {
      use cdata <- parser.do(parse_cdata())
      parser.return([text_elem, option.Some(cdata)] |> option.values())
    }
    d if d == hex_char_reference -> {
      use ref_content <- parser.do(parse_reference(CharHex))
      let text_node = Text(content: ref_content)
      parser.return([text_elem, option.Some(text_node)] |> option.values())
    }
    d if d == dec_char_reference -> {
      use ref_content <- parser.do(parse_reference(CharDec))
      let text_node = Text(content: ref_content)
      parser.return([text_elem, option.Some(text_node)] |> option.values())
    }
    d if d == entity_reference -> {
      use ref_content <- parser.do(parse_reference(Entity))
      let text_node = Text(content: ref_content)
      parser.return([text_elem, option.Some(text_node)] |> option.values())
    }
    _ -> parser.fail("Unexpected delimiter in content")
  }
}

fn fix_text_whitespace(text: String) -> String {
  let assert Ok(reg) = regexp.from_string("\n\\s*")
  reg |> regexp.replace(text, " ")
}

fn merge_text_nodes(children: List(XmlNode)) -> List(XmlNode) {
  case children {
    [] -> []
    [_] -> children
    [first, ..rest] -> do_merge_text_nodes(rest, [first])
  }
}

fn do_merge_text_nodes(
  remaining: List(XmlNode),
  acc: List(XmlNode),
) -> List(XmlNode) {
  case remaining, acc {
    [], _ -> list.reverse(acc)
    [Text(t1), ..rest], [Text(t2), ..acc_rest] -> {
      let merged_text = Text(content: t2 <> t1)
      do_merge_text_nodes(rest, [merged_text, ..acc_rest])
    }
    [next, ..rest], _ -> do_merge_text_nodes(rest, [next, ..acc])
  }
}

fn parse_closing_tag(expected_name: String) {
  use <- parser.with_mode(EndTag)
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use tagname <- parser.do(parser.expect(">"))

  case tagname == expected_name {
    True -> parser.return(Nil)
    False ->
      parser.fail(
        "Expected closing tag '</"
        <> expected_name
        <> ">' but got '</"
        <> tagname
        <> ">'",
      )
  }
}

fn parse_comment() -> parser.Parser(XmlNode, Mode) {
  use <- parser.with_mode(CommentValue)
  use comment_content <- parser.do(parser.expect(comment_end))
  parser.return(Comment(content: comment_content))
}

fn parse_cdata() -> parser.Parser(XmlNode, Mode) {
  use <- parser.with_mode(CDATA)
  use cdata_content <- parser.do(parser.expect(cdata_end))
  parser.return(Text(content: cdata_content))
}

fn echo_state(state: parser.State(m)) {
  io.println("State: " <> string.inspect(state) <> "\n")
}

pub fn get_nodes(root: XmlNode, path: List(String)) -> List(XmlNode) {
  case path, root {
    [name, ..rest], Element(n, _, _) if n == name -> do_get_nodes(rest, [root])
    _, _ -> []
  }
}

fn do_get_nodes(path: List(String), nodes: List(XmlNode)) -> List(XmlNode) {
  case path {
    [] -> nodes
    ["*", ..rest] -> {
      let children =
        nodes
        |> list.flat_map(fn(node) {
          case node {
            Element(_, _, children) -> children
            _ -> []
          }
        })
      do_get_nodes(rest, children)
    }
    [name, ..rest] -> {
      let children =
        nodes
        |> list.flat_map(fn(node) {
          case node {
            Element(_, _, children) -> {
              children
              |> list.filter_map(fn(child) {
                case child {
                  Element(n, _, _) if n == name -> Ok(child)
                  _ -> Error(Nil)
                }
              })
            }
            _ -> []
          }
        })
      do_get_nodes(rest, children)
    }
  }
}

pub fn get_node(root: XmlNode, path: List(String)) -> Result(XmlNode, String) {
  let nodes = get_nodes(root, path)
  case nodes {
    [node, ..] -> Ok(node)
    [] -> Error("No node found at path " <> string.join(path, "/"))
  }
}

pub fn get_attribute(node: XmlNode, name: String) -> Result(String, String) {
  case node {
    Element(_, attrs, _) -> {
      attrs
      |> dict.get(name)
      |> result.replace_error("No attribute with name " <> name)
    }
    _ -> Error("Node is not an element")
  }
}

pub fn get_texts(node: XmlNode) -> List(String) {
  case node {
    Element(_, _, children) ->
      children
      |> list.filter_map(fn(child) {
        case child {
          Text(content) -> Ok(content)
          _ -> Error(Nil)
        }
      })
    _ -> []
  }
}

pub fn get_nonempty_texts(node: XmlNode) -> List(String) {
  get_texts(node)
  |> list.filter(fn(text) { string.trim(text) != "" })
}

pub fn get_comments(node: XmlNode) -> List(String) {
  case node {
    Element(_, _, children) ->
      children
      |> list.filter_map(fn(child) {
        case child {
          Comment(content) -> Ok(content)
          _ -> Error(Nil)
        }
      })
    _ -> []
  }
}
