///|
test "RSS source URL resolves core links and enclosure but not guid" {
  let xml =
    #|<rss version="2.0"><channel><title>Feed</title><link>/home?lang=en</link><description>Desc</description>
    #|<item><guid>opaque-guid</guid><title>Post</title><link>posts/one#part</link>
    #|<enclosure url="../media/a.mp3" length="12" type="audio/mpeg"/></item></channel></rss>
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/news.xml")
    is Ok(feed) else {
    fail("expected resolved RSS")
  }
  assert_eq(feed.link, Some("https://example.test/home?lang=en"))
  assert_eq(feed.entries[0].identifier, Some("opaque-guid"))
  assert_eq(
    feed.entries[0].link,
    Some("https://example.test/feeds/posts/one#part"),
  )
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://example.test/media/a.mp3",
  )
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(xml) is Ok(raw) else { fail("expected raw RSS") }
  assert_eq(raw.entries[0].link, Some("posts/one#part"))
  assert_eq(raw.entries[0].attachments[0].url, "../media/a.mp3")
}

///|
test "RSS link fallback identifier stays raw when resolved link changes" {
  let xml =
    #|<rss version="2.0"><channel><title>Feed</title><link>https://example.test/</link><description>Desc</description>
    #|<item><link>article</link></item></channel></rss>
  guard @feedlens.parse_with_source(xml, "https://example.test/feed.xml")
    is Ok(feed) else {
    fail("expected RSS")
  }
  assert_eq(feed.entries[0].identifier, Some("article"))
  assert_eq(feed.entries[0].link, Some("https://example.test/article"))
}

///|
test "Atom nested xml:base applies to alternate and enclosure links" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://cdn.example.test/site/"><id>urn:feed</id><title>Feed</title><updated>2026-10-19T00:00:00Z</updated><author><name>A</name></author>
    #|<link href="?view=home"/><entry xml:base="posts/"><id>urn:entry</id><title>Entry</title><updated>2026-10-19T00:00:00Z</updated><content>Body</content>
    #|<link rel="self" href="ignored"/><link rel="alternate" xml:base="../" href="article?view=full#top"/><link rel="enclosure" xml:base="media/" href="../audio/a.mp3" type="audio/mpeg" length="12"/><link rel="enclosure" href="/global/b.ogg"/></entry></feed>
  guard @feedlens.parse_with_source(
      xml, "https://origin.example.test/feeds/main.atom",
    )
    is Ok(feed) else {
    fail("expected resolved Atom")
  }
  assert_eq(feed.link, Some("https://cdn.example.test/site/?view=home"))
  assert_eq(feed.entries[0].identifier, Some("urn:entry"))
  assert_eq(
    feed.entries[0].link,
    Some("https://cdn.example.test/site/article?view=full#top"),
  )
  assert_eq(feed.entries[0].attachments.length(), 2)
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://cdn.example.test/site/posts/audio/a.mp3",
  )
  assert_eq(
    feed.entries[0].attachments[1].url,
    "https://cdn.example.test/global/b.ogg",
  )
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(xml) is Ok(raw) else { fail("expected raw Atom") }
  assert_eq(raw.entries[0].link, Some("article?view=full#top"))
  assert_eq(raw.entries[0].attachments[0].url, "../audio/a.mp3")
}

///|
test "Atom ignores wrong-namespace base and reports invalid base at element" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:not-xml" x:base="https://wrong.test/"><id>urn:feed</id><title>Feed</title><updated>2026-10-19T00:00:00Z</updated><author><name>A</name></author>
    #|<entry xml:base="http:///bad"><id>urn:entry</id><title>Entry</title><updated>2026-10-19T00:00:00Z</updated><content>Body</content>
    #|<link href="article"/><link rel="enclosure" href="https://example.test/a.mp3"/></entry></feed>
  guard @feedlens.parse_with_source(xml, "https://example.test/feed.xml")
    is Ok(feed) else {
    fail("expected recoverable URI diagnostics")
  }
  assert_eq(feed.entries[0].link, Some("article"))
  assert_eq(feed.entries[0].attachments[0].url, "https://example.test/a.mp3")
  assert_true(
    feed.diagnostics[0].kind is @feedlens.UnresolvedUri("atom xml:base"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[0].column, 1)
  assert_true(feed.diagnostics[1].kind is @feedlens.UnresolvedUri(_))
  assert_eq(feed.diagnostics[1].line, 3)
}

