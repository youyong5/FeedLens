///|
test "Atom feed entry and source diagnose malformed href without a source URL" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author><link href="bad%2G"/><link rel="self" href=""/>
    #|<entry><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><link href="post[one]"/><link rel="enclosure" href="audio|bad" type="audio/mpeg"/><source><link rel="related" href="bad#first#second"/></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.link, Some("bad%2G"))
  assert_eq(feed.links[1].href, "")
  assert_eq(feed.entries[0].link, Some("post[one]"))
  assert_eq(feed.entries[0].attachments[0].url, "audio|bad")
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected Atom source")
  }
  assert_eq(source.links[0].href, "bad#first#second")
  assert_eq(feed.diagnostics.length(), 4)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidAtomLink("invalid href"),
  )
  assert_eq(feed.diagnostics[0].line, 1)
  assert_true(
    feed.diagnostics[1].kind is @feedlens.InvalidAtomLink("invalid href"),
  )
  assert_eq(feed.diagnostics[1].line, 2)
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidAttachment("invalid Atom enclosure href"),
  )
  assert_eq(feed.diagnostics[2].line, 2)
  assert_true(
    feed.diagnostics[3].kind is @feedlens.InvalidAtomLink("invalid href"),
  )
  assert_eq(feed.diagnostics[3].line, 2)

  guard @feedlens.parse_with_source(xml, "https://example.test/feed.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.link, Some("bad%2G"))
  assert_eq(resolved.entries[0].attachments[0].url, "audio|bad")
  assert_true(
    resolved.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
}

///|
test "standalone Atom Entry distinguishes empty and malformed href" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author><content>Body</content><link href=""/><link rel="related" href="post?x={raw}"/><link rel="enclosure" href="audio%GG"/></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(entry.link, Some(""))
  assert_eq(entry.attachments[0].url, "audio%GG")
  assert_eq(diagnostics.length(), 2)
  assert_true(diagnostics[0].kind is @feedlens.InvalidAtomLink("invalid href"))
  assert_true(
    diagnostics[1].kind
    is @feedlens.InvalidAttachment("invalid Atom enclosure href"),
  )
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware standalone Entry")
  }
  assert_eq(resolved.link, Some("https://example.test/entries/one.atom"))
  assert_eq(resolved.links[1].href, "post?x={raw}")
  assert_true(located.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }))
}

///|
test "Atom raw links retain legal empty and uncommon IRI reference forms" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author>
    #|<link href=""/><link rel="related" href="?q=一"/><link rel="self" href="#part"/><link rel="via" href="//"/><link rel="custom" href="http:g"/><link rel="enclosure" href="音频.mp3?token=%5B1%5D"/></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.link, Some(""))
  assert_eq(feed.links.length(), 6)
  assert_eq(feed.links[3].href, "//")
  assert_eq(feed.links[4].href, "http:g")
  assert_eq(feed.links[5].href, "音频.mp3?token=%5B1%5D")
  assert_eq(feed.diagnostics, [])
}
