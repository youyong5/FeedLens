///|
test "Atom Person email keeps quoted and domain literal addr-specs and diagnoses defects" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-28T00:00:00Z</updated><author><name>A</name><email>"a@b"@example.test</email></author>
    #|<contributor><name>B</name><email>bad..dot@example.test</email></contributor><entry><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><author><name>C</name><email/></author>
    #|<source><author><name>D</name><email>user@[192.0.2.1]</email></author></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.authors[0].email, Some("\"a@b\"@example.test"))
  assert_eq(feed.contributors[0].email, Some("bad..dot@example.test"))
  assert_eq(feed.entries[0].authors[0].email, Some(""))
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.authors[0].email, Some("user@[192.0.2.1]"))
  assert_eq(feed.diagnostics.length(), 2)
  for diagnostic in feed.diagnostics {
    assert_true(
      diagnostic.kind is @feedlens.InvalidAuthor("invalid atom person email"),
    )
    assert_eq(diagnostic.line, 2)
  }
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.authors[0].email, feed.authors[0].email)
  assert_eq(resolved.entries[0].authors[0].email, Some(""))
  assert_eq(resolved.diagnostics, feed.diagnostics)
}

///|
test "standalone Atom Entry retains invalid email and accepts comments" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><author><name>A</name><email>MissingAt</email></author><contributor><name>B</name><email>(note)user@example.test</email></contributor><content>Body</content></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(entry.authors[0].email, Some("MissingAt"))
  assert_eq(entry.contributors[0].email, Some("(note)user@example.test"))
  assert_eq(diagnostics.length(), 1)
  assert_true(
    diagnostics[0].kind is @feedlens.InvalidAuthor("invalid atom person email"),
  )
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/e.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware Entry")
  }
  assert_eq(resolved.authors[0].email, Some("MissingAt"))
  assert_eq(located, diagnostics)
}
