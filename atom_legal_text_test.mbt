///|
test "legal empty Atom text constructs and feed rights apply in document order" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml"><id>urn:empty-feed</id><title>   </title><updated>2026-10-23T00:00:00Z</updated><author><name>Editor</name></author>
    #|<entry><id>urn:one</id><title/><updated>2026-10-23T00:00:00Z</updated><link href="posts/one"/><summary/></entry>
    #|<entry><id>urn:two</id><title type="xhtml"><h:div/></title><updated>2026-10-23T00:00:00Z</updated><rights type="html"/><content/></entry>
    #|<entry><id>urn:three</id><title>Third</title><updated>2026-10-23T00:00:00Z</updated><content>Body</content><source><id>urn:original</id><title/><subtitle type="html"/><rights/></source></entry>
    #|<entry><id>urn:four</id><title>External</title><updated>2026-10-23T00:00:00Z</updated><summary/><content src="media/story.xml" type="application/xml"/></entry>
    #|<entry><id>urn:five</id><title>Binary</title><updated>2026-10-23T00:00:00Z</updated><summary/><content type="image/png">AQID</content></entry>
    #|<rights type="xhtml"><h:div>License <h:em>shared</h:em></h:div></rights></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("valid Atom") }
  assert_eq(feed.title, Some("   "))
  assert_eq(feed.rights, Some("License shared"))
  assert_true(feed.rights_kind is @feedlens.Xhtml)
  guard feed.rights_xhtml is Some(rights_fragment) else {
    fail("feed rights XHTML")
  }
  assert_eq(feed.entries.length(), 5)
  assert_eq(feed.entries[0].title, Some(""))
  assert_eq(feed.entries[0].description, Some(""))
  assert_eq(feed.entries[0].rights, feed.rights)
  assert_eq(feed.entries[0].rights_xhtml, Some(rights_fragment))
  assert_true(feed.entries[0].rights_kind is @feedlens.Xhtml)
  assert_eq(feed.entries[1].title, Some(""))
  assert_true(feed.entries[1].title_kind is @feedlens.Xhtml)
  assert_eq(feed.entries[1].content, Some(""))
  assert_eq(feed.entries[1].rights, Some(""))
  assert_true(feed.entries[1].rights_kind is @feedlens.Html)
  assert_eq(feed.entries[1].rights_xhtml, None)
  assert_eq(feed.entries[2].rights, feed.rights)
  guard feed.entries[2].atom_source is Some(source) else { fail("source") }
  assert_eq(source.title, Some(""))
  assert_eq(source.subtitle, Some(""))
  assert_eq(source.rights, Some(""))
  assert_eq(feed.entries[3].description, Some(""))
  assert_eq(feed.entries[3].content_source, Some("media/story.xml"))
  assert_true(feed.entries[3].atom_body is Some(@feedlens.External(_)))
  assert_eq(feed.entries[3].rights, feed.rights)
  assert_eq(feed.entries[4].description, Some(""))
  guard feed.entries[4].atom_body is Some(@feedlens.InlineBinary(bytes, _)) else {
    fail("binary body")
  }
  assert_eq(bytes.length(), 3)
  assert_eq(feed.entries[4].rights, feed.rights)
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/main.atom",
    )
    is Ok(resolved) else {
    fail("resolved Atom")
  }
  assert_eq(
    resolved.entries[0].link,
    Some("https://example.test/feeds/posts/one"),
  )
  assert_eq(resolved.entries[0].rights_xhtml, Some(rights_fragment))
  assert_eq(
    resolved.entries[3].content_source,
    Some("https://example.test/feeds/media/story.xml"),
  )
  assert_eq(resolved.diagnostics, [])
}

///|
test "stand-alone Atom Entry accepts empty title without inventing feed rights" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:alone</id><title type="html"/><updated>2026-10-23T00:00:00Z</updated><author><name>A</name></author><link href="one"/></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("valid Atom Entry")
  }
  assert_eq(entry.title, Some(""))
  assert_true(entry.title_kind is @feedlens.Html)
  assert_eq(entry.rights, None)
  assert_eq(diagnostics, [])
}
