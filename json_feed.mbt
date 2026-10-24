///|
const JSON_FEED_1_0 = "https://jsonfeed.org/version/1"

///|
const JSON_FEED_1_1 = "https://jsonfeed.org/version/1.1"

///|
fn add_json_diagnostic(
  diagnostics : Array[Diagnostic],
  item_index : Int32?,
  field : String,
) -> Unit {
  let kind = match item_index {
    Some(index) => InvalidJsonFeedItem(index, field)
    None => InvalidJsonFeedField(field)
  }
  // The core JSON DOM deliberately does not retain field spans. JSON semantic
  // diagnostics therefore point at the document root; JSON syntax errors keep
  // their parser-supplied location in `ParseError::InvalidJson`.
  diagnostics.push({ kind, line: 1, column: 1, })
}

///|
fn json_field(object : Map[String, Json], name : String) -> Json? {
  object.get(name)
}

///|
fn json_string(value : Json) -> String? {
  match value {
    String(text) => Some(text)
    _ => None
  }
}

///|
fn json_item_identifier(value : Json, version : String) -> String? {
  match value {
    // A blank ID cannot identify an item. Keep nonblank identifiers verbatim,
    // including any whitespace surrounding their meaningful text.
    String(text) => non_blank_text(text)
    // `stringify` uses the parsed number's source representation when one is
    // available, so converting a JSON number does not silently round it.
    Number(_, ..) => non_blank_text(value.stringify())
    // JSON Feed 1.0 explicitly requires readers to coerce other JSON values
    // to a string. JSON serialization gives these values a deterministic
    // representation without silently discarding an otherwise usable item.
    _ if version == JSON_FEED_1_0 => non_blank_text(value.stringify())
    _ => None
  }
}

///|
fn json_optional_string(
  object : Map[String, Json],
  name : String,
  diagnostics : Array[Diagnostic],
  item_index : Int32?,
) -> String? {
  match json_field(object, name) {
    None => None
    Some(value) =>
      match json_string(value) {
        Some(text) => Some(text)
        None => {
          add_json_diagnostic(diagnostics, item_index, name)
          None
        }
      }
  }
}

///|
// Invalid date text remains available to callers; a malformed optional date
// does not discard an otherwise usable JSON Feed item.
fn json_date_field(
  item : Map[String, Json],
  name : String,
  diagnostics : Array[Diagnostic],
  index : Int32,
) -> String? {
  let raw = json_optional_string(item, name, diagnostics, Some(index))
  match raw {
    Some(value) =>
      match normalize_date(JsonFeed1, Some(value)) {
        Ok(_) => ()
        Err(_) => diagnostics.push({
          kind: InvalidJsonFeedDate(index, name),
          line: 1,
          column: 1,
        })
      }
    None => ()
  }
  raw
}

///|
fn json_language(
  object : Map[String, Json],
  diagnostics : Array[Diagnostic],
  item_index : Int32?,
) -> (Bool, String?) {
  match json_field(object, "language") {
    None => (false, None)
    Some(String(value)) =>
      match non_blank_text(value) {
        Some(language) => (true, Some(language))
        None => {
          diagnostics.push({
            kind: InvalidLanguage("json feed language blank"),
            line: 1,
            column: 1,
          })
          (true, None)
        }
      }
    Some(_) => {
      add_json_diagnostic(diagnostics, item_index, "language")
      (true, None)
    }
  }
}

///|
fn json_feed_images(
  object : Map[String, Json],
  diagnostics : Array[Diagnostic],
) -> Array[FeedImage] {
  let images : Array[FeedImage] = []
  for field in ["icon", "favicon"] {
    match json_optional_string(object, field, diagnostics, None) {
      Some(value) =>
        match non_blank_text(value) {
          Some(url) =>
            images.push({
              source: JsonFeed1,
              role: if field == "icon" {
                JsonIcon
              } else {
                JsonFavicon
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
              kind: InvalidFeedImage("json feed " + field + " missing URL"),
              line: 1,
              column: 1,
            })
        }
      None => ()
    }
  }
  images
}

///|
fn json_hubs(
  object : Map[String, Json],
  diagnostics : Array[Diagnostic],
) -> Array[Hub] {
  let hubs : Array[Hub] = []
  match json_field(object, "hubs") {
    None => ()
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(hub) => {
            let transport_type = match
              json_optional_string(hub, "type", diagnostics, None) {
              Some(raw) => non_blank_text(raw)
              None => None
            }
            let url = match
              json_optional_string(hub, "url", diagnostics, None) {
              Some(raw) => non_blank_text(raw)
              None => None
            }
            match (transport_type, url) {
              (Some(transport_type), Some(url)) =>
                hubs.push({ transport_type, url, })
              _ => add_json_diagnostic(diagnostics, None, "hubs entry")
            }
          }
          _ => add_json_diagnostic(diagnostics, None, "hubs entry")
        }
      }
    Some(_) => add_json_diagnostic(diagnostics, None, "hubs")
  }
  hubs
}

