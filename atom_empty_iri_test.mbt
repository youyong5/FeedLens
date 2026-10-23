///|
test "empty Atom IRI references retain presence and resolve scoped base" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="pages/index.atom?view=feed"><id>urn:f</id><title>F</title><updated>2026-10-23T00:00:00Z</updated><author><name>Editor</name></author><link href=""/><entry xml:base="../entries/current.atom?edition=1"><id>urn:e</id><title>E</title><updated>2026-10-23T00:00:00Z</updated><summary>External</summary><link rel="alternate" href=""/><link rel="enclosure" href="" type="audio/mpeg" length="0"/><source><link href=""/></source><content src="" type="application/xml"/></entry></feed>
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.link, Some(""))
  assert_eq(raw.links[0].href, "")
  let entry = raw.entries[0]
  assert_eq(entry.link, Some(""))
  assert_eq(entry.links.length(), 2)
  assert_eq(entry.attachments.length(), 1)
  assert_eq(entry.attachments[0].url, "")
  assert_eq(entry.content_source, Some(""))
  guard entry.atom_body is Some(@feedlens.External(reference)) else {
    fail("expected external content")
  }
  assert_eq(reference.src, "")
  assert_eq(reference.url, "")
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.link, Some(""))
  assert_eq(source.links[0].href, "")
  assert_eq(raw.diagnostics, [])

  guard @feedlens.parse_with_source(
      input, "https://example.test/root/feed.atom",
    )
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  let feed_url = "https://example.test/root/pages/index.atom?view=feed"
  let entry_url = "https://example.test/root/entries/current.atom?edition=1"
  assert_eq(resolved.link, Some(feed_url))
  assert_eq(resolved.links[0].href, feed_url)
  assert_eq(resolved.entries[0].link, Some(entry_url))
  assert_eq(resolved.entries[0].links[0].href, entry_url)
  assert_eq(resolved.entries[0].links[1].href, entry_url)
  assert_eq(resolved.entries[0].attachments[0].url, entry_url)
  assert_eq(resolved.entries[0].content_source, Some(entry_url))
  guard resolved.entries[0].atom_body is Some(@feedlens.External(external)) else {
    fail("expected resolved external content")
  }
  assert_eq(external.src, "")
  assert_eq(external.url, entry_url)
  assert_eq(external.base_uri, Some(entry_url))
  guard resolved.entries[0].atom_source is Some(source) else {
    fail("expected resolved source")
  }
  assert_eq(source.link, Some(entry_url))
  assert_eq(source.links[0].href, entry_url)
  assert_eq(resolved.diagnostics, [])
}

///|
test "independent Atom entry distinguishes empty references from missing attributes" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:alone</id><title>Standalone</title><updated>2026-10-23T00:00:00Z</updated><author><name>Editor</name></author><summary>Remote body</summary><link href=""/><link rel="related"/><link rel="enclosure" href=""/><content src="" type="image/png"/></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected standalone Atom")
  }
  assert_eq(entry.link, Some(""))
  assert_eq(entry.links.length(), 2)
  assert_eq(entry.attachments[0].url, "")
  assert_eq(entry.content_source, Some(""))
  assert_true(
    diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidAtomLink("missing href")
    }),
  )
  assert_true(
    !diagnostics.any(fn(d) { d.kind is @feedlens.MissingAlternateLink(_) }),
  )
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, _)) else {
    fail("expected resolved standalone Atom")
  }
  assert_eq(resolved.link, Some("https://example.test/entries/one.atom"))
  assert_eq(
    resolved.attachments[0].url,
    "https://example.test/entries/one.atom",
  )
  assert_eq(
    resolved.content_source,
    Some("https://example.test/entries/one.atom"),
  )
}
