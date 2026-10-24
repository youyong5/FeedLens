///|
test "RSS RFC 822 date tokens ignore case and Z has a known UTC offset" {
  let xml =
    #|<rss version="2.0"><channel><title>Case and zone</title><link>https://example.test/</link><description>Dates</description><pubDate>sAt, 24 oCt 2026 07:00:00 eSt</pubDate>
    #|<lastBuildDate>Sat, 24 Oct 2026 12:15:00 z</lastBuildDate>
    #|<item><guid>zulu</guid><title>Zulu</title><pubDate>Sat, 24 Oct 2026 12:00:00 Z</pubDate></item>
    #|<item><guid>mixed</guid><title>Mixed</title><pubDate>sAt, 24 oct 26 08:30:00 pSt</pubDate></item>
    #|<item><guid>military</guid><title>Unknown zone</title><pubDate>Sat, 24 Oct 2026 12:00:00 A</pubDate></item>
    #|</channel></rss>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.published_at, Some("sAt, 24 oCt 2026 07:00:00 eSt"))
  assert_eq(feed.entries[0].published_at, Some("Sat, 24 Oct 2026 12:00:00 Z"))
  assert_eq(feed.entries[2].published_at, Some("Sat, 24 Oct 2026 12:00:00 A"))
  assert_eq(feed.entries.length(), 3)
  guard @feedlens.normalize_date(feed.format, feed.published_at)
    is Ok(Some(published)) else { fail("expected known EST date") }
  assert_eq(published.utc, "2026-10-24T12:00:00Z")
  assert_eq(published.offset_minutes, -300)
  assert_true(published.offset_known)
  guard @feedlens.normalize_date(feed.format, feed.updated_at)
    is Ok(Some(updated)) else { fail("expected known z date") }
  assert_eq(updated.utc, "2026-10-24T12:15:00Z")
  assert_true(updated.offset_known)
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(zulu)) else { fail("expected known Z date") }
  assert_eq(zulu.utc, "2026-10-24T12:00:00Z")
  assert_eq(zulu.offset_minutes, 0)
  assert_true(zulu.offset_known)
  guard @feedlens.normalize_date(feed.format, feed.entries[1].published_at)
    is Ok(Some(mixed)) else { fail("expected mixed-case PST date") }
  assert_eq(mixed.utc, "2026-10-24T16:30:00Z")
  assert_eq(mixed.offset_minutes, -480)
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(feed.diagnostics[0].kind is @feedlens.UnnormalizedRssDate("item pubDate"))
  assert_eq(feed.diagnostics[0].line, 5)
  assert_true(
    @feedlens.normalize_date(feed.format, feed.entries[2].published_at)
    is Err(@feedlens.UnsupportedTimeZone),
  )
  assert_true(
    @feedlens.normalize_date(feed.format, Some("Sat, 24 Oct 2026 12:00:00 J"))
    is Err(@feedlens.UnsupportedTimeZone),
  )
  assert_true(
    @feedlens.normalize_date(feed.format, Some("mOn, 24 oCt 2026 12:00:00 Z"))
    is Err(@feedlens.InvalidCalendarDate),
  )
}
