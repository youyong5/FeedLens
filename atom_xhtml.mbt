///|
fn xhtml_namespace() -> String {
  "http://www.w3.org/1999/xhtml"
}

///|
fn xhtml_xml_namespace() -> String {
  "http://www.w3.org/XML/1998/namespace"
}

///|
fn xhtml_copy_references(references : Array[String]) -> Array[String] {
  let copy : Array[String] = []
  for reference in references {
    copy.push(reference)
  }
  copy
}

///|
priv struct AtomXhtmlCapture {
  mut valid : Bool
  mut div_seen : Bool
  mut div_open : Bool
  mut plain_text : String
  mut markup : String
  mut language : String?
  base_references : Array[String]
}

///|
fn AtomXhtmlCapture::new(
  language : String?,
  base_references : Array[String],
) -> AtomXhtmlCapture {
  {
    valid: true,
    div_seen: false,
    div_open: false,
    plain_text: "",
    markup: "",
    language,
    base_references: xhtml_copy_references(base_references),
  }
}

///|
fn xhtml_other_namespace(uri : String, namespaces : Array[String]) -> Unit {
  if uri == xhtml_namespace() || uri == xhtml_xml_namespace() {
    return
  }
  for existing in namespaces {
    if existing == uri {
      return
    }
  }
  namespaces.push(uri)
}

///|
fn xhtml_name(name : @xml.XmlName, namespaces : Array[String]) -> String {
  match name.namespace_uri {
    None => name.local_name
    Some(uri) if uri == xhtml_namespace() => "h:" + name.local_name
    Some(uri) if uri == xhtml_xml_namespace() => "xml:" + name.local_name
    Some(uri) => {
      for index = 0; index < namespaces.length(); index = index + 1 {
        if namespaces[index] == uri {
          return "n" + index.to_string() + ":" + name.local_name
        }
      }
      name.local_name
    }
  }
}

///|
fn xhtml_start_tag(element : @xml.NamespaceElement, empty : Bool) -> String {
  let namespaces : Array[String] = []
  match element.name.namespace_uri {
    Some(uri) => xhtml_other_namespace(uri, namespaces)
    None => ()
  }
  for attribute in element.attributes {
    match attribute.name.namespace_uri {
      Some(uri) => xhtml_other_namespace(uri, namespaces)
      None => ()
    }
  }
  let mut tag = "<" +
    xhtml_name(element.name, namespaces) +
    " xmlns:h=\"" +
    xhtml_namespace() +
    "\""
  for index = 0; index < namespaces.length(); index = index + 1 {
    tag = tag +
      " xmlns:n" +
      index.to_string() +
      "=\"" +
      @xml.escape(namespaces[index]) +
      "\""
  }
  for attribute in element.attributes {
    tag = tag +
      " " +
      xhtml_name(attribute.name, namespaces) +
      "=\"" +
      @xml.escape(attribute.value) +
      "\""
  }
  tag + (if empty { "/>" } else { ">" })
}

///|
fn xhtml_end_tag(name : @xml.XmlName) -> String {
  let namespaces : Array[String] = []
  match name.namespace_uri {
    Some(uri) => xhtml_other_namespace(uri, namespaces)
    None => ()
  }
  "</" + xhtml_name(name, namespaces) + ">"
}

///|
fn AtomXhtmlCapture::node(
  self : AtomXhtmlCapture,
  element : @xml.NamespaceElement,
  is_root : Bool,
  empty : Bool,
) -> Unit {
  if is_root {
    if self.div_seen ||
      element.name.local_name != "div" ||
      element.name.namespace_uri != Some(xhtml_namespace()) {
      self.valid = false
      return
    }
    self.div_seen = true
    self.div_open = !empty
    match xml_language_attribute(element) {
      Some(value) => self.language = non_blank_text(value)
      None => ()
    }
    match xml_base_attribute(element) {
      Some(value) => self.base_references.push(value)
      None => ()
    }
  } else if self.div_open {
    self.markup = self.markup + xhtml_start_tag(element, empty)
  } else {
    self.valid = false
  }
}

///|
fn AtomXhtmlCapture::text(
  self : AtomXhtmlCapture,
  value : String,
  inside_div : Bool,
) -> Unit {
  if inside_div && self.div_open {
    self.plain_text = self.plain_text + value
    self.markup = self.markup + @xml.escape(value)
  } else if !value.trim().is_empty() {
    self.valid = false
  }
}

///|
fn AtomXhtmlCapture::comment(self : AtomXhtmlCapture, value : String) -> Unit {
  if self.div_open {
    self.markup = self.markup + "<!--" + value + "-->"
  }
}

///|
fn AtomXhtmlCapture::processing_instruction(
  self : AtomXhtmlCapture,
  target : String,
  data : String,
) -> Unit {
  if self.div_open {
    self.markup = self.markup +
      "<?" +
      target +
      (if data.is_empty() { "" } else { " " + data }) +
      "?>"
  }
}

///|
fn AtomXhtmlCapture::end(
  self : AtomXhtmlCapture,
  name : @xml.XmlName,
  is_root : Bool,
) -> Unit {
  if is_root {
    self.div_open = false
  } else if self.div_open {
    self.markup = self.markup + xhtml_end_tag(name)
  }
}

///|
fn AtomXhtmlCapture::fragment(self : AtomXhtmlCapture) -> XhtmlFragment? {
  if !self.valid || !self.div_seen || self.div_open {
    return None
  }
  Some({
    markup: self.markup,
    language: self.language,
    base_references: self.base_references,
  })
}
