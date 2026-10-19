///|
/// A recovered problem that does not prevent the rest of an RSS feed from
/// being used. `line` and `column` are one-indexed source locations. A blank
/// channel field points to its element; an absent one points to `<channel>`.
pub struct Diagnostic {
  kind : DiagnosticKind
  line : Int32
  column : Int32
} derive(Debug, Eq)

///|
/// The kind of recoverable RSS data problem.
pub enum DiagnosticKind {
  MissingChannelField(String)
  MissingItemIdentifier(Int32)
  MissingFeedField(String)
  MissingEntryField(Int32, String)
  UnsupportedNestedMarkup(String)
  UnsupportedTextConstruct(String)
  UnsupportedAtomContent(String)
  MissingAlternateLink(Int32)
  MissingSummaryForExternalContent(Int32)
  InvalidAuthor(String)
  InvalidCategory(String)
  InvalidAttachment(String)
  InvalidLanguage(String)
  InvalidFeedImage(String)
  UnresolvedUri(String)
  InvalidJsonFeedField(String)
  InvalidJsonFeedItem(Int32, String)
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
/// Metadata for a related resource. `size_in_bytes` is limited to the largest
/// integer exactly representable by all three backends and JSON consumers.
/// `title` is available from Atom links and JSON Feed; duration is supplied
/// by JSON Feed only.
pub struct Attachment {
  source : FeedFormat
  url : String
  media_type : String?
  size_in_bytes : Int64?
  title : String?
  duration_in_seconds : Double?
} derive(Debug, Eq)

///|
/// A feed-level visual identity. Roles are source-specific; in particular an
/// Atom logo and JSON favicon are not interchangeable.
pub enum FeedImageRole {
  RssImage
  AtomIcon
  AtomLogo
  JsonIcon
  JsonFavicon
} derive(Debug, Eq)

///|
/// URL and optional RSS image metadata. Dimensions are declared pixel values,
/// not inferred image dimensions; no image resource is downloaded.
pub struct FeedImage {
  source : FeedFormat
  role : FeedImageRole
  url : String
  title : String?
  link : String?
  description : String?
  width : Int32?
  height : Int32?
} derive(Debug, Eq)

///|
/// JSON Feed item images serve distinct reader presentation roles.
pub enum EntryImageRole {
  JsonFeatured
  JsonBanner
} derive(Debug, Eq)

///|
/// An item image hint, separate from downloadable attachments.
pub struct EntryImage {
  source : FeedFormat
  role : EntryImageRole
  url : String
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
  /// JSON Feed `external_url` names an outside page, not the item permalink.
  external_url : String?
  /// Effective language for this entry when declared or inherited; no
  /// language is guessed from text or the local environment.
  language : String?
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
  attachments : Array[Attachment]
  images : Array[EntryImage]
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
  /// Declared feed language, if present; spelling is preserved.
  language : String?
  /// RSS channel `description`, Atom `subtitle`, or JSON Feed `description`.
  description : String?
  description_kind : TextKind
  /// Atom feed `updated`; RSS and JSON Feed have no corresponding feed-level
  /// core field in the supported subset.
  updated_at : String?
  authors : Array[Author]
  categories : Array[Category]
  images : Array[FeedImage]
  entries : Array[Entry]
  diagnostics : Array[Diagnostic]
} derive(Debug, Eq)

///|
fn with_entry_language(entry : Entry, language : String?) -> Entry {
  {
    identifier: entry.identifier,
    title: entry.title,
    title_kind: entry.title_kind,
    link: entry.link,
    external_url: entry.external_url,
    language,
    description: entry.description,
    description_kind: entry.description_kind,
    content: entry.content,
    content_kind: entry.content_kind,
    authors: entry.authors,
    categories: entry.categories,
    attachments: entry.attachments,
    images: entry.images,
    published_at: entry.published_at,
    updated_at: entry.updated_at,
  }
}

///|
/// A fatal error that prevents producing a feed.
pub enum ParseError {
  InvalidXml(String, Int32, Int32)
  UnsupportedRoot(String, String?)
  UnsupportedRssVersion(String?)
  MissingChannel
  InvalidRssStructure(String)
  InvalidJson(String, Int32, Int32)
  InvalidJsonFeed(String)
  UnsupportedJsonFeedVersion(String?)
  InvalidSourceUrl(String)
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
pub extend Attachment with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Attachment with Eq::{not_equal, equal}

///|
pub extend FeedImageRole with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FeedImageRole with Eq::{not_equal, equal}

///|
pub extend FeedImage with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FeedImage with Eq::{not_equal, equal}

///|
pub extend EntryImageRole with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EntryImageRole with Eq::{not_equal, equal}

///|
pub extend EntryImage with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EntryImage with Eq::{not_equal, equal}

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
fn xml_language_attribute(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == "lang" &&
      attribute.name.namespace_uri ==
      Some("http://www.w3.org/XML/1998/namespace") {
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
/// Byte counts are non-negative decimal integers within JS's exact integer
/// range. Validation happens before arithmetic, so malformed inputs cannot
/// wrap or be rounded by the JSON DOM's Double representation.
fn attachment_size(text : String) -> Int64? {
  let text = text.trim()
  if text.is_empty() {
    return None
  }
  let mut value = 0L
  for character in text {
    let digit = character.to_int() - 48
    if digit < 0 ||
      digit > 9 ||
      value > (9007199254740991L - digit.to_int64()) / 10L {
      return None
    }
    value = value * 10L + digit.to_int64()
  }
  Some(value)
}

///|
fn xml_attachment(
  element : @xml.NamespaceElement,
  source : FeedFormat,
  url_name : String,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> Attachment? {
  let url = match attribute_value(element, url_name) {
    Some(value) => non_blank_text(value)
    None => None
  }
  let media_type = match attribute_value(element, "type") {
    Some(value) => non_blank_text(value)
    None => None
  }
  let length = attribute_value(element, "length")
  let size = match length {
    Some(raw) =>
      match attachment_size(raw) {
        Some(value) => Some(value)
        None => {
          diagnostics.push({
            kind: InvalidAttachment("invalid length"),
            line,
            column,
          })
          None
        }
      }
    None => None
  }
  if url is None ||
    (source == Rss2 && (media_type is None || length is None || size is None)) {
    diagnostics.push({
      kind: InvalidAttachment(
        if source == Rss2 {
          "missing required RSS enclosure attribute"
        } else {
          "missing Atom enclosure href"
        },
      ),
      line,
      column,
    })
    return None
  }
  Some({
    source,
    url: url.unwrap(),
    media_type,
    size_in_bytes: size,
    title: if source == Atom1 {
      match attribute_value(element, "title") {
        Some(value) => non_blank_text(value)
        None => None
      }
    } else {
      None
    },
    duration_in_seconds: None,
  })
}

///|
fn missing_field_location(
  field_location : (Int32, Int32)?,
  channel_line : Int32,
  channel_column : Int32,
) -> (Int32, Int32) {
  field_location.unwrap_or((channel_line, channel_column))
}

///|
fn add_missing_channel_diagnostics(
  title : String?,
  link : String?,
  description : String?,
  title_location : (Int32, Int32)?,
  link_location : (Int32, Int32)?,
  description_location : (Int32, Int32)?,
  diagnostics : Array[Diagnostic],
  channel_line : Int32,
  channel_column : Int32,
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
    let mut channel_language : String? = None
    let mut channel_title_location : (Int32, Int32)? = None
    let mut channel_link_location : (Int32, Int32)? = None
    let mut channel_description_location : (Int32, Int32)? = None
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
    let mut item_attachments : Array[Attachment] = []

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
            item_attachments = []
          } else if item_open &&
            depth == item_depth &&
            is_rss_name(element.name, "enclosure") {
            match
              xml_attachment(
                element,
                Rss2,
                "url",
                event.span.start.line,
                event.span.start.column,
                diagnostics,
              ) {
              Some(attachment) => item_attachments.push(attachment)
              None => ()
            }
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
              is_rss_name(element.name, "description") ||
              is_rss_name(element.name, "language")
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
              "description" =>
                channel_description_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              _ => ()
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
              external_url: None,
              language: channel_language,
              description: None,
              description_kind: Unspecified,
              content: None,
              content_kind: Unspecified,
              authors: [],
              categories: [],
              attachments: [],
              images: [],
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
              is_rss_name(element.name, "description") ||
              is_rss_name(element.name, "language")
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
              "description" => {
                channel_description = None
                channel_description_location = Some(
                  (event.span.start.line, event.span.start.column),
                )
              }
              _ => {
                channel_language = None
                diagnostics.push({
                  kind: InvalidLanguage("rss channel language blank"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
            }
          } else if item_open &&
            depth == item_depth &&
            is_rss_name(element.name, "enclosure") {
            match
              xml_attachment(
                element,
                Rss2,
                "url",
                event.span.start.line,
                event.span.start.column,
                diagnostics,
              ) {
              Some(attachment) => item_attachments.push(attachment)
              None => ()
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
                  "description" => channel_description = None
                  _ => channel_language = None
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
                "description" =>
                  channel_description = non_blank_text(captured_text)
                _ => {
                  channel_language = non_blank_text(captured_text)
                  if channel_language is None {
                    diagnostics.push({
                      kind: InvalidLanguage("rss channel language blank"),
                      line: capture_line,
                      column: capture_column,
                    })
                  }
                }
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
              external_url: None,
              language: None,
              description: item_description,
              description_kind: Unspecified,
              content: item_content,
              content_kind: Unspecified,
              authors: item_authors,
              categories: item_categories,
              attachments: item_attachments,
              images: [],
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
          for index = 0; index < entries.length(); index = index + 1 {
            entries[index] = with_entry_language(
              entries[index],
              channel_language,
            )
          }
          return Ok({
            format: Rss2,
            identifier: None,
            title: channel_title,
            title_kind: Unspecified,
            link: channel_link,
            language: channel_language,
            description: channel_description,
            description_kind: Unspecified,
            updated_at: None,
            authors: [],
            categories: channel_categories,
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
            return match parse_rss(input) {
              Ok(feed) => add_xml_feed_images(input, feed, None, true)
              Err(error) => Err(error)
            }
          }
          if is_atom_name(element.name, "feed") {
            return match parse_atom(input) {
              Ok(feed) => add_xml_feed_images(input, feed, None, true)
              Err(error) => Err(error)
            }
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
