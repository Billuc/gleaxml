import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string

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
  use doc <- result.try(parse_document(input))
  use xmldoc <- result.try(decode_document(doc))
  Ok(XmlDocument(..xmldoc, root_element: fix_text(xmldoc.root_element)))
}

@external(erlang, "gleaxml_ffi", "parse")
@external(javascript, "./gleaxml_ffi.mjs", "parse")
fn parse_document(input: String) -> Result(dynamic.Dynamic, String)

fn decode_document(doc: dynamic.Dynamic) -> Result(XmlDocument, String) {
  decode.run(doc, {
    use version <- decode.field("version", decode.string)
    use encoding <- decode.field("encoding", decode.string)
    use standalone <- decode.field("standalone", decode.bool)
    use root_element <- decode.field("root_element", decode_xml_node())

    decode.success(XmlDocument(version, encoding, standalone, root_element))
  })
  |> result.map_error(fn(errors) {
    errors
    |> list.map(fn(e) {
      "Expected "
      <> e.expected
      <> " at "
      <> string.join(e.path, "/")
      <> ", got "
      <> e.found
    })
    |> string.join("\n")
  })
}

fn decode_xml_node() -> decode.Decoder(XmlNode) {
  use type_ <- decode.field("type", decode.string)

  case type_ {
    "element" -> {
      use name <- decode.field("tag_name", decode.string)
      use attrs <- decode.field(
        "attributes",
        decode.dict(decode.string, decode.string),
      )
      use children <- decode.field("children", decode.list(decode_xml_node()))
      decode.success(Element(name: name, attrs: attrs, children: children))
    }
    "text" -> decode.at(["content"], decode.string) |> decode.map(Text)
    "comment" -> decode.at(["content"], decode.string) |> decode.map(Comment)
    _ -> decode.failure(Comment(""), "Unknown node type: " <> type_)
  }
}

fn fix_text(node: XmlNode) -> XmlNode {
  case node {
    Comment(_content) -> node
    Element(name:, attrs:, children:) ->
      Element(
        name: name,
        attrs: attrs,
        children: children |> list.map(fix_text),
      )
    Text(content:) -> Text(content: fix_text_whitespace(content))
  }
}

fn fix_text_whitespace(text: String) -> String {
  let assert Ok(reg) = regexp.from_string("\n\\s*")
  reg
  |> regexp.replace(text, " ")
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
