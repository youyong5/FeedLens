///|
test "Atom category scheme is an absolute IRI at feed, entry and source" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:other" xml:base="https://example.test/feeds/">
    #|<id>urn:schemes:feed</id><title>Categories</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author>
    #|<category term="news" scheme="https://taxonomy.test/topics" label="News"/><category term="code" scheme="urn:taxonomy:code"/><x:category term="ignored" scheme="relative"/>
    #|<entry xml:base="articles/"><id>urn:schemes:entry</id><title>Item</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><category term="item" scheme="https://taxonomy.test/items"/><source xml:base="../origin/"><category term="archive" scheme="urn:taxonomy:archive"/></source></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.categories.length(), 2)
  assert_eq(raw.categories[0].scheme, Some("https://taxonomy.test/topics"))
  assert_eq(raw.categories[1].scheme, Some("urn:taxonomy:code"))
  assert_eq(
    raw.entries[0].categories[0].scheme,
    Some("https://taxonomy.test/items"),
  )
  guard raw.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.categories[0].scheme, Some("urn:taxonomy:archive"))
  assert_eq(raw.diagnostics, [])
  guard @feedlens.parse_with_source(input, "https://example.test/main.atom")
    is Ok(resolved) else {
    fail("expected resolved Atom")
  }
  assert_eq(resolved.categories, raw.categories)
  assert_eq(resolved.entries[0].categories, raw.entries[0].categories)
  assert_eq(resolved.entries[0].atom_source, raw.entries[0].atom_source)
  assert_eq(resolved.diagnostics, [])
}

///|
test "standalone Atom Entry keeps invalid relative category scheme with location" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/entry/"><id>urn:schemes:alone</id><title>Alone</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content><category term="bad" scheme="../topics"/><source><category term="source" scheme=" "/></source></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(raw, diagnostics)) else {
    fail("expected standalone Entry")
  }
  assert_eq(raw.categories[0].scheme, Some("../topics"))
  guard raw.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.categories[0].scheme, Some(" "))
  assert_eq(diagnostics.length(), 2)
  assert_true(
    diagnostics.all(fn(d) {
      d.kind
      is @feedlens.InvalidCategory(
        "atom category scheme must be an absolute IRI"
      )
    }),
  )
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/document.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected resolved Entry")
  }
  assert_eq(resolved.categories[0].scheme, Some("../topics"))
  assert_eq(located, diagnostics)
}
