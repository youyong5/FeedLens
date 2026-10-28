///|
test "Atom feed and source retain declared empty and whitespace generator text" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/feeds/"><id>urn:g</id><title>Generator</title><updated>2026-10-28T00:00:00Z</updated><author><name>Editor</name></author><generator uri="tools/" version=""/>
    #|<entry><id>urn:g:item</id><title>Item</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><source><generator uri="" version="2">  </generator></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected feed") }
  assert_eq(feed.generator, Some(""))
  assert_eq(feed.generator_uri, Some("tools/"))
  assert_eq(feed.generator_version, Some(""))
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source metadata")
  }
  assert_eq(source.generator, Some("  "))
  assert_eq(source.generator_uri, Some(""))
  assert_eq(source.generator_version, Some("2"))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(xml, "https://example.test/main.atom")
    is Ok(resolved) else {
    fail("expected source-aware feed")
  }
  assert_eq(resolved.generator, Some(""))
  assert_eq(resolved.generator_uri, Some("https://example.test/feeds/tools/"))
  guard resolved.entries[0].atom_source is Some(resolved_source) else {
    fail("expected resolved source")
  }
  assert_eq(resolved_source.generator, Some("  "))
  assert_eq(resolved_source.generator_uri, Some("https://example.test/feeds/"))
}

///|
test "standalone Atom Entry source retains a present empty generator" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:g:entry</id><title>Entry</title><updated>2026-10-28T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content><source><generator version="3"/></source></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Entry")
  }
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.generator, Some(""))
  assert_eq(source.generator_version, Some("3"))
  assert_eq(diagnostics, [])
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware independent Entry")
  }
  guard resolved.atom_source is Some(resolved_source) else {
    fail("expected resolved source")
  }
  assert_eq(resolved_source.generator, Some(""))
  assert_eq(located, [])
}