///|
fn json_item_url(
  item : Map[String, Json],
  field : String,
  diagnostics : Array[Diagnostic],
  index : Int32,
) -> String? {
  match json_optional_string(item, field, diagnostics, Some(index)) {
    None => None
    Some(value) =>
      match non_blank_text(value) {
        Some(url) => Some(url)
        None => {
          add_json_diagnostic(diagnostics, Some(index), field)
          None
        }
      }
  }
}

///|
fn json_entry_images(
  item : Map[String, Json],
  diagnostics : Array[Diagnostic],
  index : Int32,
) -> Array[EntryImage] {
  let images : Array[EntryImage] = []
  for field in ["image", "banner_image"] {
    match json_item_url(item, field, diagnostics, index) {
      Some(url) =>
        images.push({
          source: JsonFeed1,
          role: if field == "image" {
            JsonFeatured
          } else {
            JsonBanner
          },
          url,
        })
      None => ()
    }
  }
  images
}

///|
fn json_author(
  value : Json,
  diagnostics : Array[Diagnostic],
  item_index : Int32?,
  field : String,
) -> Author? {
  match value {
    Object(object) => {
      let name = match
        json_optional_string(object, "name", diagnostics, item_index) {
        // A declared plain-text name is an opaque string, including an empty
        // one. Its presence also satisfies the author's required member.
        Some(value) => Some(value)
        None => None
      }
      let uri = match
        json_optional_string(object, "url", diagnostics, item_index) {
        Some(value) => non_blank_text(value)
        None => None
      }
      let avatar = match
        json_optional_string(object, "avatar", diagnostics, item_index) {
        Some(value) => non_blank_text(value)
        None => None
      }
      match (name, uri, avatar) {
        (None, None, None) => {
          diagnostics.push({
            kind: InvalidAuthor("json feed author missing name or url"),
            line: 1,
            column: 1,
          })
          None
        }
        _ => Some({ source: JsonFeed, name, uri, email: None, avatar, })
      }
    }
    _ => {
      add_json_diagnostic(diagnostics, item_index, field)
      None
    }
  }
}

///|
/// Returns whether either JSON Feed author spelling was declared. An empty
/// `authors` array is intentional and therefore suppresses legacy `author`.
fn json_authors(
  object : Map[String, Json],
  diagnostics : Array[Diagnostic],
  item_index : Int32?,
) -> (Bool, Array[Author]) {
  match json_field(object, "authors") {
    Some(Array(values)) => {
      let authors : Array[Author] = []
      for value in values {
        match json_author(value, diagnostics, item_index, "authors") {
          Some(author) => authors.push(author)
          None => ()
        }
      }
      (true, authors)
    }
    Some(_) => {
      add_json_diagnostic(diagnostics, item_index, "authors")
      (true, [])
    }
    None =>
      match json_field(object, "author") {
        Some(value) => {
          let authors : Array[Author] = []
          match json_author(value, diagnostics, item_index, "author") {
            Some(author) => authors.push(author)
            None => ()
          }
          (true, authors)
        }
        None => (false, [])
      }
  }
}

///|
fn json_tags(
  object : Map[String, Json],
  diagnostics : Array[Diagnostic],
  item_index : Int32,
) -> Array[Category] {
  let categories : Array[Category] = []
  match json_field(object, "tags") {
    None => ()
    Some(Array(tags)) =>
      for tag in tags {
        match json_string(tag) {
          Some(text) =>
            categories.push({
              source: JsonFeed1,
              term: text,
              domain: None,
              scheme: None,
              label: None,
            })
          None => add_json_diagnostic(diagnostics, Some(item_index), "tags")
        }
      }
    Some(_other) => add_json_diagnostic(diagnostics, Some(item_index), "tags")
  }
  categories
}

///|
fn json_attachment_problem(
  diagnostics : Array[Diagnostic],
  item_index : Int32,
  attachment_index : Int32,
  field : String,
) -> Unit {
  // Core JSON values have no semantic source span; see add_json_diagnostic.
  diagnostics.push({
    kind: InvalidAttachment(
      "json feed item " +
      item_index.to_string() +
      " attachment " +
      attachment_index.to_string() +
      ": " +
      field,
    ),
    line: 1,
    column: 1,
  })
}

