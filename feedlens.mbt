///|
/// A recovered problem that does not prevent the rest of an RSS feed from
/// being used. `line` and `column` are one-indexed source locations. A blank
/// channel field points to its element; an absent one points to `<channel>`.
pub struct Diagnostic {
  kind : DiagnosticKind
  line : Int
  column : Int
} derive(Debug, Eq)

///|
/// The kind of recoverable RSS data problem.
pub enum DiagnosticKind {
  MissingChannelField(String)
  MissingItemIdentifier(Int)
  MissingFeedField(String)
  MissingEntryField(Int, String)
  UnsupportedNestedMarkup(String)
  UnsupportedTextConstruct(String)
  UnsupportedAtomContent(String)
  MissingAlternateLink(Int)
  MissingSummaryForExternalContent(Int)
  InvalidAuthor(String)
  InvalidCategory(String)
  InvalidJsonFeedField(String)
  InvalidJsonFeedItem(Int, String)
} derive(Debug, Eq)

///|
/// The feed syntax accepted by this library.
pub enum FeedFormat {
  Rss2
  Atom1
  JsonFeed1
} derive(Debug, Eq)

///|
/// How a text field was declared by its source format.
pub enum TextKind {
  Unspecified
  Text
  Html
} derive(Debug, Eq)

///|
/// The source syntax that defines an author's fields.
pub enum AuthorSource {
  Rss2
  Atom1
  JsonFeed
} derive(Debug, Eq)

///|
/// An RSS raw author email, Atom person construct, or JSON Feed author. RSS
/// values use only `email`; JSON Feed maps its `url` to `uri`.
pub struct Author {
  source : AuthorSource
  name : String?
  uri : String?
  email : String?
} derive(Debug, Eq)

///|
/// A category whose optional metadata retains its source-specific meaning.
/// `domain` belongs only to RSS; `scheme` and `label` belong only to Atom.
/// JSON Feed tags use only `term`.
pub struct Category {
  source : FeedFormat
  term : String
  domain : String?
  scheme : String?
  label : String?
} derive(Debug, Eq)

///|
/// A normalized feed entry. Fields retain decoded source text without HTML
/// rendering or sanitization.
pub struct Entry {
  /// RSS: non-blank `guid`, otherwise non-blank `link`. Atom: entry `id`.
  /// JSON Feed: item `id` (a JSON number is retained as its JSON spelling).
  identifier : String?
  title : String?
  title_kind : TextKind
  link : String?
  /// RSS `description`, Atom `summary`, or JSON Feed `summary`.
  description : String?
  description_kind : TextKind
  /// RSS Content `encoded`, inline Atom `content`, or JSON Feed
  /// `content_html`/`content_text`. External Atom content is not fetched and
  /// therefore remains `None`.
  content : String?
  content_kind : TextKind
  authors : Array[Author]
  categories : Array[Category]
  /// RSS `pubDate`, Atom `published`, or JSON Feed `date_published`.
  published_at : String?
  /// Atom `updated` or JSON Feed `date_modified`; RSS has no corresponding
  /// core field.
  updated_at : String?
} derive(Debug, Eq)

///|
/// A normalized feed and its entries, in document order.
pub struct Feed {
  format : FeedFormat
  /// Atom feed `id` or JSON Feed `feed_url`; RSS has no corresponding core
  /// field.
  identifier : String?
  title : String?
  title_kind : TextKind
  link : String?
  /// RSS channel `description`, Atom `subtitle`, or JSON Feed `description`.
  description : String?
  description_kind : TextKind
  /// Atom feed `updated`; RSS and JSON Feed have no corresponding feed-level
  /// core field in the supported subset.
  updated_at : String?
  authors : Array[Author]
  categories : Array[Category]
  entries : Array[Entry]
  diagnostics : Array[Diagnostic]
} derive(Debug, Eq)

