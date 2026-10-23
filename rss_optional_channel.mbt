///|
fn rss_channel_cloud(
  element : @xml.NamespaceElement,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
  record_errors : Bool,
) -> RssCloud? {
  let domain = match attribute_value(element, "domain") {
    Some(value) => non_blank_text(value)
    None => None
  }
  let path = match attribute_value(element, "path") {
    Some(value) => non_blank_text(value)
    None => None
  }
  let procedure = match attribute_value(element, "registerProcedure") {
    Some(value) => non_blank_text(value)
    None => None
  }
  let protocol = match attribute_value(element, "protocol") {
    Some(value) => non_blank_text(value)
    None => None
  }
  let port = match attribute_value(element, "port") {
    Some(value) => rss_ttl_minutes(value)
    None => None
  }
  match (domain, port, path, procedure, protocol) {
    (Some(domain), Some(port), Some(path), Some(procedure), Some(protocol)) if port >
      0 &&
      port <= 65535 &&
      (protocol == "xml-rpc" || protocol == "soap" || protocol == "http-post") =>
      Some({ domain, port, path, register_procedure: procedure, protocol, })
    _ => {
      if record_errors {
        diagnostics.push({ kind: InvalidRssField("cloud"), line, column, })
      }
      None
    }
  }
}

///|
fn rss_optional_problem(
  diagnostics : Array[Diagnostic],
  record_errors : Bool,
  field : String,
  line : Int32,
  column : Int32,
) -> Unit {
  if record_errors {
    diagnostics.push({ kind: InvalidRssField(field), line, column, })
  }
}

///|
fn with_rss_optional_channel(
  feed : Feed,
  docs_url : String?,
  rating : String?,
  cloud : RssCloud?,
  text_input : RssTextInput?,
) -> Feed {
  {
    format: feed.format,
    identifier: feed.identifier,
    title: feed.title,
    title_kind: feed.title_kind,
    title_xhtml: feed.title_xhtml,
    link: feed.link,
    language: feed.language,
    description: feed.description,
    description_kind: feed.description_kind,
    description_xhtml: feed.description_xhtml,
    updated_at: feed.updated_at,
    published_at: feed.published_at,
    ttl_minutes: feed.ttl_minutes,
    docs_url,
    rating,
    cloud,
    text_input,
    skip_hours: feed.skip_hours,
    skip_days: feed.skip_days,
    rights: feed.rights,
    rights_kind: feed.rights_kind,
    rights_xhtml: feed.rights_xhtml,
    generator: feed.generator,
    generator_uri: feed.generator_uri,
    generator_version: feed.generator_version,
    managing_editor: feed.managing_editor,
    webmaster: feed.webmaster,
    next_url: feed.next_url,
    expired: feed.expired,
    hubs: feed.hubs,
    links: feed.links,
    authors: feed.authors,
    contributors: feed.contributors,
    categories: feed.categories,
    images: feed.images,
    entries: feed.entries,
    diagnostics: feed.diagnostics,
  }
}

