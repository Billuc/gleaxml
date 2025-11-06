import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import gleamy/bench
import gleaxml/ffi/gleaxml as gleaxml_ffi
import gleaxml/nibble/gleaxml as gleaxml_nibble
import gleaxml/nibble/parser as gleaxml_nibble_parser
import gleaxml/splitter/gleaxml as gleaxml_splitter
import simplifile

pub fn main() {
  let assert Ok(rss_xml) = simplifile.read("./phys.org.xml")
  let assert Ok(xml_20mb) = simplifile.read("./nasa.xml")

  bench.run(
    [
      bench.Input(
        "Small XML",
        "<root><child attr=\"value\">Text</child><!-- Comment --></root>",
      ),
      bench.Input("RSS XML", rss_xml),
    ],
    [
      bench.Function("Nibble Xml Parser", nibble_parse),
      bench.Function("Splitter Xml Parser", splitter_parse),
      bench.Function("FFI Xml Parser", ffi_parse),
    ],
    [],
  )
  |> bench.table([
    bench.IPS,
    bench.Mean,
    bench.SD,
    bench.Min,
    bench.Max,
    bench.P(99),
  ])
  |> io.println()

  io.println(
    "Not benching Nibble Xml Parser on 20MB XML due to very long execution time and high memory usage.",
  )
  bench.run(
    [bench.Input("20MB XML", xml_20mb)],
    [
      bench.Function("Splitter Xml Parser", splitter_parse),
      bench.Function("FFI Xml Parser", ffi_parse),
    ],
    [bench.Duration(30_000)],
  )
  |> bench.table([bench.IPS, bench.Min, bench.Max, bench.Mean, bench.P(99)])
  |> io.println()
}

type XmlDocument {
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

fn nibble_parse(input: String) -> Result(XmlDocument, String) {
  use doc <- result.try(gleaxml_nibble.parse(input))

  let gleaxml_nibble_parser.XmlDocument(
    version,
    encoding,
    standalone,
    root_element,
  ) = doc

  Ok(XmlDocument(version, encoding, standalone, from_nibble_node(root_element)))
}

fn from_nibble_node(node: gleaxml_nibble_parser.XmlNode) -> XmlNode {
  case node {
    gleaxml_nibble_parser.Element(name, attrs, children) ->
      Element(name, attrs, children |> list.map(from_nibble_node))
    gleaxml_nibble_parser.Text(content) -> Text(content)
    gleaxml_nibble_parser.Comment(content) -> Comment(content)
  }
}

fn splitter_parse(input: String) -> Result(XmlDocument, String) {
  use doc <- result.try(gleaxml_splitter.parse(input))

  let gleaxml_splitter.XmlDocument(version, encoding, standalone, root_element) =
    doc

  Ok(XmlDocument(
    version,
    encoding,
    standalone,
    from_splitter_node(root_element),
  ))
}

fn from_splitter_node(node: gleaxml_splitter.XmlNode) -> XmlNode {
  case node {
    gleaxml_splitter.Element(name, attrs, children) ->
      Element(name, attrs, children |> list.map(from_splitter_node))
    gleaxml_splitter.Text(content) -> Text(content)
    gleaxml_splitter.Comment(content) -> Comment(content)
  }
}

fn ffi_parse(input: String) -> Result(XmlDocument, String) {
  use doc <- result.try(gleaxml_ffi.parse(input))

  let gleaxml_ffi.XmlDocument(version, encoding, standalone, root_element) = doc

  Ok(XmlDocument(version, encoding, standalone, from_ffi_node(root_element)))
}

fn from_ffi_node(node: gleaxml_ffi.XmlNode) -> XmlNode {
  case node {
    gleaxml_ffi.Element(name, attrs, children) ->
      Element(name, attrs, children |> list.map(from_ffi_node))
    gleaxml_ffi.Text(content) -> Text(content)
    gleaxml_ffi.Comment(content) -> Comment(content)
  }
}
