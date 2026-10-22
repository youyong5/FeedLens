///|
test "RSS title-only and description-only items are valid without identifiers" {
  let input =
    #|<rss version="2.0"><channel><title>Anonymous stories</title><link>https://example.test/</link><description>Stories with no permalink</description>
    #|<item><title>Title alone</title></item>
    #|<item><description>Body &amp; context</description></item>
    #|<item><title>Both</title><description>Full story</description></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected legal RSS items")
  }
  assert_eq(feed.diagnostics, [])
  assert_eq(feed.entries.length(), 3)
  assert_eq(feed.entries[0].identifier, None)
  assert_eq(feed.entries[0].title, Some("Title alone"))
  assert_eq(feed.entries[0].description, None)
  assert_eq(feed.entries[1].identifier, None)
  assert_eq(feed.entries[1].title, None)
  assert_eq(feed.entries[1].description, Some("Body & context"))
  assert_eq(feed.entries[2].identifier, None)
  assert_eq(feed.entries[2].title, Some("Both"))
  assert_eq(feed.entries[2].description, Some("Full story"))
}

///|
test "RSS missing item title and description has a located recoverable diagnostic" {
  let input =
    #|<rss version="2.0" xmlns:other="urn:other"><channel><title>News</title><link>https://example.test/</link><description>Stories</description>
    #|<item/>
    #|<item><link>https://example.test/link-only</link></item>
    #|<item><guid>opaque</guid><other:title>Not an RSS title</other:title></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected recovered RSS feed")
  }
  assert_eq(feed.entries.length(), 3)
  assert_eq(feed.entries[1].identifier, Some("https://example.test/link-only"))
  assert_eq(feed.entries[2].identifier, Some("opaque"))
  assert_eq(feed.entries[2].title, None)
  assert_eq(feed.diagnostics.length(), 3)
  for index = 0; index < 3; index = index + 1 {
    guard feed.diagnostics[index].kind is @feedlens.MissingItemContent(actual) else {
      fail("expected missing item content")
    }
    assert_eq(actual, index)
    assert_eq(feed.diagnostics[index].line, index + 2)
    assert_eq(feed.diagnostics[index].column, 1)
  }
}
