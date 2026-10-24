///|
test "Atom link MIME hints accept composite types and diagnose malformed declarations" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed:link-type</id><title>Link types</title><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author>
    #|<link rel="self" href="index.atom" type="application/atom+xml; profile=&quot;all;items&quot;"/>
    #|<entry><id>urn:entry:link-type</id><title>Entry</title><updated>2026-10-24T00:00:00Z</updated><content>Body</content>
    #|<link href="article" type="text/html" hreflang="en"/>
    #|<link rel="related" href="bundle" type="multipart/alternative"/>
    #|<link rel="related" href="bad-token" type="text"/>
    #|<link rel="related" href="bad-parameter" type="image/png; name="/>
    #|<link rel="enclosure" href="bad-audio" type="audio"/>
    #|<link rel="enclosure" href="good-audio" type="audio/mpeg; codec=&quot;mp3&quot;" length="42"/>
    #|<source><link rel="related" href="source-bundle" type="message/rfc822"/></source>
    #|</entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.links[0].media_type, Some("application/atom+xml; profile=\"all;items\""))
  assert_eq(feed.entries[0].link, Some("article"))
  assert_eq(feed.entries[0].links.length(), 6)
  assert_eq(feed.entries[0].links[1].media_type, Some("multipart/alternative"))
  assert_eq(feed.entries[0].links[2].media_type, Some("text"))
  assert_eq(feed.entries[0].links[3].media_type, Some("image/png; name="))
  assert_eq(feed.entries[0].attachments.length(), 2)
  assert_eq(feed.entries[0].attachments[0].media_type, Some("audio"))
  assert_eq(feed.entries[0].attachments[1].media_type, Some("audio/mpeg; codec=\"mp3\""))
  guard feed.entries[0].atom_source is Some(source) else {
    fail("expected Atom source")
  }
  assert_eq(source.links[0].media_type, Some("message/rfc822"))
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidAtomLink("invalid type"))
  assert_eq(feed.diagnostics[0].line, 6)
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidAtomLink("invalid type"))
  assert_eq(feed.diagnostics[1].line, 7)
  assert_true(feed.diagnostics[2].kind is @feedlens.InvalidAttachment("invalid Atom enclosure type"))
  assert_eq(feed.diagnostics[2].line, 8)
}

///|
test "independent Atom Entry validates MIME hints without losing related links" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:entry:standalone</id><title>Standalone</title><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content>
    #|<link rel="related" href="bundle" type="multipart/mixed"/><link href="article" type="html"/>
    #|</entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry")
  }
  assert_eq(entry.links[0].media_type, Some("multipart/mixed"))
  assert_eq(entry.link, Some("article"))
  assert_eq(entry.links[1].media_type, Some("html"))
  assert_eq(diagnostics.length(), 1)
  assert_true(diagnostics[0].kind is @feedlens.InvalidAtomLink("invalid type"))
  assert_eq(diagnostics[0].line, 2)
}
