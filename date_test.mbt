///|
test "public date API uses the format and raw value from a parsed feed" {
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>Feed</title><link>https://example.test/</link><description>Desc</description><item><guid>one</guid><pubDate>Wed, 14 Oct 2026 13:00:00 +0000</pubDate></item></channel></rss>",
    )
    is Ok(feed) else {
    fail("expected RSS feed")
  }
  assert_eq(
    feed.entries[0].published_at,
    Some("Wed, 14 Oct 2026 13:00:00 +0000"),
  )
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected normalized publication date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00Z")
  assert_true(date.precision is @feedlens.Second)
}
