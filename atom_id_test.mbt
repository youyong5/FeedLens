///|
test "Atom ids retain raw absolute and malformed values with distinct diagnostics" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/feeds/">
    #|<id>urn:feed:stable</id><title>Identifiers</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author>
    #|<entry><id>chapters/one</id><title>Relative</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><source><id>origins/main</id><title>Original</title></source></entry>
    #|<entry><id>https://例子.test/作品</id><title>IRI</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content></entry>
    #|<entry><id> urn:bad:spaces </id><title>Spaces</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content></entry>
    #|<entry><id/><title>Empty</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.identifier, Some("urn:feed:stable"))
  assert_eq(raw.entries[0].identifier, Some("chapters/one"))
  guard raw.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.identifier, Some("origins/main"))
  assert_eq(raw.entries[1].identifier, Some("https://例子.test/作品"))
  assert_eq(raw.entries[2].identifier, Some(" urn:bad:spaces "))
  assert_eq(raw.entries[3].identifier, None)
  assert_eq(raw.entries.length(), 4)
  assert_eq(raw.diagnostics.length(), 4)
  assert_true(raw.diagnostics[0].kind is @feedlens.InvalidAtomId("entry id"))
  assert_true(raw.diagnostics[1].kind is @feedlens.InvalidAtomId("source id"))
  assert_true(raw.diagnostics[2].kind is @feedlens.InvalidAtomId("entry id"))
  assert_true(raw.diagnostics[3].kind is @feedlens.MissingEntryField(3, "id"))
  assert_eq((raw.diagnostics[0].line, raw.diagnostics[0].column), (3, 8))
  assert_eq((raw.diagnostics[1].line, raw.diagnostics[1].column), (3, 122))
  assert_eq((raw.diagnostics[2].line, raw.diagnostics[2].column), (5, 8))
  assert_eq((raw.diagnostics[3].line, raw.diagnostics[3].column), (6, 8))
  guard @feedlens.parse_with_source(input, "https://example.test/feed.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.entries[0].identifier, Some("chapters/one"))
  assert_eq(resolved.entries[0].atom_source, raw.entries[0].atom_source)
  assert_eq(resolved.diagnostics, raw.diagnostics)
}

///|
test "standalone Atom Entry diagnoses a relative id without resolving it" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/entry/"><id>relative</id><title>Standalone</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(entry.identifier, Some("relative"))
  assert_eq(diagnostics.length(), 1)
  assert_true(diagnostics[0].kind is @feedlens.InvalidAtomId("entry id"))
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/source.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, resolved_diagnostics)) else {
    fail("expected source-aware Entry")
  }
  assert_eq(resolved.identifier, Some("relative"))
  assert_eq(resolved_diagnostics, diagnostics)
}
