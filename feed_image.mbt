///|
fn rss_image_dimension(raw : String, maximum : Int32) -> Int32? {
  let raw = raw.trim()
  if raw.is_empty() {
    return None
  }
  let mut value = 0
  for character in raw {
    let digit = character.to_int() - 48
    if digit < 0 || digit > 9 || value > (maximum - digit) / 10 {
      return None
    }
    value = value * 10 + digit
    if value > maximum {
      return None
    }
  }
  if value == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn feed_image_problem(
  diagnostics : Array[Diagnostic],
  record_errors : Bool,
  message : String,
  line : Int32,
  column : Int32,
) -> Unit {
  if record_errors {
    diagnostics.push({ kind: InvalidFeedImage(message), line, column, })
  }
}

///|
fn with_feed_images(feed : Feed, images : Array[FeedImage]) -> Feed {
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
    images,
    entries: feed.entries,
    diagnostics: feed.diagnostics,
  }
}

///|
/// Scan only feed-level visuals after the core XML parse. The scan is also
/// reused with a source URL so Atom icon/logo URI text gets its own xml:base
/// scope. Core fields and entries are never reinterpreted by this pass.
fn add_xml_feed_images(
  input : String,
  feed : Feed,
  source_url : String?,
  record_errors : Bool,
) -> Result[Feed, ParseError] {
  let reader = @xml.NamespaceReader::from_string(input)
  let images : Array[FeedImage] = []
  let diagnostics = feed.diagnostics
  let bases : Array[String?] = []
  let base_scratch : Array[Diagnostic] = []
  let mut depth = 0
  let mut channel_depth = 0
  let mut rss_image_seen = false
  let mut atom_icon_seen = false
  let mut atom_logo_seen = false
  let mut rss_image_open = false
  let mut image_depth = 0
  let mut image_line = 1
  let mut image_column = 1
  let mut image_url : String? = None
  let mut image_url_location : (Int32, Int32)? = None
  let mut image_title : String? = None
  let mut image_link : String? = None
  let mut image_link_location : (Int32, Int32)? = None
  let mut image_description : String? = None
  let mut image_width : Int32? = None
  let mut image_height : Int32? = None
  let mut capture : String? = None
  let mut capture_depth = 0
  let mut capture_text = ""
  let mut capture_nested = false
  let mut capture_base : String? = None
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
          let parent_base = if bases.is_empty() {
            source_url
          } else {
            bases[bases.length() - 1]
          }
          let base = if source_url is Some(_) && feed.format == Atom1 {
            xml_effective_base(
              element,
              parent_base,
              Atom1,
              event.span.start.line,
              event.span.start.column,
              base_scratch,
            )
          } else {
            parent_base
          }
          if feed.format == Rss2 {
            if depth == 1 && is_rss_name(element.name, "channel") {
              channel_depth = depth + 1
            } else if depth == channel_depth &&
              channel_depth > 0 &&
              is_rss_name(element.name, "image") {
              if rss_image_seen {
                feed_image_problem(
                  diagnostics,
                  record_errors,
                  "multiple rss channel image elements",
                  event.span.start.line,
                  event.span.start.column,
                )
              } else {
                rss_image_seen = true
                rss_image_open = true
                image_depth = depth + 1
                image_line = event.span.start.line
                image_column = event.span.start.column
                image_url = None
                image_url_location = None
                image_title = None
                image_link = None
                image_link_location = None
                image_description = None
                image_width = None
                image_height = None
              }
            } else if rss_image_open &&
              depth == image_depth &&
              (
                is_rss_name(element.name, "url") ||
                is_rss_name(element.name, "title") ||
                is_rss_name(element.name, "link") ||
                is_rss_name(element.name, "description") ||
                is_rss_name(element.name, "width") ||
                is_rss_name(element.name, "height")
              ) {
              capture = Some(element.name.local_name)
              capture_depth = depth + 1
              capture_text = ""
              capture_nested = false
              capture_base = base
              capture_line = event.span.start.line
              capture_column = event.span.start.column
              if element.name.local_name == "url" {
                image_url_location = Some((capture_line, capture_column))
              } else if element.name.local_name == "link" {
                image_link_location = Some((capture_line, capture_column))
              }
            }
          } else if depth == 1 &&
            (
              is_atom_name(element.name, "icon") ||
              is_atom_name(element.name, "logo")
            ) {
            let is_icon = element.name.local_name == "icon"
            if (is_icon && atom_icon_seen) || (!is_icon && atom_logo_seen) {
              feed_image_problem(
                diagnostics,
                record_errors,
                "duplicate atom " + element.name.local_name,
                event.span.start.line,
                event.span.start.column,
              )
            } else {
              if is_icon {
                atom_icon_seen = true
              } else {
                atom_logo_seen = true
              }
              capture = Some(element.name.local_name)
              capture_depth = depth + 1
              capture_text = ""
              capture_nested = false
              capture_base = base
              capture_line = event.span.start.line
              capture_column = event.span.start.column
            }
          }
          bases.push(base)
          depth = depth + 1
        }
        @xml.Empty(element) =>
          if capture is Some(_) && depth >= capture_depth {
            capture_nested = true
          } else if feed.format == Rss2 &&
            depth == channel_depth &&
            channel_depth > 0 &&
            is_rss_name(element.name, "image") {
            if !rss_image_seen {
              rss_image_seen = true
              feed_image_problem(
                diagnostics,
                record_errors,
                "rss image missing url/title/link",
                event.span.start.line,
                event.span.start.column,
              )
            } else {
              feed_image_problem(
                diagnostics,
                record_errors,
                "multiple rss channel image elements",
                event.span.start.line,
                event.span.start.column,
              )
            }
          } else if feed.format == Rss2 &&
            rss_image_open &&
            depth == image_depth &&
            (
              is_rss_name(element.name, "width") ||
              is_rss_name(element.name, "height")
            ) {
            feed_image_problem(
              diagnostics,
              record_errors,
              "rss image invalid " + element.name.local_name,
              event.span.start.line,
              event.span.start.column,
            )
          } else if feed.format == Atom1 &&
            depth == 1 &&
            (
              is_atom_name(element.name, "icon") ||
              is_atom_name(element.name, "logo")
            ) {
            let is_icon = element.name.local_name == "icon"
            if (is_icon && atom_icon_seen) || (!is_icon && atom_logo_seen) {
              feed_image_problem(
                diagnostics,
                record_errors,
                "duplicate atom " + element.name.local_name,
                event.span.start.line,
                event.span.start.column,
              )
            } else {
              if is_icon {
                atom_icon_seen = true
              } else {
                atom_logo_seen = true
              }
              feed_image_problem(
                diagnostics,
                record_errors,
                "atom " + element.name.local_name + " missing URL",
                event.span.start.line,
                event.span.start.column,
              )
            }
          }
        @xml.Text(text) | @xml.CData(text) =>
          if capture is Some(_) {
            capture_text = capture_text + text
          }
        @xml.End(name) => {
          if capture is Some(field) &&
            capture_depth == depth &&
            (
              (feed.format == Rss2 && is_rss_name(name, field)) ||
              (feed.format == Atom1 && is_atom_name(name, field))
            ) {
            if capture_nested {
              if record_errors {
                diagnostics.push({
                  kind: UnsupportedNestedMarkup("feed image " + field),
                  line: capture_line,
                  column: capture_column,
                })
              }
            } else if feed.format == Rss2 {
              match field {
                "url" => image_url = non_blank_text(capture_text)
                "title" => image_title = non_blank_text(capture_text)
                "link" => image_link = non_blank_text(capture_text)
                "description" =>
                  image_description = non_blank_text(capture_text)
                "width" | "height" => {
                  let maximum = if field == "width" { 144 } else { 400 }
                  let dimension = rss_image_dimension(capture_text, maximum)
                  if dimension is None {
                    feed_image_problem(
                      diagnostics,
                      record_errors,
                      "rss image invalid " + field,
                      capture_line,
                      capture_column,
                    )
                  }
                  if field == "width" {
                    image_width = dimension
                  } else {
                    image_height = dimension
                  }
                }
                _ => ()
              }
            } else {
              match non_blank_text(capture_text) {
                Some(url) => {
                  let url = match source_url {
                    Some(_) =>
                      uri_at(
                        capture_base,
                        url,
                        "atom " + field,
                        capture_line,
                        capture_column,
                        diagnostics,
                      )
                    None => url
                  }
                  images.push({
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
                }
                None =>
                  feed_image_problem(
                    diagnostics,
                    record_errors,
                    "atom " + field + " missing URL",
                    capture_line,
                    capture_column,
                  )
              }
            }
            capture = None
            capture_text = ""
            capture_nested = false
          }
          if feed.format == Rss2 &&
            rss_image_open &&
            depth == image_depth &&
            is_rss_name(name, "image") {
            match (image_url, image_title, image_link) {
              (Some(url), Some(title), Some(link)) => {
                let (url_line, url_column) = image_url_location.unwrap_or(
                  (image_line, image_column),
                )
                let (link_line, link_column) = image_link_location.unwrap_or(
                  (image_line, image_column),
                )
                let (url, link) = match source_url {
                  Some(base) =>
                    (
                      uri_at(
                        Some(base),
                        url,
                        "rss image url",
                        url_line,
                        url_column,
                        diagnostics,
                      ),
                      uri_at(
                        Some(base),
                        link,
                        "rss image link",
                        link_line,
                        link_column,
                        diagnostics,
                      ),
                    )
                  None => (url, link)
                }
                images.push({
                  source: Rss2,
                  role: RssImage,
                  url,
                  title: Some(title),
                  link: Some(link),
                  description: image_description,
                  width: image_width,
                  height: image_height,
                })
              }
              _ =>
                feed_image_problem(
                  diagnostics, record_errors, "rss image missing url/title/link",
                  image_line, image_column,
                )
            }
            rss_image_open = false
          }
          depth = depth - 1
          ignore(bases.pop())
        }
        @xml.Eof => return Ok(with_feed_images(feed, images))
        _ => ()
      }
    }
    abort("unreachable")
  } catch {
    @xml.At(error~, span~) =>
      Err(InvalidXml(error.to_string(), span.start.line, span.start.column))
  }
}
