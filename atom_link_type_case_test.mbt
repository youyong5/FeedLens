///|
test "Atom alternate MIME names compare case-insensitively without folding parameter values" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:mime:feed</id><title>MIME links</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author>
    #|<link href="first" type="text/html" hreflang="en-US"/>
    #|<link href="same-type" type="TEXT/HTML" hreflang="EN-us"/>
    #|<link href="profile-one" type="text/html; profile=One" hreflang="fr"/>
    #|<link href="profile-two" type="TEXT/HTML; profile=one" hreflang="fr"/>
    #|<entry><id>urn:mime:entry</id><title>Entry</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content>
    #|<link href="entry-first" type="application/atom+xml"/>
    #|<link href="entry-same-type" type="APPLICATION/ATOM+XML"/>
    #|</entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.link, Some("first"))
  assert_eq(feed.links.length(), 4)
  assert_eq(feed.links[1].media_type, Some("TEXT/HTML"))
  assert_eq(feed.links[3].media_type, Some("TEXT/HTML; profile=one"))
  assert_eq(feed.entries[0].link, Some("entry-first"))
  assert_eq(feed.entries[0].links.length(), 2)
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.DuplicateAtomField("feed alternate link"),
  )
  assert_eq(feed.diagnostics[0].line, 3)
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.DuplicateAtomField("entry alternate link"),
  )
  assert_eq(feed.diagnostics[1].line, 8)
}

///|
test "independent Atom Entry compares alternate MIME names" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:mime:standalone</id><title>Entry</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content>
    #|<link href="first" type="text/html"/><link href="second" type="TEXT/HTML"/>
    #|</entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected Atom Entry")
  }
  assert_eq(entry.link, Some("first"))
  assert_eq(entry.links[1].media_type, Some("TEXT/HTML"))
  assert_eq(diagnostics.length(), 1)
  assert_true(
    diagnostics[0].kind is @feedlens.DuplicateAtomField("entry alternate link"),
  )
  assert_eq(diagnostics[0].line, 2)
}
