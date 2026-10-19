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
fn atom_text_kind(element : @xml.NamespaceElement) -> TextKind? {
  match atom_attribute_value(element, "type") {
    None | Some("text") => Some(Text)
    Some("html") => Some(Html)
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
    link: entry.link,
    description: entry.description,
    description_kind: entry.description_kind,
    content: entry.content,
    content_kind: entry.content_kind,
    authors,
    categories: entry.categories,
    attachments: entry.attachments,
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
fn parse_atom(input : String) -> Result[Feed, ParseError] {
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
    let mut feed_link : String? = None
    let feed_authors : Array[Author] = []
    let feed_categories : Array[Category] = []
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
    let mut feed_id_location : (Int32, Int32)? = None
    let mut feed_title_location : (Int32, Int32)? = None
    let mut feed_updated_location : (Int32, Int32)? = None

    let entries : Array[Entry] = []
    let diagnostics : Array[Diagnostic] = []
    let entry_needs_feed_authors : Array[Bool] = []
    let entry_locations : Array[(Int32, Int32)] = []

    let mut entry_open = false
    let mut entry_depth = 0
    let mut entry_line = 1
    let mut entry_column = 1
    let mut entry_id : String? = None
    let mut entry_title : String? = None
    let mut entry_published : String? = None
    let mut entry_updated : String? = None
    let mut entry_summary : String? = None
    let mut entry_link : String? = None
    let mut entry_own_authors : Array[Author] = []
    let mut entry_source_authors : Array[Author] = []
    let mut entry_categories : Array[Category] = []
    let mut source_open = false
    let mut source_depth = 0
    let mut entry_content_present = false
    let mut entry_external_content_location : (Int32, Int32)? = None
    let mut entry_content : String? = None
    let mut entry_title_kind = Text
    let mut entry_summary_kind = Text
    let mut entry_content_kind = Text
    let mut entry_id_location : (Int32, Int32)? = None
    let mut entry_title_location : (Int32, Int32)? = None
    let mut entry_updated_location : (Int32, Int32)? = None

    let mut capture_field : String? = None
    let mut capture_in_entry = false
    let mut capture_depth = 0
    let mut captured_text = ""
    let mut capture_has_nested_markup = false
    let mut capture_unsupported_type = false
    let mut capture_text_kind = Text
    let mut capture_line = 1
    let mut capture_column = 1

    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) => {
          if capture_field is Some(_) && depth >= capture_depth {
            capture_has_nested_markup = true
          }
          if !root_seen {
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
          } else if depth == 1 && is_atom_name(element.name, "entry") {
            entry_open = true
            entry_depth = depth + 1
            entry_line = event.span.start.line
            entry_column = event.span.start.column
            entry_id = None
            entry_title = None
            entry_published = None
            entry_updated = None
            entry_summary = None
            entry_link = None
            entry_own_authors = []
            entry_source_authors = []
            entry_categories = []
            source_open = false
            source_depth = 0
            entry_content_present = false
            entry_external_content_location = None
            entry_content = None
            entry_title_kind = Text
            entry_summary_kind = Text
            entry_content_kind = Text
            entry_id_location = None
            entry_title_location = None
            entry_updated_location = None
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "author") {
            author_owner = Some("feed")
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
            is_atom_name(element.name, "author") {
            author_owner = Some("entry")
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
          } else if source_open &&
            depth == source_depth &&
            is_atom_name(element.name, "author") {
            author_owner = Some("source")
            author_depth = depth + 1
            author_line = event.span.start.line
            author_column = event.span.start.column
            author_name = None
            author_uri = None
            author_email = None
            author_child = None
            author_child_text = ""
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
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "link") {
            if feed_link is None {
              feed_link = atom_alternate_link(element)
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "link") {
            if entry_link is None {
              entry_link = atom_alternate_link(element)
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "content") {
            entry_content_present = true
            match atom_attribute_value(element, "src") {
              Some(_) => {
                entry_external_content_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
                diagnostics.push({
                  kind: UnsupportedAtomContent("external Atom content"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
              None =>
                match atom_text_kind(element) {
                  Some(kind) => {
                    capture_field = Some("content")
                    capture_in_entry = true
                    capture_depth = depth + 1
                    captured_text = ""
                    capture_has_nested_markup = false
                    capture_unsupported_type = false
                    capture_text_kind = kind
                    capture_line = event.span.start.line
                    capture_column = event.span.start.column
                  }
                  None =>
                    diagnostics.push({
                      kind: UnsupportedAtomContent(
                        "Atom content with unsupported type",
                      ),
                      line: event.span.start.line,
                      column: event.span.start.column,
                    })
                }
            }
          } else if capture_field is None &&
            !entry_open &&
            depth == 1 &&
            (
              is_atom_name(element.name, "id") ||
              is_atom_name(element.name, "title") ||
              is_atom_name(element.name, "subtitle") ||
              is_atom_name(element.name, "updated")
            ) {
            capture_field = Some(element.name.local_name)
            capture_in_entry = false
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_text_kind = atom_text_kind(element).unwrap_or(Text)
            capture_unsupported_type = element.name.local_name
              is ("title" | "subtitle") &&
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
              is_atom_name(element.name, "summary")
            ) {
            capture_field = Some(element.name.local_name)
            capture_in_entry = true
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_text_kind = atom_text_kind(element).unwrap_or(Text)
            capture_unsupported_type = element.name.local_name
              is ("title" | "summary") &&
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
          depth = depth + 1
        }
        @xml.Empty(element) =>
          if capture_field is Some(_) && depth >= capture_depth {
            capture_has_nested_markup = true
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
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "author") {
            diagnostics.push({
              kind: InvalidAuthor("atom author missing name"),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "author") {
            diagnostics.push({
              kind: InvalidAuthor("atom author missing name"),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if source_open &&
            depth == source_depth &&
            is_atom_name(element.name, "author") {
            diagnostics.push({
              kind: InvalidAuthor("atom author missing name"),
              line: event.span.start.line,
              column: event.span.start.column,
            })
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
          } else if !entry_open &&
            depth == 1 &&
            is_atom_name(element.name, "link") {
            if feed_link is None {
              feed_link = atom_alternate_link(element)
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "link") {
            if entry_link is None {
              entry_link = atom_alternate_link(element)
            }
          } else if entry_open &&
            depth == entry_depth &&
            is_atom_name(element.name, "content") {
            entry_content_present = true
            match atom_attribute_value(element, "src") {
              Some(_) => {
                entry_external_content_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
                diagnostics.push({
                  kind: UnsupportedAtomContent("external Atom content"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
              None =>
                match atom_text_kind(element) {
                  Some(kind) => {
                    entry_content = Some("")
                    entry_content_kind = kind
                  }
                  None =>
                    diagnostics.push({
                      kind: UnsupportedAtomContent(
                        "Atom content with unsupported type",
                      ),
                      line: event.span.start.line,
                      column: event.span.start.column,
                    })
                }
            }
          } else if !entry_open &&
            depth == 1 &&
            (
              is_atom_name(element.name, "id") ||
              is_atom_name(element.name, "title") ||
              is_atom_name(element.name, "subtitle") ||
              is_atom_name(element.name, "updated")
            ) {
            if element.name.local_name is ("title" | "subtitle") &&
              atom_text_kind(element) is None {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "atom " + element.name.local_name,
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
              }
              "updated" => feed_updated = None
              _ => {
                feed_subtitle = None
                feed_subtitle_kind = kind
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
              is_atom_name(element.name, "summary")
            ) {
            if element.name.local_name is ("title" | "summary") &&
              atom_text_kind(element) is None {
              diagnostics.push({
                kind: UnsupportedTextConstruct(
                  "atom entry " + element.name.local_name,
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
              }
              "published" => entry_published = None
              "updated" => entry_updated = None
              _ => {
                entry_summary = None
                entry_summary_kind = kind
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
        @xml.Text(text) | @xml.CData(text) => {
          if author_child is Some(_) {
            author_child_text = author_child_text + text
          }
          if capture_field is Some(_) {
            captured_text = captured_text + text
          }
        }
        @xml.End(name) => {
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
            is_atom_name(name, "author") {
            match author_name {
              Some(author_name) => {
                let author = {
                  source: Atom1,
                  name: Some(author_name),
                  uri: author_uri,
                  email: author_email,
                }
                match author_owner {
                  Some("feed") => feed_authors.push(author)
                  Some("source") => entry_source_authors.push(author)
                  _ => entry_own_authors.push(author)
                }
              }
              None =>
                diagnostics.push({
                  kind: InvalidAuthor("atom author missing name"),
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
            source_open = false
          }
          if capture_field is Some(field) &&
            capture_depth == depth &&
            is_atom_name(name, field) {
            if capture_unsupported_type || capture_has_nested_markup {
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
            } else if capture_in_entry {
              match field {
                "id" => entry_id = non_blank_text(captured_text)
                "title" => {
                  entry_title = non_blank_text(captured_text)
                  entry_title_kind = capture_text_kind
                }
                "published" => entry_published = non_blank_text(captured_text)
                "updated" => entry_updated = non_blank_text(captured_text)
                "content" => {
                  entry_content = Some(captured_text)
                  entry_content_kind = capture_text_kind
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
                _ => {
                  feed_subtitle = non_blank_text(captured_text)
                  feed_subtitle_kind = capture_text_kind
                }
              }
            }
            capture_field = None
            captured_text = ""
            capture_has_nested_markup = false
            capture_unsupported_type = false
            capture_text_kind = Text
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
            let authors = if entry_own_authors.length() > 0 {
              copy_authors(entry_own_authors)
            } else {
              copy_authors(entry_source_authors)
            }
            entries.push({
              identifier: entry_id,
              title: entry_title,
              title_kind: entry_title_kind,
              link: entry_link,
              description: entry_summary,
              description_kind: entry_summary_kind,
              content: entry_content,
              content_kind: entry_content_kind,
              authors,
              categories: entry_categories,
              attachments: [],
              published_at: entry_published,
              updated_at: entry_updated,
            })
            entry_needs_feed_authors.push(
              entry_own_authors.length() == 0 &&
              entry_source_authors.length() == 0,
            )
            entry_locations.push((entry_line, entry_column))
            entry_open = false
          }
          depth = depth - 1
        }
        @xml.Eof => {
          add_missing_atom_feed_diagnostics(
            feed_id, feed_title, feed_updated, feed_id_location, feed_title_location,
            feed_updated_location, feed_line, feed_column, diagnostics,
          )
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
            link: feed_link,
            description: feed_subtitle,
            description_kind: feed_subtitle_kind,
            updated_at: feed_updated,
            authors: feed_authors,
            categories: feed_categories,
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
