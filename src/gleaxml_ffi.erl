
-module(gleaxml_ffi).
-export([
  parse/1,
  to_document/1 
]).
-include_lib("xmerl/include/xmerl.hrl").

parse(XmlString) when is_binary(XmlString) ->
    parse(binary_to_list(XmlString));
parse(XmlString) when is_list(XmlString) ->
    case xmerl_scan:string(XmlString) of
        {error, Reason} ->
            {error, Reason};
        {Xml, _Rest} ->
            {ok, Xml};
        Other -> 
            {error, Other}
    end.


to_document(Xml) ->
    case is_node(Xml) of
        false -> {error, list_to_binary("unsupported_node")};
        true -> {ok, {
                  xml_document, 
                  list_to_binary("1.0"), 
                  list_to_binary("utf8"), 
                  true, 
                  to_node(Xml)
            }}
    end.

to_node(Xml) ->
    case Xml of
        #xmlElement{name = Name, attributes = Attrs, content = Children} ->
            Tag = atom_to_binary(Name),
            AttrMap = maps:from_list(
                [ {atom_to_binary(A#xmlAttribute.name), list_to_binary(A#xmlAttribute.value)} || A <- Attrs ]
            ),
            ChildNodes = [to_node(C) || C <- Children, is_node(C)],
            {element, Tag, AttrMap, ChildNodes};
        #xmlText{value = Content} ->
            {text, list_to_binary(Content)};
        #xmlComment{value = Content} ->
            {comment, list_to_binary(Content)};
        _ ->
            undefined
    end.

is_node(#xmlElement{}) -> true;
is_node(#xmlText{}) -> true;
is_node(#xmlComment{}) -> true;
is_node(_) -> false.
