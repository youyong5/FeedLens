///|
test "Atom feed, entry and source dates retain raw text and report malformed values" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom">
    #|<id>urn:date:invalid</id><title>Dates</title><updated>2026-02-30T00:00:00Z</updated><author><name>Editor</name></author>
    #|<entry><id>urn:date:one</id><title>One</title><updated>2026-10-23t09:00:00Z</updated><published>2026-10-23T09:00:00+25:00</published><content>Body</content><source><updated>2026-13-01T00:00:00Z</updated></source></entry>
    #|<entry><id>urn:date:two</id><title>Two</title><updated>2026-10-23T09:00:00-00:00</updated><published/></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected feed") }
  assert_eq(feed.updated_at, Some("2026-02-30T00:00:00Z"))
  assert_eq(feed.entries[0].updated_at, Some("2026-10-23t09:00:00Z"))
  assert_eq(feed.entries[0].published_at, Some("2026-10-23T09:00:00+25:00"))
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.updated_at, Some("2026-13-01T00:00:00Z"))
  assert_eq(feed.entries[1].updated_at, Some("2026-10-23T09:00:00-00:00"))
  assert_eq(feed.entries[1].published_at, None)
  let invalid : Array[@feedlens.Diagnostic] = []
  for diagnostic in feed.diagnostics {
    if diagnostic.kind is @feedlens.InvalidAtomDate(_) {
      invalid.push(diagnostic)
    }
  }
  assert_eq(invalid.length(), 5)
  assert_eq(invalid[0].kind, @feedlens.InvalidAtomDate("feed updated"))
  assert_eq((invalid[0].line, invalid[0].column), (2, 46))
  assert_eq(invalid[1].kind, @feedlens.InvalidAtomDate("entry updated"))
  assert_eq(invalid[2].kind, @feedlens.InvalidAtomDate("entry published"))
  assert_eq(invalid[3].kind, @feedlens.InvalidAtomDate("source updated"))
  assert_eq(invalid[4].kind, @feedlens.InvalidAtomDate("entry published"))
  assert_eq((invalid[4].line, invalid[4].column), (4, 91))
}

///|
test "independent Atom Entry reports invalid date without losing its content" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:date:alone</id><title>Alone</title><updated>2026-10-23T09:00:00z</updated><content>Readable</content><author><name>Editor</name></author></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone entry")
  }
  assert_eq(entry.content, Some("Readable"))
  assert_eq(entry.updated_at, Some("2026-10-23T09:00:00z"))
  assert_true(diagnostics.any(fn(d) {
    d.kind is @feedlens.InvalidAtomDate("entry updated") && d.line == 1
  }))
}
