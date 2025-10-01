import { Ok, Error, List } from "./gleam.mjs";

export function newDomParser() {
  return new DOMParser();
}

export function parseFromString(domParser, string) {
  const document = domParser.parseFromString(string, "application/xml");
  const errorNode = document.querySelector("parsererror");

  if (errorNode) {
    return Error(errorNode.textContent);
  }
  return Ok(document);
}

export function getRootElement(document) {
  return document.documentElement;
}

export function getChildren(element) {
  const children = Array.from(element.children);
  return List.fromArray(children);
}

export function getTagName(element) {
  return element.tagName;
}

export function getAttributes(element) {
  const attributeKeyValuePairs = Array.from(element.attributes).map((attr) => [
    attr.name,
    attr.value,
  ]);
  return List.fromArray(attributeKeyValuePairs);
}
