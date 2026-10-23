///|
test "Atom dates require uppercase T and Z while JSON Feed accepts RFC 3339 case" {
  let atom =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:date:feed</id><title>Dates</title><updated>2026-10-14T13:00:00Z</updated><author><name>Editor</name></author>
    #|<entry><id>urn:date:entry</id><title>Entry</title><updated>2026-10-14T13:00:00Z</updated><published>2026-10-14T14:00:00+01:00</published><content>Body</content></entry>
    #|</feed>
  guard @feedlens.parse(atom) is Ok(feed) else { fail("expected Atom") }
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(published)) else {
    fail("expected valid Atom date")
  }
  assert_eq(published.utc, "2026-10-14T13:00:00Z")
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Dates\",\"items\":[]}",
    )
    is Ok(json_feed) else {
    fail("expected JSON Feed")
  }
  for raw in ["2026-10-14t13:00:00Z", "2026-10-14T13:00:00z"] {
    assert_true(
      @feedlens.normalize_date(feed.format, Some(raw))
      is Err(@feedlens.InvalidSyntax),
    )
    guard @feedlens.normalize_date(json_feed.format, Some(raw))
      is Ok(Some(date)) else {
      fail("expected valid case-insensitive JSON Feed RFC 3339 date")
    }
    assert_eq(date.utc, "2026-10-14T13:00:00Z")
  }
  guard @feedlens.parse_document(
      "<entry xmlns=\"http://www.w3.org/2005/Atom\"><id>urn:one</id><title>One</title><updated>2026-10-14T13:00:00Z</updated><author><name>N</name></author><content>Body</content></entry>",
    )
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry")
  }
  assert_eq(diagnostics, [])
  assert_true(
    @feedlens.normalize_date(feed.format, entry.updated_at) is Ok(Some(_)),
  )
}

///|
test "JSON Feed keeps explicitly empty plain-text author names and lowercase RFC 3339" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"People","authors":[{"name":""},{"avatar":"https://example.test/avatar.png"}],"items":[
    #|{"id":"one","content_text":"A","authors":[{"name":" "}],"date_published":"2026-10-14t13:00:00z"},
    #|{"id":"two","content_text":"B","date_modified":"2026-10-14T14:00:00+01:00"},
    #|{"id":"three","content_text":"C","author":{"name":""}}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.authors.length(), 2)
  assert_eq(feed.authors[0].name, Some(""))
  assert_eq(feed.authors[1].avatar, Some("https://example.test/avatar.png"))
  assert_eq(feed.entries.length(), 3)
  assert_eq(feed.entries[0].authors.length(), 1)
  assert_eq(feed.entries[0].authors[0].name, Some(" "))
  assert_eq(feed.entries[1].authors.length(), 2)
  assert_eq(feed.entries[1].authors[0].name, Some(""))
  assert_eq(feed.entries[2].authors.length(), 1)
  assert_eq(feed.entries[2].authors[0].name, Some(""))
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(first)) else {
    fail("expected lower-case JSON Feed date")
  }
  guard @feedlens.normalize_date(feed.format, feed.entries[1].updated_at)
    is Ok(Some(second)) else {
    fail("expected offset JSON Feed date")
  }
  assert_eq(first.utc, second.utc)
  assert_eq(feed.diagnostics, [])
}

///|
test "JSON Feed 1.0 also retains an explicitly empty singular author name" {
  let input = "{\"version\":\"https://jsonfeed.org/version/1\",\"title\":\"Legacy\",\"author\":{\"name\":\"\"},\"items\":[{\"id\":\"one\",\"content_text\":\"A\"}]}"
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected version 1") }
  assert_eq(feed.authors.length(), 1)
  assert_eq(feed.authors[0].name, Some(""))
  assert_eq(feed.entries[0].authors[0].name, Some(""))
  assert_eq(feed.diagnostics, [])
}
