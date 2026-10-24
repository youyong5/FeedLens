///|
test "Atom link language syntax retains raw tags and finds translated alternate duplicates" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed:languages</id><title>Languages</title><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author>
    #|<link href="zh" type="text/html" hreflang="zh-Hant-TW"/>
    #|<link href="zh-copy" type="text/html" hreflang="ZH-hant-tw"/>
    #|<link rel="related" href="klingon" hreflang="i-klingon"/>
    #|<entry><id>urn:entry:languages</id><title>Entry</title><updated>2026-10-24T00:00:00Z</updated><content>Body</content>
    #|<link href="private" hreflang="x-private-12345678"/>
    #|<link rel="related" href="blank" hreflang=""/>
    #|<link rel="related" href="gap" hreflang="en--US"/>
    #|<link rel="enclosure" href="audio" type="" hreflang="en_US"/>
    #|<source><link rel="self" href="source" hreflang="fr-CA"/></source>
    #|</entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.link, Some("zh"))
  assert_eq(feed.links[1].hreflang, Some("ZH-hant-tw"))
  assert_eq(feed.links[2].hreflang, Some("i-klingon"))
  let entry = feed.entries[0]
  assert_eq(entry.link, Some("private"))
  assert_eq(entry.links.length(), 4)
  assert_eq(entry.links[0].hreflang, Some("x-private-12345678"))
  assert_eq(entry.links[1].hreflang, Some(""))
  assert_eq(entry.links[2].hreflang, Some("en--US"))
  assert_eq(entry.links[3].media_type, Some(""))
  assert_eq(entry.attachments[0].media_type, Some(""))
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.links[0].hreflang, Some("fr-CA"))
  assert_eq(feed.diagnostics.length(), 5)
  assert_true(feed.diagnostics[0].kind is @feedlens.DuplicateAtomField("feed alternate link"))
  assert_eq(feed.diagnostics[0].line, 3)
  for index in 1..<3 {
    assert_true(feed.diagnostics[index].kind is @feedlens.InvalidAtomLink("invalid hreflang"))
    assert_eq(feed.diagnostics[index].line, index + 6)
  }
  assert_true(feed.diagnostics[3].kind is @feedlens.InvalidAtomLink("invalid hreflang"))
  assert_eq(feed.diagnostics[3].line, 9)
  assert_true(feed.diagnostics[4].kind is @feedlens.InvalidAttachment("invalid Atom enclosure type"))
  assert_eq(feed.diagnostics[4].line, 9)
}

///|
test "independent Atom Entry distinguishes a long legal language segment from an overlong one" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:standalone</id><title>Standalone</title><updated>2026-10-24T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content>
    #|<link href="one" hreflang="en-12345678"/><link rel="related" href="two" hreflang="en-123456789"/><link rel="related" href="three" type=""/>
    #|</entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry")
  }
  assert_eq(entry.links[0].hreflang, Some("en-12345678"))
  assert_eq(entry.links[1].hreflang, Some("en-123456789"))
  assert_eq(entry.links[2].media_type, Some(""))
  assert_eq(diagnostics.length(), 2)
  assert_true(diagnostics[0].kind is @feedlens.InvalidAtomLink("invalid hreflang"))
  assert_true(diagnostics[1].kind is @feedlens.InvalidAtomLink("invalid type"))
}
