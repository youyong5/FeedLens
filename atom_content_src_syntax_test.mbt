///|
test "Atom feed content src validates IRI syntax without losing the declaration" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-28T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>urn:a</id><title>A</title><updated>2026-10-28T00:00:00Z</updated><summary>S</summary><content src="bad%2G" type="application/xml"/></entry>
    #|<entry><id>urn:b</id><title>B</title><updated>2026-10-28T00:00:00Z</updated><summary>S</summary><content src="../媒体.xml?x=%5B1%5D" type="application/xml"/></entry>
    #|<entry><id>urn:c</id><title>C</title><updated>2026-10-28T00:00:00Z</updated><summary>S</summary><content src="" type="application/xml"/></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].content_source, Some("bad%2G"))
  assert_eq(feed.entries[0].atom_body, None)
  assert_eq(feed.entries[1].content_source, Some("../媒体.xml?x=%5B1%5D"))
  guard feed.entries[1].atom_body is Some(@feedlens.External(valid)) else {
    fail("expected legal relative IRI")
  }
  assert_eq(valid.url, "../媒体.xml?x=%5B1%5D")
  assert_true(feed.entries[2].atom_body is Some(@feedlens.External(_)))
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("invalid external Atom src"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.entries[0].content_source, Some("bad%2G"))
  assert_eq(resolved.entries[0].atom_body, None)
  assert_true(
    resolved.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom entry 0 content src")
    }),
  )
  guard resolved.entries[1].atom_body
    is Some(@feedlens.External(resolved_valid)) else {
    fail("expected resolved content")
  }
  assert_eq(resolved_valid.url, "https://example.test/媒体.xml?x=%5B1%5D")
  assert_eq(
    resolved.entries[2].content_source,
    Some("https://example.test/feeds/main.atom"),
  )
}

///|
test "standalone Atom Entry diagnoses malformed content src and retains raw value" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><author><name>A</name></author><summary>S</summary><content src="bad[one]" type="text/plain"/></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(entry.content_source, Some("bad[one]"))
  assert_eq(entry.atom_body, None)
  assert_eq(diagnostics.length(), 1)
  assert_true(
    diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("invalid external Atom src"),
  )
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware standalone Entry")
  }
  assert_eq(resolved.content_source, Some("bad[one]"))
  assert_eq(resolved.atom_body, None)
  assert_true(located.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }))
}