///|
test "Atom lookalike base attribute does not override source URL" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:not-xml" x:base="https://wrong.test/"><id>urn:feed</id><title>Feed</title><updated>2026-10-19T00:00:00Z</updated><author><name>A</name></author>
    #|<link href="home"/><entry><id>urn:entry</id><title>Entry</title><updated>2026-10-19T00:00:00Z</updated><content>Body</content>
    #|<link href="article"/><link rel="enclosure" href="audio.mp3"/></entry></feed>
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(feed) else {
    fail("expected Atom")
  }
  assert_eq(feed.link, Some("https://example.test/feeds/home"))
  assert_eq(feed.entries[0].link, Some("https://example.test/feeds/article"))
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://example.test/feeds/audio.mp3",
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "JSON Feed source URL resolves home, item, and attachment references" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Feed","home_page_url":"/home","items":[{"id":"opaque","url":"../articles/one?mode=full#top","content_text":"Body","attachments":[{"url":"?download=1","mime_type":"audio/mpeg"},{"url":"/media/two.ogg","mime_type":"audio/ogg"}]}]}
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/current/feed.json",
    )
    is Ok(feed) else {
    fail("expected resolved JSON Feed")
  }
  assert_eq(feed.link, Some("https://example.test/home"))
  assert_eq(feed.entries[0].identifier, Some("opaque"))
  assert_eq(
    feed.entries[0].link,
    Some("https://example.test/feeds/articles/one?mode=full#top"),
  )
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://example.test/feeds/current/feed.json?download=1",
  )
  assert_eq(
    feed.entries[0].attachments[1].url,
    "https://example.test/media/two.ogg",
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "URI failures leave raw fields, locate diagnostics, and reject invalid source" {
  let xml =
    #|<rss version="2.0"><channel><title>Feed</title><link>bad%2G</link><description>Desc</description>
    #|<item><guid>one</guid><link>good</link><enclosure url="bad path" length="1" type="audio/mpeg"/></item></channel></rss>
  guard @feedlens.parse_with_source(xml, "https://example.test/feed.xml")
    is Ok(feed) else {
    fail("expected recoverable RSS")
  }
  assert_eq(feed.link, Some("bad%2G"))
  assert_eq(feed.entries[0].link, Some("https://example.test/good"))
  assert_eq(feed.entries[0].attachments[0].url, "bad path")
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnresolvedUri("rss item 0 enclosure 0"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_true(
    feed.diagnostics[1].kind is @feedlens.UnresolvedUri("rss channel link"),
  )
  assert_eq(feed.diagnostics[1].line, 1)
  assert_true(
    @feedlens.parse_with_source(xml, "relative/feed.xml")
    is Err(@feedlens.InvalidSourceUrl("relative/feed.xml")),
  )
}

///|
test "JSON Feed unresolved attachment retains raw URL with document diagnostic" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Feed","items":[{"id":"one","content_text":"Body","attachments":[{"url":"bad%2G","mime_type":"audio/mpeg"}]}]}
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(feed) else {
    fail("expected recovered JSON Feed")
  }
  assert_eq(feed.entries[0].attachments[0].url, "bad%2G")
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnresolvedUri("json feed item 0 attachment 0"),
  )
  assert_eq(feed.diagnostics[0].line, 1)
  assert_eq(feed.diagnostics[0].column, 1)
}
