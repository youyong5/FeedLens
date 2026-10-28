///|
test "RSS core singleton diagnostics keep usable values and reset for each item" {
  let input =
    #|<rss version="2.0" xmlns:x="urn:other"><channel>
    #|<title>First feed</title><title>Latest feed</title><link/><link>https://example.test/</link><description>News</description><category>A</category><category>B</category><x:title>Foreign</x:title>
    #|<item><guid>first</guid><guid isPermaLink="false">last</guid><title>First item</title><title>Latest item</title><description>Body</description><author>a@example.test</author><author>b@example.test</author><category>One</category><category>Two</category><enclosure url="a" length="1" type="audio/mpeg"/><enclosure url="b" length="2" type="audio/mpeg"/></item>
    #|<item><title>Next</title><description>Another</description></item><x:item><title>Ignored</title></x:item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.title, Some("Latest feed"))
  assert_eq(feed.link, Some("https://example.test/"))
  assert_eq(feed.categories.length(), 2)
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].identifier, Some("last"))
  assert_eq(feed.entries[0].title, Some("Latest item"))
  assert_eq(feed.entries[0].authors.length(), 2)
  assert_eq(feed.entries[0].categories.length(), 2)
  assert_eq(feed.entries[0].attachments.length(), 2)
  assert_eq(feed.entries[1].title, Some("Next"))
  assert_eq(feed.diagnostics.length(), 5)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidRssField("channel title duplicate"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidRssField("channel link duplicate"),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.InvalidRssField("item guid duplicate"),
  )
  assert_true(
    feed.diagnostics[3].kind
    is @feedlens.InvalidRssField("item title duplicate"),
  )
  assert_true(
    feed.diagnostics[4].kind
    is @feedlens.InvalidRssField("item author duplicate"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[2].line, 3)
}
