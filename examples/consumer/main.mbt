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
  let atom =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">Plan <em>A</em></div></title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author></feed>
  match @feedlens.parse(atom) {
    Ok(feed) =>
      if feed.title_kind is @feedlens.Xhtml {
        match feed.title_xhtml {
          Some(fragment) => {
            println("xhtml_title=" + feed.title.unwrap_or(""))
            println("xhtml_markup=" + fragment.markup)
          }
          None => println("xhtml fragment unavailable")
        }
      }
    Err(_) => println("Atom XHTML parse failed")
  }
}
