///|
test "RSS channel image retains role, metadata, and raw references" {
  let input =
    #|<rss version="2.0"><channel><title>T</title><link>/home</link><description>D</description>
    #|<image><url>icons/site.png</url><title>Site</title><link>/home</link><width>32</width><height>31</height><description>Badge</description></image>
    #|<item><guid>x</guid></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.images.length(), 1)
  let image = feed.images[0]
  assert_true(image.role is @feedlens.RssImage)
  assert_true(image.source is @feedlens.Rss2)
  assert_eq(image.url, "icons/site.png")
  assert_eq(image.title, Some("Site"))
  assert_eq(image.link, Some("/home"))
  assert_eq(image.width, Some(32))
  assert_eq(image.height, Some(31))
  assert_eq(image.description, Some("Badge"))
  assert_eq(feed.entries[0].attachments, [])
  guard @feedlens.parse_with_source(input, "https://example.test/feeds/rss.xml")
    is Ok(resolved) else {
    fail("expected resolved RSS")
  }
  assert_eq(resolved.images[0].url, "https://example.test/feeds/icons/site.png")
  assert_eq(resolved.images[0].link, Some("https://example.test/home"))
}

///|
test "RSS invalid image dimensions are diagnostic, required fields decide retention" {
  let input =
    #|<rss version="2.0" xmlns:bad="urn:bad"><channel><title>T</title><link>L</link><description>D</description>
    #|<bad:image><bad:url>wrong.png</bad:url></bad:image>
    #|<image><url>ok.png</url><title>Icon</title><link>/</link><width>999999999999999999</width><height>0</height></image>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.images.length(), 1)
  assert_eq(feed.images[0].url, "ok.png")
  assert_eq(feed.images[0].width, None)
  assert_eq(feed.images[0].height, None)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidFeedImage(_))
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidFeedImage(_))
  assert_eq(feed.diagnostics[0].line, 3)
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>T</title><link>L</link><description>D</description><image><url>x</url></image></channel></rss>",
    )
    is Ok(missing) else {
    fail("expected RSS")
  }
  assert_eq(missing.images, [])
  assert_true(missing.diagnostics[0].kind is @feedlens.InvalidFeedImage(_))
}

///|
test "Atom icon and logo retain distinct roles and inherited xml:base" {
  let input =
    #|<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:bad="urn:bad" xml:base="https://example.test/assets/">
    #|<a:id>f</a:id><a:title>T</a:title><a:updated>2026-10-19T00:00:00Z</a:updated>
    #|<bad:icon>wrong.png</bad:icon><a:icon xml:base="icons/">small.png</a:icon>
    #|<a:logo xml:base="../brands/">wide.png</a:logo>
    #|</a:feed>
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.images.length(), 2)
  assert_true(raw.images[0].role is @feedlens.AtomIcon)
  assert_true(raw.images[1].role is @feedlens.AtomLogo)
  assert_eq(raw.images[0].url, "small.png")
  assert_eq(raw.images[1].url, "wide.png")
  guard @feedlens.parse_with_source(input, "https://example.test/feed.atom")
    is Ok(resolved) else {
    fail("expected resolved Atom")
  }
  assert_eq(
    resolved.images[0].url,
    "https://example.test/assets/icons/small.png",
  )
  assert_eq(resolved.images[1].url, "https://example.test/brands/wide.png")
}

///|
test "Atom blank, duplicate, nested, and unresolvable visuals have located diagnostics" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:bad">
    #|<id>f</id><title>T</title><updated>2026-10-19T00:00:00Z</updated>
    #|<icon> </icon><icon>duplicate.png</icon><logo><x:span>hidden</x:span></logo>
    #|</feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.images, [])
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidFeedImage(_))
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidFeedImage(_))
  assert_true(feed.diagnostics[2].kind is @feedlens.UnsupportedNestedMarkup(_))
  assert_eq(feed.diagnostics[0].line, 3)
  let bad_uri =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>T</title><updated>2026-10-19T00:00:00Z</updated>
    #|<icon xml:base="http://[bad">relative.png</icon></feed>
  guard @feedlens.parse_with_source(bad_uri, "https://example.test/feed.atom")
    is Ok(unresolved) else {
    fail("expected Atom")
  }
  assert_eq(unresolved.images[0].url, "relative.png")
  assert_true(
    unresolved.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom icon") && d.line == 2
    }),
  )
}

///|
test "JSON Feed icon and favicon retain separate roles and invalid types are diagnosed" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"T","icon":"icons/large.png","favicon":"/tiny.png","items":[]}
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected JSON Feed") }
  assert_eq(raw.images.length(), 2)
  assert_true(raw.images[0].role is @feedlens.JsonIcon)
  assert_true(raw.images[1].role is @feedlens.JsonFavicon)
  assert_eq(raw.images[0].url, "icons/large.png")
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(resolved) else {
    fail("expected resolved JSON Feed")
  }
  assert_eq(resolved.images[0].url, "https://example.test/icons/large.png")
  assert_eq(resolved.images[1].url, "https://example.test/tiny.png")
  let invalid =
    #|{"version":"https://jsonfeed.org/version/1","title":"T","icon":42,"favicon":"  ","items":[]}
  guard @feedlens.parse(invalid) is Ok(bad) else { fail("expected JSON Feed") }
  assert_eq(bad.images, [])
  assert_true(bad.diagnostics[0].kind is @feedlens.InvalidJsonFeedField("icon"))
  assert_true(bad.diagnostics[1].kind is @feedlens.InvalidFeedImage(_))
  assert_eq(bad.diagnostics[0].line, 1)
}
