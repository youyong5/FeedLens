///|
test "JSON Feed item external URL and two image roles stay separate from permalink and attachments" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"T","items":[{"id":"one","content_text":"B","url":"posts/one","banner_image":"/wide.png","image":"preview.png","external_url":"https://outside.test/story"}]}
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected JSON Feed") }
  let entry = raw.entries[0]
  assert_eq(entry.link, Some("posts/one"))
  assert_eq(entry.external_url, Some("https://outside.test/story"))
  assert_eq(entry.images.length(), 2)
  assert_true(entry.images[0].role is @feedlens.JsonFeatured)
  assert_true(entry.images[1].role is @feedlens.JsonBanner)
  assert_eq(entry.images[0].url, "preview.png")
  assert_eq(entry.images[1].url, "/wide.png")
  assert_eq(entry.attachments, [])
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(resolved) else {
    fail("expected resolved JSON Feed")
  }
  assert_eq(resolved.entries[0].link, Some("https://example.test/posts/one"))
  assert_eq(
    resolved.entries[0].external_url,
    Some("https://outside.test/story"),
  )
  assert_eq(
    resolved.entries[0].images[0].url,
    "https://example.test/preview.png",
  )
  assert_eq(resolved.entries[0].images[1].url, "https://example.test/wide.png")
}

///|
test "JSON Feed 1.0 also defines item external and image fields" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"T","items":[{"id":"one","content_text":"B","external_url":"outside","image":"pic.jpg"}]}
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(feed) else {
    fail("expected JSON Feed 1.0")
  }
  assert_eq(feed.entries[0].link, None)
  assert_eq(feed.entries[0].external_url, Some("https://example.test/outside"))
  assert_eq(feed.entries[0].images[0].url, "https://example.test/pic.jpg")
}

///|
test "Missing item display URLs stay absent; wrong types and blank URLs are diagnostic" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"T","items":[{"id":"one","content_text":"B"},{"id":"two","content_text":"B","external_url":42,"image":" ","banner_image":false}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries[0].external_url, None)
  assert_eq(feed.entries[0].images, [])
  assert_eq(feed.entries[1].external_url, None)
  assert_eq(feed.entries[1].images, [])
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidJsonFeedItem(1, "external_url"),
  )
  assert_true(
    feed.diagnostics[1].kind is @feedlens.InvalidJsonFeedItem(1, "image"),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.InvalidJsonFeedItem(1, "banner_image"),
  )
  assert_eq(feed.diagnostics[0].line, 1)
  assert_eq(feed.diagnostics[0].column, 1)
}

///|
test "Malformed item image references remain raw with explicit URI diagnostics" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"T","items":[{"id":"one","content_text":"B","external_url":"bad space","image":"http://[bad","banner_image":"#section"}]}
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(feed) else {
    fail("expected JSON Feed")
  }
  assert_eq(feed.entries[0].external_url, Some("bad space"))
  assert_eq(feed.entries[0].images[0].url, "http://[bad")
  assert_eq(
    feed.entries[0].images[1].url,
    "https://example.test/feed.json#section",
  )
  assert_true(feed.diagnostics[0].kind is @feedlens.UnresolvedUri(_))
  assert_true(feed.diagnostics[1].kind is @feedlens.UnresolvedUri(_))
  assert_eq(feed.diagnostics[0].line, 1)
}

///|
test "RSS and Atom core entries do not invent JSON-only display fields" {
  let rss = "<rss version=\"2.0\"><channel><title>T</title><link>L</link><description>D</description><item><guid>x</guid><enclosure url=\"https://example.test/a.mp3\" length=\"1\" type=\"audio/mpeg\"/></item></channel></rss>"
  guard @feedlens.parse(rss) is Ok(rss_feed) else { fail("expected RSS") }
  assert_eq(rss_feed.entries[0].external_url, None)
  assert_eq(rss_feed.entries[0].images, [])
  assert_eq(rss_feed.entries[0].attachments.length(), 1)
  let atom = "<feed xmlns=\"http://www.w3.org/2005/Atom\"><id>f</id><title>T</title><updated>2026-10-19T00:00:00Z</updated><author><name>N</name></author><entry><id>x</id><title>X</title><updated>2026-10-19T00:00:00Z</updated><link href=\"https://example.test/x\"/></entry></feed>"
  guard @feedlens.parse(atom) is Ok(atom_feed) else { fail("expected Atom") }
  assert_eq(atom_feed.entries[0].external_url, None)
  assert_eq(atom_feed.entries[0].images, [])
}
