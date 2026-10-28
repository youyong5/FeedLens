///|
test "Atom person URI distinguishes empty, legal relative and malformed references" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-28T00:00:00Z</updated><author xml:base="authors/"><name>F</name><uri/></author>
    #|<entry><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><contributor><name>C</name><uri>bad%2G</uri></contributor>
    #|<source xml:base="../origins/"><author><name>S</name><uri>?p=一</uri></author></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.authors[0].uri, Some(""))
  assert_eq(feed.entries[0].contributors[0].uri, Some("bad%2G"))
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.authors[0].uri, Some("?p=一"))
  assert_eq(feed.entries[0].authors[0].uri, Some("?p=一"))
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAuthor("invalid atom person uri"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(
    resolved.authors[0].uri,
    Some("https://example.test/feeds/authors/"),
  )
  assert_eq(resolved.entries[0].contributors[0].uri, Some("bad%2G"))
  guard resolved.entries[0].atom_source is Some(out_source) else {
    fail("expected resolved source")
  }
  assert_eq(
    out_source.authors[0].uri,
    Some("https://example.test/origins/?p=一"),
  )
  assert_eq(resolved.entries[0].authors[0].uri, out_source.authors[0].uri)
  assert_true(
    resolved.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom person uri") && d.line == 2
    }),
  )
}

///|
test "standalone Atom Entry preserves an explicitly empty person URI" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><author xml:base="people/"><name>A</name><uri></uri></author><content>Body</content></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(entry.authors[0].uri, Some(""))
  assert_eq(diagnostics, [])
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware standalone Entry")
  }
  assert_eq(
    resolved.authors[0].uri,
    Some("https://example.test/entries/people/"),
  )
  assert_eq(located, [])
}
