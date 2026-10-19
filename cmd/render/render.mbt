///|
pub enum Command {
  Help
  Parse(String, Bool)
}

///|
pub fn parse_args(args : Array[String]) -> Result[Command, String] {
  match args {
    ["--help"] | ["-h"] => Ok(Help)
    [path] if !path.has_prefix("-") => Ok(Parse(path, false))
    ["--json", path] if !path.has_prefix("-") => Ok(Parse(path, true))
    [] => Err("missing input file path")
    _ => Err("expected one input path, optionally preceded by --json")
  }
}

///|
pub fn help_text() -> String {
  (
    #|Usage: feedlens [--json] <path>
    #|
    #|Read one local RSS 2.0, Atom 1.0, or JSON Feed 1.0/1.1 file.
    #|
    #|Options:
    #|  --json       Write FeedLens's normalized model as JSON.
    #|  -h, --help   Show this help text.
  )
}

///|
pub fn parse_error_text(error : @feedlens.ParseError) -> String {
  match error {
    InvalidXml(message, line, column) =>
      "invalid XML at " +
      line.to_string() +
      ":" +
      column.to_string() +
      ": " +
      message
    UnsupportedRoot(name, namespace_uri) =>
      "unsupported XML root " +
      name +
      " in namespace " +
      namespace_uri.unwrap_or("(none)")
    UnsupportedRssVersion(version) =>
      "unsupported RSS version " + version.unwrap_or("(missing)")
    MissingChannel => "RSS feed has no channel"
    InvalidRssStructure(message) => "invalid RSS structure: " + message
    InvalidJson(message, line, column) =>
      "invalid JSON at " +
      line.to_string() +
      ":" +
      column.to_string() +
      ": " +
      message
    InvalidJsonFeed(message) => "invalid JSON Feed: " + message
    UnsupportedJsonFeedVersion(version) =>
      "unsupported JSON Feed version " + version.unwrap_or("(missing)")
  }
}

///|
fn option_or_none(value : String?) -> String {
  value.unwrap_or("(none)")
}

///|
pub fn format_name(format : @feedlens.FeedFormat) -> String {
  match format {
    Rss2 => "RSS 2.0"
    Atom1 => "Atom 1.0"
    JsonFeed1 => "JSON Feed 1.x"
  }
}

///|
fn diagnostic_text(kind : @feedlens.DiagnosticKind) -> String {
  match kind {
    MissingChannelField(field) => "missing channel field: " + field
    MissingItemIdentifier(index) =>
      "missing item identifier: " + index.to_string()
    MissingFeedField(field) => "missing feed field: " + field
    MissingEntryField(index, field) =>
      "missing entry field " + index.to_string() + ": " + field
    UnsupportedNestedMarkup(field) => "unsupported nested markup: " + field
    UnsupportedTextConstruct(field) => "unsupported text construct: " + field
    UnsupportedAtomContent(content) => "unsupported Atom content: " + content
    MissingAlternateLink(index) =>
      "missing alternate link: " + index.to_string()
    MissingSummaryForExternalContent(index) =>
      "missing summary for external content: " + index.to_string()
    InvalidAuthor(author) => "invalid author: " + author
    InvalidCategory(category) => "invalid category: " + category
    InvalidAttachment(message) => "invalid attachment: " + message
    InvalidJsonFeedField(field) => "invalid JSON Feed field: " + field
    InvalidJsonFeedItem(index, field) =>
      "invalid JSON Feed item " + index.to_string() + ": " + field
  }
}

///|
pub fn render_human(feed : @feedlens.Feed) -> String {
  let output = StringBuilder()
  output.write_string("Format: ")
  output.write_string(format_name(feed.format))
  output.write_string("\nTitle: ")
  output.write_string(option_or_none(feed.title))
  output.write_string("\nLink: ")
  output.write_string(option_or_none(feed.link))
  output.write_string("\nEntries: ")
  output.write_string(feed.entries.length().to_string())
  for index = 0; index < feed.entries.length(); index = index + 1 {
    let entry = feed.entries[index]
    output.write_string("\n\n")
    output.write_string((index + 1).to_string())
    output.write_string(". identifier: ")
    output.write_string(option_or_none(entry.identifier))
    output.write_string("\n   title: ")
    output.write_string(option_or_none(entry.title))
    output.write_string("\n   link: ")
    output.write_string(option_or_none(entry.link))
  }
  if feed.diagnostics.is_empty() {
    output.write_string("\n\nDiagnostics: none\n")
  } else {
    output.write_string("\n\nDiagnostics:")
    for diagnostic in feed.diagnostics {
      output.write_string("\n  [")
      output.write_string(diagnostic.line.to_string())
      output.write_string(":")
      output.write_string(diagnostic.column.to_string())
      output.write_string("] ")
      output.write_string(diagnostic_text(diagnostic.kind))
    }
    output.write_string("\n")
  }
  output.to_string()
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(text) => Json::string(text)
    None => Json::null()
  }
}

