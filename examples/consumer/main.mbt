///|
/// This package imports only the public library, not the CLI renderer or XML
/// implementation. The document is embedded so the example needs no network.
fn main {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Reader sample","language":"en-US","icon":"icons/feed.png","items":[{"id":"story-1","content_text":"Body","url":"posts/one","external_url":"elsewhere/story","image":"images/preview.png","date_published":"2026-10-19T10:30:00+02:00"}]}
  match @feedlens.parse_with_source(input, "https://example.test/feed.json") {
    Ok(feed) => {
      let entry = feed.entries[0]
      let published = match
        @feedlens.normalize_date(feed.format, entry.published_at) {
        Ok(Some(date)) => date.utc
        _ => "(date unavailable)"
      }
      println("feed=" + feed.title.unwrap_or("(untitled)"))
      println("language=" + feed.language.unwrap_or("(none)"))
      println("icon=" + feed.images[0].url)
      println("permalink=" + entry.link.unwrap_or("(none)"))
      println("outside=" + entry.external_url.unwrap_or("(none)"))
      println("featured=" + entry.images[0].url)
      println("published=" + published)
    }
    Err(_) => println("feed parse failed")
  }
}
