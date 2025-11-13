import gleam/dict
import gleam/int
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

  case parse_xml_document(splitters, state) {
    Ok(ParserReturn(doc, _)) -> Ok(doc)
    Error(err) -> Error(print_error(err))
  }
}

fn print_error(error: XmlParseError) -> String {
  case error {
    ParserError(e) -> "Parser error: " <> parser2.print_error(e)
    ClosingTagMismatch(expected, found) ->
      "Closing tag mismatch: expected </"
      <> expected
      <> "> but found </"
      <> found
      <> ">"
    InvalidReference(reference) -> "Invalid reference: " <> reference
    InvalidStartTag -> "Invalid start tag"
    NoVersion -> "XML declaration missing version attribute"
    InvalidStandaloneValue(value) -> "Invalid standalone value: " <> value
  }
}

type XmlParseError {
  ParserError(error: parser2.ParserError)
  ClosingTagMismatch(expected: String, found: String)
  InvalidReference(reference: String)
  InvalidStartTag
  NoVersion
  InvalidStandaloneValue(value: String)
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
  STCarriageReturn
  STNewLine
  STSpace
}

fn start_tag_splitter() {
  parser2.splitter()
  |> parser2.add_token("/>", STSelfClosingTag)
  |> parser2.add_token(">", STGreaterThan)
  |> parser2.add_token("=", STEqualSign)
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
  XDDeclarationEnd
  XDCarriageReturn
  XDNewLine
  XDSpace
}