///|
fn json_attachment(
  value : Json,
  diagnostics : Array[Diagnostic],
  item_index : Int32,
  attachment_index : Int32,
) -> Attachment? {
  let object = match value {
    Object(object) => object
    _ => {
      json_attachment_problem(
        diagnostics, item_index, attachment_index, "object",
      )
      return None
    }
  }
  let url = match json_field(object, "url") {
    Some(String(value)) => non_blank_text(value)
    _ => None
  }
  let media_type = match json_field(object, "mime_type") {
    Some(String(value)) => non_blank_text(value)
    _ => None
  }
  if url is None {
    json_attachment_problem(diagnostics, item_index, attachment_index, "url")
    return None
  }
  // mime_type is required for publishers, but a reader can still expose the
  // attachment URL and metadata when it is missing or unusable.
  if media_type is None {
    json_attachment_problem(
      diagnostics, item_index, attachment_index, "mime_type",
    )
  }
  let title = match json_field(object, "title") {
    None => None
    Some(String(value)) => Some(value)
    Some(_) => {
      json_attachment_problem(
        diagnostics, item_index, attachment_index, "title",
      )
      None
    }
  }
  let size = match json_field(object, "size_in_bytes") {
    None => None
    Some(number) =>
      match number {
        Number(_, ..) =>
          match attachment_size(number.stringify()) {
            Some(value) => Some(value)
            None => {
              json_attachment_problem(
                diagnostics, item_index, attachment_index, "size_in_bytes",
              )
              None
            }
          }
        _ => {
          json_attachment_problem(
            diagnostics, item_index, attachment_index, "size_in_bytes",
          )
          None
        }
      }
  }
  let duration = match json_field(object, "duration_in_seconds") {
    None => None
    Some(number) =>
      match number {
        Number(value, ..) if value >= 0.0 && !value.is_inf() && !value.is_nan() =>
          Some(value)
        _ => {
          json_attachment_problem(
            diagnostics, item_index, attachment_index, "duration_in_seconds",
          )
          None
        }
      }
  }
  Some({
    source: JsonFeed1,
    url: url.unwrap(),
    media_type,
    size_in_bytes: size,
    title,
    duration_in_seconds: duration,
  })
}

///|
fn json_attachments(
  item : Map[String, Json],
  diagnostics : Array[Diagnostic],
  item_index : Int32,
) -> Array[Attachment] {
  let attachments : Array[Attachment] = []
  match json_field(item, "attachments") {
    None => ()
    Some(Array(values)) =>
      for index = 0; index < values.length(); index = index + 1 {
        match json_attachment(values[index], diagnostics, item_index, index) {
          Some(attachment) => attachments.push(attachment)
          None => ()
        }
      }
    Some(_) =>
      json_attachment_problem(diagnostics, item_index, 0, "attachments array")
  }
  attachments
}

///|
fn json_parse_error_location(error : @json.ParseError) -> (Int32, Int32) {
  match error {
    @json.InvalidChar({ line, column, }, _) => (line, column + 1)
    @json.InvalidNumber({ line, column, }, _) => (line, column + 1)
    @json.InvalidIdentEscape({ line, column, }) => (line, column + 1)
    _ => (1, 1)
  }
}

