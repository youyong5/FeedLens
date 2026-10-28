///|
test "Atom Person text fields diagnose nested markup without losing other declarations" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:person-extension"><id>urn:people</id><title>People</title><updated>2026-10-28T00:00:00Z</updated>
    #|<author><name>Feed &lt;em&gt;</name><x:badge>allowed extension</x:badge></author>
    #|<contributor><name>A<x:b>nested</x:b><x:i/>Z</name><uri>people/<x:part/></uri><email>user@example.test<x:note/></email></contributor>
    #|<entry><id>urn:item</id><title>Item</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><author><name>Entry <x:b>mixed</x:b> text</name></author>
    #|<source><author><name>Source</name><email>source@example.test<x:note/></email><x:badge>allowed extension</x:badge></author></source></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.authors[0].name, Some("Feed <em>"))
  assert_eq(feed.contributors[0].name, Some("AnestedZ"))
  assert_eq(feed.contributors[0].uri, Some("people/"))
  assert_eq(feed.contributors[0].email, Some("user@example.test"))
  assert_eq(feed.entries[0].authors[0].name, Some("Entry mixed text"))
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected Atom source")
  }
  assert_eq(source.authors[0].email, Some("source@example.test"))
  let expected = [
    "nested markup in atom person name", "nested markup in atom person uri", "nested markup in atom person email",
    "nested markup in atom person name", "nested markup in atom person email",
  ]
  assert_eq(feed.diagnostics.length(), expected.length())
  for index = 0; index < expected.length(); index = index + 1 {
    guard feed.diagnostics[index].kind is @feedlens.InvalidAuthor(message) else {
      fail("expected Atom Person diagnostic")
    }
    assert_eq(message, expected[index])
    assert_true(feed.diagnostics[index].line >= 3)
    assert_true(feed.diagnostics[index].column > 0)
  }
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/main.atom")
    is Ok(resolved) else {
    fail("expected resolved Atom feed")
  }
  assert_eq(
    resolved.contributors[0].uri,
    Some("https://example.test/feeds/people/"),
  )
  assert_eq(resolved.diagnostics, feed.diagnostics)
}

///|
test "independent Atom Entry diagnoses nested Person URI and keeps source resolution" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:person-extension"><id>urn:standalone</id><title>Standalone</title><updated>2026-10-28T00:00:00Z</updated><author><name>Standalone</name><uri>people/<x:part/></uri></author><content>Body</content></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected Atom Entry document")
  }
  assert_eq(entry.authors[0].uri, Some("people/"))
  assert_eq(diagnostics.length(), 1)
  assert_true(
    diagnostics[0].kind
    is @feedlens.InvalidAuthor("nested markup in atom person uri"),
  )
  guard @feedlens.parse_document_with_source(
      xml, "https://example.test/entries/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, located)) else {
    fail("expected resolved Atom Entry document")
  }
  assert_eq(
    resolved.authors[0].uri,
    Some("https://example.test/entries/people/"),
  )
  assert_eq(located, diagnostics)
}
