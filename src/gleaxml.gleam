import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import gleaxml/parser
import splitter

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

pub type Mode {
  Root
  StartTag
  EndTag
  Content
  CommentValue
  AttrValue
  CDATA
  Reference
  XmlDecl
}

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
  parser.runner(parse_xml_document(), Root)
  |> parser.register(Root, root_splitter())
  |> parser.register(StartTag, start_tag_splitter())
  |> parser.register(EndTag, end_tag_splitter())
  |> parser.register(AttrValue, attr_value_splitter())
  |> parser.register(Content, content_splitter())
  |> parser.register(CommentValue, comment_value_splitter())
  |> parser.register(CDATA, cdata_splitter())
  |> parser.register(XmlDecl, xml_decl_splitter())
  |> parser.register(Reference, reference_splitter())
  |> parser.run(input)
}

fn root_splitter() {
  splitter.new([xml_decl_start, "<", "\r", "\n", " "])
}

fn attr_value_splitter() {
  splitter.new([
    hex_char_reference,
    dec_char_reference,
    entity_reference,
    "\"",
    "'",
  ])
}

fn start_tag_splitter() {
  splitter.new(["/>", ">", "=", "\"", "'", "\r", "\n", " "])
}

fn end_tag_splitter() {
  splitter.new([">", "\r", " ", "\n"])
}

fn content_splitter() {
  splitter.new([
    "</",
    hex_char_reference,
    dec_char_reference,
    entity_reference,
    comment_start,
    cdata_start,
    "<",
  ])
}

fn comment_value_splitter() {
  splitter.new([comment_end, "--"])
}

fn cdata_splitter() {
  splitter.new([cdata_end])
}

fn xml_decl_splitter() {
  splitter.new(["=", "\"", "'", xml_decl_end, "\r", "\n", " "])
}

fn reference_splitter() {
  splitter.new([semi_colon])
}

fn parse_xml_document() -> parser.Parser(XmlDocument, Mode) {
  use _ <- parser.do(parser.drop_chars([" ", "\r", "\n"]))
  use _, delim <- parser.do_delim(parser.next_split())

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
