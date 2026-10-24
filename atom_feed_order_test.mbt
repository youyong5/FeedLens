///|
test "Atom feed metadata following an entry is diagnosed without losing values" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:example:extension">
    #|<id>urn:order:feed</id><title>Feed</title><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author><x:before/>
    #|<entry><content>First body</content><updated>2026-10-24T00:00:00Z</updated><title>First</title><id>urn:order:first</id></entry>
    #|<subtitle>Late subtitle</subtitle><link href="late-home"/>
    #|<entry><id>urn:order:second</id><content>Second body</content><title>Second</title><updated>2026-10-24T01:00:00Z</updated></entry>
    #|<x:after/>
    #|</feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected feed") }
  assert_eq(feed.description, Some("Late subtitle"))
  assert_eq(feed.link, Some("late-home"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].content, Some("First body"))
  assert_eq(feed.entries[1].content, Some("Second body"))
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidAtomOrder("subtitle"))
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidAtomOrder("link"))
  assert_true(feed.diagnostics[2].kind is @feedlens.InvalidAtomOrder("x:after"))
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (4, 1))
  assert_eq((feed.diagnostics[1].line, feed.diagnostics[1].column), (4, 35))
  assert_eq((feed.diagnostics[2].line, feed.diagnostics[2].column), (6, 1))
}

///|
test "Atom feed metadata before entries and entry fields in any order are legal" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:example:extension"><x:before/><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author><title>Feed</title><id>urn:order:legal</id><entry><content>Body</content><updated>2026-10-24T00:00:00Z</updated><title>One</title><id>urn:order:one</id></entry><entry><id>urn:order:two</id><title>Two</title><updated>2026-10-24T01:00:00Z</updated><content>Other</content></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected feed") }
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.diagnostics, [])
}

///|
test "empty Atom entry still starts the feed entry section" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:order:empty</id><title>Feed</title><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author><entry/><subtitle/></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected feed") }
  assert_true(feed.diagnostics.any(fn(d) {
    d.kind is @feedlens.InvalidAtomOrder("subtitle")
  }))
  let independent =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><content>Body</content><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author><id>urn:order:alone</id><title>Alone</title></entry>
  guard @feedlens.parse_document(independent)
    is Ok(@feedlens.AtomEntryDocument(_, diagnostics)) else {
    fail("expected standalone entry")
  }
  assert_eq(diagnostics, [])
}
