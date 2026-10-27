///|
test "RSS channel Atom self link is distinct from its website link" {
  let input =
    #|<rss version="2.0" xmlns:a="http://www.w3.org/2005/Atom" xmlns:other="urn:other"><channel><title>Stories</title><link>https://example.test/</link><description>News</description>
    #|<a:link rel="self" href="../feeds/stories.xml" type="application/rss+xml"/>
    #|<a:link rel="http://www.iana.org/assignments/relation/self" href="https://mirror.test/stories.xml"/>
    #|<a:link rel="related" href="https://example.test/about"/><other:link rel="self" href="https://wrong.test/"/>
    #|<wrapper><a:link rel="self" href="https://nested.test/"/></wrapper>
    #|<item><title>One</title><a:link rel="self" href="https://item.test/"/></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_true(feed.format is @feedlens.Rss2)
  assert_eq(feed.link, Some("https://example.test/"))
  assert_eq(feed.links.length(), 2)
  assert_eq(feed.links[0].relation, "self")
  assert_eq(feed.links[0].href, "../feeds/stories.xml")
  assert_eq(feed.links[0].media_type, Some("application/rss+xml"))
  assert_eq(
    feed.links[1].relation,
    "http://www.iana.org/assignments/relation/self",
  )
  assert_eq(feed.links[1].href, "https://mirror.test/stories.xml")
  assert_eq(feed.entries[0].links, [])
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/public/current.xml",
    )
    is Ok(resolved) else {
    fail("expected source-aware RSS")
  }
  assert_eq(resolved.link, feed.link)
  assert_eq(resolved.links.length(), 2)
  assert_eq(resolved.links[0].href, "https://example.test/feeds/stories.xml")
  assert_eq(resolved.links[1].href, feed.links[1].href)
  assert_eq(resolved.diagnostics, [])
}

///|
test "RSS invalid channel Atom self link is diagnosed without losing the feed" {
  let input = "<rss version=\"2.0\" xmlns:a=\"http://www.w3.org/2005/Atom\"><channel><title>N</title><link>https://example.test/</link><description>D</description><a:link rel=\"self\"/></channel></rss>"
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected recovered RSS")
  }
  assert_eq(feed.links, [])
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidAtomLink("missing href") && d.line == 1
    }),
  )
}
