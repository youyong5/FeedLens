///|
test "registered Atom relation IRIs keep raw spelling and map alternate and enclosure" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="feeds/"><id>urn:feed</id><title>Audio feed</title><updated>2026-10-23T00:00:00Z</updated><author><name>Editor</name></author>
    #|<link rel="http://www.iana.org/assignments/relation/alternate" href="home"/>
    #|<entry xml:base="posts/"><id>urn:entry</id><title>One</title><updated>2026-10-23T00:00:00Z</updated>
    #|<link rel="http://www.iana.org/assignments/relation/enclosure" href="audio/one.mp3" type="audio/mpeg" length="42"/>
    #|<link rel="http://www.iana.org/assignments/relation/alternate" href="one"/>
    #|<link rel="https://example.test/relation/enclosure" href="unrelated"/>
    #|</entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.link, Some("home"))
  assert_eq(
    feed.links[0].relation,
    "http://www.iana.org/assignments/relation/alternate",
  )
  assert_eq(feed.entries[0].link, Some("one"))
  assert_eq(feed.entries[0].links.length(), 3)
  assert_eq(
    feed.entries[0].links[0].relation,
    "http://www.iana.org/assignments/relation/enclosure",
  )
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].url, "audio/one.mp3")
  assert_eq(feed.entries[0].attachments[0].media_type, Some("audio/mpeg"))
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, Some(42L))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/root/main.atom",
    )
    is Ok(resolved) else {
    fail("expected resolved Atom")
  }
  assert_eq(resolved.link, Some("https://example.test/root/feeds/home"))
  assert_eq(
    resolved.entries[0].link,
    Some("https://example.test/root/feeds/posts/one"),
  )
  assert_eq(
    resolved.entries[0].attachments[0].url,
    "https://example.test/root/feeds/posts/audio/one.mp3",
  )
  assert_eq(
    resolved.entries[0].links[2].href,
    "https://example.test/root/feeds/posts/unrelated",
  )
  assert_eq(resolved.diagnostics, [])
}

///|
test "Atom alternate duplicate and invalid enclosure use registered relation equivalence" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author>
    #|<link href="one" type="text/html" hreflang="en"/><link rel="http://www.iana.org/assignments/relation/alternate" href="two" type="text/html" hreflang="en"/>
    #|<entry><id>e</id><title>E</title><updated>2026-10-23T00:00:00Z</updated><content>Body</content>
    #|<link rel="http://www.iana.org/assignments/relation/enclosure" href="audio" length="-1"/>
    #|<link rel="http://www.iana.org/assignments/relation/enclosure" length="42"/></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.link, Some("one"))
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, None)
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("feed alternate link") &&
      d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidAttachment("invalid length") && d.line == 4
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidAttachment("missing Atom enclosure href") &&
      d.line == 5
    }),
  )
  assert_true(
    !feed.diagnostics.any(fn(d) { d.kind is @feedlens.InvalidAtomLink(_) }),
  )
}

///|
test "independent Atom Entry accepts registered alternate and enclosure IRIs" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xml:base="posts/"><id>urn:one</id><title>One</title><updated>2026-10-23T00:00:00Z</updated><author><name>Editor</name></author>
    #|<link rel="http://www.iana.org/assignments/relation/alternate" href="one"/>
    #|<link rel="http://www.iana.org/assignments/relation/enclosure" href="audio.mp3" type="audio/mpeg"/>
    #|</entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom entry")
  }
  assert_eq(entry.link, Some("one"))
  assert_eq(entry.attachments[0].url, "audio.mp3")
  assert_eq(diagnostics, [])
  guard @feedlens.parse_document_with_source(
      input, "https://example.test/news/one.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved, problems)) else {
    fail("expected resolved independent Atom entry")
  }
  assert_eq(resolved.link, Some("https://example.test/news/posts/one"))
  assert_eq(
    resolved.attachments[0].url,
    "https://example.test/news/posts/audio.mp3",
  )
  assert_eq(problems, [])
}
