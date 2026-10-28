///|
test "Atom generator and visuals preserve empty and malformed IRI declarations" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="assets/"><id>urn:f</id><title>F</title><updated>2026-10-28T00:00:00Z</updated><author><name>A</name></author>
    #|<generator uri="bad[one]">Maker</generator><icon xml:base="icons/"/><logo>bad%GG</logo>
    #|<entry><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><source xml:base="../origins/"><generator uri="">Origin</generator><icon>bad|url</icon><logo xml:base="brands/"></logo></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.generator_uri, Some("bad[one]"))
  assert_eq(feed.images.length(), 2)
  assert_eq(feed.images[0].url, "")
  assert_eq(feed.images[1].url, "bad%GG")
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.generator_uri, Some(""))
  assert_eq(source.images.length(), 2)
  assert_eq(source.images[0].url, "bad|url")
  assert_eq(source.images[1].url, "")
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAtomGeneratorUri("feed generator uri"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidFeedImage("atom source icon invalid IRI"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidFeedImage("atom logo invalid IRI"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[1].line, 3)
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.generator_uri, Some("bad[one]"))
  assert_eq(resolved.images[0].url, "https://example.test/feeds/assets/icons/")
  assert_eq(resolved.images[1].url, "bad%GG")
  guard resolved.entries[0].atom_source is Some(out_source) else {
    fail("expected resolved source")
  }
  assert_eq(
    out_source.generator_uri,
    Some("https://example.test/feeds/origins/"),
  )
  assert_eq(out_source.images[0].url, "bad|url")
  assert_eq(
    out_source.images[1].url,
    "https://example.test/feeds/origins/brands/",
  )
  assert_true(
    resolved.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom feed generator uri")
    }),
  )
  assert_true(
    resolved.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom logo")
    }),
  )
  assert_true(
    resolved.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom source icon")
    }),
  )
}

///|
test "standalone Entry resolves empty source visual and diagnoses generator URI" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-28T00:00:00Z</updated><author><name>A</name></author><content>Body</content><source xml:base="origin/"><generator uri="tool%Q0">Maker</generator><icon xml:base="images/"/></source></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Entry")
  }
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.generator_uri, Some("tool%Q0"))
  assert_eq(source.images[0].url, "")
  assert_true(
    diagnostics[0].kind
    is @feedlens.InvalidAtomGeneratorUri("source generator uri"),
  )
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected source-aware Entry")
  }
  guard resolved.atom_source is Some(out) else { fail("expected source") }
  assert_eq(out.generator_uri, Some("tool%Q0"))
  assert_eq(out.images[0].url, "https://example.test/entries/origin/images/")
  assert_true(
    located.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom source generator uri")
    }),
  )
}
