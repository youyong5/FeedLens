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

///|
test "RSS date precision comparison sample retains whole-second source" {
  let input =
    #|<rss version="2.0"><channel><title>Precision</title><link>https://example.test/</link><description>Same instant</description>
    #|<item><guid>urn:instant:one</guid><title>One</title><pubDate>Wed, 14 Oct 2026 13:00:00 +0000</pubDate></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.diagnostics, [])
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected normalized RSS date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00Z")
  assert_eq(date.nanosecond, 0)
}

///|
test "Atom RFC 3339 accepts sub-nanosecond precision with original digits" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed:precision</id><title>Precision</title><updated>2026-10-14T14:00:00.123456789123+01:00</updated><author><name>Editor</name></author>
    #|<entry><id>urn:instant:one</id><title>One</title><updated>2026-10-14T14:00:00.123456789123+01:00</updated><published>2026-10-14T14:00:00.123456789123+01:00</published><content>Body</content></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.diagnostics, [])
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected normalized Atom date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00.123456789123Z")
  assert_eq(date.nanosecond, 123456789)
  assert_eq(date.offset_minutes, 60)
  guard date.precision is @feedlens.Fraction(digits) else {
    fail("expected declared fractional precision")
  }
  assert_eq(digits, 12)
  assert_true(
    @feedlens.normalize_date(feed.format, Some("2026-10-14T13:00:00.Z"))
    is Err(@feedlens.InvalidSyntax),
  )
}

///|
test "JSON Feed RFC 3339 retains trailing zeros beyond nanoseconds" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Precision","items":[
    #|{"id":"urn:instant:one","title":"One","date_published":"2026-10-14T08:00:00.123456789123000-05:00","content_text":"Body"}
    #|]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.diagnostics, [])
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected normalized JSON Feed date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00.123456789123000Z")
  assert_eq(date.nanosecond, 123456789)
  assert_eq(date.offset_minutes, -300)
  guard date.precision is @feedlens.Fraction(digits) else {
    fail("expected declared fractional precision")
  }
  assert_eq(digits, 15)
}
