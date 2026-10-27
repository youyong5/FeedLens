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
  MissingItemContent(Int32)
  MissingFeedField(String)
  MissingEntryField(Int32, String)
  UnsupportedNestedMarkup(String)
  UnsupportedTextConstruct(String)
  UnsupportedAtomContent(String)
  MissingAlternateLink(Int32)
  MissingSummaryForExternalContent(Int32)
  MissingSummaryForBinaryContent(Int32)
  DuplicateAtomField(String)
  InvalidAuthor(String)
  InvalidCategory(String)
  InvalidAttachment(String)
  InvalidLanguage(String)
  InvalidFeedImage(String)
  InvalidRssField(String)
  UnnormalizedRssDate(String)
  InvalidAtomLink(String)
  InvalidAtomDate(String)
  InvalidAtomOrder(String)
  UnresolvedUri(String)
  InvalidJsonFeedField(String)
  InvalidJsonFeedItem(Int32, String)
  InvalidJsonFeedDate(Int32, String)
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
  Xhtml
} derive(Debug, Eq)

///|
/// An attribute declared on the outer Atom XHTML div. Names are expanded
/// into namespace URI and local name so prefixes do not affect callers.
pub struct XhtmlAttribute {
  local_name : String
  namespace_uri : String?
  value : String
} derive(Debug, Eq)

///|
pub extend XhtmlAttribute with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend XhtmlAttribute with Eq::{not_equal, equal}

///|
/// An Atom XHTML fragment. `markup` omits the required outer XHTML div and
/// uses deterministic namespace-qualified XML serialization. `language` is
/// the effective xml:lang at that div; `base_references` retains the ordered
/// xml:base declarations from the feed/entry, text construct, and div. The
/// latter are raw references, not guessed absolute URLs. `container_attributes`
/// retains the discarded div's attributes in source order, including xml:lang
/// and xml:base; markup and attributes are unsanitized.
pub struct XhtmlFragment {
  markup : String
  language : String?
  base_references : Array[String]
  container_attributes : Array[XhtmlAttribute]
} derive(Debug, Eq)

///|
/// An XML media-type Atom body, serialized with stable namespace-qualified
/// names. Unlike XHTML, no wrapper element is removed. This is unsanitized.
pub struct XmlFragment {
  markup : String
  language : String?
  base_references : Array[String]
} derive(Debug, Eq)

///|
/// An Atom out-of-line body reference. `src` is the original IRI reference;
/// `url` is that reference after optional source resolution. `base_uri` is
/// present only when an absolute effective base is known. No fetch occurs.
pub struct AtomExternalContent {
  src : String
  url : String
  media_type : String?
  base_uri : String?
} derive(Debug, Eq)

///|
/// Detailed Atom body representation. `Bytes` contains exact decoded octets
/// on Wasm, JS, and Native. MIME spelling is kept.
pub enum AtomBody {
  InlineText(String, String)
  InlineHtml(String)
  InlineXhtml(XhtmlFragment)
  InlineXml(XmlFragment, String)
  InlineBinary(Bytes, String)
  External(AtomExternalContent)
} derive(Debug, Eq)

///|
pub extend XmlFragment with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend XmlFragment with Eq::{not_equal, equal}

///|
pub extend AtomExternalContent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomExternalContent with Eq::{not_equal, equal}

///|
pub extend AtomBody with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomBody with Eq::{not_equal, equal}

///|
/// The source syntax that defines an author's fields.
pub enum AuthorSource {
  Rss2
  DublinCore
  Atom1
  JsonFeed
} derive(Debug, Eq)

