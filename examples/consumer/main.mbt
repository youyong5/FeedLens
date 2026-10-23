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
    Ok(feed) => {
      match
        @feedlens.normalize_date(feed.format, Some("2026-10-14T13:00:00-00:00")) {
        Ok(Some(date)) =>
          println(
            "unknown_local_zone=" +
            date.utc +
            ":" +
            date.offset_known.to_string(),
          )
        _ => println("unknown local zone date failed")
      }
      match
        @feedlens.normalize_date(feed.format, Some("2016-12-31T23:59:60Z")) {
        Ok(Some(date)) =>
          println(
            "leap_second=" + date.utc + ":" + date.is_leap_second.to_string(),
          )
        _ => println("leap-second date failed")
      }
      if feed.title_kind is @feedlens.Xhtml {
        match feed.title_xhtml {
          Some(fragment) => {
            println("xhtml_title=" + feed.title.unwrap_or(""))
            println("xhtml_markup=" + fragment.markup)
          }
          None => println("xhtml fragment unavailable")
        }
      }
    }
    Err(_) => println("Atom XHTML parse failed")
  }
  let atom_body =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="application/octet-stream">AQID</content></entry></feed>
  match @feedlens.parse(atom_body) {
    Ok(feed) =>
      match feed.entries[0].atom_body {
        Some(@feedlens.InlineBinary(bytes, media_type)) => {
          println("atom_binary_type=" + media_type)
          println("atom_binary_bytes=" + bytes.length().to_string())
        }
        _ => println("Atom binary body unavailable")
      }
    Err(_) => println("Atom binary parse failed")
  }
  let standalone =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="posts/"><id>urn:e</id><title>Independent entry</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><link href="one"/></entry>
  match
    @feedlens.parse_document_with_source(
      standalone, "https://example.test/news/entry.atom",
    ) {
    Ok(@feedlens.AtomEntryDocument(entry, _)) => {
      println("atom_entry=" + entry.title.unwrap_or(""))
      println("atom_entry_link=" + entry.link.unwrap_or(""))
    }
    _ => println("Atom Entry Document parse failed")
  }
  let rss =
    #|<rss version="2.0"><channel><title>Desk</title><link>https://example.test/</link><description>News</description><docs>../rss-spec.html</docs><cloud domain="notify.example.test" port="80" path="/RPC2" registerProcedure="ping" protocol="xml-rpc"/><textInput><title>Search</title><description>Archives</description><name>q</name><link>../search</link></textInput></channel></rss>
  match
    @feedlens.parse_with_source(rss, "https://example.test/feeds/daily.xml") {
    Ok(feed) => {
      println("rss_docs=" + feed.docs_url.unwrap_or(""))
      match feed.cloud {
        Some(cloud) =>
          println("rss_cloud=" + cloud.domain + ":" + cloud.port.to_string())
        None => ()
      }
      match feed.text_input {
        Some(form) => println("rss_search=" + form.link)
        None => ()
      }
    }
    Err(_) => println("RSS channel parse failed")
  }
}
