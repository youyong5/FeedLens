///|
fn atom_attribute_value(
  element : @xml.NamespaceElement,
  expected : String,
) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == expected &&
      attribute.name.namespace_uri is None {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn atom_alternate_link(element : @xml.NamespaceElement) -> String? {
  let rel = atom_attribute_value(element, "rel")
  let href = atom_attribute_value(element, "href")
  match rel {
    None | Some("alternate") =>
      match href {
        Some(value) if !value.trim().is_empty() => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn atom_link(
  element : @xml.NamespaceElement,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> AtomLink? {
  let relation = atom_attribute_value(element, "rel").unwrap_or("alternate")
  let href = match atom_non_blank_attribute(element, "href") {
    Some(href) => href
    None => {
      if relation != "enclosure" {
        diagnostics.push({
          kind: InvalidAtomLink("missing href"),
          line,
          column,
        })
      }
      return None
    }
  }
  let length = match atom_attribute_value(element, "length") {
    Some(raw) =>
      match attachment_size(raw) {
        Some(value) => Some(value)
        None => {
          if relation != "enclosure" {
            diagnostics.push({
              kind: InvalidAtomLink("invalid length"),
              line,
              column,
            })
          }
          None
        }
      }
    None => None
  }
  Some({
    relation,
    href,
    media_type: atom_non_blank_attribute(element, "type"),
    hreflang: atom_non_blank_attribute(element, "hreflang"),
    title: atom_non_blank_attribute(element, "title"),
    length,
  })
}

///|
fn atom_append_link(
  links : Array[AtomLink],
  element : @xml.NamespaceElement,
  owner : String,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match atom_link(element, line, column, diagnostics) {
    Some(link) => {
      if link.relation == "alternate" &&
        links.any(fn(previous) {
          previous.relation == "alternate" &&
          previous.media_type == link.media_type &&
          previous.hreflang == link.hreflang
        }) {
        diagnostics.push({
          kind: DuplicateAtomField(owner + " alternate link"),
          line,
          column,
        })
      }
      links.push(link)
    }
    None => ()
  }
}

///|
fn atom_text_kind(element : @xml.NamespaceElement) -> TextKind? {
  match atom_attribute_value(element, "type") {
    None | Some("text") => Some(Text)
    Some("html") => Some(Html)
    Some("xhtml") => Some(Xhtml)
    _ => None
  }
}

///|
fn atom_non_blank_attribute(
  element : @xml.NamespaceElement,
  expected : String,
) -> String? {
  match atom_attribute_value(element, expected) {
    Some(value) => non_blank_text(value)
    None => None
  }
}

///|
fn atom_category(element : @xml.NamespaceElement) -> Category? {
  match atom_non_blank_attribute(element, "term") {
    Some(term) =>
      match non_blank_text(term) {
        Some(term) =>
          Some({
            source: Atom1,
            term,
            domain: None,
            scheme: atom_non_blank_attribute(element, "scheme"),
            label: atom_non_blank_attribute(element, "label"),
          })
        None => None
      }
    None => None
  }
}

///|
fn copy_authors(authors : Array[Author]) -> Array[Author] {
  let copied : Array[Author] = []
  for author in authors {
    copied.push(author)
  }
  copied
}

///|
fn with_authors(entry : Entry, authors : Array[Author]) -> Entry {
  {
    identifier: entry.identifier,
    title: entry.title,
    title_kind: entry.title_kind,
    title_xhtml: entry.title_xhtml,
    link: entry.link,
    external_url: entry.external_url,
    language: entry.language,
    description: entry.description,
    description_kind: entry.description_kind,
    description_xhtml: entry.description_xhtml,
    content: entry.content,
    content_text: entry.content_text,
    content_html: entry.content_html,
    content_kind: entry.content_kind,
    content_xhtml: entry.content_xhtml,
    content_source: entry.content_source,
    content_media_type: entry.content_media_type,
    atom_body: entry.atom_body,
    atom_source: entry.atom_source,
    links: entry.links,
    comments_url: entry.comments_url,
    source_url: entry.source_url,
    source_title: entry.source_title,
    guid_is_permalink: entry.guid_is_permalink,
    rights: entry.rights,
    rights_kind: entry.rights_kind,
    rights_xhtml: entry.rights_xhtml,
    authors,
    contributors: entry.contributors,
    categories: entry.categories,
    attachments: entry.attachments,
    images: entry.images,
    published_at: entry.published_at,
    updated_at: entry.updated_at,
  }
}

///|
fn atom_location(
  field_location : (Int32, Int32)?,
  entry_line : Int32,
  entry_column : Int32,
) -> (Int32, Int32) {
  field_location.unwrap_or((entry_line, entry_column))
}

///|
fn atom_singleton(
  element : @xml.NamespaceElement,
  seen : Array[String],
  entry : Bool,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let field = element.name.local_name
  let unique = if entry {
    field
    is ("id"
    | "title"
    | "updated"
    | "published"
    | "summary"
    | "content"
    | "rights"
    | "source")
  } else {
    field
    is ("id"
    | "title"
    | "updated"
    | "subtitle"
    | "rights"
    | "generator"
    | "icon"
    | "logo")
  }
  if !unique || !is_atom_name(element.name, field) {
    return
  }
  for previous in seen {
    if previous == field {
      diagnostics.push({
        kind: DuplicateAtomField(
          if entry {
            "entry " + field
          } else {
            "feed " + field
          },
        ),
        line,
        column,
      })
      return
    }
  }
  seen.push(field)
}

///|
fn add_missing_atom_feed_diagnostics(
  id : String?,
  title : String?,
  updated : String?,
  id_location : (Int32, Int32)?,
  title_location : (Int32, Int32)?,
  updated_location : (Int32, Int32)?,
  feed_line : Int32,
  feed_column : Int32,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if id is None {
    let (line, column) = atom_location(id_location, feed_line, feed_column)
    diagnostics.push({ kind: MissingFeedField("id"), line, column, })
  }
  if title is None {
    let (line, column) = atom_location(title_location, feed_line, feed_column)
    diagnostics.push({ kind: MissingFeedField("title"), line, column, })
  }
  if updated is None {
    let (line, column) = atom_location(updated_location, feed_line, feed_column)
    diagnostics.push({ kind: MissingFeedField("updated"), line, column, })
  }
}

///|
fn add_missing_atom_entry_diagnostics(
  index : Int32,
  id : String?,
  title : String?,
  updated : String?,
  id_location : (Int32, Int32)?,
  title_location : (Int32, Int32)?,
  updated_location : (Int32, Int32)?,
  entry_line : Int32,
  entry_column : Int32,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if id is None {
    let (line, column) = atom_location(id_location, entry_line, entry_column)
    diagnostics.push({ kind: MissingEntryField(index, "id"), line, column, })
  }
  if title is None {
    let (line, column) = atom_location(title_location, entry_line, entry_column)
    diagnostics.push({ kind: MissingEntryField(index, "title"), line, column, })
  }
  if updated is None {
    let (line, column) = atom_location(
      updated_location, entry_line, entry_column,
    )
    diagnostics.push({
      kind: MissingEntryField(index, "updated"),
      line,
      column,
    })
  }
}

///|
fn parse_atom(input : String, standalone : Bool) -> Result[Feed, ParseError] {
  let reader = @xml.NamespaceReader::from_string(input)
  try {
    let mut depth = 0
    let mut root_seen = false
    let mut feed_line = 1
    let mut feed_column = 1
    let mut feed_id : String? = None
    let mut feed_title : String? = None
    let mut feed_subtitle : String? = None
    let mut feed_updated : String? = None
    let mut feed_rights : String? = None
    let mut feed_rights_kind = Text
    let mut feed_rights_xhtml : XhtmlFragment? = None
    let mut feed_generator : String? = None
    let mut feed_generator_uri : String? = None
    let mut feed_generator_version : String? = None
    let mut feed_link : String? = None
    let mut feed_language : String? = None
    let mut feed_base_references : Array[String] = []
    let feed_authors : Array[Author] = []
    let feed_contributors : Array[Author] = []
    let feed_categories : Array[Category] = []
    let feed_links : Array[AtomLink] = []
    let mut author_owner : String? = None
    let mut author_depth = 0
    let mut author_line = 1
    let mut author_column = 1
    let mut author_name : String? = None
    let mut author_uri : String? = None
    let mut author_email : String? = None
    let mut author_child : String? = None
    let mut author_child_depth = 0
    let mut author_child_text = ""
    let mut feed_title_kind = Text
    let mut feed_subtitle_kind = Text
    let mut feed_title_xhtml : XhtmlFragment? = None
    let mut feed_subtitle_xhtml : XhtmlFragment? = None
    let mut feed_id_location : (Int32, Int32)? = None
    let mut feed_title_location : (Int32, Int32)? = None
    let mut feed_updated_location : (Int32, Int32)? = None

    let entries : Array[Entry] = []
    let diagnostics : Array[Diagnostic] = []
    let entry_needs_feed_authors : Array[Bool] = []
    let entry_has_own_author : Array[Bool] = []
    let entry_locations : Array[(Int32, Int32)] = []
    let feed_singletons : Array[String] = []
    let mut entry_singletons : Array[String] = []

    let mut entry_open = false
    let mut entry_depth = 0
    let mut entry_line = 1
    let mut entry_column = 1
    let mut entry_id : String? = None
    let mut entry_title : String? = None
    let mut entry_published : String? = None
    let mut entry_updated : String? = None
    let mut entry_rights : String? = None
    let mut entry_rights_kind = Text
    let mut entry_rights_xhtml : XhtmlFragment? = None
    let mut entry_summary : String? = None
    let mut entry_link : String? = None
    let mut entry_language : String? = None
    let mut entry_base_references : Array[String] = []
    let mut entry_own_authors : Array[Author] = []
    let mut entry_contributors : Array[Author] = []
    let mut entry_source_authors : Array[Author] = []
    let mut entry_atom_source : AtomSource? = None
    let mut source_id : String? = None
    let mut source_title : String? = None
    let mut source_title_kind = Text
    let mut source_title_xhtml : XhtmlFragment? = None
    let mut source_subtitle : String? = None
    let mut source_subtitle_kind = Text
    let mut source_subtitle_xhtml : XhtmlFragment? = None
    let mut source_updated : String? = None
    let mut source_rights : String? = None
    let mut source_rights_kind = Text
    let mut source_rights_xhtml : XhtmlFragment? = None
    let mut source_generator : String? = None
    let mut source_generator_uri : String? = None
    let mut source_generator_version : String? = None
    let mut source_link : String? = None
    let mut source_links : Array[AtomLink] = []
    let mut source_images : Array[FeedImage] = []
    let mut source_contributors : Array[Author] = []
    let mut source_categories : Array[Category] = []
    let mut source_language : String? = None
    let mut source_base_references : Array[String] = []
    let mut source_singletons : Array[String] = []
    let mut entry_categories : Array[Category] = []
    let mut entry_attachments : Array[Attachment] = []
    let mut entry_links : Array[AtomLink] = []
    let mut source_open = false
    let mut source_depth = 0
    let mut entry_content_present = false
    let mut entry_external_content_location : (Int32, Int32)? = None
    let mut entry_content : String? = None
    let mut entry_content_source : String? = None
    let mut entry_content_media_type : String? = None
    let mut entry_title_kind = Text
    let mut entry_summary_kind = Text
    let mut entry_content_kind = Text
    let mut entry_title_xhtml : XhtmlFragment? = None
    let mut entry_summary_xhtml : XhtmlFragment? = None
    let mut entry_content_xhtml : XhtmlFragment? = None
    let mut entry_atom_body : AtomBody? = None
    let mut entry_binary_content_location : (Int32, Int32)? = None
    let mut entry_id_location : (Int32, Int32)? = None
    let mut entry_title_location : (Int32, Int32)? = None
    let mut entry_updated_location : (Int32, Int32)? = None

    let mut capture_field : String? = None
    let mut capture_in_entry = false
    let mut capture_in_source = false
    let mut capture_depth = 0
    let mut captured_text = ""
    let mut capture_has_nested_markup = false
    let mut capture_unsupported_type = false
    let mut capture_text_kind = Text
    let mut xhtml_capture : AtomXhtmlCapture? = None
    let mut xml_capture : AtomXmlCapture? = None
    let mut capture_content_mode = ""
    let mut capture_media_type = ""
    let mut capture_line = 1
    let mut capture_column = 1

    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) => {
          if capture_field is Some(_) && depth >= capture_depth {
            match xhtml_capture {
              Some(state) => state.node(element, depth == capture_depth, false)
              None =>
                match xml_capture {
                  Some(state) => state.node(element, false)
                  None => capture_has_nested_markup = true
                }
            }
          }
          if !root_seen {
            root_seen = true
            if !is_atom_name(element.name, "feed") &&
              !(standalone && is_atom_name(element.name, "entry")) {
              return Err(
                UnsupportedRoot(
                  element.name.qualified_name,
                  element.name.namespace_uri,
                ),
              )
            }
            feed_line = event.span.start.line
            feed_column = event.span.start.column
            if !standalone {
              feed_language = match xml_language_attribute(element) {
                Some(value) => non_blank_text(value)
                None => None
              }
              feed_base_references = []
              match xml_base_attribute(element) {
                Some(value) => feed_base_references.push(value)
                None => ()
              }
            }
          }
          if (depth == 1 || (standalone && depth == 0)) &&
            is_atom_name(element.name, "entry") {
            entry_open = true
            entry_singletons = []
            entry_depth = depth + 1
            entry_line = event.span.start.line
            entry_column = event.span.start.column
            entry_id = None
            entry_title = None
            entry_published = None
            entry_updated = None
            entry_rights = None
            entry_rights_kind = Text
            entry_rights_xhtml = None
            entry_summary = None
            entry_link = None
            entry_language = match xml_language_attribute(element) {
              Some(value) => non_blank_text(value)
              None => feed_language
            }
            entry_base_references = xhtml_copy_references(feed_base_references)
            match xml_base_attribute(element) {
              Some(value) => entry_base_references.push(value)
              None => ()
            }
            entry_own_authors = []
            entry_contributors = []
            entry_source_authors = []
            entry_atom_source = None
            entry_categories = []
            entry_attachments = []
            entry_links = []
            source_open = false
            source_depth = 0
            entry_content_present = false
            entry_external_content_location = None
            entry_content = None
            entry_content_source = None
            entry_content_media_type = None
            entry_title_kind = Text
            entry_summary_kind = Text
            entry_content_kind = Text
            entry_title_xhtml = None
            entry_summary_xhtml = None
            entry_content_xhtml = None
            entry_atom_body = None
            entry_binary_content_location = None
            entry_id_location = None
            entry_title_location = None
            entry_updated_location = None
          } else if !entry_open &&
            depth == 1 &&
            (
              is_atom_name(element.name, "author") ||
              is_atom_name(element.name, "contributor")
            ) {
            author_owner = Some(
              if is_atom_name(element.name, "author") {
                "feed"
              } else {
                "feed_contributor"
              },
            )
            author_depth = depth + 1
            author_line = event.span.start.line
            author_column = event.span.start.column
            author_name = None
            author_uri = None
            author_email = None
            author_child = None
            author_child_text = ""
          } else if entry_open &&
            depth == entry_depth &&
            (
              is_atom_name(element.name, "author") ||
              is_atom_name(element.name, "contributor")
            ) {
            author_owner = Some(
              if is_atom_name(element.name, "author") {
                "entry"
              } else {
                "entry_contributor"
              },
            )
            author_depth = depth + 1
            author_line = event.span.start.line
            author_column = event.span.start.column
            author_name = None
            author_uri = None
            author_email = None
            author_child = None
            author_child_text = ""
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "source") {
            source_open = true
            source_depth = depth + 1
            source_id = None
            source_title = None
            source_title_kind = Text
            source_title_xhtml = None
            source_subtitle = None
            source_subtitle_kind = Text
            source_subtitle_xhtml = None
            source_updated = None
            source_rights = None
            source_rights_kind = Text
            source_rights_xhtml = None
            source_generator = None
            source_generator_uri = None
            source_generator_version = None
            source_link = None
            source_links = []
            source_images = []
            source_contributors = []
            source_categories = []
            entry_source_authors = []
            source_singletons = []
            source_language = match xml_language_attribute(element) {
              Some(value) => non_blank_text(value)
              None => entry_language
            }
            source_base_references = xhtml_copy_references(
              entry_base_references,
            )
            match xml_base_attribute(element) {
              Some(value) => source_base_references.push(value)
              None => ()
            }
          } else if source_open &&
            depth == source_depth &&
            (
              is_atom_name(element.name, "author") ||
              is_atom_name(element.name, "contributor")
            ) {
            author_owner = Some(
              if is_atom_name(element.name, "author") {
                "source"
              } else {
                "source_contributor"
              },
            )
            author_depth = depth + 1
            author_line = event.span.start.line
            author_column = event.span.start.column
            author_name = None
            author_uri = None
            author_email = None
            author_child = None
            author_child_text = ""
          } else if capture_field is None &&
            source_open &&
            depth == source_depth &&
            element.name.local_name
            is ("id"
            | "title"
            | "subtitle"
            | "updated"
            | "rights"
            | "generator"
            | "icon"
            | "logo") &&
            is_atom_name(element.name, element.name.local_name) {
            let field = element.name.local_name
            if source_singletons.any(fn(previous) { previous == field }) {
              diagnostics.push({
                kind: DuplicateAtomField("source " + field),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            source_singletons.push(field)
            match field {
              "id" => source_id = None
              "title" => {
                source_title = None
                source_title_xhtml = None
              }
              "subtitle" => {
                source_subtitle = None
                source_subtitle_xhtml = None
              }
              "rights" => {
                source_rights = None
                source_rights_xhtml = None
              }
              "updated" => source_updated = None
              "generator" => {
                source_generator = None
                source_generator_uri = atom_attribute_value(element, "uri")
                source_generator_version = atom_attribute_value(
                  element, "version",
                )
              }
              _ => ()
            }
            capture_field = Some(field)
            capture_in_source = true
            capture_in_entry = false
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_text_kind = if field is ("title" | "subtitle" | "rights") {
              atom_text_kind(element).unwrap_or(Text)
            } else {
              Text
            }
            capture_unsupported_type = field
              is ("title" | "subtitle" | "rights") &&
              atom_text_kind(element) is None
            capture_line = event.span.start.line
            capture_column = event.span.start.column
            if capture_unsupported_type {
              diagnostics.push({
                kind: UnsupportedTextConstruct("atom source " + field),
                line: capture_line,
                column: capture_column,
              })
            }
            xhtml_capture = if field is ("title" | "subtitle" | "rights") &&
              capture_text_kind == Xhtml {
              let references = xhtml_copy_references(source_base_references)
              match xml_base_attribute(element) {
                Some(value) => references.push(value)
                None => ()
              }
              let language = match xml_language_attribute(element) {
                Some(value) => non_blank_text(value)
                None => source_language
              }
              Some(AtomXhtmlCapture::new(language, references))
            } else {
              None
            }
          } else if source_open &&
            depth == source_depth &&
            is_atom_name(element.name, "category") {
            match atom_category(element) {
              Some(category) => source_categories.push(category)
              None =>
                diagnostics.push({
                  kind: InvalidCategory("atom category missing term"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
            }
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "category") {
            match atom_category(element) {
              Some(category) => feed_categories.push(category)
              None =>
                diagnostics.push({
                  kind: InvalidCategory("atom category missing term"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "category") {
            match atom_category(element) {
              Some(category) => entry_categories.push(category)
              None =>
                diagnostics.push({
                  kind: InvalidCategory("atom category missing term"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
            }
          } else if author_owner is Some(_) &&
            depth == author_depth &&
            (
              is_atom_name(element.name, "name") ||
              is_atom_name(element.name, "uri") ||
              is_atom_name(element.name, "email")
            ) {
            author_child = Some(element.name.local_name)
            author_child_depth = depth + 1
            author_child_text = ""
          } else if source_open &&
            depth == source_depth &&
            is_atom_name(element.name, "link") {
            atom_append_link(
              source_links,
              element,
              "source",
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
            if source_link is None {
              source_link = atom_alternate_link(element)
            }
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "link") {
            atom_append_link(
              feed_links,
              element,
              "feed",
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
            if feed_link is None {
              feed_link = atom_alternate_link(element)
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "link") {
            atom_append_link(
              entry_links,
              element,
              "entry",
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
            if entry_link is None {
              entry_link = atom_alternate_link(element)
            }
            if atom_attribute_value(element, "rel") == Some("enclosure") {
              match
                xml_attachment(
                  element,
                  Atom1,
                  "href",
                  event.span.start.line,
                  event.span.start.column,
                  diagnostics,
                ) {
                Some(attachment) => entry_attachments.push(attachment)
                None => ()
              }
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "content") {
            entry_content_present = true
            entry_content = None
            entry_content_kind = Text
            entry_content_xhtml = None
            entry_content_media_type = atom_attribute_value(element, "type")
            entry_content_source = atom_attribute_value(element, "src")
            entry_external_content_location = None
            entry_atom_body = None
            match entry_content_source {
              Some(_) => {
                entry_external_content_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
                let mode = atom_content_mode(
                  atom_attribute_value(element, "type"),
                )
                if mode == "invalid" ||
                  mode == "html" ||
                  mode == "xhtml" ||
                  atom_attribute_value(element, "type") == Some("text") {
                  diagnostics.push({
                    kind: UnsupportedAtomContent(
                      "invalid external Atom media type",
                    ),
                    line: event.span.start.line,
                    column: event.span.start.column,
                  })
                } else {
                  match atom_external_content(element, entry_base_references) {
                    Some(reference) =>
                      entry_atom_body = Some(External(reference))
                    None =>
                      diagnostics.push({
                        kind: UnsupportedAtomContent("empty external Atom src"),
                        line: event.span.start.line,
                        column: event.span.start.column,
                      })
                  }
                }
                capture_field = Some("content")
                capture_in_entry = true
                capture_depth = depth + 1
                captured_text = ""
                capture_has_nested_markup = false
                capture_unsupported_type = false
                capture_content_mode = "external"
                capture_line = event.span.start.line
                capture_column = event.span.start.column
              }
              None => {
                let mode = atom_content_mode(
                  atom_attribute_value(element, "type"),
                )
                if mode == "invalid" {
                  diagnostics.push({
                    kind: UnsupportedAtomContent(
                      "invalid Atom content media type",
                    ),
                    line: event.span.start.line,
                    column: event.span.start.column,
                  })
                } else {
                  let kind = match mode {
                    "html" => Html
                    "xhtml" => Xhtml
                    _ => Text
                  }
                  capture_field = Some("content")
                  capture_in_entry = true
                  capture_depth = depth + 1
                  captured_text = ""
                  capture_has_nested_markup = false
                  capture_unsupported_type = false
                  capture_text_kind = kind
                  capture_content_mode = mode
                  capture_media_type = atom_content_media_type(
                    atom_attribute_value(element, "type"),
                  )
                  if mode == "binary" {
                    entry_binary_content_location = Some(
                      (event.span.start.line, event.span.start.column),
                    )
                  }
                  entry_content_xhtml = None
                  xhtml_capture = if kind == Xhtml {
                    let references = xhtml_copy_references(
                      entry_base_references,
                    )
                    match xml_base_attribute(element) {
                      Some(value) => references.push(value)
                      None => ()
                    }
                    let language = match xml_language_attribute(element) {
                      Some(value) => non_blank_text(value)
                      None => entry_language
                    }
                    Some(AtomXhtmlCapture::new(language, references))
                  } else {
                    None
                  }
                  xml_capture = if mode == "xml" {
                    let references = xhtml_copy_references(
                      entry_base_references,
                    )
                    match xml_base_attribute(element) {
                      Some(value) => references.push(value)
                      None => ()
                    }
                    let language = match xml_language_attribute(element) {
                      Some(value) => non_blank_text(value)
                      None => entry_language
                    }
                    Some(AtomXmlCapture::new(language, references))
                  } else {
                    None
                  }
                  capture_line = event.span.start.line
                  capture_column = event.span.start.column
                }
              }
            }
          } else if capture_field is None &&
            !entry_open &&
            depth == 1 &&
            (
              is_atom_name(element.name, "id") ||
              is_atom_name(element.name, "title") ||
              is_atom_name(element.name, "subtitle") ||
              is_atom_name(element.name, "rights") ||
              is_atom_name(element.name, "generator") ||
              is_atom_name(element.name, "updated")
            ) {
            capture_field = Some(element.name.local_name)
            capture_in_entry = false
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_text_kind = if element.name.local_name
              is ("title" | "subtitle" | "rights") {
              atom_text_kind(element).unwrap_or(Text)
            } else {
              Text
            }
            match element.name.local_name {
              "title" => {
                feed_title = None
                feed_title_xhtml = None
              }
              "subtitle" => {
                feed_subtitle = None
                feed_subtitle_xhtml = None
              }
              "rights" => {
                feed_rights = None
                feed_rights_xhtml = None
              }
              "generator" => {
                feed_generator = None
                feed_generator_uri = atom_attribute_value(element, "uri")
                feed_generator_version = atom_attribute_value(
                  element, "version",
                )
              }
              _ => ()
            }
            xhtml_capture = if capture_text_kind == Xhtml &&
              element.name.local_name is ("title" | "subtitle" | "rights") {
              let references = xhtml_copy_references(feed_base_references)
              match xml_base_attribute(element) {
                Some(value) => references.push(value)
                None => ()
              }
              let language = match xml_language_attribute(element) {
                Some(value) => non_blank_text(value)
                None => feed_language
              }
              Some(AtomXhtmlCapture::new(language, references))
            } else {
              None
            }
            capture_unsupported_type = element.name.local_name
              is ("title" | "subtitle" | "rights") &&
              atom_text_kind(element) is None
            capture_line = event.span.start.line
            capture_column = event.span.start.column
            if capture_unsupported_type {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "atom " + element.name.local_name,
                ),
                line: capture_line,
                column: capture_column,
              })
            }
            match element.name.local_name {
              "id" => feed_id_location = Some((capture_line, capture_column))
              "title" =>
                feed_title_location = Some((capture_line, capture_column))
              "updated" =>
                feed_updated_location = Some((capture_line, capture_column))
              _ => ()
            }
          } else if capture_field is None &&
            entry_open &&
            depth == entry_depth &&
            (
              is_atom_name(element.name, "id") ||
              is_atom_name(element.name, "title") ||
              is_atom_name(element.name, "published") ||
              is_atom_name(element.name, "updated") ||
              is_atom_name(element.name, "summary") ||
              is_atom_name(element.name, "rights")
            ) {
            capture_field = Some(element.name.local_name)
            capture_in_entry = true
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_text_kind = if element.name.local_name
              is ("title" | "summary" | "rights") {
              atom_text_kind(element).unwrap_or(Text)
            } else {
              Text
            }
            match element.name.local_name {
              "title" => {
                entry_title = None
                entry_title_xhtml = None
              }
              "summary" => {
                entry_summary = None
                entry_summary_xhtml = None
              }
              "rights" => {
                entry_rights = None
                entry_rights_xhtml = None
              }
              _ => ()
            }
            xhtml_capture = if capture_text_kind == Xhtml &&
              element.name.local_name is ("title" | "summary" | "rights") {
              let references = xhtml_copy_references(entry_base_references)
              match xml_base_attribute(element) {
                Some(value) => references.push(value)
                None => ()
              }
              let language = match xml_language_attribute(element) {
                Some(value) => non_blank_text(value)
                None => entry_language
              }
              Some(AtomXhtmlCapture::new(language, references))
            } else {
              None
            }
            capture_unsupported_type = element.name.local_name
              is ("title" | "summary" | "rights") &&
              atom_text_kind(element) is None
            capture_line = event.span.start.line
            capture_column = event.span.start.column
            if capture_unsupported_type {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "atom entry " + element.name.local_name,
                ),
                line: capture_line,
                column: capture_column,
              })
            }
            match element.name.local_name {
              "id" => entry_id_location = Some((capture_line, capture_column))
              "title" =>
                entry_title_location = Some((capture_line, capture_column))
              "updated" =>
                entry_updated_location = Some((capture_line, capture_column))
              _ => ()
            }
          }
          if entry_open && depth == entry_depth {
            atom_singleton(
              element,
              entry_singletons,
              true,
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
          } else if !entry_open && depth == 1 {
            atom_singleton(
              element,
              feed_singletons,
              false,
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
          }
          depth = depth + 1
        }
        @xml.Empty(element) => {
          if entry_open && depth == entry_depth {
            atom_singleton(
              element,
              entry_singletons,
              true,
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
          } else if !entry_open && depth == 1 {
            atom_singleton(
              element,
              feed_singletons,
              false,
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
          }
          if capture_field is Some(_) && depth >= capture_depth {
            match xhtml_capture {
              Some(state) => state.node(element, depth == capture_depth, true)
              None =>
                match xml_capture {
                  Some(state) => state.node(element, true)
                  None => capture_has_nested_markup = true
                }
            }
          } else if !root_seen {
            root_seen = true
            if !is_atom_name(element.name, "feed") {
              return Err(
                UnsupportedRoot(
                  element.name.qualified_name,
                  element.name.namespace_uri,
                ),
              )
            }
            feed_line = event.span.start.line
            feed_column = event.span.start.column
            feed_language = match xml_language_attribute(element) {
              Some(value) => non_blank_text(value)
              None => None
            }
          } else if !entry_open &&
            depth == 1 &&
            (
              is_atom_name(element.name, "author") ||
              is_atom_name(element.name, "contributor")
            ) {
            diagnostics.push({
              kind: InvalidAuthor(
                if is_atom_name(element.name, "author") {
                  "atom author missing name"
                } else {
                  "atom contributor missing name"
                },
              ),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if entry_open &&
            depth == entry_depth &&
            (
              is_atom_name(element.name, "author") ||
              is_atom_name(element.name, "contributor")
            ) {
            diagnostics.push({
              kind: InvalidAuthor(
                if is_atom_name(element.name, "author") {
                  "atom author missing name"
                } else {
                  "atom contributor missing name"
                },
              ),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "source") {
            entry_atom_source = Some({
              identifier: None,
              title: None,
              title_kind: Text,
              title_xhtml: None,
              subtitle: None,
              subtitle_kind: Text,
              subtitle_xhtml: None,
              updated_at: None,
              rights: None,
              rights_kind: Text,
              rights_xhtml: None,
              generator: None,
              generator_uri: None,
              generator_version: None,
              authors: [],
              contributors: [],
              categories: [],
              link: None,
              links: [],
              images: [],
            })
          } else if source_open &&
            depth == source_depth &&
            (
              is_atom_name(element.name, "author") ||
              is_atom_name(element.name, "contributor")
            ) {
            diagnostics.push({
              kind: InvalidAuthor(
                if is_atom_name(element.name, "author") {
                  "atom author missing name"
                } else {
                  "atom contributor missing name"
                },
              ),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if source_open &&
            depth == source_depth &&
            element.name.local_name
            is ("id"
            | "title"
            | "subtitle"
            | "updated"
            | "rights"
            | "generator"
            | "icon"
            | "logo") &&
            is_atom_name(element.name, element.name.local_name) {
            let field = element.name.local_name
            if source_singletons.any(fn(previous) { previous == field }) {
              diagnostics.push({
                kind: DuplicateAtomField("source " + field),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            source_singletons.push(field)
            if field is ("title" | "subtitle" | "rights") {
              let kind = atom_text_kind(element).unwrap_or(Text)
              if field == "title" {
                source_title = None
                source_title_kind = kind
                source_title_xhtml = None
              } else if field == "subtitle" {
                source_subtitle = None
                source_subtitle_kind = kind
                source_subtitle_xhtml = None
              } else {
                source_rights = None
                source_rights_kind = kind
                source_rights_xhtml = None
              }
              if atom_text_kind(element) is None || kind == Xhtml {
                diagnostics.push({
                  kind: UnsupportedTextConstruct("atom source " + field),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
            } else if field == "id" {
              source_id = None
            } else if field == "updated" {
              source_updated = None
            } else if field == "generator" {
              source_generator = None
              source_generator_uri = atom_attribute_value(element, "uri")
              source_generator_version = atom_attribute_value(
                element, "version",
              )
            } else {
              diagnostics.push({
                kind: InvalidFeedImage("atom source " + field + " missing URL"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
          } else if source_open &&
            depth == source_depth &&
            is_atom_name(element.name, "category") {
            match atom_category(element) {
              Some(category) => source_categories.push(category)
              None =>
                diagnostics.push({
                  kind: InvalidCategory("atom category missing term"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
            }
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "category") {
            match atom_category(element) {
              Some(category) => feed_categories.push(category)
              None =>
                diagnostics.push({
                  kind: InvalidCategory("atom category missing term"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "category") {
            match atom_category(element) {
              Some(category) => entry_categories.push(category)
              None =>
                diagnostics.push({
                  kind: InvalidCategory("atom category missing term"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
            }
          } else if source_open &&
            depth == source_depth &&
            is_atom_name(element.name, "link") {
            atom_append_link(
              source_links,
              element,
              "source",
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
            if source_link is None {
              source_link = atom_alternate_link(element)
            }
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "link") {
            atom_append_link(
              feed_links,
              element,
              "feed",
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
            if feed_link is None {
              feed_link = atom_alternate_link(element)
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "link") {
            atom_append_link(
              entry_links,
              element,
              "entry",
              event.span.start.line,
              event.span.start.column,
              diagnostics,
            )
            if entry_link is None {
              entry_link = atom_alternate_link(element)
            }
            if atom_attribute_value(element, "rel") == Some("enclosure") {
              match
                xml_attachment(
                  element,
                  Atom1,
                  "href",
                  event.span.start.line,
                  event.span.start.column,
                  diagnostics,
                ) {
                Some(attachment) => entry_attachments.push(attachment)
                None => ()
              }
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "content") {
            entry_content_present = true
            entry_content = None
            entry_content_kind = Text
            entry_content_xhtml = None
            entry_content_media_type = atom_attribute_value(element, "type")
            entry_content_source = atom_attribute_value(element, "src")
            entry_external_content_location = None
            entry_atom_body = None
            match entry_content_source {
              Some(_) => {
                entry_external_content_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
                let mode = atom_content_mode(
                  atom_attribute_value(element, "type"),
                )
                if mode == "invalid" ||
                  mode == "html" ||
                  mode == "xhtml" ||
                  atom_attribute_value(element, "type") == Some("text") {
                  diagnostics.push({
                    kind: UnsupportedAtomContent(
                      "invalid external Atom media type",
                    ),
                    line: event.span.start.line,
                    column: event.span.start.column,
                  })
                } else {
                  match atom_external_content(element, entry_base_references) {
                    Some(reference) =>
                      entry_atom_body = Some(External(reference))
                    None =>
                      diagnostics.push({
                        kind: UnsupportedAtomContent("empty external Atom src"),
                        line: event.span.start.line,
                        column: event.span.start.column,
                      })
                  }
                }
              }
              None => {
                let mode = atom_content_mode(
                  atom_attribute_value(element, "type"),
                )
                match mode {
                  "xhtml" =>
                    diagnostics.push({
                      kind: UnsupportedAtomContent("invalid Atom XHTML div"),
                      line: event.span.start.line,
                      column: event.span.start.column,
                    })
                  "text" | "text-mime" | "html" => {
                    entry_content = Some("")
                    entry_content_kind = if mode == "html" {
                      Html
                    } else {
                      Text
                    }
                    entry_atom_body = if mode == "html" {
                      Some(InlineHtml(""))
                    } else {
                      Some(
                        InlineText(
                          "",
                          atom_content_media_type(
                            atom_attribute_value(element, "type"),
                          ),
                        ),
                      )
                    }
                  }
                  "xml" => {
                    let references = xhtml_copy_references(
                      entry_base_references,
                    )
                    match xml_base_attribute(element) {
                      Some(value) => references.push(value)
                      None => ()
                    }
                    let language = match xml_language_attribute(element) {
                      Some(value) => non_blank_text(value)
                      None => entry_language
                    }
                    entry_atom_body = Some(
                      InlineXml(
                        { markup: "", language, base_references: references, },
                        atom_content_media_type(
                          atom_attribute_value(element, "type"),
                        ),
                      ),
                    )
                  }
                  "binary" => {
                    entry_binary_content_location = Some(
                      (event.span.start.line, event.span.start.column),
                    )
                    entry_atom_body = Some(
                      InlineBinary(
                        b"",
                        atom_content_media_type(
                          atom_attribute_value(element, "type"),
                        ),
                      ),
                    )
                  }
                  _ =>
                    diagnostics.push({
                      kind: UnsupportedAtomContent(
                        "invalid Atom content media type",
                      ),
                      line: event.span.start.line,
                      column: event.span.start.column,
                    })
                }
              }
            }
          } else if !entry_open &&
            depth == 1 &&
            (
              is_atom_name(element.name, "id") ||
              is_atom_name(element.name, "title") ||
              is_atom_name(element.name, "subtitle") ||
              is_atom_name(element.name, "rights") ||
              is_atom_name(element.name, "generator") ||
              is_atom_name(element.name, "updated")
            ) {
            if element.name.local_name is ("title" | "subtitle" | "rights") &&
              atom_text_kind(element) is None {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "atom " + element.name.local_name,
                ),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            if element.name.local_name is ("title" | "subtitle" | "rights") &&
              atom_text_kind(element) == Some(Xhtml) {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "invalid atom XHTML " + element.name.local_name,
                ),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            let kind = atom_text_kind(element).unwrap_or(Text)
            match element.name.local_name {
              "id" => feed_id = None
              "title" => {
                feed_title = None
                feed_title_kind = kind
                feed_title_xhtml = None
              }
              "updated" => feed_updated = None
              "rights" => {
                feed_rights = None
                feed_rights_kind = kind
                feed_rights_xhtml = None
              }
              "generator" => {
                feed_generator = None
                feed_generator_uri = atom_attribute_value(element, "uri")
                feed_generator_version = atom_attribute_value(
                  element, "version",
                )
              }
              _ => {
                feed_subtitle = None
                feed_subtitle_kind = kind
                feed_subtitle_xhtml = None
              }
            }
            match element.name.local_name {
              "id" =>
                feed_id_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              "title" =>
                feed_title_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              "updated" =>
                feed_updated_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              _ => ()
            }
          } else if entry_open &&
            depth == entry_depth &&
            (
              is_atom_name(element.name, "id") ||
              is_atom_name(element.name, "title") ||
              is_atom_name(element.name, "published") ||
              is_atom_name(element.name, "updated") ||
              is_atom_name(element.name, "summary") ||
              is_atom_name(element.name, "rights")
            ) {
            if element.name.local_name is ("title" | "summary" | "rights") &&
              atom_text_kind(element) is None {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "atom entry " + element.name.local_name,
                ),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            if element.name.local_name is ("title" | "summary" | "rights") &&
              atom_text_kind(element) == Some(Xhtml) {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "invalid atom XHTML " + element.name.local_name,
                ),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            let kind = atom_text_kind(element).unwrap_or(Text)
            match element.name.local_name {
              "id" => entry_id = None
              "title" => {
                entry_title = None
                entry_title_kind = kind
                entry_title_xhtml = None
              }
              "published" => entry_published = None
              "updated" => entry_updated = None
              "rights" => {
                entry_rights = None
                entry_rights_kind = kind
                entry_rights_xhtml = None
              }
              _ => {
                entry_summary = None
                entry_summary_kind = kind
                entry_summary_xhtml = None
              }
            }
            match element.name.local_name {
              "id" =>
                entry_id_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              "title" =>
                entry_title_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              "updated" =>
                entry_updated_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              _ => ()
            }
          }
        }
        @xml.Text(text) | @xml.CData(text) => {
          if author_child is Some(_) {
            author_child_text = author_child_text + text
          }
          if capture_field is Some(_) {
            match xhtml_capture {
              Some(state) => state.text(text, depth > capture_depth)
              None => {
                captured_text = captured_text + text
                match xml_capture {
                  Some(state) => state.text(text)
                  None => ()
                }
              }
            }
          }
        }
        @xml.Comment(value) => {
          match xhtml_capture {
            Some(state) => state.comment(value)
            None => ()
          }
          match xml_capture {
            Some(state) => state.comment(value)
            None => ()
          }
        }
        @xml.PI(target~, data~) => {
          match xhtml_capture {
            Some(state) => state.processing_instruction(target, data)
            None => ()
          }
          match xml_capture {
            Some(state) => state.processing_instruction(target, data)
            None => ()
          }
        }
        @xml.End(name) => {
          if capture_field is Some(_) && depth > capture_depth {
            match xhtml_capture {
              Some(state) => state.end(name, depth == capture_depth + 1)
              None =>
                match xml_capture {
                  Some(state) => state.end(name)
                  None => ()
                }
            }
          }
          if author_child is Some(field) &&
            author_child_depth == depth &&
            is_atom_name(name, field) {
            match field {
              "name" => author_name = non_blank_text(author_child_text)
              "uri" => author_uri = non_blank_text(author_child_text)
              _ => author_email = non_blank_text(author_child_text)
            }
            author_child = None
            author_child_text = ""
          }
          if author_owner is Some(_) &&
            author_depth == depth &&
            (is_atom_name(name, "author") || is_atom_name(name, "contributor")) {
            match author_name {
              Some(author_name) => {
                let author = {
                  source: Atom1,
                  name: Some(author_name),
                  uri: author_uri,
                  email: author_email,
                  avatar: None,
                }
                match author_owner {
                  Some("feed") => feed_authors.push(author)
                  Some("source") => entry_source_authors.push(author)
                  Some("source_contributor") => source_contributors.push(author)
                  Some("feed_contributor") => feed_contributors.push(author)
                  Some("entry_contributor") => entry_contributors.push(author)
                  _ => entry_own_authors.push(author)
                }
              }
              None =>
                diagnostics.push({
                  kind: InvalidAuthor(
                    if is_atom_name(name, "contributor") {
                      "atom contributor missing name"
                    } else {
                      "atom author missing name"
                    },
                  ),
                  line: author_line,
                  column: author_column,
                })
            }
            author_owner = None
            author_child = None
            author_child_text = ""
          }
          if source_open &&
            source_depth == depth &&
            is_atom_name(name, "source") {
            entry_atom_source = Some({
              identifier: source_id,
              title: source_title,
              title_kind: source_title_kind,
              title_xhtml: source_title_xhtml,
              subtitle: source_subtitle,
              subtitle_kind: source_subtitle_kind,
              subtitle_xhtml: source_subtitle_xhtml,
              updated_at: source_updated,
              rights: source_rights,
              rights_kind: source_rights_kind,
              rights_xhtml: source_rights_xhtml,
              generator: source_generator,
              generator_uri: source_generator_uri,
              generator_version: source_generator_version,
              authors: copy_authors(entry_source_authors),
              contributors: source_contributors,
              categories: source_categories,
              link: source_link,
              links: source_links,
              images: source_images,
            })
            source_open = false
          }
          if capture_field is Some(field) &&
            capture_depth == depth &&
            is_atom_name(name, field) {
            let xhtml_fragment = match xhtml_capture {
              Some(state) => state.fragment()
              None => None
            }
            if field == "content" && capture_content_mode == "external" {
              if capture_has_nested_markup || !captured_text.is_empty() {
                entry_atom_body = None
                diagnostics.push({
                  kind: UnsupportedAtomContent(
                    "external Atom content must be empty",
                  ),
                  line: capture_line,
                  column: capture_column,
                })
              }
            } else if field == "content" && capture_content_mode == "xml" {
              match xml_capture {
                Some(state) =>
                  entry_atom_body = Some(
                    InlineXml(state.fragment(), capture_media_type),
                  )
                None => ()
              }
            } else if field == "content" &&
              capture_content_mode == "binary" &&
              !capture_has_nested_markup {
              match atom_decode_base64(captured_text) {
                Some(bytes) =>
                  entry_atom_body = Some(
                    InlineBinary(bytes, capture_media_type),
                  )
                None =>
                  diagnostics.push({
                    kind: UnsupportedAtomContent("invalid Atom Base64 content"),
                    line: capture_line,
                    column: capture_column,
                  })
              }
            } else if capture_text_kind == Xhtml && xhtml_fragment is None {
              if field == "content" {
                diagnostics.push({
                  kind: UnsupportedAtomContent("invalid Atom XHTML div"),
                  line: capture_line,
                  column: capture_column,
                })
              } else {
                diagnostics.push({
                  kind: UnsupportedTextConstruct("invalid atom XHTML " + field),
                  line: capture_line,
                  column: capture_column,
                })
              }
            } else if capture_unsupported_type || capture_has_nested_markup {
              if field == "content" && capture_has_nested_markup {
                diagnostics.push({
                  kind: UnsupportedAtomContent(
                    "Atom content with nested markup",
                  ),
                  line: capture_line,
                  column: capture_column,
                })
              } else if capture_has_nested_markup && !capture_unsupported_type {
                diagnostics.push({
                  kind: UnsupportedTextConstruct("atom " + field),
                  line: capture_line,
                  column: capture_column,
                })
              }
            } else if capture_text_kind == Xhtml {
              match xhtml_capture {
                Some(state) => {
                  let plain = state.plain_text
                  if capture_in_source {
                    if field == "title" {
                      source_title = non_blank_text(plain)
                      source_title_kind = Xhtml
                      source_title_xhtml = xhtml_fragment
                    } else if field == "subtitle" {
                      source_subtitle = non_blank_text(plain)
                      source_subtitle_kind = Xhtml
                      source_subtitle_xhtml = xhtml_fragment
                    } else {
                      source_rights = non_blank_text(plain)
                      source_rights_kind = Xhtml
                      source_rights_xhtml = xhtml_fragment
                    }
                  } else if capture_in_entry {
                    match field {
                      "title" => {
                        entry_title = non_blank_text(plain)
                        entry_title_kind = Xhtml
                        entry_title_xhtml = xhtml_fragment
                      }
                      "summary" => {
                        entry_summary = non_blank_text(plain)
                        entry_summary_kind = Xhtml
                        entry_summary_xhtml = xhtml_fragment
                      }
                      "rights" => {
                        entry_rights = non_blank_text(plain)
                        entry_rights_kind = Xhtml
                        entry_rights_xhtml = xhtml_fragment
                      }
                      _ => {
                        entry_content = Some(plain)
                        entry_content_kind = Xhtml
                        entry_content_xhtml = xhtml_fragment
                        match xhtml_fragment {
                          Some(fragment) =>
                            entry_atom_body = Some(InlineXhtml(fragment))
                          None => ()
                        }
                      }
                    }
                  } else if field == "title" {
                    feed_title = non_blank_text(plain)
                    feed_title_kind = Xhtml
                    feed_title_xhtml = xhtml_fragment
                  } else if field == "rights" {
                    feed_rights = non_blank_text(plain)
                    feed_rights_kind = Xhtml
                    feed_rights_xhtml = xhtml_fragment
                  } else {
                    feed_subtitle = non_blank_text(plain)
                    feed_subtitle_kind = Xhtml
                    feed_subtitle_xhtml = xhtml_fragment
                  }
                }
                None => ()
              }
            } else if capture_in_source {
              match field {
                "id" => source_id = non_blank_text(captured_text)
                "title" => {
                  source_title = non_blank_text(captured_text)
                  source_title_kind = capture_text_kind
                }
                "subtitle" => {
                  source_subtitle = non_blank_text(captured_text)
                  source_subtitle_kind = capture_text_kind
                }
                "rights" => {
                  source_rights = non_blank_text(captured_text)
                  source_rights_kind = capture_text_kind
                }
                "updated" => source_updated = non_blank_text(captured_text)
                "generator" => source_generator = non_blank_text(captured_text)
                "icon" | "logo" =>
                  match non_blank_text(captured_text) {
                    Some(url) =>
                      source_images.push({
                        source: Atom1,
                        role: if field == "icon" {
                          AtomIcon
                        } else {
                          AtomLogo
                        },
                        url,
                        title: None,
                        link: None,
                        description: None,
                        width: None,
                        height: None,
                      })
                    None =>
                      diagnostics.push({
                        kind: InvalidFeedImage(
                          "atom source " + field + " missing URL",
                        ),
                        line: capture_line,
                        column: capture_column,
                      })
                  }
                _ => ()
              }
            } else if capture_in_entry {
              match field {
                "id" => entry_id = non_blank_text(captured_text)
                "title" => {
                  entry_title = non_blank_text(captured_text)
                  entry_title_kind = capture_text_kind
                }
                "published" => entry_published = non_blank_text(captured_text)
                "updated" => entry_updated = non_blank_text(captured_text)
                "rights" => {
                  entry_rights = non_blank_text(captured_text)
                  entry_rights_kind = capture_text_kind
                }
                "content" => {
                  entry_content = Some(captured_text)
                  entry_content_kind = capture_text_kind
                  entry_atom_body = if capture_content_mode == "html" {
                    Some(InlineHtml(captured_text))
                  } else {
                    Some(InlineText(captured_text, capture_media_type))
                  }
                }
                _ => {
                  entry_summary = non_blank_text(captured_text)
                  entry_summary_kind = capture_text_kind
                }
              }
            } else {
              match field {
                "id" => feed_id = non_blank_text(captured_text)
                "title" => {
                  feed_title = non_blank_text(captured_text)
                  feed_title_kind = capture_text_kind
                }
                "updated" => feed_updated = non_blank_text(captured_text)
                "rights" => {
                  feed_rights = non_blank_text(captured_text)
                  feed_rights_kind = capture_text_kind
                }
                "generator" => feed_generator = non_blank_text(captured_text)
                _ => {
                  feed_subtitle = non_blank_text(captured_text)
                  feed_subtitle_kind = capture_text_kind
                }
              }
            }
            capture_field = None
            capture_in_source = false
            captured_text = ""
            capture_has_nested_markup = false
            capture_unsupported_type = false
            capture_text_kind = Text
            xhtml_capture = None
            xml_capture = None
            capture_content_mode = ""
            capture_media_type = ""
          }
          if entry_open && depth == entry_depth && is_atom_name(name, "entry") {
            let index = entries.length()
            add_missing_atom_entry_diagnostics(
              index, entry_id, entry_title, entry_updated, entry_id_location, entry_title_location,
              entry_updated_location, entry_line, entry_column, diagnostics,
            )
            if !entry_content_present && entry_link is None {
              diagnostics.push({
                kind: MissingAlternateLink(index),
                line: entry_line,
                column: entry_column,
              })
            }
            match entry_external_content_location {
              Some((content_line, content_column)) if entry_summary is None =>
                diagnostics.push({
                  kind: MissingSummaryForExternalContent(index),
                  line: content_line,
                  column: content_column,
                })
              _ => ()
            }
            match entry_binary_content_location {
              Some((content_line, content_column)) if entry_summary is None =>
                diagnostics.push({
                  kind: MissingSummaryForBinaryContent(index),
                  line: content_line,
                  column: content_column,
                })
              _ => ()
            }
            let authors = if entry_own_authors.length() > 0 {
              copy_authors(entry_own_authors)
            } else {
              copy_authors(entry_source_authors)
            }
            entries.push({
              identifier: entry_id,
              title: entry_title,
              title_kind: entry_title_kind,
              title_xhtml: entry_title_xhtml,
              link: entry_link,
              external_url: None,
              language: entry_language,
              description: entry_summary,
              description_kind: entry_summary_kind,
              description_xhtml: entry_summary_xhtml,
              content: entry_content,
              content_text: None,
              content_html: None,
              content_kind: entry_content_kind,
              content_xhtml: entry_content_xhtml,
              content_source: entry_content_source,
              content_media_type: entry_content_media_type,
              atom_body: entry_atom_body,
              atom_source: entry_atom_source,
              links: entry_links,
              comments_url: None,
              source_url: None,
              source_title: None,
              guid_is_permalink: None,
              rights: entry_rights,
              rights_kind: entry_rights_kind,
              rights_xhtml: entry_rights_xhtml,
              authors,
              contributors: entry_contributors,
              categories: entry_categories,
              attachments: entry_attachments,
              images: [],
              published_at: entry_published,
              updated_at: entry_updated,
            })
            entry_needs_feed_authors.push(
              entry_own_authors.length() == 0 &&
              entry_source_authors.length() == 0,
            )
            entry_has_own_author.push(entry_own_authors.length() > 0)
            entry_locations.push((entry_line, entry_column))
            entry_open = false
          }
          depth = depth - 1
        }
        @xml.Eof => {
          if !standalone {
            add_missing_atom_feed_diagnostics(
              feed_id, feed_title, feed_updated, feed_id_location, feed_title_location,
              feed_updated_location, feed_line, feed_column, diagnostics,
            )
            if feed_authors.is_empty() &&
              (
                entries.is_empty() ||
                entry_has_own_author.any(fn(value) { !value })
              ) {
              diagnostics.push({
                kind: MissingFeedField("author"),
                line: feed_line,
                column: feed_column,
              })
            }
          }
          for index = 0
              index < entry_needs_feed_authors.length()
              index = index + 1 {
            if entry_needs_feed_authors[index] {
              if feed_authors.length() > 0 {
                entries[index] = with_authors(
                  entries[index],
                  copy_authors(feed_authors),
                )
              } else {
                let (line, column) = entry_locations[index]
                diagnostics.push({
                  kind: MissingEntryField(index, "author"),
                  line,
                  column,
                })
              }
            }
          }
          return Ok({
            format: Atom1,
            identifier: feed_id,
            title: feed_title,
            title_kind: feed_title_kind,
            title_xhtml: feed_title_xhtml,
            link: feed_link,
            language: feed_language,
            description: feed_subtitle,
            description_kind: feed_subtitle_kind,
            description_xhtml: feed_subtitle_xhtml,
            updated_at: feed_updated,
            published_at: None,
            ttl_minutes: None,
            rights: feed_rights,
            rights_kind: feed_rights_kind,
            rights_xhtml: feed_rights_xhtml,
            generator: feed_generator,
            generator_uri: feed_generator_uri,
            generator_version: feed_generator_version,
            managing_editor: None,
            webmaster: None,
            next_url: None,
            expired: None,
            hubs: [],
            links: feed_links,
            authors: feed_authors,
            contributors: feed_contributors,
            categories: feed_categories,
            images: [],
            entries,
            diagnostics,
          })
        }
        _ => ()
      }
    }
    abort("unreachable")
  } catch {
    @xml.At(error~, span~) =>
      Err(InvalidXml(error.to_string(), span.start.line, span.start.column))
  }
}
