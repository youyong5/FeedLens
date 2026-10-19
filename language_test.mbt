///|
test "RSS channel language applies to earlier items without a guessed default" {
  let input =
    #|<rss version="2.0"><channel>
    #|<title>T</title><link>https://example.test</link><description>D</description>
    #|<item><guid>first</guid></item>
    #|<language>en-US</language><item><guid>second</guid></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.language, Some("en-US"))
  assert_eq(feed.entries[0].language, Some("en-US"))
  assert_eq(feed.entries[1].language, Some("en-US"))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>T</title><link>L</link><description>D</description></channel></rss>",
    )
    is Ok(absent) else {
    fail("expected RSS")
  }
  assert_eq(absent.language, None)
}

///|
test "RSS blank and wrong-namespace language do not yield a value" {
  let input =
    #|<rss version="2.0" xmlns:bad="urn:bad"><channel>
    #|<title>T</title><link>L</link><description>D</description>
    #|<bad:language>fr</bad:language><language>  </language>
    #|<item><guid>x</guid></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.language, None)
  assert_eq(feed.entries[0].language, None)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidLanguage(_))
  assert_eq(feed.diagnostics[0].line, 3)
}

///|
test "Atom xml:lang inherits, overrides, and explicitly resets" {
  let input =
    #|<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:fake="urn:fake" xml:lang="en-US">
    #|<a:id>f</a:id><a:title>T</a:title><a:updated>2026-10-19T00:00:00Z</a:updated><a:author><a:name>N</a:name></a:author>
    #|<a:entry><a:id>1</a:id><a:title>One</a:title><a:updated>2026-10-19T00:00:00Z</a:updated><a:link href="one"/></a:entry>
    #|<a:entry xml:lang="fr"><a:id>2</a:id><a:title>Deux</a:title><a:updated>2026-10-19T00:00:00Z</a:updated><a:link href="two"/></a:entry>
    #|<a:entry xml:lang=""><a:id>3</a:id><a:title>Three</a:title><a:updated>2026-10-19T00:00:00Z</a:updated><a:link href="three"/></a:entry>
    #|<a:entry fake:lang="de"><a:id>4</a:id><a:title>Four</a:title><a:updated>2026-10-19T00:00:00Z</a:updated><a:link href="four"/></a:entry>
    #|</a:feed>
  guard @feedlens.parse_with_source(input, "https://example.test/feed.atom")
    is Ok(feed) else {
    fail("expected Atom")
  }
  assert_eq(feed.language, Some("en-US"))
  assert_eq(feed.entries[0].language, Some("en-US"))
  assert_eq(feed.entries[1].language, Some("fr"))
  assert_eq(feed.entries[2].language, None)
  assert_eq(feed.entries[3].language, Some("en-US"))
  assert_eq(feed.entries[0].link, Some("https://example.test/one"))
}

///|
test "JSON Feed 1.1 language inheritance and invalid declarations" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"T","items":[{"id":"1","content_text":"one"},{"id":"2","content_text":"two","language":"fr"},{"id":"3","content_text":"three","language":""},{"id":"4","content_text":"four","language":42}],"language":"en-US"}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.language, Some("en-US"))
  assert_eq(feed.entries[0].language, Some("en-US"))
  assert_eq(feed.entries[1].language, Some("fr"))
  assert_eq(feed.entries[2].language, None)
  assert_eq(feed.entries[3].language, None)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidLanguage(_))
  assert_true(
    feed.diagnostics[1].kind is @feedlens.InvalidJsonFeedItem(3, "language"),
  )
  assert_eq(feed.diagnostics[0].line, 1)
  assert_eq(feed.diagnostics[0].column, 1)
}

///|
test "JSON Feed 1.0 language keys remain outside its declared format" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"T","language":"en","items":[{"id":"1","content_text":"x","language":"fr"}]}
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected JSON Feed 1.0")
  }
  assert_eq(feed.language, None)
  assert_eq(feed.entries[0].language, None)
  assert_eq(feed.diagnostics, [])
}
