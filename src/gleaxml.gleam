import gleam/bool
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import splitter

pub type Parser {
  Parser(input: String, remaining: String, splitters: Splitters, mode: Mode)
}

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
  StartTag
  EndTag
  // Content
  // Comment
  AttrValue(quote: String, parent: Mode)
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

pub type Splitters {
  Splitters(
    start_tag_splitter: splitter.Splitter,
    end_tag_splitter: splitter.Splitter,
    attr_value_splitter: splitter.Splitter,
  )
}

fn parse(parser: Parser) {
  todo
}

fn parse_start_tag(parser: Parser) {
  let parser = drop_newlines_and_whitespaces(parser)
  use tag_name, delim, parser <- expect_one_of(parser, [" ", "\r", "\n"])
  todo
}

fn parse_attributes(input: String, splitters: Splitters) {
  todo
}

fn parse_attribute(parser: Parser) {
  let parser = parser |> drop_newlines_and_whitespaces

  use attr_name, parser <- expect(parser, "=")
  use _, quote, parser <- expect_one_of(parser, ["\"", "'"])

  let parser = parser |> into(AttrValue(quote:, parent: parser.mode))

  use #(attr_value, parser) <- result.try(split_while_not(parser, quote))
  todo
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

fn drop_newlines(parser: Parser) -> Parser {
  case parser.remaining {
    "\n" <> rest -> drop_newlines(Parser(..parser, remaining: rest))
    "\r\n" <> rest -> drop_newlines(Parser(..parser, remaining: rest))
    _ -> parser
  }
}

fn drop_whitespaces(parser: Parser) -> Parser {
  case parser.remaining {
    " " <> rest -> drop_whitespaces(Parser(..parser, remaining: rest))
    _ -> parser
  }
}

fn drop_newlines_and_whitespaces(parser: Parser) -> Parser {
  case parser.remaining {
    "\n" <> rest ->
      drop_newlines_and_whitespaces(Parser(..parser, remaining: rest))
    "\r\n" <> rest ->
      drop_newlines_and_whitespaces(Parser(..parser, remaining: rest))
    " " <> rest ->
      drop_newlines_and_whitespaces(Parser(..parser, remaining: rest))
    _ -> parser
  }
}

fn expect(
  parser: Parser,
  expected_split: String,
  then: fn(String, Parser) -> Result(a, Nil),
) {
  let splitter = get_splitter(parser)
  let #(before, delim, after) = splitter.split(splitter, parser.remaining)

  case delim {
    d if d == expected_split -> then(before, Parser(..parser, remaining: after))
    _ -> Error(Nil)
  }
}

fn expect_one_of(
  parser: Parser,
  expected_splits: List(String),
  then: fn(String, String, Parser) -> Result(a, Nil),
) {
  let splitter = get_splitter(parser)
  let #(before, delim, after) = splitter.split(splitter, parser.remaining)

  use <- bool.guard(!list.contains(expected_splits, delim), Error(Nil))

  then(before, delim, Parser(..parser, remaining: after))
}

fn get_splitter(parser: Parser) -> splitter.Splitter {
  case parser.mode {
    AttrValue(quote:, parent:) -> parser.splitters.attr_value_splitter
    // CDATA -> todo
    // Comment -> todo
    // Content -> todo
    EndTag -> parser.splitters.end_tag_splitter
    // Reference(parent:) -> todo
    StartTag -> parser.splitters.start_tag_splitter
    // XmlDecl -> todo
  }
}

fn into(parser: Parser, mode: Mode) -> Parser {
  Parser(..parser, mode:)
}

fn split(parser: Parser) {
  let splitter = get_splitter(parser)
  let #(before, delim, after) = splitter.split(splitter, parser.remaining)
  #(before, delim, Parser(..parser, remaining: after))
}

fn split_while_not(parser: Parser, stopper: String) {
  do_split_while_not(parser, stopper, "")
}

fn do_split_while_not(parser: Parser, stopper: String, accumulator: String) {
  let #(before, delim, parser) = split(parser)

  case delim {
    d if d == stopper -> Ok(#(accumulator <> before, parser))
    "" -> Error(Nil)
    _ -> do_split_while_not(parser, stopper, accumulator <> before <> delim)
  }
}
