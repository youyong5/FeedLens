///|
test "RSS date diagnostics retain channel and item text and recover the items" {
  let input =
    #|<rss version="2.0"><channel><title>Dates</title><link>https://example.test/</link><description>Dates</description>
    #|<pubDate>Mon, 30 Feb 2026 09:00:00 GMT</pubDate><lastBuildDate>Sat, 24 Oct 2026 10:00:00 +2500</lastBuildDate>
    #|<item><guid>bad-weekday</guid><title>One</title><pubDate>Mon, 24 Oct 2026 11:00:00 GMT</pubDate></item>
    #|<item><guid>blank</guid><title>Two</title><pubDate/></item>
    #|<item><guid>good</guid><title>Three</title><pubDate>Sat, 24 Oct 26 12:00:00 GMT</pubDate></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.published_at, Some("Mon, 30 Feb 2026 09:00:00 GMT"))
  assert_eq(feed.updated_at, Some("Sat, 24 Oct 2026 10:00:00 +2500"))
  assert_eq(feed.entries.length(), 3)
  assert_eq(feed.entries[0].published_at, Some("Mon, 24 Oct 2026 11:00:00 GMT"))
  assert_eq(feed.entries[1].published_at, None)
  assert_eq(feed.entries[2].published_at, Some("Sat, 24 Oct 26 12:00:00 GMT"))
  assert_eq(feed.diagnostics.length(), 4)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnnormalizedRssDate("channel pubDate"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnnormalizedRssDate("channel lastBuildDate"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.UnnormalizedRssDate("item pubDate"),
  )
  assert_true(
    feed.diagnostics[3].kind
    is @feedlens.UnnormalizedRssDate("item pubDate"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (2, 1))
  assert_eq((feed.diagnostics[1].line, feed.diagnostics[1].column), (2, 49))
  assert_eq((feed.diagnostics[2].line, feed.diagnostics[2].column), (3, 49))
  assert_eq((feed.diagnostics[3].line, feed.diagnostics[3].column), (4, 43))
  assert_true(
    @feedlens.normalize_date(feed.format, feed.entries[2].published_at)
    is Ok(Some(_)),
  )
}

///|
test "RSS namespaced and nested date lookalikes do not gain core date values" {
  let input =
    #|<rss version="2.0" xmlns:x="urn:other"><channel><title>Dates</title><link>https://example.test/</link><description>Dates</description><x:pubDate>nonsense</x:pubDate><item><title>One</title><description>Body</description><pubDate><x:time>2026</x:time></pubDate></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.published_at, None)
  assert_eq(feed.entries[0].published_at, None)
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedNestedMarkup("rss pubDate"),
  )
}
