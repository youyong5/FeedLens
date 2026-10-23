///|
/// Classify Atom content's declared type without conflating the Atom `html`
/// token with the distinct MIME type `text/html`.
fn atom_content_mode(declared : String?) -> String {
  match declared {
    None | Some("text") => "text"
    Some("html") => "html"
    Some("xhtml") => "xhtml"
    Some(value) => {
      guard atom_mime_essence(value) is Some(essence) else { return "invalid" }
      match essence.split_once("/") {
        Some((major, minor)) if atom_mime_token(major.to_owned()) &&
          atom_mime_token(minor.to_owned()) &&
          major != "multipart" &&
          major != "message" =>
          if essence.has_suffix("+xml") || essence.has_suffix("/xml") {
            "xml"
          } else if essence.has_prefix("text/") {
            "text-mime"
          } else {
            "binary"
          }
        _ => "invalid"
      }
    }
  }
}

///|
/// Validate the MIME type and its common parameter forms before dispatching
/// on the essence. Keep the original declaration on the public Atom body.
fn atom_mime_essence(value : String) -> String? {
  let (head, tail) = match value.split_once(";") {
    Some((head, tail)) => (head.to_owned(), Some(tail.to_owned()))
    None => (value, None)
  }
  let essence = head.trim().to_owned().to_lower()
  guard essence.split_once("/") is Some((major, minor)) &&
    atom_mime_token(major.to_owned()) &&
    atom_mime_token(minor.to_owned()) else {
    return None
  }
  guard tail is Some(parameters) else { return Some(essence) }
  let chars = parameters.to_array()
  let mut index = 0
  while index < chars.length() {
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    let start = index
    while index < chars.length() && atom_mime_token_char(chars[index]) {
      index = index + 1
    }
    if index == start {
      return None
    }
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index == chars.length() || chars[index] != '=' {
      return None
    }
    index = index + 1
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index < chars.length() && chars[index] == '"' {
      index = index + 1
      let mut closed = false
      while index < chars.length() {
        if chars[index] == '"' {
          index = index + 1
          closed = true
          break
        }
        if chars[index] == '\\' {
          index = index + 1
          if index == chars.length() ||
            chars[index].to_int() < 32 ||
            chars[index].to_int() > 126 {
            return None
          }
        } else if chars[index].to_int() < 32 || chars[index].to_int() > 126 {
          return None
        }
        index = index + 1
      }
      if !closed {
        return None
      }
    } else {
      let start = index
      while index < chars.length() && atom_mime_token_char(chars[index]) {
        index = index + 1
      }
      if index == start {
        return None
      }
    }
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index == chars.length() {
      return Some(essence)
    }
    if chars[index] != ';' {
      return None
    }
    index = index + 1
  }
  None // A trailing semicolon has no parameter.
}

///|
fn atom_mime_token(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for c in value.to_array() {
    if !atom_mime_token_char(c) {
      return false
    }
  }
  true
}

///|
fn atom_mime_token_char(c : Char) -> Bool {
  match c {
    'a'..<='z'
    | 'A'..<='Z'
    | '0'..<='9'
    | '!'
    | '#'
    | '$'
    | '%'
    | '&'
    | '\''
    | '*'
    | '+'
    | '-'
    | '.'
    | '^'
    | '_'
    | '`'
    | '|'
    | '~' => true
    _ => false
  }
}

///|
fn atom_content_media_type(declared : String?) -> String {
  match declared {
    Some(value) if value != "text" => value
    _ => "text/plain"
  }
}

///|
fn atom_base_from_references(references : Array[String]) -> String? {
  let mut base : String? = None
  for reference in references {
    base = match base {
      Some(parent) => uri_resolve(parent, reference)
      None => uri_absolute(reference)
    }
  }
  base
}

///|
fn atom_external_content(
  element : @xml.NamespaceElement,
  base_references : Array[String],
) -> AtomExternalContent? {
  guard atom_attribute_value(element, "src") is Some(src) else { return None }
  guard !src.trim().is_empty() else { return None }
  let references = xhtml_copy_references(base_references)
  match xml_base_attribute(element) {
    Some(reference) => references.push(reference)
    None => ()
  }
  Some({
    src,
    url: src,
    media_type: atom_attribute_value(element, "type"),
    base_uri: atom_base_from_references(references),
  })
}

///|
/// The same deterministic XML serializer used for XHTML is applied to all
/// XML media bodies, but there is deliberately no XHTML div removal.
priv struct AtomXmlCapture {
  mut markup : String
  language : String?
  base_references : Array[String]
}

///|
fn AtomXmlCapture::new(
  language : String?,
  base_references : Array[String],
) -> AtomXmlCapture {
  { markup: "", language, base_references, }
}

///|
fn AtomXmlCapture::node(
  self : AtomXmlCapture,
  element : @xml.NamespaceElement,
  empty : Bool,
) -> Unit {
  self.markup = self.markup + xhtml_start_tag(element, empty)
}

///|
fn AtomXmlCapture::text(self : AtomXmlCapture, value : String) -> Unit {
  self.markup = self.markup + @xml.escape(value)
}

///|
fn AtomXmlCapture::end(self : AtomXmlCapture, name : @xml.XmlName) -> Unit {
  self.markup = self.markup + xhtml_end_tag(name)
}

///|
fn AtomXmlCapture::comment(self : AtomXmlCapture, value : String) -> Unit {
  self.markup = self.markup + "<!--" + value + "-->"
}

///|
fn AtomXmlCapture::processing_instruction(
  self : AtomXmlCapture,
  target : String,
  data : String,
) -> Unit {
  self.markup = self.markup +
    "<?" +
    target +
    (if data.is_empty() { "" } else { " " + data }) +
    "?>"
}

///|
fn AtomXmlCapture::fragment(self : AtomXmlCapture) -> XmlFragment {
  {
    markup: self.markup,
    language: self.language,
    base_references: self.base_references,
  }
}

///|
fn atom_decode_base64(value : String) -> Bytes? {
  // RFC 4287 permits surrounding XML whitespace and LF-separated lines.
  // Padding is required; interior spaces and tabs are not line separators.
  let trimmed = value.trim()
  let mut encoded_length = 0
  let mut previous_newline = false
  for c in trimmed.to_array() {
    match c {
      '\n' => {
        if previous_newline {
          return None
        }
        previous_newline = true
      }
      ' ' | '\t' | '\r' => return None
      _ => {
        encoded_length = encoded_length + 1
        previous_newline = false
      }
    }
  }
  if encoded_length % 4 != 0 {
    return None
  }
  Some(@base64.decode(trimmed.view(), ignore_whitespace=true)) catch {
    _ => None
  }
}
