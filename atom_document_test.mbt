///|
test "stand-alone Atom Entry Document keeps fields, XHTML, and source scopes" {
  let input =
    #|<?xml version="1.0" encoding="utf-8"?>
    #|<entry xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml" xml:lang="en" xml:base="posts/">
    #|  <id>urn:feedlens:standalone:1</id>
    #|  <title type="xhtml"><h:div>One <h:em>entry</h:em></h:div></title>
    #|  <updated>2026-10-21T12:00:00Z</updated>
    #|  <author><name>Editor</name><uri>https://example.test/editor</uri></author>
    #|  <link rel="alternate" href="one"/>
    #|  <link rel="enclosure" href="audio/one.mp3" type="audio/mpeg" length="12"/>
    #|  <content type="xhtml"><h:div><h:p>Body &amp; context.</h:p></h:div></content>
    #|</entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom entry")
  }
  assert_eq(entry.identifier, Some("urn:feedlens:standalone:1"))
  assert_eq(entry.title, Some("One entry"))
  assert_true(entry.title_kind is @feedlens.Xhtml)
  assert_eq(entry.content, Some("Body & context."))
  assert_eq(entry.language, Some("en"))
  assert_eq(entry.authors[0].name, Some("Editor"))
  assert_eq(entry.attachments[0].url, "audio/one.mp3")
  assert_eq(diagnostics, [])
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/news/entry.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, problems)) else {
    fail("expected resolved independent Atom entry")
  }
  assert_eq(resolved.link, Some("https://example.test/news/posts/one"))
  assert_eq(
    resolved.attachments[0].url,
    "https://example.test/news/posts/audio/one.mp3",
  )
  assert_eq(problems, [])
  assert_true(@feedlens.parse(input) is Err(@feedlens.UnsupportedRoot(_, _)))
}

///|
test "entry documents use source author and required metadata diagnostics" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><source><author><name>Source editor</name></author></source><id>urn:one</id><title>One</title><updated>2026-10-21T12:00:00Z</updated><content>Body</content></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom entry")
  }
  assert_eq(entry.authors[0].name, Some("Source editor"))
  assert_eq(diagnostics, [])
  let incomplete =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><title>One</title></entry>
  guard @feedlens.parse_document(incomplete)
    is Ok(@feedlens.AtomEntryDocument(_, problems)) else {
    fail("expected recovered entry")
  }
  assert_true(problems[0].kind is @feedlens.MissingEntryField(0, "id"))
  assert_true(problems[1].kind is @feedlens.MissingEntryField(0, "updated"))
  assert_true(problems[2].kind is @feedlens.MissingAlternateLink(0))
  assert_true(problems[3].kind is @feedlens.MissingEntryField(0, "author"))
}