///|
fn parse_json_feed_value(root : Json) -> Result[Feed, ParseError] {
  let object = match root {
    Object(object) => object
    _ => return Err(InvalidJsonFeed("JSON Feed root must be an object"))
  }
  let version = match json_field(object, "version") {
    Some(String(version)) => version
    Some(_) => return Err(InvalidJsonFeed("JSON Feed version must be a string"))
    None => return Err(InvalidJsonFeed("JSON Feed version is required"))
  }
  if version != JSON_FEED_1_0 && version != JSON_FEED_1_1 {
    return Err(UnsupportedJsonFeedVersion(Some(version)))
  }
  let title = match json_field(object, "title") {
    Some(String(title)) => title
    Some(_) => return Err(InvalidJsonFeed("JSON Feed title must be a string"))
    None => return Err(InvalidJsonFeed("JSON Feed title is required"))
  }
  let items = match json_field(object, "items") {
    Some(Array(items)) => items
    Some(_) => return Err(InvalidJsonFeed("JSON Feed items must be an array"))
    None => return Err(InvalidJsonFeed("JSON Feed items are required"))
  }

  let diagnostics : Array[Diagnostic] = []
  let description = json_optional_string(
    object,
    "description",
    diagnostics,
    None,
  )
  let link = json_optional_string(object, "home_page_url", diagnostics, None)
  let identifier = json_optional_string(object, "feed_url", diagnostics, None)
  let next_url = match
    json_optional_string(object, "next_url", diagnostics, None) {
    Some(url) if Some(url) == identifier => {
      add_json_diagnostic(diagnostics, None, "next_url equals feed_url")
      None
    }
    value => value
  }
  let expired = match json_field(object, "expired") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => {
      add_json_diagnostic(diagnostics, None, "expired")
      None
    }
    None => None
  }
  let feed_language = if version == JSON_FEED_1_1 {
    json_language(object, diagnostics, None).1
  } else {
    None
  }
  let (_, feed_authors) = json_authors(object, diagnostics, None)
  let images = json_feed_images(object, diagnostics)
  let hubs = json_hubs(object, diagnostics)
  let entries : Array[Entry] = []
  let seen_identifiers : Array[String] = []

  for index = 0; index < items.length(); index = index + 1 {
    let item = match items[index] {
      Object(item) => item
      _ => {
        add_json_diagnostic(diagnostics, Some(index), "item")
        continue
      }
    }
    let identifier = match json_field(item, "id") {
      Some(value) =>
        match json_item_identifier(value, version) {
          Some(identifier) => identifier
          None => {
            add_json_diagnostic(diagnostics, Some(index), "id")
            continue
          }
        }
      None => {
        add_json_diagnostic(diagnostics, Some(index), "id")
        continue
      }
    }
    let html = json_optional_string(
      item,
      "content_html",
      diagnostics,
      Some(index),
    )
    let text = json_optional_string(
      item,
      "content_text",
      diagnostics,
      Some(index),
    )
    let (content, content_kind) = match html {
      Some(html) => (Some(html), Html)
      None =>
        match text {
          Some(text) => (Some(text), Text)
          None => {
            add_json_diagnostic(diagnostics, Some(index), "content")
            continue
          }
        }
    }
    let (declared_authors, item_authors) = json_authors(
      item,
      diagnostics,
      Some(index),
    )
    let authors = if declared_authors {
      item_authors
    } else {
      copy_authors(feed_authors)
    }
    let language = if version == JSON_FEED_1_1 {
      let (declared, item_language) = json_language(
        item,
        diagnostics,
        Some(index),
      )
      if declared {
        item_language
      } else {
        feed_language
      }
    } else {
      None
    }
    // Compare usable IDs exactly as exposed to callers, after the specified
    // number-to-string recovery. An item discarded for invalid content does
    // not occupy an identity in the resulting feed.
    if seen_identifiers.any(fn(previous) { previous == identifier }) {
      add_json_diagnostic(diagnostics, Some(index), "duplicate id")
    } else {
      seen_identifiers.push(identifier)
    }
    entries.push({
      identifier: Some(identifier),
      title: json_optional_string(item, "title", diagnostics, Some(index)),
      title_kind: Text,
      title_xhtml: None,
      link: json_optional_string(item, "url", diagnostics, Some(index)),
      external_url: json_item_url(item, "external_url", diagnostics, index),
      language,
      description: json_optional_string(
        item,
        "summary",
        diagnostics,
        Some(index),
      ),
      description_kind: Text,
      description_xhtml: None,
      content,
      content_text: text,
      content_html: html,
      content_kind,
      content_xhtml: None,
      content_source: None,
      content_media_type: None,
      atom_body: None,
      atom_source: None,
      links: [],
      comments_url: None,
      source_url: None,
      source_title: None,
      guid_is_permalink: None,
      rights: None,
      rights_kind: Unspecified,
      rights_xhtml: None,
      authors,
      contributors: [],
      categories: json_tags(item, diagnostics, index),
      attachments: json_attachments(item, diagnostics, index),
      images: json_entry_images(item, diagnostics, index),
      published_at: json_date_field(item, "date_published", diagnostics, index),
      updated_at: json_date_field(item, "date_modified", diagnostics, index),
    })
  }
  Ok({
    format: JsonFeed1,
    identifier,
    title: Some(title),
    title_kind: Text,
    title_xhtml: None,
    link,
    language: feed_language,
    description,
    description_kind: Text,
    description_xhtml: None,
    updated_at: None,
    published_at: None,
    ttl_minutes: None,
    docs_url: None,
    rating: None,
    cloud: None,
    text_input: None,
    skip_hours: [],
    skip_days: [],
    rights: None,
    rights_kind: Unspecified,
    rights_xhtml: None,
    generator: None,
    generator_uri: None,
    generator_version: None,
    managing_editor: None,
    webmaster: None,
    next_url,
    expired,
    hubs,
    links: [],
    authors: feed_authors,
    contributors: [],
    categories: [],
    images,
    entries,
    diagnostics,
  })
}

///|
fn parse_json_feed(input : String) -> Result[Feed, ParseError] {
  parse_json_feed_value(@json.parse(input)) catch {
    error => {
      let (line, column) = json_parse_error_location(error)
      Err(InvalidJson(error.to_string(), line, column))
    }
  }
}
