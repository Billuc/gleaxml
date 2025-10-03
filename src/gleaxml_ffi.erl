
-module(gleaxml_ffi).
-export([
  parse/1
]).
-include_lib("xmerl/include/xmerl.hrl").

parse(XmlString) when is_binary(XmlString) ->
    parse(binary_to_list(XmlString));
parse(XmlString) when is_list(XmlString) ->
    case do_parse(XmlString) of
        {error, Reason} ->
            {error, Reason};
        {Xml, _Rest} -> to_xml_document(Xml);
        Other -> 
            {error, Other}
    end.

do_parse(XmlString) when is_list(XmlString) ->
    try xmerl_scan:string(XmlString)
    catch
        _:Reason -> {error, Reason}
    end.


to_xml_document(Xml) ->
    case is_node(Xml) of
        false -> {error, list_to_binary("unsupported_node")};
        true -> {ok, #{
                  atom_to_binary(version) => list_to_binary("1.0"), 
                  atom_to_binary(encoding) => list_to_binary("utf8"), 
                  atom_to_binary(standalone) => true, 
                  list_to_binary("root_element") => to_node(Xml)
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
            #{atom_to_binary(type) => atom_to_binary(element), list_to_binary("tag_name") => Tag, atom_to_binary(attributes) => AttrMap, atom_to_binary(children) => ChildNodes};
        #xmlText{value = Content} ->
            #{atom_to_binary(type) => atom_to_binary(text), atom_to_binary(content) => list_to_binary(Content)};
        #xmlComment{value = Content} ->
            #{atom_to_binary(type) => atom_to_binary(comment), atom_to_binary(content) => list_to_binary(Content)};
        _ ->
            undefined
    end.

is_node(#xmlElement{}) -> true;
is_node(#xmlText{}) -> true;
is_node(#xmlComment{}) -> true;
is_node(_) -> false.
