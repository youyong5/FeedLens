///|
test "Atom direct-child cardinality is scoped to feed entry source and person" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:other">
    #|<id>urn:card:feed</id><title>First feed</title><title>Last feed</title><updated>2026-10-28T00:00:00Z</updated>
    #|<author><name>First editor</name><name>Last editor</name></author><category term="a"/><category term="b"/><x:title>Extension title</x:title>
    #|<entry><id>urn:card:entry</id><title>Entry</title><updated>2026-10-28T00:00:00Z</updated><updated>2026-10-28T01:00:00Z</updated><content>First body</content><content>Last body</content>
    #|<source><id>urn:card:origin</id><id>urn:card:last</id><title>Origin</title><author><name>Origin editor</name></author><category term="c"/><category term="d"/></source>
    #|<contributor><name>Contributor one</name></contributor><contributor><name>Contributor two</name></contributor><x:content>Extension body</x:content></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected feed") }
  assert_eq(feed.title, Some("Last feed"))
  assert_eq(feed.authors[0].name, Some("Last editor"))
  assert_eq(feed.categories.length(), 2)
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].updated_at, Some("2026-10-28T01:00:00Z"))
  assert_eq(feed.entries[0].content, Some("Last body"))
  assert_eq(feed.entries[0].contributors.length(), 2)
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(source.identifier, Some("urn:card:last"))
  assert_eq(source.categories.length(), 2)
  assert_eq(feed.entries[0].authors[0].name, Some("Origin editor"))
  assert_eq(feed.diagnostics.length(), 5)
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("feed title") && d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("atom author name") && d.line == 3
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("entry updated") && d.line == 4
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("entry content") && d.line == 4
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("source id") && d.line == 5
    }),
  )
}

///|
test "Atom source author satisfies independent Entry but not feed author rule" {
  let standalone =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:card:alone</id><title>Alone</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><source><author><name>Origin</name></author></source></entry>
  guard @feedlens.parse_document(standalone)
    is Ok(@feedlens.AtomEntryDocument(entry, problems)) else {
    fail("expected independent entry")
  }
  assert_eq(entry.authors[0].name, Some("Origin"))
  assert_eq(problems, [])
  let feed_input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:card:feed</id><title>Feed</title><updated>2026-10-28T00:00:00Z</updated><entry><id>urn:card:entry</id><title>Entry</title><updated>2026-10-28T00:00:00Z</updated><content>Body</content><source><author><name>Origin</name></author></source></entry></feed>
  guard @feedlens.parse(feed_input) is Ok(feed) else {
    fail("expected recovered feed")
  }
  assert_eq(feed.entries[0].authors[0].name, Some("Origin"))
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(feed.diagnostics[0].kind is @feedlens.MissingFeedField("author"))
}
