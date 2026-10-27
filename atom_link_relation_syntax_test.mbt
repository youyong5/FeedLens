///|
test "Atom link rel accepts simple names and absolute IRIs only" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author>
    #|<link href="home"/><link rel="custom" href="custom"/><link rel="urn:example:relation" href="urn"/><link rel="https://例子.test/关系" href="iri"/>
    #|<link rel="" href="empty"/><link rel="bad/path" href="path"/><link rel="?query" href="query"/><link rel="bad#fragment" href="fragment"/><link rel="bad rel" href="space"/><link rel="https:///missing-host" href="host"/>
    #|<entry><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><link rel="related" href="relative"/><source><link rel="../relative" href="source"/></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.link, Some("home"))
  assert_eq(feed.links.length(), 10)
  assert_eq(feed.links[2].relation, "urn:example:relation")
  assert_eq(feed.links[3].relation, "https://例子.test/关系")
  assert_eq(feed.links[4].relation, "")
  assert_eq(feed.links[5].relation, "bad/path")
  assert_eq(feed.entries[0].links[0].relation, "related")
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected Atom source")
  }
  assert_eq(source.links[0].relation, "../relative")
  assert_eq(feed.diagnostics.length(), 7)
  for index = 0; index < 6; index = index + 1 {
    assert_true(
      feed.diagnostics[index].kind is @feedlens.InvalidAtomLink("invalid rel"),
    )
    assert_eq(feed.diagnostics[index].line, 3)
  }
  assert_true(
    feed.diagnostics[6].kind is @feedlens.InvalidAtomLink("invalid rel"),
  )
  assert_eq(feed.diagnostics[6].line, 4)
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.link, Some("https://example.test/feeds/home"))
  assert_eq(resolved.links[5].href, "https://example.test/feeds/path")
  assert_eq(resolved.diagnostics, feed.diagnostics)
}

///|
test "independent Atom Entry retains invalid rel and locates it" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author><content>Body</content>
    #|<link rel="self" href="self"/><link rel="./related" href="bad"/><link rel="urn:relation:valid" href="good"/></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(entry.links.length(), 3)
  assert_eq(entry.links[1].relation, "./related")
  assert_eq(diagnostics.length(), 1)
  assert_true(diagnostics[0].kind is @feedlens.InvalidAtomLink("invalid rel"))
  assert_eq(diagnostics[0].line, 2)
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entry.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware Entry")
  }
  assert_eq(resolved.links[1].href, "https://example.test/bad")
  assert_eq(located, diagnostics)
}
