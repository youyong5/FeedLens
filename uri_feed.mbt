///|
fn uri_source_valid(source_url : String) -> Bool {
  match uri_parts(source_url) {
    Some(parts) =>
      match (parts.scheme, parts.authority, parts.fragment) {
        (Some(scheme), Some(authority), None) =>
          (scheme.to_lower() == "http" || scheme.to_lower() == "https") &&
          !authority.is_empty()
        _ => false
      }
    None => false
  }
}

///|
fn uri_absolute(reference : String) -> String? {
  match uri_parts(reference) {
    Some(parts) if uri_valid_absolute(parts) =>
      Some(
        uri_build({
          scheme: parts.scheme,
          authority: parts.authority,
          path: uri_remove_dot_segments(parts.path),
          query: parts.query,
          fragment: parts.fragment,
        }),
      )
    _ => None
  }
}

///|
fn uri_at(
  base : String?,
  raw : String,
  field : String,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> String {
  let resolved = match base {
    Some(base) => uri_resolve(base, raw)
    None => uri_absolute(raw)
  }
  match resolved {
    Some(value) => value
    None => {
      diagnostics.push({ kind: UnresolvedUri(field), line, column, })
      raw
    }
  }
}

///|
fn uri_with_attachment_url(attachment : Attachment, url : String) -> Attachment {
  {
    source: attachment.source,
    url,
    media_type: attachment.media_type,
    size_in_bytes: attachment.size_in_bytes,
    title: attachment.title,
    duration_in_seconds: attachment.duration_in_seconds,
  }
}

///|
fn uri_with_entry_urls(
  entry : Entry,
  link : String?,
  attachments : Array[Attachment],
) -> Entry {
  {
    identifier: entry.identifier,
    title: entry.title,
    title_kind: entry.title_kind,
    link,
    description: entry.description,
    description_kind: entry.description_kind,
    content: entry.content,
    content_kind: entry.content_kind,
    authors: entry.authors,
    categories: entry.categories,
    attachments,
    published_at: entry.published_at,
    updated_at: entry.updated_at,
  }
}

///|
fn uri_with_feed_urls(
  feed : Feed,
  link : String?,
  entries : Array[Entry],
) -> Feed {
  {
    format: feed.format,
    identifier: feed.identifier,
    title: feed.title,
    title_kind: feed.title_kind,
    link,
    description: feed.description,
    description_kind: feed.description_kind,
    updated_at: feed.updated_at,
    authors: feed.authors,
    categories: feed.categories,
    entries,
    diagnostics: feed.diagnostics,
  }
}

///|
fn xml_base_attribute(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == "base" &&
      attribute.name.namespace_uri ==
      Some("http://www.w3.org/XML/1998/namespace") {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn xml_effective_base(
  element : @xml.NamespaceElement,
  parent_base : String?,
  format : FeedFormat,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> String? {
  if format != Atom1 {
    return parent_base
  }
  match xml_base_attribute(element) {
    None => parent_base
    Some(reference) => {
      let resolved = match parent_base {
        Some(base) => uri_resolve(base, reference)
        None => uri_absolute(reference)
      }
      if resolved is None {
        diagnostics.push({ kind: UnresolvedUri("atom xml:base"), line, column, })
      }
      resolved
    }
  }
}

///|
fn rss_valid_enclosure(element : @xml.NamespaceElement) -> Bool {
  let url = attribute_value(element, "url")
  let media_type = attribute_value(element, "type")
  let length = attribute_value(element, "length")
  match (url, media_type, length) {
    (Some(url), Some(media_type), Some(length)) =>
      !url.trim().is_empty() &&
      !media_type.trim().is_empty() &&
      attachment_size(length) is Some(_)
    _ => false
  }
}

///|
priv struct UriXmlState {
  format : FeedFormat
  source_url : String
  diagnostics : Array[Diagnostic]
  mut feed_link : String?
  links : Array[String?]
  attachments : Array[Array[Attachment]]
  entry_link_locations : Array[(Int32, Int32)?]
  mut feed_link_location : (Int32, Int32)?
  mut channel_depth : Int32
  mut entry_index : Int32
  mut entry_depth : Int32
  mut entry_open : Bool
  mut feed_alternate_seen : Bool
  mut entry_alternate_seen : Bool
  mut attachment_index : Int32
}

///|
fn UriXmlState::new(feed : Feed, source_url : String) -> UriXmlState {
  let links : Array[String?] = []
  let attachments : Array[Array[Attachment]] = []
  let locations : Array[(Int32, Int32)?] = []
  for entry in feed.entries {
    links.push(entry.link)
    let copied : Array[Attachment] = []
    for attachment in entry.attachments {
      copied.push(attachment)
    }
    attachments.push(copied)
    locations.push(None)
  }
  {
    format: feed.format,
    source_url,
    diagnostics: feed.diagnostics,
    feed_link: feed.link,
    links,
    attachments,
    entry_link_locations: locations,
    feed_link_location: None,
    channel_depth: 0,
    entry_index: -1,
    entry_depth: 0,
    entry_open: false,
    feed_alternate_seen: false,
    entry_alternate_seen: false,
    attachment_index: 0,
  }
}

///|
fn UriXmlState::resolve_attachment(
  self : UriXmlState,
  raw : String,
  base : String?,
  field : String,
  line : Int32,
  column : Int32,
) -> Unit {
  if self.entry_index < 0 || self.entry_index >= self.attachments.length() {
    return
  }
  let entries_attachments = self.attachments[self.entry_index]
  if self.attachment_index >= entries_attachments.length() ||
    entries_attachments[self.attachment_index].url != raw {
    return
  }
  let resolved = uri_at(base, raw, field, line, column, self.diagnostics)
  entries_attachments[self.attachment_index] = uri_with_attachment_url(
    entries_attachments[self.attachment_index],
    resolved,
  )
  self.attachment_index = self.attachment_index + 1
}

///|
fn UriXmlState::on_element(
  self : UriXmlState,
  element : @xml.NamespaceElement,
  depth : Int32,
  base : String?,
  line : Int32,
  column : Int32,
  is_empty : Bool,
) -> Unit {
  if self.format == Rss2 {
    if depth == 1 && is_rss_name(element.name, "channel") {
      self.channel_depth = depth + 1
    } else if self.channel_depth > 0 &&
      depth == self.channel_depth &&
      is_rss_name(element.name, "item") {
      self.entry_index = self.entry_index + 1
      self.entry_depth = depth + 1
      self.entry_open = !is_empty
      self.attachment_index = 0
    } else if self.entry_open &&
      depth == self.entry_depth &&
      is_rss_name(element.name, "link") {
      self.entry_link_locations[self.entry_index] = Some((line, column))
    } else if !self.entry_open &&
      depth == self.channel_depth &&
      is_rss_name(element.name, "link") {
      self.feed_link_location = Some((line, column))
    } else if self.entry_open &&
      depth == self.entry_depth &&
      is_rss_name(element.name, "enclosure") &&
      rss_valid_enclosure(element) {
      match attribute_value(element, "url") {
        Some(url) =>
          self.resolve_attachment(
            url,
            base,
            "rss item " +
            self.entry_index.to_string() +
            " enclosure " +
            self.attachment_index.to_string(),
            line,
            column,
          )
        None => ()
      }
    }
    return
  }
  if depth == 1 && is_atom_name(element.name, "entry") {
    self.entry_index = self.entry_index + 1
    self.entry_depth = depth + 1
    self.entry_open = !is_empty
    self.entry_alternate_seen = false
    self.attachment_index = 0
  } else if !self.entry_open && depth == 1 && is_atom_name(element.name, "link") {
    if !self.feed_alternate_seen {
      match atom_alternate_link(element) {
        Some(href) => {
          self.feed_alternate_seen = true
          self.feed_link = Some(
            uri_at(
              base,
              href,
              "atom feed alternate link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
  } else if self.entry_open &&
    depth == self.entry_depth &&
    is_atom_name(element.name, "link") {
    if !self.entry_alternate_seen {
      match atom_alternate_link(element) {
        Some(href) => {
          self.entry_alternate_seen = true
          self.links[self.entry_index] = Some(
            uri_at(
              base,
              href,
              "atom entry " + self.entry_index.to_string() + " alternate link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
    if atom_attribute_value(element, "rel") == Some("enclosure") {
      match atom_non_blank_attribute(element, "href") {
        Some(href) =>
          self.resolve_attachment(
            href,
            base,
            "atom entry " +
            self.entry_index.to_string() +
            " enclosure " +
            self.attachment_index.to_string(),
            line,
            column,
          )
        None => ()
      }
    }
  }
}

///|
fn UriXmlState::finish(self : UriXmlState, feed : Feed) -> Feed {
  if self.format == Rss2 {
    match self.feed_link {
      Some(link) => {
        let (line, column) = self.feed_link_location.unwrap_or((1, 1))
        self.feed_link = Some(
          uri_at(
            Some(self.source_url),
            link,
            "rss channel link",
            line,
            column,
            self.diagnostics,
          ),
        )
      }
      None => ()
    }
    for index = 0; index < self.links.length(); index = index + 1 {
      match self.links[index] {
        Some(link) => {
          let (line, column) = self.entry_link_locations[index].unwrap_or(
            (1, 1),
          )
          self.links[index] = Some(
            uri_at(
              Some(self.source_url),
              link,
              "rss item " + index.to_string() + " link",
              line,
              column,
              self.diagnostics,
            ),
          )
        }
        None => ()
      }
    }
  }
  let entries : Array[Entry] = []
  for index = 0; index < feed.entries.length(); index = index + 1 {
    entries.push(
      uri_with_entry_urls(
        feed.entries[index],
        self.links[index],
        self.attachments[index],
      ),
    )
  }
  uri_with_feed_urls(feed, self.feed_link, entries)
}

///|
fn resolve_xml_feed(
  input : String,
  feed : Feed,
  source_url : String,
) -> Result[Feed, ParseError] {
  let reader = @xml.NamespaceReader::from_string(input)
  let state = UriXmlState::new(feed, source_url)
  let bases : Array[String?] = []
  let mut depth = 0
  try {
    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) => {
          let parent_base = if bases.is_empty() {
            Some(source_url)
          } else {
            bases[bases.length() - 1]
          }
          let base = xml_effective_base(
            element,
            parent_base,
            feed.format,
            event.span.start.line,
            event.span.start.column,
            state.diagnostics,
          )
          state.on_element(
            element,
            depth,
            base,
            event.span.start.line,
            event.span.start.column,
            false,
          )
          bases.push(base)
          depth = depth + 1
        }
        @xml.Empty(element) => {
          let parent_base = if bases.is_empty() {
            Some(source_url)
          } else {
            bases[bases.length() - 1]
          }
          let base = xml_effective_base(
            element,
            parent_base,
            feed.format,
            event.span.start.line,
            event.span.start.column,
            state.diagnostics,
          )
          state.on_element(
            element,
            depth,
            base,
            event.span.start.line,
            event.span.start.column,
            true,
          )
        }
        @xml.End(name) => {
          if state.entry_open &&
            depth == state.entry_depth &&
            (
              (state.format == Rss2 && is_rss_name(name, "item")) ||
              (state.format == Atom1 && is_atom_name(name, "entry"))
            ) {
            state.entry_open = false
          }
          depth = depth - 1
          ignore(bases.pop())
        }
        @xml.Eof => return Ok(state.finish(feed))
        _ => ()
      }
    }
    abort("unreachable")
  } catch {
    @xml.At(error~, span~) =>
      Err(InvalidXml(error.to_string(), span.start.line, span.start.column))
  }
}

///|
fn resolve_json_feed(feed : Feed, source_url : String) -> Feed {
  let diagnostics = feed.diagnostics
  let link = match feed.link {
    Some(raw) =>
      Some(
        uri_at(
          Some(source_url),
          raw,
          "json feed home_page_url",
          1,
          1,
          diagnostics,
        ),
      )
    None => None
  }
  let entries : Array[Entry] = []
  for index = 0; index < feed.entries.length(); index = index + 1 {
    let entry = feed.entries[index]
    let entry_link = match entry.link {
      Some(raw) =>
        Some(
          uri_at(
            Some(source_url),
            raw,
            "json feed item " + index.to_string() + " url",
            1,
            1,
            diagnostics,
          ),
        )
      None => None
    }
    let attachments : Array[Attachment] = []
    for attachment_index = 0
        attachment_index < entry.attachments.length()
        attachment_index = attachment_index + 1 {
      let attachment = entry.attachments[attachment_index]
      let url = uri_at(
        Some(source_url),
        attachment.url,
        "json feed item " +
        index.to_string() +
        " attachment " +
        attachment_index.to_string(),
        1,
        1,
        diagnostics,
      )
      attachments.push(uri_with_attachment_url(attachment, url))
    }
    entries.push(uri_with_entry_urls(entry, entry_link, attachments))
  }
  uri_with_feed_urls(feed, link, entries)
}

///|
/// Parse a document and resolve only feed/entry alternate links and attachment
/// URLs against an explicit HTTP(S) source URL. Atom `xml:base` is inherited
/// by nested elements. Identifiers and HTML content are never rewritten.
/// `parse(String)` remains the raw-reference entry point.
pub fn parse_with_source(
  input : String,
  source_url : String,
) -> Result[Feed, ParseError] {
  if !uri_source_valid(source_url) {
    return Err(InvalidSourceUrl(source_url))
  }
  match parse(input) {
    Err(error) => Err(error)
    Ok(feed) =>
      match feed.format {
        JsonFeed1 => Ok(resolve_json_feed(feed, source_url))
        Rss2 | Atom1 => resolve_xml_feed(input, feed, source_url)
      }
  }
}