fn xml_decl_splitter() {
  parser2.splitter()
  |> parser2.add_token("=", XDEqual)
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

fn parse_xml_document(
  splitters: Splitters,
  state: State(RootToken),
) -> Result(ParserReturn(XmlDocument, RootToken), XmlParseError) {
  use ParserReturn(_, state) <- result.try(
    parser2.drop_tokens(state, [RSpace, RCarriageReturn, RNewLine])
    |> result.map_error(ParserError),
  )
  use ParserReturn(_, state) <- result.try(
    parser2.expect_one_of(state, [RXmlDeclStart, RLessThan])
    |> result.map_error(ParserError),
  )

  case state.delimiter {
    option.Some(RXmlDeclStart) -> {
      let state = parser2.with_splitter(state, splitters.xml_decl)
      use ParserReturn(decl, state) <- result.try(parse_xml_declaration(
        splitters,
        state,
      ))
      let state = parser2.with_splitter(state, splitters.root)
      use _ <- result.try(
        parser2.drop_tokens(state, [RSpace, RCarriageReturn, RNewLine])
        |> result.map_error(ParserError),
      )
      use ParserReturn(_, state) <- result.try(
        parser2.expect(state, RLessThan)
        |> result.map_error(ParserError),
      )
      use ParserReturn(root_element, state) <- result.try(parse_start_tag(
        splitters,
        state,
      ))
      use _ <- result.try(
        parser2.drop_tokens(state, [RSpace, RCarriageReturn, RNewLine])
        |> result.map_error(ParserError),
      )
      use _ <- result.try(
        parser2.eof(state)
        |> result.map_error(ParserError),
      )

      Ok(ParserReturn(
        XmlDocument(
          version: decl.0,
          encoding: decl.1,
          standalone: decl.2,
          root_element:,
        ),
        state,
      ))
    }
    option.Some(RLessThan) -> {
      use ParserReturn(root_element, state) <- result.try(parse_start_tag(
        splitters,
        state,
      ))
      use _ <- result.try(
        parser2.drop_tokens(state, [RSpace, RCarriageReturn, RNewLine])
        |> result.map_error(ParserError),
      )
      use _ <- result.try(
        parser2.eof(state)
        |> result.map_error(ParserError),
      )

      Ok(ParserReturn(
        XmlDocument(
          version: "1.0",
          encoding: "UTF-8",
          standalone: True,
          root_element:,
        ),
        state,
      ))
    }
    _ -> Error(ParserError(parser2.Unreachable))
  }
}

fn parse_xml_declaration(
  splitters: Splitters,
  state: State(XmlDeclToken),
) -> Result(ParserReturn(#(String, String, Bool), XmlDeclToken), XmlParseError) {
  use _ <- result.try(
    parser2.drop_tokens(state, [XDSpace, XDCarriageReturn, XDNewLine])
    |> result.map_error(ParserError),
  )
  use ParserReturn(attrs, state) <- result.try(parse_xml_decl_attributes(
    splitters,
    state,
  ))

  use version <- result.try(
    dict.get(attrs, "version")
    |> result.replace_error(NoVersion),
  )
  let encoding = case dict.get(attrs, "encoding") {
    Ok(enc) -> enc
    Error(_) -> "UTF-8"
  }
  use standalone <- result.try(case dict.get(attrs, "standalone") {
    Ok(value) -> parse_standalone(value)
    Error(_) -> Ok(True)
  })

  Ok(ParserReturn(#(version, encoding, standalone), state))
}

fn parse_standalone(value: String) -> Result(Bool, XmlParseError) {
  case value {
    "yes" -> Ok(True)
    "no" -> Ok(False)
    _ -> Error(InvalidStandaloneValue(value))
  }
}

fn parse_start_tag(
  splitters: Splitters,
  state: State(a),
) -> Result(ParserReturn(XmlNode, a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.start_tag)
  use ParserReturn(tag_name, state) <- result.try(
    parser2.any(state)
    |> result.map_error(ParserError),
  )
  let tag_name = string.trim(tag_name)

  use ParserReturn(attributes, state) <- result.try(parse_attributes(
    splitters,
    state,
  ))

  case state.delimiter {
    option.Some(STSelfClosingTag) ->
      Ok(ParserReturn(
        Element(name: tag_name, attrs: attributes, children: []),
        state,
      ))
    option.Some(STGreaterThan) -> {
      use ParserReturn(children, state) <- result.try(parse_children(
        splitters,
        state,
      ))
      use ParserReturn(_, state) <- result.try(parse_closing_tag(
        splitters,
        state,
        tag_name,
      ))
      Ok(ParserReturn(
        Element(name: tag_name, attrs: attributes, children: children),
        state,
      ))
    }
    _ -> Error(ParserError(parser2.Unreachable))
  }
}

fn parse_xml_decl_attributes(
  splitters: Splitters,
  state: State(XmlDeclToken),
) -> Result(
  ParserReturn(dict.Dict(String, String), XmlDeclToken),
  XmlParseError,
) {
  do_parse_xml_decl_attributes(splitters, state, dict.new())
}

fn do_parse_xml_decl_attributes(
  splitters: Splitters,
  state: State(XmlDeclToken),
  accumulator: dict.Dict(String, String),
) -> Result(
  ParserReturn(dict.Dict(String, String), XmlDeclToken),
  XmlParseError,
) {
  use ParserReturn(_, state) <- result.try(
    parser2.drop_tokens(state, [XDSpace, XDCarriageReturn, XDNewLine])
    |> result.map_error(ParserError),
  )
  use ParserReturn(before, state) <- result.try(
    parser2.expect_one_of(state, [XDEqual, XDDeclarationEnd])
    |> result.map_error(ParserError),
  )

  case state.delimiter, string.trim(before) {
    option.None, _ -> Error(ParserError(parser2.Unreachable))
    option.Some(XDDeclarationEnd), "" -> Ok(ParserReturn(accumulator, state))
    option.Some(XDEqual), attr_name if attr_name != "" -> {
      use ParserReturn(value, state) <- result.try(parse_attribute_value(
        splitters,
        state,
      ))
      let new_accumulator = dict.insert(accumulator, attr_name, value)
      do_parse_xml_decl_attributes(splitters, state, new_accumulator)
    }
    _, _ -> Error(InvalidStartTag)
  }
}

fn parse_attributes(
  splitters: Splitters,
  state: State(StartTagToken),
) -> Result(
  ParserReturn(dict.Dict(String, String), StartTagToken),
  XmlParseError,
) {
  do_parse_attributes(splitters, state, dict.new())
}

fn do_parse_attributes(
  splitters: Splitters,
  state: State(StartTagToken),
  accumulator: dict.Dict(String, String),
) -> Result(
  ParserReturn(dict.Dict(String, String), StartTagToken),
  XmlParseError,
) {
  use ParserReturn(_, state) <- result.try(
    parser2.drop_tokens(state, [STSpace, STCarriageReturn, STNewLine])
    |> result.map_error(ParserError),
  )
  use ParserReturn(before, state) <- result.try(
    parser2.expect_one_of(state, [STSelfClosingTag, STGreaterThan, STEqualSign])
    |> result.map_error(ParserError),
  )

  case state.delimiter, string.trim(before) {
    option.None, _ -> Error(ParserError(parser2.Unreachable))
    option.Some(STSelfClosingTag), "" | option.Some(STGreaterThan), "" ->
      Ok(ParserReturn(accumulator, state))
    option.Some(STEqualSign), attr_name if attr_name != "" -> {
      use ParserReturn(value, state) <- result.try(parse_attribute_value(
        splitters,
        state,
      ))
      let new_accumulator = dict.insert(accumulator, attr_name, value)
      do_parse_attributes(splitters, state, new_accumulator)
    }
    _, _ -> Error(InvalidStartTag)
  }
}

fn parse_attribute_value(
  splitters: Splitters,
  state: State(a),
) -> Result(ParserReturn(String, a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.attr_value)
  use ParserReturn(_, state) <- result.try(
    parser2.expect_one_of(state, [AVSingleQuote, AVDoubleQuote])
    |> result.map_error(ParserError),
  )

  case state.delimiter {
    option.None -> Error(ParserError(parser2.Unreachable))
    option.Some(quote) -> do_parse_attribute_value(splitters, state, quote, "")
  }
}

fn do_parse_attribute_value(
  splitters: Splitters,
  state: State(AttrValueToken),
  quote: AttrValueToken,
  accumulator: String,
) -> Result(ParserReturn(String, AttrValueToken), XmlParseError) {
  use ParserReturn(value, state) <- result.try(
    parser2.any(state)
    |> result.map_error(ParserError),
  )

  case state.delimiter {
    option.None -> Error(ParserError(parser2.Unreachable))
    option.Some(AVDoubleQuote) if quote == AVDoubleQuote ->
      Ok(ParserReturn(accumulator <> value, state))
    option.Some(AVSingleQuote) if quote == AVSingleQuote ->
      Ok(ParserReturn(accumulator <> value, state))
    option.Some(AVHexCharReference) -> {
      use ParserReturn(ref_content, state) <- result.try(parse_reference(
        splitters,
        state,
        CharHex,
      ))
      do_parse_attribute_value(
        splitters,
        state,
        quote,
        accumulator <> ref_content,
      )
    }
    option.Some(AVDecCharReference) -> {
      use ParserReturn(ref_content, state) <- result.try(parse_reference(
        splitters,
        state,
        CharDec,
      ))
      do_parse_attribute_value(
        splitters,
        state,
        quote,
        accumulator <> ref_content,
      )
    }
    option.Some(AVEntityReference) -> {
      use ParserReturn(ref_content, state) <- result.try(parse_reference(
        splitters,
        state,
        Entity,
      ))
      do_parse_attribute_value(
        splitters,
        state,
        quote,
        accumulator <> ref_content,
      )
    }
    _ ->
      do_parse_attribute_value(
        splitters,
        state,
        quote,
        accumulator <> value <> state.delimiter_string,
      )
  }
}

fn parse_reference(
  splitters: Splitters,
  state: State(a),
  reference_type: ReferenceType,
) -> Result(ParserReturn(String, a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.reference)
  use ParserReturn(reference_content, state) <- result.try(
    parser2.expect(state, RSemicolon)
    |> result.map_error(ParserError),
  )

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
    Ok(str_content) -> Ok(ParserReturn(str_content, state))
    Error(_) ->
      Error(
        InvalidReference(print_reference(reference_type, reference_content)),
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

fn parse_children(
  splitters: Splitters,
  state: State(a),
) -> Result(ParserReturn(List(XmlNode), a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.content)

  use ParserReturn(children, state) <- result.try(
    do_parse_children(splitters, state, []),
  )
  let children = merge_text_nodes(children)

  Ok(ParserReturn(children, state))
}

fn do_parse_children(
  splitters: Splitters,
  state: State(ContentToken),
  accumulator: List(XmlNode),
) -> Result(ParserReturn(List(XmlNode), ContentToken), XmlParseError) {
  use ParserReturn(child, state) <- result.try(parse_child(splitters, state))
  let children = list.append(accumulator, child)

  case state.delimiter {
    option.None -> Error(ParserError(parser2.Unreachable))
    option.Some(CEndTagStart) -> Ok(ParserReturn(children, state))
    _ -> do_parse_children(splitters, state, children)
  }
}

fn parse_child(
  splitters: Splitters,
  state: State(ContentToken),
) -> Result(ParserReturn(List(XmlNode), ContentToken), XmlParseError) {
  use ParserReturn(text, state) <- result.try(
    parser2.any(state) |> result.map_error(ParserError),
  )

  let text_elem = case text {
    "" -> option.None
    _ -> option.Some(Text(fix_text_whitespace(text)))
  }
  case state.delimiter {
    option.None -> Error(ParserError(parser2.Unreachable))
    option.Some(CEndTagStart) ->
      Ok(ParserReturn([text_elem] |> option.values(), state))
    option.Some(CLessThan) -> {
      use ParserReturn(child, state) <- result.try(parse_start_tag(
        splitters,
        state,
      ))
      Ok(ParserReturn([text_elem, option.Some(child)] |> option.values(), state))
    }
    option.Some(CCommentStart) -> {
      use ParserReturn(comment, state) <- result.try(parse_comment(
        splitters,
        state,
      ))
      Ok(ParserReturn(
        [text_elem, option.Some(comment)] |> option.values(),
        state,
      ))
    }
    option.Some(CCDataStart) -> {
      use ParserReturn(cdata, state) <- result.try(parse_cdata(splitters, state))
      Ok(ParserReturn([text_elem, option.Some(cdata)] |> option.values(), state))
    }
    option.Some(CHexCharReference) -> {
      use ParserReturn(ref_content, state) <- result.try(parse_reference(
        splitters,
        state,
        CharHex,
      ))
      Ok(ParserReturn(
        [text_elem, option.Some(Text(content: ref_content))]
          |> option.values(),
        state,
      ))
    }
    option.Some(CDecCharReference) -> {
      use ParserReturn(ref_content, state) <- result.try(parse_reference(
        splitters,
        state,
        CharDec,
      ))
      Ok(ParserReturn(
        [text_elem, option.Some(Text(content: ref_content))]
          |> option.values(),
        state,
      ))
    }
    option.Some(CEntityReference) -> {
      use ParserReturn(ref_content, state) <- result.try(parse_reference(
        splitters,
        state,
        Entity,
      ))
      Ok(ParserReturn(
        [text_elem, option.Some(Text(content: ref_content))]
          |> option.values(),
        state,
      ))
    }
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

fn parse_closing_tag(
  splitters: Splitters,
  state: State(a),
  expected_name: String,
) -> Result(ParserReturn(Nil, a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.end_tag)
  use ParserReturn(tagname, state) <- result.try(
    parser2.expect(state, ETGreaterThan)
    |> result.map_error(ParserError),
  )
  let tagname = string.trim(tagname)

  case tagname == expected_name {
    True -> Ok(ParserReturn(Nil, state))
    False -> Error(ClosingTagMismatch(expected_name, tagname))
  }
}

fn parse_comment(
  splitters: Splitters,
  state: State(a),
) -> Result(ParserReturn(XmlNode, a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.comment_value)
  use ParserReturn(comment_content, state) <- result.try(
    parser2.expect(state, CECommentEnd)
    |> result.map_error(ParserError),
  )
  Ok(ParserReturn(Comment(content: comment_content), state))
}

fn parse_cdata(
  splitters: Splitters,
  state: State(a),
) -> Result(ParserReturn(XmlNode, a), XmlParseError) {
  use state <- parser2.use_splitter(state, splitters.cdata)
  use ParserReturn(content, state) <- result.try(
    parser2.expect(state, CDCEnd)
    |> result.map_error(ParserError),
  )
  Ok(ParserReturn(Text(content: content), state))
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
