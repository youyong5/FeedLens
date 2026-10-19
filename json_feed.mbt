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
fn json_item_identifier(value : Json) -> String? {
  match value {
    String(text) => non_blank_text(text)
    // `stringify` uses the parsed number's source representation when one is
    // available, so converting a JSON number does not silently round it.
    Number(_, ..) => non_blank_text(value.stringify())
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
        Some(value) => non_blank_text(value)
        None => None
      }
      let uri = match
        json_optional_string(object, "url", diagnostics, item_index) {
        Some(value) => non_blank_text(value)
        None => None
      }
      match (name, uri) {
        (None, None) => {
          diagnostics.push({
            kind: InvalidAuthor("json feed author missing name or url"),
            line: 1,
            column: 1,
          })
          None
        }
        _ => Some({ source: JsonFeed, name, uri, email: None, })
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
            match non_blank_text(text) {
              Some(term) =>
                categories.push({
                  source: JsonFeed1,
                  term,
                  domain: None,
                  scheme: None,
                  label: None,
                })
              None =>
                diagnostics.push({
                  kind: InvalidCategory("json feed tag missing term"),
                  line: 1,
                  column: 1,
                })
            }
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
  if url is None || media_type is None {
    json_attachment_problem(
      diagnostics, item_index, attachment_index, "url or mime_type",
    )
    return None
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
  let feed_language = if version == JSON_FEED_1_1 {
    json_language(object, diagnostics, None).1
  } else {
    None
  }
  let (_, feed_authors) = json_authors(object, diagnostics, None)
  let entries : Array[Entry] = []

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
        match json_item_identifier(value) {
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
    entries.push({
      identifier: Some(identifier),
      title: json_optional_string(item, "title", diagnostics, Some(index)),
      title_kind: Text,
      link: json_optional_string(item, "url", diagnostics, Some(index)),
      language,
      description: json_optional_string(
        item,
        "summary",
        diagnostics,
        Some(index),
      ),
      description_kind: Text,
      content,
      content_kind,
      authors,
      categories: json_tags(item, diagnostics, index),
      attachments: json_attachments(item, diagnostics, index),
      published_at: json_optional_string(
        item,
        "date_published",
        diagnostics,
        Some(index),
      ),
      updated_at: json_optional_string(
        item,
        "date_modified",
        diagnostics,
        Some(index),
      ),
    })
  }
  Ok({
    format: JsonFeed1,
    identifier,
    title: Some(title),
    title_kind: Text,
    link,
    language: feed_language,
    description,
    description_kind: Text,
    updated_at: None,
    authors: feed_authors,
    categories: [],
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
