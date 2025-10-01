import { Ok, Error, List } from "./gleam.mjs";
import { JSDOM } from "jsdom";

function newDomParser() {
  if (typeof process === "object") {
    const jsdom = new JSDOM("");
    return new jsdom.window.DOMParser();
  }
  return new DOMParser();
}

export function parse(string) {
  const domParser = newDomParser();
  const document = domParser.parseFromString(string, "application/xml");
  const errorNode = document.querySelector("parsererror");

  if (errorNode) {
    return new Error(errorNode.textContent);
  }
  return new Ok(document);
}

export function toDocument(xml) {
  return new Ok({
    version: "1.0",
    standalone: true,
    encoding: "UTF-8",
    root_element: toElement(getRootElement(xml)),
  });
}

function getRootElement(document) {
  return document.documentElement;
}

function toElement(element) {
  if (element.nodeType === 3) {
    // TEXT NODE
    return {
      content: element.textContent,
    };
  }
  if (element.nodeType === 8) {
    // COMMENT NODE
    return {
      content: element.textContent,
    };
  }
  if (element.nodeType === 1) {
    // ELEMENT NODE
    return {
      tag_name: getTagName(element),
      attributes: getAttributes(element),
      children: getChildren(element),
    };
  }

  return null;
}

function getChildren(element) {
  const children = Array.from(element.childNodes)
    .map(toElement)
    .filter((child) => child !== null);
  return List.fromArray(children);
}

function getTagName(element) {
  return element.tagName;
}

function getAttributes(element) {
  const attributeKeyValuePairs = Array.from(element.attributes).map((attr) => [
    attr.name,
    attr.value,
  ]);
  return List.fromArray(attributeKeyValuePairs);
}
