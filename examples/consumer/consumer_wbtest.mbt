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

///|
test "a separate package can read Atom XHTML without importing XML internals" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">Plan <em>A</em></div></title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.title, Some("Plan A"))
  assert_true(feed.title_kind is @feedlens.Xhtml)
  guard feed.title_xhtml is Some(fragment) else {
    fail("expected public XHTML fragment")
  }
  assert_eq(
    fragment.markup,
    "Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em>",
  )
}

///|
test "a separate package can use detailed Atom body variants" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="application/octet-stream">AQID</content></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  guard feed.entries[0].atom_body
    is Some(@feedlens.InlineBinary(bytes, media_type)) else {
    fail("expected public binary variant")
  }
  assert_eq(media_type, "application/octet-stream")
  assert_eq(bytes.length(), 3)
  assert_eq(bytes[2].to_int(), 3)
}
