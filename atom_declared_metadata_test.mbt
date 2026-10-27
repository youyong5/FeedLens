///|
test "Atom explicit empty and whitespace metadata survives without false inheritance" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:meta:feed</id><title>Declared strings</title><updated>2026-10-23T00:00:00Z</updated>
    #|<author><name/></author><category term="" label="  " scheme=""/><link href="home" title=""/>
    #|<entry><id>urn:meta:own</id><title>Own</title><updated>2026-10-23T00:00:00Z</updated><author><name>  </name></author><category term="  " label="" scheme="topics"/><link href="post" title="  "/><link rel="enclosure" href="audio.mp3" title=""/><content>Body</content></entry>
    #|<entry><id>urn:meta:source</id><title>Source</title><updated>2026-10-23T00:00:00Z</updated><source><author><name>Origin</name></author><category term="" label=""/></source><content>Body</content></entry>
    #|<entry><id>urn:meta:inherited</id><title>Inherited</title><updated>2026-10-23T00:00:00Z</updated><content>Body</content></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.authors[0].name, Some(""))
  assert_eq(raw.categories[0].term, "")
  assert_eq(raw.categories[0].label, Some("  "))
  assert_eq(raw.categories[0].scheme, Some(""))
  assert_eq(raw.links[0].title, Some(""))
  assert_eq(raw.entries[0].authors[0].name, Some("  "))
  assert_eq(raw.entries[0].categories[0].term, "  ")
  assert_eq(raw.entries[0].categories[0].label, Some(""))
  assert_eq(raw.entries[0].links[0].title, Some("  "))
  assert_eq(raw.entries[0].links[1].title, Some(""))
  assert_eq(raw.entries[0].attachments[0].title, Some(""))
  assert_eq(raw.entries[1].authors[0].name, Some("Origin"))
  guard raw.entries[1].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.categories[0].term, "")
  assert_eq(source.categories[0].label, Some(""))
  assert_eq(raw.entries[2].authors[0].name, Some(""))
  assert_eq(raw.diagnostics.length(), 2)
  assert_true(
    raw.diagnostics[0].kind
    is @feedlens.InvalidCategory("atom category scheme must be an absolute IRI"),
  )
  assert_true(
    raw.diagnostics[1].kind
    is @feedlens.InvalidCategory("atom category scheme must be an absolute IRI"),
  )
  assert_eq((raw.diagnostics[0].line, raw.diagnostics[0].column), (2, 25))
  assert_eq((raw.diagnostics[1].line, raw.diagnostics[1].column), (3, 118))

  guard @feedlens.parse_with_source(input, "https://example.test/feed.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.authors[0].name, Some(""))
  assert_eq(resolved.entries[0].authors[0].name, Some("  "))
  assert_eq(resolved.entries[1].authors[0].name, Some("Origin"))
  assert_eq(resolved.entries[2].authors[0].name, Some(""))
  assert_eq(resolved.categories[0].scheme, Some(""))
  assert_eq(resolved.links[0].title, Some(""))
  assert_eq(resolved.entries[0].attachments[0].title, Some(""))
  assert_eq(resolved.diagnostics, raw.diagnostics)
}

///|
test "standalone Atom Entry preserves empty person names and still reports missing name" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:alone</id><title>Alone</title><updated>2026-10-23T00:00:00Z</updated><content>Body</content><author><name/></author><contributor><name> </name></contributor><contributor><uri>nobody</uri></contributor><category term=""/><category label="Missing term"/></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(raw, diagnostics)) else {
    fail("expected standalone Atom")
  }
  assert_eq(raw.authors[0].name, Some(""))
  assert_eq(raw.contributors[0].name, Some(" "))
  assert_eq(raw.categories[0].term, "")
  assert_eq(raw.categories.length(), 1)
  assert_true(
    diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidAuthor("atom contributor missing name")
    }),
  )
  assert_true(
    diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidCategory("atom category missing term")
    }),
  )
  assert_true(
    !diagnostics.any(fn(d) {
      d.kind is @feedlens.MissingEntryField(_, "author")
    }),
  )
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/entry.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, _)) else {
    fail("expected source-aware standalone Atom")
  }
  assert_eq(resolved.authors[0].name, Some(""))
  assert_eq(resolved.contributors[0].name, Some(" "))
}