///|
/// A fatal error that prevents producing a feed.
pub enum ParseError {
  InvalidXml(String, Int, Int)
  UnsupportedRoot(String, String?)
  UnsupportedRssVersion(String?)
  MissingChannel
  InvalidRssStructure(String)
  InvalidJson(String, Int, Int)
  InvalidJsonFeed(String)
  UnsupportedJsonFeedVersion(String?)
} derive(Debug, Eq)

///|
pub extend Diagnostic with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Diagnostic with Eq::{not_equal, equal}

///|
pub extend DiagnosticKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DiagnosticKind with Eq::{not_equal, equal}

///|
pub extend FeedFormat with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FeedFormat with Eq::{not_equal, equal}

///|
pub extend TextKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TextKind with Eq::{not_equal, equal}

///|
pub extend AuthorSource with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AuthorSource with Eq::{not_equal, equal}

///|
pub extend Author with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Author with Eq::{not_equal, equal}

///|
pub extend Category with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Category with Eq::{not_equal, equal}

///|
pub extend Entry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Entry with Eq::{not_equal, equal}

///|
pub extend Feed with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Feed with Eq::{not_equal, equal}

///|
pub extend ParseError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
fn is_rss_name(name : @xml.XmlName, expected : String) -> Bool {
  name.local_name == expected && name.namespace_uri is None
}

///|
fn is_atom_name(name : @xml.XmlName, expected : String) -> Bool {
  name.local_name == expected &&
  name.namespace_uri == Some("http://www.w3.org/2005/Atom")
}

///|
fn is_rss_content_encoded(name : @xml.XmlName) -> Bool {
  name.local_name == "encoded" &&
  name.namespace_uri == Some("http://purl.org/rss/1.0/modules/content/")
}

