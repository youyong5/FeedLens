///|
// Copied into a separate temporary MoonBit module by check_external_consumer.py.
// It imports the public library package, not FeedLens' CLI or XML internals.
fn main {
  let json_input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"External consumer","items":[{"id":"one","content_text":"Body","url":"posts/one","attachments":[{"url":"audio.mp3","mime_type":"audio/mpeg","size_in_bytes":1e3}]}]}
  match @feedlens.parse_with_source(
      json_input, "https://example.test/feeds/current.json",
    ) {
    Ok(feed) => {
      let entry = feed.entries[0]
      println("json=" + feed.title.unwrap_or(""))
      println("json_url=" + entry.link.unwrap_or(""))
      println(
        "json_bytes=" +
        entry.attachments[0].size_in_bytes.unwrap_or(-1L).to_string(),
      )
      println("json_diagnostics=" + feed.diagnostics.length().to_string())
    }
    Err(_) => println("FAIL json")
  }
  let rss_input =
    #|<rss version="2.0"><channel><title>RSS</title><link>https://example.test/</link><description>News</description><item><title>One</title><enclosure url="audio.mp3" length="3" type="audio/mpeg"/></item></channel></rss>
  match @feedlens.parse(rss_input) {
    Ok(feed) => {
      println("rss=" + feed.entries[0].title.unwrap_or(""))
      println("rss_audio=" + feed.entries[0].attachments[0].url)
      println("rss_diagnostics=" + feed.diagnostics.length().to_string())
    }
    Err(_) => println("FAIL rss")
  }
  let atom_entry =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="posts/"><id>urn:entry:one</id><title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">Plan <em>A</em></div></title><updated>2026-10-28T00:00:00Z</updated><link href="one"/><source><author><name>Editor</name></author></source></entry>
  match @feedlens.parse_document_with_source(
      atom_entry, "https://example.test/news/entry.atom",
    ) {
    Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) => {
      println("atom_title=" + entry.title.unwrap_or(""))
      println("atom_xhtml=" + (entry.title_kind is @feedlens.Xhtml).to_string())
      println("atom_author=" + entry.authors[0].name.unwrap_or(""))
      println("atom_url=" + entry.link.unwrap_or(""))
      println("atom_diagnostics=" + diagnostics.length().to_string())
    }
    _ => println("FAIL atom entry")
  }
}
