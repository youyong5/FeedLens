///|
test "Atom person URI scopes and inheritance across feed, entry and source" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/feeds/"><id>urn:people</id><title>People</title><updated>2026-10-22T00:00:00Z</updated><author><name>Feed editor</name><uri xml:base="staff/">editor</uri></author><contributor><name>Feed helper</name><uri>team</uri></contributor>
    #|<entry xml:base="posts/"><id>urn:one</id><title>Own author</title><updated>2026-10-22T00:00:00Z</updated><content>One</content><author><name>Writer</name><uri xml:base="../people/">writer</uri></author><contributor><name>Reviewer</name><uri>reviewer</uri></contributor><source xml:base="../origin/"><author><name>Original</name><uri>original</uri></author><contributor><name>Helper</name><uri xml:base="staff/">helper</uri></contributor></source></entry>
    #|<entry><id>urn:two</id><title>Source author</title><updated>2026-10-22T00:00:00Z</updated><content>Two</content><source xml:base="origin/"><author><name>Source editor</name><uri xml:base="people/">source-editor</uri></author></source></entry>
    #|<entry><id>urn:three</id><title>Feed author</title><updated>2026-10-22T00:00:00Z</updated><content>Three</content></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.entries.length(), 3)
  assert_eq(raw.authors[0].uri, Some("editor"))
  assert_eq(raw.entries[0].authors[0].uri, Some("writer"))
  guard raw.entries[0].atom_source is Some(raw_source) else {
    fail("expected source")
  }
  assert_eq(raw_source.authors[0].uri, Some("original"))
  guard @feedlens.parse_with_source(
      input, "https://example.test/aggregate.atom",
    )
    is Ok(feed) else {
    fail("expected resolved Atom")
  }
  assert_eq(
    feed.authors[0].uri,
    Some("https://example.test/feeds/staff/editor"),
  )
  assert_eq(feed.contributors[0].uri, Some("https://example.test/feeds/team"))
  assert_eq(
    feed.entries[0].authors[0].uri,
    Some("https://example.test/feeds/people/writer"),
  )
  assert_eq(
    feed.entries[0].contributors[0].uri,
    Some("https://example.test/feeds/posts/reviewer"),
  )
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected source")
  }
  assert_eq(
    source.authors[0].uri,
    Some("https://example.test/feeds/origin/original"),
  )
  assert_eq(
    source.contributors[0].uri,
    Some("https://example.test/feeds/origin/staff/helper"),
  )
  assert_eq(
    feed.entries[1].authors[0].uri,
    Some("https://example.test/feeds/origin/people/source-editor"),
  )
  assert_eq(feed.entries[2].authors[0].uri, feed.authors[0].uri)
  assert_eq(feed.diagnostics, [])
}

///|
test "independent Atom Entry resolves person URI under its own element base" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="posts/"><id>urn:e</id><title>E</title><updated>2026-10-22T00:00:00Z</updated><content>Body</content><author><name>Writer</name><uri xml:base="../people/">writer</uri></author><contributor><name>Helper</name><uri>helper</uri></contributor></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(raw, _)) else {
    fail("expected independent entry")
  }
  assert_eq(raw.authors[0].uri, Some("writer"))
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/feeds/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(entry, problems)) else {
    fail("expected source-aware entry")
  }
  assert_eq(
    entry.authors[0].uri,
    Some("https://example.test/feeds/people/writer"),
  )
  assert_eq(
    entry.contributors[0].uri,
    Some("https://example.test/feeds/posts/helper"),
  )
  assert_eq(problems, [])
}

///|
test "invalid person URI stays raw and duplicate children are located" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:other"><id>urn:e</id><title>E</title><updated>2026-10-22T00:00:00Z</updated><content>Body</content>
    #|<author><name>A</name><x:uri>ignored</x:uri><uri>first</uri><uri>bad path</uri><email>a@example.test</email><email>b@example.test</email></author>
    #|<contributor><name>B</name><uri>good</uri><uri/></contributor></entry>
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/posts/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(entry, problems)) else {
    fail("expected recoverable entry")
  }
  assert_eq(entry.authors[0].uri, Some("bad path"))
  assert_eq(entry.authors[0].email, Some("b@example.test"))
  assert_eq(
    entry.contributors[0].uri,
    Some("https://example.test/posts/one.atom"),
  )
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.InvalidAuthor("invalid atom person uri") &&
      d.line == 2
    }),
  )
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("atom author uri") && d.line == 2
    }),
  )
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("atom author email") && d.line == 2
    }),
  )
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("atom contributor uri") &&
      d.line == 3
    }),
  )
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom person uri") && d.line == 2
    }),
  )
}

///|
test "identical Atom person references retain independent XML Base scopes" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-22T00:00:00Z</updated><author xml:base="a/"><name>Editor</name><uri>person</uri></author><author xml:base="b/"><name>Editor</name><uri>person</uri></author><entry><id>urn:e</id><title>E</title><updated>2026-10-22T00:00:00Z</updated><content>Body</content></entry></feed>
  guard @feedlens.parse_with_source(input, "https://example.test/feed.atom")
    is Ok(feed) else {
    fail("expected Atom")
  }
  assert_eq(feed.authors[0].uri, Some("https://example.test/a/person"))
  assert_eq(feed.authors[1].uri, Some("https://example.test/b/person"))
  assert_eq(feed.entries[0].authors, feed.authors)
  assert_eq(feed.diagnostics, [])
}