///|
fn attribute_value(
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
fn non_blank_text(text : String) -> String? {
  if text.trim().is_empty() {
    None
  } else {
    Some(text)
  }
}

///|
fn missing_field_location(
  field_location : (Int, Int)?,
  channel_line : Int,
  channel_column : Int,
) -> (Int, Int) {
  field_location.unwrap_or((channel_line, channel_column))
}

///|
fn add_missing_channel_diagnostics(
  title : String?,
  link : String?,
  description : String?,
  title_location : (Int, Int)?,
  link_location : (Int, Int)?,
  description_location : (Int, Int)?,
  diagnostics : Array[Diagnostic],
  channel_line : Int,
  channel_column : Int,
) -> Unit {
  if title is None {
    let (line, column) = missing_field_location(
      title_location, channel_line, channel_column,
    )
    diagnostics.push({ kind: MissingChannelField("title"), line, column, })
  }
  if link is None {
    let (line, column) = missing_field_location(
      link_location, channel_line, channel_column,
    )
    diagnostics.push({ kind: MissingChannelField("link"), line, column, })
  }
  if description is None {
    let (line, column) = missing_field_location(
      description_location, channel_line, channel_column,
    )
    diagnostics.push({ kind: MissingChannelField("description"), line, column, })
  }
}

///|
/// Parse one RSS 2.0 XML document.
///
/// XML failures and unsupported document shapes return `Err`. Missing channel
/// fields and incomplete items return `Ok`, with `None` fields and diagnostics.
fn parse_rss(input : String) -> Result[Feed, ParseError] {
  let reader = @xml.NamespaceReader::from_string(input)
  try {
    let mut depth = 0
    let mut root_seen = false
    let mut channel_seen = false
    let mut channel_depth = 0
    let mut channel_line = 1
    let mut channel_column = 1
    let mut channel_title : String? = None
    let mut channel_link : String? = None
    let mut channel_description : String? = None
    let mut channel_title_location : (Int, Int)? = None
    let mut channel_link_location : (Int, Int)? = None
    let mut channel_description_location : (Int, Int)? = None
    let channel_categories : Array[Category] = []
    let entries : Array[Entry] = []
    let diagnostics : Array[Diagnostic] = []

    let mut item_open = false
    let mut item_depth = 0
    let mut item_line = 1
    let mut item_column = 1
    let mut item_guid : String? = None
    let mut item_title : String? = None
    let mut item_link : String? = None
    let mut item_description : String? = None
    let mut item_content : String? = None
    let mut item_published_at : String? = None
    let mut item_authors : Array[Author] = []
    let mut item_categories : Array[Category] = []

    let mut capture_field : String? = None
    let mut capture_depth = 0
    let mut captured_text = ""
    let mut capture_has_nested_markup = false
    let mut capture_line = 1
    let mut capture_column = 1
    let mut capture_category_domain : String? = None

    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) => {
          if capture_field is Some(_) && depth >= capture_depth {
            capture_has_nested_markup = true
          }
          if !root_seen {
            root_seen = true
            if !is_rss_name(element.name, "rss") {
              return Err(
                UnsupportedRoot(
                  element.name.qualified_name,
                  element.name.namespace_uri,
                ),
              )
            }
            let version = attribute_value(element, "version")
            if version != Some("2.0") {
              return Err(UnsupportedRssVersion(version))
            }
          } else if depth == 1 && is_rss_name(element.name, "channel") {
            if channel_seen {
              return Err(InvalidRssStructure("multiple channel elements"))
            }
            channel_seen = true
            channel_depth = depth + 1
            channel_line = event.span.start.line
            channel_column = event.span.start.column
          } else if channel_seen &&
            depth == channel_depth &&
            is_rss_name(element.name, "item") {
            item_open = true
            item_depth = depth + 1
            item_line = event.span.start.line
            item_column = event.span.start.column
            item_guid = None
            item_title = None
            item_link = None
            item_description = None
            item_content = None
            item_published_at = None
            item_authors = []
            item_categories = []
          } else if capture_field is None &&
            channel_seen &&
            depth == channel_depth &&
            !item_open &&
            is_rss_name(element.name, "category") {
            capture_field = Some("category")
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_line = event.span.start.line
            capture_column = event.span.start.column
            capture_category_domain = attribute_value(element, "domain")
          } else if capture_field is None &&
            channel_seen &&
            depth == channel_depth &&
            !item_open &&
            (
              is_rss_name(element.name, "title") ||
              is_rss_name(element.name, "link") ||
              is_rss_name(element.name, "description")
            ) {
            capture_field = Some(element.name.local_name)
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_category_domain = None
            capture_line = event.span.start.line
            capture_column = event.span.start.column
            match element.name.local_name {
              "title" =>
                channel_title_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              "link" =>
                channel_link_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              _ =>
                channel_description_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
            }
          } else if capture_field is None &&
            item_open &&
            depth == item_depth &&
            (
              is_rss_name(element.name, "guid") ||
              is_rss_name(element.name, "title") ||
              is_rss_name(element.name, "link") ||
              is_rss_name(element.name, "description") ||
              is_rss_name(element.name, "pubDate") ||
              is_rss_name(element.name, "author") ||
              is_rss_name(element.name, "category") ||
              is_rss_content_encoded(element.name)
            ) {
            capture_field = Some(
              if is_rss_content_encoded(element.name) {
                "content:encoded"
              } else {
                element.name.local_name
              },
            )
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_category_domain = if is_rss_name(element.name, "category") {
              attribute_value(element, "domain")
            } else {
              None
            }
            capture_line = event.span.start.line
            capture_column = event.span.start.column
          }
          depth = depth + 1
        }
        @xml.Empty(element) =>
          if capture_field is Some(_) && depth >= capture_depth {
            capture_has_nested_markup = true
          } else if !root_seen {
            root_seen = true
            if !is_rss_name(element.name, "rss") {
              return Err(
                UnsupportedRoot(
                  element.name.qualified_name,
                  element.name.namespace_uri,
                ),
              )
            }
            let version = attribute_value(element, "version")
            if version != Some("2.0") {
              return Err(UnsupportedRssVersion(version))
            }
          } else if depth == 1 && is_rss_name(element.name, "channel") {
            if channel_seen {
              return Err(InvalidRssStructure("multiple channel elements"))
            }
            channel_seen = true
            channel_depth = depth + 1
            channel_line = event.span.start.line
            channel_column = event.span.start.column
          } else if channel_seen &&
            depth == channel_depth &&
            is_rss_name(element.name, "item") {
            let item_index = entries.length()
            entries.push({
              identifier: None,
              title: None,
              title_kind: Unspecified,
              link: None,
              description: None,
              description_kind: Unspecified,
              content: None,
              content_kind: Unspecified,
              authors: [],
              categories: [],
              published_at: None,
              updated_at: None,
            })
            diagnostics.push({
              kind: MissingItemIdentifier(item_index),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if channel_seen &&
            depth == channel_depth &&
            !item_open &&
            is_rss_name(element.name, "category") {
            diagnostics.push({
              kind: InvalidCategory("rss category missing term"),
              line: event.span.start.line,
              column: event.span.start.column,
            })
          } else if channel_seen &&
            depth == channel_depth &&
            !item_open &&
            (
              is_rss_name(element.name, "title") ||
              is_rss_name(element.name, "link") ||
              is_rss_name(element.name, "description")
            ) {
            match element.name.local_name {
              "title" => {
                channel_title = None
                channel_title_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              }
              "link" => {
                channel_link = None
                channel_link_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              }
              _ => {
                channel_description = None
                channel_description_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              }
            }
          } else if item_open &&
            depth == item_depth &&
            (
              is_rss_name(element.name, "guid") ||
              is_rss_name(element.name, "title") ||
              is_rss_name(element.name, "link") ||
              is_rss_name(element.name, "description") ||
              is_rss_name(element.name, "pubDate") ||
              is_rss_name(element.name, "author") ||
              is_rss_name(element.name, "category") ||
              is_rss_content_encoded(element.name)
            ) {
            if is_rss_content_encoded(element.name) {
              item_content = Some("")
            } else if is_rss_name(element.name, "author") {
              diagnostics.push({
                kind: InvalidAuthor("rss author missing email"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            } else if is_rss_name(element.name, "category") {
              diagnostics.push({
                kind: InvalidCategory("rss category missing term"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            } else {
              match element.name.local_name {
                "guid" => item_guid = None
                "title" => item_title = None
                "link" => item_link = None
                "description" => item_description = None
                _ => item_published_at = None
              }
            }
          }
        @xml.Text(text) | @xml.CData(text) =>
          if capture_field is Some(_) {
            captured_text = captured_text + text
          }
        @xml.End(name) => {
          if capture_field is Some(field) &&
            capture_depth == depth &&
            (
              is_rss_name(name, field) ||
              (field == "content:encoded" && is_rss_content_encoded(name))
            ) {
            if capture_has_nested_markup {
              diagnostics.push({
                kind: UnsupportedNestedMarkup("rss " + field),
                line: capture_line,
                column: capture_column,
              })
              if item_open {
                match field {
                  "guid" => item_guid = None
                  "title" => item_title = None
                  "link" => item_link = None
                  "description" => item_description = None
                  "content:encoded" => item_content = None
                  "author" => ()
                  "category" => ()
                  _ => item_published_at = None
                }
              } else {
                match field {
                  "title" => channel_title = None
                  "link" => channel_link = None
                  _ => channel_description = None
                }
              }
            } else if item_open {
              match field {
                "guid" => item_guid = non_blank_text(captured_text)
                "title" => item_title = non_blank_text(captured_text)
                "link" => item_link = non_blank_text(captured_text)
                "description" =>
                  item_description = non_blank_text(captured_text)
                "content:encoded" => item_content = Some(captured_text)
                "author" =>
                  match non_blank_text(captured_text) {
                    Some(email) =>
                      item_authors.push({
                        source: Rss2,
                        name: None,
                        uri: None,
                        email: Some(email),
                      })
                    None =>
                      diagnostics.push({
                        kind: InvalidAuthor("rss author missing email"),
                        line: capture_line,
                        column: capture_column,
                      })
                  }
                "category" =>
                  match non_blank_text(captured_text) {
                    Some(term) =>
                      item_categories.push({
                        source: Rss2,
                        term,
                        domain: capture_category_domain,
                        scheme: None,
                        label: None,
                      })
                    None =>
                      diagnostics.push({
                        kind: InvalidCategory("rss category missing term"),
                        line: capture_line,
                        column: capture_column,
                      })
                  }
                _ => item_published_at = non_blank_text(captured_text)
              }
            } else {
              match field {
                "title" => channel_title = non_blank_text(captured_text)
                "link" => channel_link = non_blank_text(captured_text)
                "category" =>
                  match non_blank_text(captured_text) {
                    Some(term) =>
                      channel_categories.push({
                        source: Rss2,
                        term,
                        domain: capture_category_domain,
                        scheme: None,
                        label: None,
                      })
                    None =>
                      diagnostics.push({
                        kind: InvalidCategory("rss category missing term"),
                        line: capture_line,
                        column: capture_column,
                      })
                  }
                _ => channel_description = non_blank_text(captured_text)
              }
            }
            capture_field = None
            captured_text = ""
            capture_has_nested_markup = false
            capture_category_domain = None
          }
          if item_open && depth == item_depth && is_rss_name(name, "item") {
            let item_index = entries.length()
            let identifier = match item_guid {
              Some(guid) => Some(guid)
              None => item_link
            }
            entries.push({
              identifier,
              title: item_title,
              title_kind: Unspecified,
              link: item_link,
              description: item_description,
              description_kind: Unspecified,
              content: item_content,
              content_kind: Unspecified,
              authors: item_authors,
              categories: item_categories,
              published_at: item_published_at,
              updated_at: None,
            })
            if identifier is None {
              diagnostics.push({
                kind: MissingItemIdentifier(item_index),
                line: item_line,
                column: item_column,
              })
            }
            item_open = false
          }
          depth = depth - 1
        }
        @xml.Eof => {
          if !channel_seen {
            return Err(MissingChannel)
          }
          add_missing_channel_diagnostics(
            channel_title, channel_link, channel_description, channel_title_location,
            channel_link_location, channel_description_location, diagnostics, channel_line,
            channel_column,
          )
          return Ok({
            format: Rss2,
            identifier: None,
            title: channel_title,
            title_kind: Unspecified,
            link: channel_link,
            description: channel_description,
            description_kind: Unspecified,
            updated_at: None,
            authors: [],
            categories: channel_categories,
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

///|
/// Parse one RSS 2.0, Atom 1.0, or JSON Feed 1.0/1.1 document.
///
/// Inputs whose first non-whitespace character is `<` are treated as XML; all
/// other inputs are treated as JSON. XML failures and JSON syntax/structural
/// failures return `Err`. Recoverable field problems return `Ok` with
/// diagnostics.
pub fn parse(input : String) -> Result[Feed, ParseError] {
  if !input.trim().has_prefix("<") {
    return parse_json_feed(input)
  }
  let reader = @xml.NamespaceReader::from_string(input)
  try {
    for ;; {
      let event = reader.read_event()
      match event.kind {
        @xml.Start(element) | @xml.Empty(element) => {
          if is_rss_name(element.name, "rss") {
            return parse_rss(input)
          }
          if is_atom_name(element.name, "feed") {
            return parse_atom(input)
          }
          return Err(
            UnsupportedRoot(
              element.name.qualified_name,
              element.name.namespace_uri,
            ),
          )
        }
        @xml.Eof => return Err(InvalidRssStructure("missing root element"))
        _ => ()
      }
    }
    abort("unreachable")
  } catch {
    @xml.At(error~, span~) =>
      Err(InvalidXml(error.to_string(), span.start.line, span.start.column))
  }
}
