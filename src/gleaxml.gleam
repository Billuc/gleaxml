import gleam/dict
import gleam/list
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

pub type Document

pub fn parse(input: String) -> Result(XmlDocument, String) {
  use doc <- result.try(parse_document(input))
  echo doc
  use xmldoc <- result.try(to_xml_document(doc))
  Ok(XmlDocument(..xmldoc, root_element: fix_text(xmldoc.root_element)))
}

@external(erlang, "gleaxml_ffi", "parse")
@external(javascript, "./gleaxml_ffi.mjs", "parse")
fn parse_document(input: String) -> Result(Document, String)

@external(erlang, "gleaxml_ffi", "to_document")
@external(javascript, "./gleaxml_ffi.mjs", "toDocument")
fn to_xml_document(doc: Document) -> Result(XmlDocument, String)

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
  text
  |> string.replace("\n", " ")
  |> string.replace("  ", " ")
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