///|
fn text_kind_json(kind : @feedlens.TextKind) -> Json {
  Json::string(
    match kind {
      Unspecified => "unspecified"
      Text => "text"
      Html => "html"
    },
  )
}

///|
fn format_json(format : @feedlens.FeedFormat) -> Json {
  Json::string(
    match format {
      Rss2 => "rss2"
      Atom1 => "atom1"
      JsonFeed1 => "jsonfeed1"
    },
  )
}

///|
fn author_source_json(source : @feedlens.AuthorSource) -> Json {
  Json::string(
    match source {
      Rss2 => "rss2"
      Atom1 => "atom1"
      JsonFeed => "jsonfeed"
    },
  )
}

///|
fn author_json(author : @feedlens.Author) -> Json {
  Json::object({
    "source": author_source_json(author.source),
    "name": optional_string_json(author.name),
    "uri": optional_string_json(author.uri),
    "email": optional_string_json(author.email),
  })
}

///|
fn category_json(category : @feedlens.Category) -> Json {
  Json::object({
    "source": format_json(category.source),
    "term": Json::string(category.term),
    "domain": optional_string_json(category.domain),
    "scheme": optional_string_json(category.scheme),
    "label": optional_string_json(category.label),
  })
}

///|
fn diagnostic_kind_json(kind : @feedlens.DiagnosticKind) -> Json {
  match kind {
    MissingChannelField(field) =>
      { "type": "MissingChannelField", "field": field }
    MissingItemIdentifier(index) =>
      { "type": "MissingItemIdentifier", "index": index }
    MissingFeedField(field) => { "type": "MissingFeedField", "field": field }
    MissingEntryField(index, field) =>
      { "type": "MissingEntryField", "index": index, "field": field }
    UnsupportedNestedMarkup(field) =>
      { "type": "UnsupportedNestedMarkup", "field": field }
    UnsupportedTextConstruct(field) =>
      { "type": "UnsupportedTextConstruct", "field": field }
    UnsupportedAtomContent(content) =>
      { "type": "UnsupportedAtomContent", "content": content }
    MissingAlternateLink(index) =>
      { "type": "MissingAlternateLink", "index": index }
    MissingSummaryForExternalContent(index) =>
      { "type": "MissingSummaryForExternalContent", "index": index }
    InvalidAuthor(author) => { "type": "InvalidAuthor", "message": author }
    InvalidCategory(category) =>
      { "type": "InvalidCategory", "message": category }
    InvalidAttachment(message) =>
      { "type": "InvalidAttachment", "message": message }
    InvalidJsonFeedField(field) =>
      { "type": "InvalidJsonFeedField", "field": field }
    InvalidJsonFeedItem(index, field) =>
      { "type": "InvalidJsonFeedItem", "index": index, "field": field }
  }
}

///|
fn diagnostic_json(diagnostic : @feedlens.Diagnostic) -> Json {
  Json::object({
    "kind": diagnostic_kind_json(diagnostic.kind),
    "line": Json(diagnostic.line),
    "column": Json(diagnostic.column),
  })
}

///|
fn entry_json(entry : @feedlens.Entry) -> Json {
  Json::object({
    "identifier": optional_string_json(entry.identifier),
    "title": optional_string_json(entry.title),
    "title_kind": text_kind_json(entry.title_kind),
    "link": optional_string_json(entry.link),
    "description": optional_string_json(entry.description),
    "description_kind": text_kind_json(entry.description_kind),
    "content": optional_string_json(entry.content),
    "content_kind": text_kind_json(entry.content_kind),
    "authors": Json::array(entry.authors.map(author_json)),
    "categories": Json::array(entry.categories.map(category_json)),
    "published_at": optional_string_json(entry.published_at),
    "updated_at": optional_string_json(entry.updated_at),
  })
}

///|
pub fn render_json(feed : @feedlens.Feed) -> String {
  @json.to_json(
    Json::object({
      "format": format_json(feed.format),
      "identifier": optional_string_json(feed.identifier),
      "title": optional_string_json(feed.title),
      "title_kind": text_kind_json(feed.title_kind),
      "link": optional_string_json(feed.link),
      "description": optional_string_json(feed.description),
      "description_kind": text_kind_json(feed.description_kind),
      "updated_at": optional_string_json(feed.updated_at),
      "authors": Json::array(feed.authors.map(author_json)),
      "categories": Json::array(feed.categories.map(category_json)),
      "entries": Json::array(feed.entries.map(entry_json)),
      "diagnostics": Json::array(feed.diagnostics.map(diagnostic_json)),
    }),
  ).stringify()
}
