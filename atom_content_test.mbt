///|
test "Atom external content exposes raw source and declared MIME type" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>Readable abstract</summary><content type="application/pdf" src="../media/issue.pdf"/></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  let entry = feed.entries[0]
  assert_eq(entry.content_source, Some("../media/issue.pdf"))
  assert_eq(entry.content_media_type, Some("application/pdf"))
  assert_eq(entry.content, None)
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom content source uses the content element xml:base scope" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/feeds/"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>A</name></author>
    #|<entry xml:base="posts/"><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>Abstract</summary><content xml:base="../media/" type="application/pdf" src="issue.pdf"/></entry></feed>
  guard @feedlens.parse_with_source(input, "https://origin.test/atom.xml")
    is Ok(feed) else {
    fail("expected resolved Atom")
  }
  assert_eq(
    feed.entries[0].content_source,
    Some("https://example.test/feeds/media/issue.pdf"),
  )
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected raw Atom") }
  assert_eq(raw.entries[0].content_source, Some("issue.pdf"))
}

///|
test "Atom text MIME content remains decoded text with its media type" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><content type="text/markdown"> Heading &amp; detail </content></entry>
    #|<entry><id>empty</id><title>Empty</title><updated>2026-10-21T00:00:00Z</updated><content type="text/plain"/></entry>
    #|<entry><id>binary</id><title>Binary</title><updated>2026-10-21T00:00:00Z</updated><content type="application/pdf">AA==</content></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].content, Some(" Heading & detail "))
  assert_eq(feed.entries[0].content_media_type, Some("text/markdown"))
  assert_true(feed.entries[0].content_kind is @feedlens.Text)
  assert_eq(feed.entries[1].content, Some(""))
  assert_eq(feed.entries[1].content_media_type, Some("text/plain"))
  assert_eq(feed.entries[2].content, None)
  assert_eq(feed.entries[2].content_media_type, Some("application/pdf"))
  guard feed.entries[2].atom_body
    is Some(@feedlens.InlineBinary(bytes, "application/pdf")) else {
    fail("expected decoded PDF body")
  }
  assert_eq(bytes.length(), 1)
  assert_eq(bytes[0].to_int(), 0)
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.MissingSummaryForBinaryContent(2),
  )
}