///|
/// The core RSS pass owns required fields and entries. This pass reads only
/// direct optional channel children and the four direct textInput children.
fn add_rss_optional_channel(
  input : String,
  feed : Feed,
  source_url : String?,
  record_errors : Bool,
) -> Result[Feed, ParseError] {
  let reader = @xml.NamespaceReader::from_string(input)
  let diagnostics = feed.diagnostics
  let mut depth = 0
  let mut channel_depth = 0
  let mut text_input_depth = 0
  let mut text_input_active = false
  let mut docs_seen = false
  let mut rating_seen = false
  let mut cloud_seen = false
  let mut text_input_seen = false
  let mut docs_url : String? = None
  let mut docs_line = 1
  let mut docs_column = 1
  let mut rating : String? = None
  let mut cloud : RssCloud? = None
  let mut text_input : RssTextInput? = None
  let mut form_title : String? = None
  let mut form_description : String? = None
  let mut form_name : String? = None
  let mut form_link : String? = None
  let mut form_line = 1
  let mut form_column = 1
  let mut capture : String? = None
  let mut capture_depth = 0
  let mut capture_text = ""
  let mut capture_nested = false
  let mut capture_line = 1
  let mut capture_column = 1
  try {
    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) => {
          if capture is Some(_) && depth >= capture_depth {
            capture_nested = true
          }
          let name = element.name
          if depth == 1 && is_rss_name(name, "channel") {
            channel_depth = depth + 1
          } else if channel_depth > 0 && depth == channel_depth {
            if is_rss_name(name, "docs") ||
              is_rss_name(name, "rating") ||
              is_rss_name(name, "cloud") ||
              is_rss_name(name, "textInput") {
              let field = name.local_name
              let seen = match field {
                "docs" => {
                  let old = docs_seen
                  docs_seen = true
                  old
                }
                "rating" => {
                  let old = rating_seen
                  rating_seen = true
                  old
                }
                "cloud" => {
                  let old = cloud_seen
                  cloud_seen = true
                  old
                }
                _ => {
                  let old = text_input_seen
                  text_input_seen = true
                  old
                }
              }
              if seen {
                rss_optional_problem(
                  diagnostics,
                  record_errors,
                  field + " duplicate",
                  event.span.start.line,
                  event.span.start.column,
                )
              } else if field == "cloud" {
                cloud = rss_channel_cloud(
                  element,
                  event.span.start.line,
                  event.span.start.column,
                  diagnostics,
                  record_errors,
                )
              } else if field == "textInput" {
                text_input_active = true
                text_input_depth = depth + 1
                form_line = event.span.start.line
                form_column = event.span.start.column
              } else {
                capture = Some(field)
                capture_depth = depth + 1
                capture_text = ""
                capture_nested = false
                capture_line = event.span.start.line
                capture_column = event.span.start.column
                if field == "docs" {
                  docs_line = capture_line
                  docs_column = capture_column
                }
              }
            }
          } else if text_input_active &&
            depth == text_input_depth &&
            (
              is_rss_name(name, "title") ||
              is_rss_name(name, "description") ||
              is_rss_name(name, "name") ||
              is_rss_name(name, "link")
            ) {
            capture = Some(name.local_name)
            capture_depth = depth + 1
            capture_text = ""
            capture_nested = false
            capture_line = event.span.start.line
            capture_column = event.span.start.column
          }
          depth = depth + 1
        }
        @xml.Empty(element) =>
          if capture is Some(_) && depth >= capture_depth {
            capture_nested = true
          } else if channel_depth > 0 && depth == channel_depth {
            if is_rss_name(element.name, "cloud") {
              if cloud_seen {
                rss_optional_problem(
                  diagnostics,
                  record_errors,
                  "cloud duplicate",
                  event.span.start.line,
                  event.span.start.column,
                )
              } else {
                cloud_seen = true
                cloud = rss_channel_cloud(
                  element,
                  event.span.start.line,
                  event.span.start.column,
                  diagnostics,
                  record_errors,
                )
              }
            } else if is_rss_name(element.name, "docs") ||
              is_rss_name(element.name, "rating") ||
              is_rss_name(element.name, "textInput") {
              let field = element.name.local_name
              rss_optional_problem(
                diagnostics,
                record_errors,
                field,
                event.span.start.line,
                event.span.start.column,
              )
              if field == "docs" {
                docs_seen = true
              }
              if field == "rating" {
                rating_seen = true
              }
              if field == "textInput" {
                text_input_seen = true
              }
            }
          } else if text_input_active &&
            depth == text_input_depth &&
            (
              is_rss_name(element.name, "title") ||
              is_rss_name(element.name, "description") ||
              is_rss_name(element.name, "name") ||
              is_rss_name(element.name, "link")
            ) {
            rss_optional_problem(
              diagnostics,
              record_errors,
              "textInput " + element.name.local_name,
              event.span.start.line,
              event.span.start.column,
            )
          }
        @xml.Text(value) | @xml.CData(value) =>
          if capture is Some(_) {
            capture_text = capture_text + value
          }
        @xml.End(name) => {
          if capture is Some(field) &&
            depth == capture_depth &&
            is_rss_name(name, field) {
            if capture_nested {
              if record_errors {
                diagnostics.push({
                  kind: UnsupportedNestedMarkup("rss " + field),
                  line: capture_line,
                  column: capture_column,
                })
              }
            } else {
              let value = non_blank_text(capture_text)
              if value is None {
                rss_optional_problem(
                  diagnostics,
                  record_errors,
                  if text_input_active {
                    "textInput " + field
                  } else {
                    field
                  },
                  capture_line,
                  capture_column,
                )
              } else if text_input_active {
                let previous = match field {
                  "title" => form_title
                  "description" => form_description
                  "name" => form_name
                  "link" => form_link
                  _ => None
                }
                if previous is Some(_) {
                  rss_optional_problem(
                    diagnostics,
                    record_errors,
                    "textInput " + field + " duplicate",
                    capture_line,
                    capture_column,
                  )
                } else {
                  match field {
                    "title" => form_title = value
                    "description" => form_description = value
                    "name" => form_name = value
                    "link" => form_link = value
                    _ => ()
                  }
                }
              } else if field == "docs" {
                docs_url = value
              } else if field == "rating" {
                rating = value
              }
            }
            capture = None
          }
          if text_input_active &&
            depth == text_input_depth &&
            is_rss_name(name, "textInput") {
            match (form_title, form_description, form_name, form_link) {
              (Some(title), Some(description), Some(name), Some(link)) =>
                text_input = Some({ title, description, name, link, })
              _ =>
                rss_optional_problem(
                  diagnostics, record_errors, "textInput required fields", form_line,
                  form_column,
                )
            }
            text_input_active = false
          }
          depth = depth - 1
        }
        @xml.Eof => {
          if source_url is Some(base) {
            if docs_url is Some(raw) {
              docs_url = Some(
                uri_at(
                  Some(base),
                  raw,
                  "rss channel docs",
                  docs_line,
                  docs_column,
                  diagnostics,
                ),
              )
            }
            if text_input is Some(form) {
              text_input = Some({
                title: form.title,
                description: form.description,
                name: form.name,
                link: uri_at(
                  Some(base),
                  form.link,
                  "rss channel textInput link",
                  form_line,
                  form_column,
                  diagnostics,
                ),
              })
            }
          }
          return Ok(
            with_rss_optional_channel(feed, docs_url, rating, cloud, text_input),
          )
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