///|
/// An RSS raw author email, Dublin Core creator name, Atom person construct,
/// or JSON Feed author. RSS uses `email`, Dublin Core uses `name`, and JSON
/// Feed maps its `url` to `uri`.
pub struct Author {
  source : AuthorSource
  name : String?
  uri : String?
  email : String?
  /// JSON Feed author avatar URL; not a feed or entry image.
  avatar : String?
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
/// JSON Feed hub declaration. Parsing does not subscribe or send notifications.
pub struct Hub {
  transport_type : String
  url : String
} derive(Debug, Eq)

///|
/// An Atom link, including relations beyond the convenience alternate link
/// and enclosure attachment fields. A missing rel is represented as alternate.
pub struct AtomLink {
  relation : String
  href : String
  media_type : String?
  hreflang : String?
  title : String?
  length : Int64?
} derive(Debug, Eq)

///|
/// Metadata retained from an Atom entry's original feed when it is copied
/// into another feed. Missing members remain absent: atom:source may carry
/// only some of its original feed's metadata.
pub struct AtomSource {
  identifier : String?
  title : String?
  title_kind : TextKind
  title_xhtml : XhtmlFragment?
  subtitle : String?
  subtitle_kind : TextKind
  subtitle_xhtml : XhtmlFragment?
  updated_at : String?
  rights : String?
  rights_kind : TextKind
  rights_xhtml : XhtmlFragment?
  generator : String?
  generator_uri : String?
  generator_version : String?
  authors : Array[Author]
  contributors : Array[Author]
  categories : Array[Category]
  link : String?
  links : Array[AtomLink]
  images : Array[FeedImage]
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
  /// Present only for a successfully captured Atom XHTML title.
  title_xhtml : XhtmlFragment?
  /// RSS item `link`, or a usable HTTP(S) permalink guid when link is absent.
  /// Other formats retain their own link mapping.
  link : String?
  /// JSON Feed `external_url` names an outside page, not the item permalink.
  external_url : String?
  /// Effective language for this entry when declared or inherited; no
  /// language is guessed from text or the local environment.
  language : String?
  /// RSS `description`, Atom `summary`, or JSON Feed `summary`.
  description : String?
  description_kind : TextKind
  /// Present only for a successfully captured Atom XHTML summary.
  description_xhtml : XhtmlFragment?
  /// RSS Content `encoded`, inline Atom `content`, or JSON Feed
  /// `content_html`/`content_text`. External Atom content is not fetched and
  /// therefore remains `None`.
  content : String?
  /// JSON Feed can supply both representations; `content` remains the
  /// established HTML-preferred convenience field.
  content_text : String?
  content_html : String?
  content_kind : TextKind
  /// Present only for a successfully captured inline Atom XHTML body.
  content_xhtml : XhtmlFragment?
  /// Raw Atom content `src`, or resolved against its scoped xml:base by
  /// `parse_with_source`. No external resource is fetched.
  content_source : String?
  /// Atom content `type` as declared (including media types); `None` when
  /// omitted or for other feed formats.
  content_media_type : String?
  /// Detailed Atom body; `None` for RSS/JSON Feed and failed Atom extraction.
  atom_body : AtomBody?
  atom_source : AtomSource?
  links : Array[AtomLink]
  /// RSS item comments/source and Atom rights retain their distinct roles.
  comments_url : String?
  source_url : String?
  /// RSS source channel's declared title; separate from this item's title.
  source_title : String?
  /// RSS guid: true when isPermaLink is omitted or true, false when false;
  /// None when there is no usable guid or for non-RSS entries.
  guid_is_permalink : Bool?
  rights : String?
  rights_kind : TextKind
  rights_xhtml : XhtmlFragment?
  authors : Array[Author]
  contributors : Array[Author]
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
/// RSS 2.0 cloud registration descriptor. Its values are metadata only.
pub struct RssCloud {
  domain : String
  port : Int32
  path : String
  register_procedure : String
  protocol : String
} derive(Debug, Eq)

///|
/// RSS 2.0 textInput form descriptor. The link is resolved only when a
/// document source URL is supplied.
pub struct RssTextInput {
  title : String
  description : String
  name : String
  link : String
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
  /// Present only for a successfully captured Atom XHTML feed title.
  title_xhtml : XhtmlFragment?
  link : String?
  /// Declared feed language, if present; spelling is preserved.
  language : String?
  /// RSS channel `description`, Atom `subtitle`, or JSON Feed `description`.
  description : String?
  description_kind : TextKind
  /// Present only for a successfully captured Atom XHTML subtitle.
  description_xhtml : XhtmlFragment?
  /// Atom feed updated, or RSS channel lastBuildDate, preserved verbatim.
  updated_at : String?
  /// RSS channel pubDate and ttl; absent on other formats.
  published_at : String?
  ttl_minutes : Int32?
  /// RSS channel advisory specification URL, retained as a reference.
  docs_url : String?
  /// RSS channel PICS rating, retained without interpretation.
  rating : String?
  /// RSS notification endpoint metadata; no registration is performed.
  cloud : RssCloud?
  /// RSS legacy search form metadata; no form is rendered or submitted.
  text_input : RssTextInput?
  /// RSS 2.0 advisory GMT hours (0–23) and weekday names in source order.
  /// An empty array means no usable hint; these do not schedule fetching.
  skip_hours : Array[Int32]
  skip_days : Array[String]
  /// RSS copyright / Atom rights, and RSS / Atom generator text.
  rights : String?
  rights_kind : TextKind
  rights_xhtml : XhtmlFragment?
  generator : String?
  generator_uri : String?
  generator_version : String?
  /// RSS contact addresses retain their distinct editorial and technical roles.
  managing_editor : String?
  webmaster : String?
  /// JSON Feed pagination is only a reference; the library never follows it.
  next_url : String?
  /// JSON Feed expired is tri-state: absent differs from explicit false.
  expired : Bool?
  hubs : Array[Hub]
  links : Array[AtomLink]
  authors : Array[Author]
  contributors : Array[Author]
  categories : Array[Category]
  images : Array[FeedImage]
  entries : Array[Entry]
  diagnostics : Array[Diagnostic]
} derive(Debug, Eq)

///|
/// A complete feed or a stand-alone Atom Entry Document. An entry document
/// has its own diagnostics and does not invent enclosing feed metadata.
pub enum ParsedDocument {
  FeedDocument(Feed)
  AtomEntryDocument(Entry, Array[Diagnostic])
} derive(Debug, Eq)

///|
fn with_entry_language(entry : Entry, language : String?) -> Entry {
  {
    identifier: entry.identifier,
    title: entry.title,
    title_kind: entry.title_kind,
    title_xhtml: entry.title_xhtml,
    link: entry.link,
    external_url: entry.external_url,
    language,
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
    authors: entry.authors,
    contributors: entry.contributors,
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
  InvalidAtomStructure(String)
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
pub extend XhtmlFragment with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend XhtmlFragment with Eq::{not_equal, equal}

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
pub extend Hub with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Hub with Eq::{not_equal, equal}

///|
pub extend RssCloud with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RssCloud with Eq::{not_equal, equal}

///|
pub extend RssTextInput with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RssTextInput with Eq::{not_equal, equal}

///|
pub extend AtomLink with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomLink with Eq::{not_equal, equal}

///|
pub extend AtomSource with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AtomSource with Eq::{not_equal, equal}

///|
pub extend Entry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Entry with Eq::{not_equal, equal}

///|
pub extend Feed with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Feed with Eq::{not_equal, equal}

///|
pub extend ParsedDocument with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParsedDocument with Eq::{not_equal, equal}

///|
pub extend ParseError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
fn is_rss_name(name : @xml.XmlName, expected : String) -> Bool {
  name.local_name == expected && name.namespace_uri is None
}

///|
// A guid may be an arbitrary identifier even when isPermaLink defaults to
// true. Project it as a link only when it is a usable web URL.
fn rss_item_link(link : String?, guid : String?, is_permalink : Bool?) -> String? {
  if link is Some(_) {
    return link
  }
  guard is_permalink is Some(true) else { return None }
  guard guid is Some(value) else { return None }
  guard uri_parts(value) is Some(parts) else { return None }
  guard parts.scheme is Some(scheme) else { return None }
  if (scheme.to_lower() == "http" || scheme.to_lower() == "https") &&
    uri_valid_absolute(parts) {
    Some(value)
  } else {
    None
  }
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
fn is_rss_dc_creator(name : @xml.XmlName) -> Bool {
  name.local_name == "creator" &&
  name.namespace_uri == Some("http://purl.org/dc/elements/1.1/")
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
// A failed normalization is diagnostic, not a claim that every legal RFC 822
// spelling is rejected by RSS. Preserve the source text for the caller.
fn rss_date_value(
  raw : String,
  field : String,
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> String? {
  match normalize_date(Rss2, Some(raw)) {
    Ok(_) => ()
    Err(_) => diagnostics.push({
      kind: UnnormalizedRssDate(field),
      line,
      column,
    })
  }
  non_blank_text(raw)
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
fn rss_ttl_minutes(raw : String) -> Int32? {
  let raw = raw.trim()
  if raw.is_empty() {
    return None
  }
  let mut minutes = 0
  for character in raw {
    let digit = character.to_int() - 48
    if digit < 0 || digit > 9 || minutes > (2147483647 - digit) / 10 {
      return None
    }
    minutes = minutes * 10 + digit
  }
  Some(minutes)
}

///|
fn rss_skip_hour(
  raw : String,
  count : Int32,
  hours : Array[Int32],
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match rss_ttl_minutes(raw) {
    Some(hour) if hour <= 23 && count <= 24 => hours.push(hour)
    _ =>
      diagnostics.push({
        kind: InvalidRssField("skipHours hour"),
        line,
        column,
      })
  }
}

///|
fn rss_skip_day(
  raw : String,
  count : Int32,
  days : Array[String],
  line : Int32,
  column : Int32,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let day = raw.trim()
  if count <= 7 &&
    (
      day == "Monday" ||
      day == "Tuesday" ||
      day == "Wednesday" ||
      day == "Thursday" ||
      day == "Friday" ||
      day == "Saturday" ||
      day == "Sunday"
    ) {
    days.push(day.to_owned())
  } else {
    diagnostics.push({ kind: InvalidRssField("skipDays day"), line, column, })
  }
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
    Some(value) if source == Atom1 && value.is_empty() => Some(value)
    Some(value) => non_blank_text(value)
    None => None
  }
  let media_type = match attribute_value(element, "type") {
    Some(value) if source == Atom1 => Some(value)
    Some(value) => non_blank_text(value)
    None => None
  }
  if source == Atom1 {
    match attribute_value(element, "type") {
      Some(raw) if atom_mime_essence(raw) is None =>
        diagnostics.push({
          kind: InvalidAttachment("invalid Atom enclosure type"),
          line,
          column,
        })
      _ => ()
    }
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
        Some(value) => Some(value)
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
    let mut channel_rights : String? = None
    let mut channel_generator : String? = None
    let mut channel_managing_editor : String? = None
    let mut channel_webmaster : String? = None
    let mut channel_published : String? = None
    let mut channel_updated : String? = None
    let mut channel_ttl : Int32? = None
    let channel_skip_hours : Array[Int32] = []
    let channel_skip_days : Array[String] = []
    let mut skip_kind : String? = None
    let mut skip_depth = 0
    let mut skip_child_count = 0
    let mut skip_ignored = false
    let mut skip_hours_seen = false
    let mut skip_days_seen = false
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
    let mut item_guid_is_permalink : Bool? = None
    let mut item_title : String? = None
    let mut item_link : String? = None
    let mut item_description : String? = None
    let mut item_content : String? = None
    let mut item_published_at : String? = None
    let mut item_comments_url : String? = None
    let mut item_source_url : String? = None
    let mut item_source_title : String? = None
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
    let mut capture_guid_is_permalink : Bool? = None

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
            item_guid_is_permalink = None
            item_title = None
            item_link = None
            item_description = None
            item_content = None
            item_published_at = None
            item_comments_url = None
            item_source_url = None
            item_source_title = None
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
          } else if channel_seen &&
            depth == channel_depth &&
            !item_open &&
            (
              is_rss_name(element.name, "skipHours") ||
              is_rss_name(element.name, "skipDays")
            ) {
            let kind = element.name.local_name
            skip_ignored = if kind == "skipHours" {
              let seen = skip_hours_seen
              skip_hours_seen = true
              seen
            } else {
              let seen = skip_days_seen
              skip_days_seen = true
              seen
            }
            if skip_ignored {
              diagnostics.push({
                kind: InvalidRssField(kind + " duplicate"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
            skip_kind = Some(kind)
            skip_depth = depth + 1
            skip_child_count = 0
          } else if skip_kind is Some(kind) &&
            !skip_ignored &&
            depth == skip_depth &&
            (
              (kind == "skipHours" && is_rss_name(element.name, "hour")) ||
              (kind == "skipDays" && is_rss_name(element.name, "day"))
            ) {
            skip_child_count = skip_child_count + 1
            capture_field = Some(element.name.local_name)
            capture_depth = depth + 1
            captured_text = ""
            capture_has_nested_markup = false
            capture_line = event.span.start.line
            capture_column = event.span.start.column
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
              is_rss_name(element.name, "language") ||
              is_rss_name(element.name, "copyright") ||
              is_rss_name(element.name, "generator") ||
              is_rss_name(element.name, "managingEditor") ||
              is_rss_name(element.name, "webMaster") ||
              is_rss_name(element.name, "pubDate") ||
              is_rss_name(element.name, "lastBuildDate") ||
              is_rss_name(element.name, "ttl")
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
              is_rss_name(element.name, "comments") ||
              is_rss_name(element.name, "source") ||
              is_rss_dc_creator(element.name) ||
              is_rss_content_encoded(element.name)
            ) {
            capture_field = Some(
              if is_rss_dc_creator(element.name) {
                "dc:creator"
              } else if is_rss_content_encoded(element.name) {
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
            if is_rss_name(element.name, "guid") {
              capture_guid_is_permalink = match
                attribute_value(element, "isPermaLink") {
                None | Some("true") => Some(true)
                Some("false") => Some(false)
                Some(_) => {
                  diagnostics.push({
                    kind: InvalidRssField("guid isPermaLink"),
                    line: event.span.start.line,
                    column: event.span.start.column,
                  })
                  None
                }
              }
            }
            if is_rss_name(element.name, "source") {
              item_source_url = match attribute_value(element, "url") {
                Some(value) => non_blank_text(value)
                None => None
              }
              if item_source_url is None {
                diagnostics.push({
                  kind: InvalidRssField("source url"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
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
              title_xhtml: None,
              link: None,
              external_url: None,
              language: channel_language,
              description: None,
              description_kind: Unspecified,
              description_xhtml: None,
              content: None,
              content_text: None,
              content_html: None,
              content_kind: Unspecified,
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
              authors: [],
              contributors: [],
              categories: [],
              attachments: [],
              images: [],
              published_at: None,
              updated_at: None,
            })
            diagnostics.push({
              kind: MissingItemContent(item_index),
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
              is_rss_name(element.name, "skipHours") ||
              is_rss_name(element.name, "skipDays")
            ) {
            let kind = element.name.local_name
            let seen = if kind == "skipHours" {
              let seen = skip_hours_seen
              skip_hours_seen = true
              seen
            } else {
              let seen = skip_days_seen
              skip_days_seen = true
              seen
            }
            if seen {
              diagnostics.push({
                kind: InvalidRssField(kind + " duplicate"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            }
          } else if skip_kind is Some(kind) &&
            !skip_ignored &&
            depth == skip_depth &&
            (
              (kind == "skipHours" && is_rss_name(element.name, "hour")) ||
              (kind == "skipDays" && is_rss_name(element.name, "day"))
            ) {
            skip_child_count = skip_child_count + 1
            if kind == "skipHours" {
              rss_skip_hour(
                "",
                skip_child_count,
                channel_skip_hours,
                event.span.start.line,
                event.span.start.column,
                diagnostics,
              )
            } else {
              rss_skip_day(
                "",
                skip_child_count,
                channel_skip_days,
                event.span.start.line,
                event.span.start.column,
                diagnostics,
              )
            }
          } else if channel_seen &&
            depth == channel_depth &&
            !item_open &&
            (
              is_rss_name(element.name, "title") ||
              is_rss_name(element.name, "link") ||
              is_rss_name(element.name, "description") ||
              is_rss_name(element.name, "language") ||
              is_rss_name(element.name, "copyright") ||
              is_rss_name(element.name, "generator") ||
              is_rss_name(element.name, "managingEditor") ||
              is_rss_name(element.name, "webMaster") ||
              is_rss_name(element.name, "pubDate") ||
              is_rss_name(element.name, "lastBuildDate") ||
              is_rss_name(element.name, "ttl")
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
              "language" => {
                channel_language = None
                diagnostics.push({
                  kind: InvalidLanguage("rss channel language blank"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
              "copyright" => channel_rights = None
              "generator" => channel_generator = None
              "managingEditor" => channel_managing_editor = None
              "webMaster" => channel_webmaster = None
              "pubDate" => channel_published = rss_date_value(
                "", "channel pubDate", event.span.start.line,
                event.span.start.column, diagnostics,
              )
              "lastBuildDate" => channel_updated = rss_date_value(
                "", "channel lastBuildDate", event.span.start.line,
                event.span.start.column, diagnostics,
              )
              _ => {
                channel_ttl = None
                diagnostics.push({
                  kind: InvalidRssField("ttl"),
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
              is_rss_name(element.name, "comments") ||
              is_rss_name(element.name, "source") ||
              is_rss_dc_creator(element.name) ||
              is_rss_content_encoded(element.name)
            ) {
            if is_rss_dc_creator(element.name) {
              diagnostics.push({
                kind: InvalidAuthor("dublin core creator missing name"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
            } else if is_rss_content_encoded(element.name) {
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
            } else if is_rss_name(element.name, "source") {
              item_source_url = match attribute_value(element, "url") {
                Some(value) => non_blank_text(value)
                None => None
              }
              diagnostics.push({
                kind: InvalidRssField("source title"),
                line: event.span.start.line,
                column: event.span.start.column,
              })
              if item_source_url is None {
                diagnostics.push({
                  kind: InvalidRssField("source url"),
                  line: event.span.start.line,
                  column: event.span.start.column,
                })
              }
            } else if is_rss_name(element.name, "comments") {
              item_comments_url = None
            } else {
              match element.name.local_name {
                "guid" => {
                  item_guid = None
                  item_guid_is_permalink = None
                }
                "title" => item_title = None
                "link" => item_link = None
                "description" => item_description = None
                "pubDate" => item_published_at = rss_date_value(
                  "", "item pubDate", event.span.start.line,
                  event.span.start.column, diagnostics,
                )
                _ => ()
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
              (field == "content:encoded" && is_rss_content_encoded(name)) ||
              (field == "dc:creator" && is_rss_dc_creator(name))
            ) {
            if capture_has_nested_markup {
              diagnostics.push({
                kind: UnsupportedNestedMarkup("rss " + field),
                line: capture_line,
                column: capture_column,
              })
              if field == "hour" || field == "day" {
                ()
              } else if item_open {
                match field {
                  "guid" => {
                    item_guid = None
                    item_guid_is_permalink = None
                  }
                  "title" => item_title = None
                  "link" => item_link = None
                  "description" => item_description = None
                  "content:encoded" => item_content = None
                  "author" => ()
                  "dc:creator" => ()
                  "category" => ()
                  "comments" => item_comments_url = None
                  "source" => item_source_title = None
                  _ => item_published_at = None
                }
              } else {
                match field {
                  "title" => channel_title = None
                  "link" => channel_link = None
                  "description" => channel_description = None
                  "copyright" => channel_rights = None
                  "generator" => channel_generator = None
                  "managingEditor" => channel_managing_editor = None
                  "webMaster" => channel_webmaster = None
                  "pubDate" => channel_published = None
                  "lastBuildDate" => channel_updated = None
                  "ttl" => channel_ttl = None
                  _ => channel_language = None
                }
              }
            } else if field == "hour" {
              rss_skip_hour(
                captured_text, skip_child_count, channel_skip_hours, capture_line,
                capture_column, diagnostics,
              )
            } else if field == "day" {
              rss_skip_day(
                captured_text, skip_child_count, channel_skip_days, capture_line,
                capture_column, diagnostics,
              )
            } else if item_open {
              match field {
                "guid" => {
                  item_guid = non_blank_text(captured_text)
                  item_guid_is_permalink = if item_guid is Some(_) {
                    capture_guid_is_permalink
                  } else {
                    None
                  }
                }
                "source" => {
                  item_source_title = non_blank_text(captured_text)
                  if item_source_title is None {
                    diagnostics.push({
                      kind: InvalidRssField("source title"),
                      line: capture_line,
                      column: capture_column,
                    })
                  }
                }
                "title" => item_title = non_blank_text(captured_text)
                "link" => item_link = non_blank_text(captured_text)
                "description" =>
                  item_description = non_blank_text(captured_text)
                "content:encoded" => item_content = Some(captured_text)
                "comments" => item_comments_url = non_blank_text(captured_text)
                "author" =>
                  match non_blank_text(captured_text) {
                    Some(email) =>
                      item_authors.push({
                        source: Rss2,
                        name: None,
                        uri: None,
                        email: Some(email),
                        avatar: None,
                      })
                    None =>
                      diagnostics.push({
                        kind: InvalidAuthor("rss author missing email"),
                        line: capture_line,
                        column: capture_column,
                      })
                  }
                "dc:creator" =>
                  match non_blank_text(captured_text) {
                    Some(name) =>
                      item_authors.push({
                        source: DublinCore,
                        name: Some(name),
                        uri: None,
                        email: None,
                        avatar: None,
                      })
                    None =>
                      diagnostics.push({
                        kind: InvalidAuthor("dublin core creator missing name"),
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
                "pubDate" => item_published_at = rss_date_value(
                  captured_text, "item pubDate", capture_line,
                  capture_column, diagnostics,
                )
                _ => ()
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
                "copyright" => channel_rights = non_blank_text(captured_text)
                "generator" => channel_generator = non_blank_text(captured_text)
                "managingEditor" =>
                  channel_managing_editor = non_blank_text(captured_text)
                "webMaster" => channel_webmaster = non_blank_text(captured_text)
                "pubDate" => channel_published = rss_date_value(
                  captured_text, "channel pubDate", capture_line,
                  capture_column, diagnostics,
                )
                "lastBuildDate" => channel_updated = rss_date_value(
                  captured_text, "channel lastBuildDate", capture_line,
                  capture_column, diagnostics,
                )
                "ttl" => {
                  channel_ttl = rss_ttl_minutes(captured_text)
                  if channel_ttl is None {
                    diagnostics.push({
                      kind: InvalidRssField("ttl"),
                      line: capture_line,
                      column: capture_column,
                    })
                  }
                }
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
            capture_guid_is_permalink = None
          }
          if skip_kind is Some(kind) &&
            depth == skip_depth &&
            is_rss_name(name, kind) {
            skip_kind = None
            skip_ignored = false
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
              title_xhtml: None,
              link: rss_item_link(item_link, item_guid, item_guid_is_permalink),
              external_url: None,
              language: None,
              description: item_description,
              description_kind: Unspecified,
              description_xhtml: None,
              content: item_content,
              content_text: None,
              content_html: None,
              content_kind: Unspecified,
              content_xhtml: None,
              content_source: None,
              content_media_type: None,
              atom_body: None,
              atom_source: None,
              links: [],
              comments_url: item_comments_url,
              source_url: item_source_url,
              source_title: item_source_title,
              guid_is_permalink: item_guid_is_permalink,
              rights: None,
              rights_kind: Unspecified,
              rights_xhtml: None,
              authors: item_authors,
              contributors: [],
              categories: item_categories,
              attachments: item_attachments,
              images: [],
              published_at: item_published_at,
              updated_at: None,
            })
            if item_title is None && item_description is None {
              diagnostics.push({
                kind: MissingItemContent(item_index),
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
            title_xhtml: None,
            link: channel_link,
            language: channel_language,
            description: channel_description,
            description_kind: Unspecified,
            description_xhtml: None,
            updated_at: channel_updated,
            published_at: channel_published,
            ttl_minutes: channel_ttl,
            docs_url: None,
            rating: None,
            cloud: None,
            text_input: None,
            skip_hours: channel_skip_hours,
            skip_days: channel_skip_days,
            rights: channel_rights,
            rights_kind: Unspecified,
            rights_xhtml: None,
            generator: channel_generator,
            generator_uri: None,
            generator_version: None,
            managing_editor: channel_managing_editor,
            webmaster: channel_webmaster,
            next_url: None,
            expired: None,
            hubs: [],
            links: [],
            authors: [],
            contributors: [],
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
              Ok(feed) =>
                match add_xml_feed_images(input, feed, None, true) {
                  Ok(imaged) =>
                    add_rss_optional_channel(input, imaged, None, true)
                  Err(error) => Err(error)
                }
              Err(error) => Err(error)
            }
          }
          if is_atom_name(element.name, "feed") {
            return match parse_atom(input, false) {
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

///|
/// Parse a feed or an independent Atom Entry Document. The established
/// `parse` function remains feed-only and keeps its Result[Feed, ParseError]
/// signature. Stand-alone entries use the same Atom field, content, and
/// diagnostic rules as entries inside feeds.
pub fn parse_document(input : String) -> Result[ParsedDocument, ParseError] {
  match parse(input) {
    Ok(feed) => Ok(FeedDocument(feed))
    Err(UnsupportedRoot(_, Some("http://www.w3.org/2005/Atom"))) =>
      match parse_atom(input, true) {
        Ok(feed) =>
          if feed.entries.length() == 1 {
            Ok(AtomEntryDocument(feed.entries[0], feed.diagnostics))
          } else {
            Err(InvalidAtomStructure("entry document has no entry"))
          }
        Err(error) => Err(error)
      }
    Err(error) => Err(error)
  }
}
