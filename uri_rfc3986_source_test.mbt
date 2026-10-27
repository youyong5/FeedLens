///|
test "RFC 3986 reference resolution reaches RSS fields without changing parse" {
  let input =
    #|<rss version="2.0"><channel><title>F</title><link>g/../h?y/./x#s</link><description>D</description>
    #|<item><title>E</title><link>../../../g</link><enclosure url="//media.test/audio.mp3" type="audio/mpeg" length="4"/></item></channel></rss>
  let source = "http://a/b/c/d;p?q"
  guard @feedlens.parse_with_source(input, source) is Ok(feed) else {
    fail("expected RSS with source")
  }
  assert_eq(feed.link, Some("http://a/b/c/h?y/./x#s"))
  assert_eq(feed.entries[0].link, Some("http://a/g"))
  assert_eq(feed.entries[0].attachments[0].url, "http://media.test/audio.mp3")
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected RSS") }
  assert_eq(raw.link, Some("g/../h?y/./x#s"))
  assert_eq(raw.entries[0].link, Some("../../../g"))
}

///|
test "RFC 3986 reference resolution reaches Atom scoped fields" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="http://a/b/c/d;p?q"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author>
    #|<link href="?y"/><entry xml:base="./"><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><link href="g/../h?y/./x#s"/><link rel="enclosure" href="../../g" type="audio/mpeg"/></entry></feed>
  guard @feedlens.parse_with_source(input, "https://origin.test/feed.atom")
    is Ok(feed) else {
    fail("expected Atom with source")
  }
  assert_eq(feed.link, Some("http://a/b/c/d;p?y"))
  assert_eq(feed.entries[0].link, Some("http://a/b/c/h?y/./x#s"))
  assert_eq(feed.entries[0].attachments[0].url, "http://a/g")
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.entries[0].link, Some("g/../h?y/./x#s"))
}

///|
test "RFC 3986 reference resolution reaches JSON Feed fields" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"F","home_page_url":"?y","items":[{"id":"e","url":"g/../h?y/./x#s","content_text":"Body","attachments":[{"url":"../../../g","mime_type":"audio/mpeg"}]}]}
  let source = "http://a/b/c/d;p?q"
  guard @feedlens.parse_with_source(input, source) is Ok(feed) else {
    fail("expected JSON Feed with source")
  }
  assert_eq(feed.link, Some("http://a/b/c/d;p?y"))
  assert_eq(feed.entries[0].link, Some("http://a/b/c/h?y/./x#s"))
  assert_eq(feed.entries[0].attachments[0].url, "http://a/g")
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected JSON Feed") }
  assert_eq(raw.entries[0].link, Some("g/../h?y/./x#s"))
}

///|
test "HTTP rootless absolute reference is not a source document URL" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"F","home_page_url":"http:g","items":[]}
  guard @feedlens.parse_with_source(input, "https://a/feed.json") is Ok(feed) else {
    fail("expected JSON Feed with source")
  }
  assert_eq(feed.link, Some("http:g"))
  assert_eq(feed.diagnostics, [])
  assert_true(
    @feedlens.parse_with_source(input, "http:g")
    is Err(@feedlens.InvalidSourceUrl("http:g")),
  )
}
