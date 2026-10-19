///|
test "a separate package can consume the public display and date API" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"T","language":"en-US","icon":"icons/feed.png","items":[{"id":"one","content_text":"B","url":"posts/one","external_url":"outside/story","image":"preview.png","date_published":"2026-10-19T10:30:00+02:00"}]}
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(feed) else {
    fail("expected JSON Feed")
  }
  assert_eq(feed.language, Some("en-US"))
  assert_true(feed.images[0].role is @feedlens.JsonIcon)
  assert_eq(feed.images[0].url, "https://example.test/icons/feed.png")
  let entry = feed.entries[0]
  assert_eq(entry.language, Some("en-US"))
  assert_eq(entry.link, Some("https://example.test/posts/one"))
  assert_eq(entry.external_url, Some("https://example.test/outside/story"))
  assert_true(entry.images[0].role is @feedlens.JsonFeatured)
  assert_eq(entry.images[0].url, "https://example.test/preview.png")
  assert_eq(entry.attachments, [])
  guard @feedlens.normalize_date(feed.format, entry.published_at)
    is Ok(Some(date)) else {
    fail("expected valid date")
  }
  assert_eq(date.utc, "2026-10-19T08:30:00Z")
}
