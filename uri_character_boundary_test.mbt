///|
test "RSS invalid URI path and fragment retain raw values with diagnostics" {
  let input =
    #|<rss version="2.0"><channel><title>F</title><link>post[1]</link><description>D</description>
    #|<item><title>E</title><link>post%5B1%5D</link><enclosure url="audio#part#two" length="4" type="audio/mpeg"/></item></channel></rss>
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/feed.xml",
    )
    is Ok(feed) else {
    fail("expected RSS with recoverable URI errors")
  }
  assert_eq(feed.link, Some("post[1]"))
  assert_eq(
    feed.entries[0].link,
    Some("https://example.test/feeds/post%5B1%5D"),
  )
  assert_eq(feed.entries[0].attachments[0].url, "audio#part#two")
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("rss channel link")
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("rss item 0 enclosure 0")
    }),
  )
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected RSS") }
  assert_eq(raw.entries[0].link, Some("post%5B1%5D"))
}

///|
test "Atom query punctuation and scoped base use URI character boundaries" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/feeds/"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><link href="post?tag={raw}"/><link rel="enclosure" href="audio?tag=%7Braw%7D" type="audio/mpeg"/></entry></feed>
  guard @feedlens.parse_with_source(input, "https://origin.test/feed.atom")
    is Ok(feed) else {
    fail("expected Atom with recoverable URI error")
  }
  assert_eq(feed.entries[0].link, Some("post?tag={raw}"))
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://example.test/feeds/audio?tag=%7Braw%7D",
  )
  assert_true(
    feed.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected Atom") }
  assert_eq(raw.entries[0].attachments[0].url, "audio?tag=%7Braw%7D")
}

///|
test "JSON Feed invalid source reference is diagnosed without dropping item" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"F","home_page_url":"home|bad","items":[{"id":"e","url":"post#part%23two","content_text":"Body","attachments":[{"url":"audio^bad","mime_type":"audio/mpeg"}]}]}
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/feed.json",
    )
    is Ok(feed) else {
    fail("expected JSON Feed with recoverable URI errors")
  }
  assert_eq(feed.link, Some("home|bad"))
  assert_eq(feed.entries.length(), 1)
  assert_eq(
    feed.entries[0].link,
    Some("https://example.test/feeds/post#part%23two"),
  )
  assert_eq(feed.entries[0].attachments[0].url, "audio^bad")
  assert_true(
    feed.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
  guard @feedlens.parse(input) is Ok(raw) else { fail("expected JSON Feed") }
  assert_eq(raw.entries[0].link, Some("post#part%23two"))
  assert_true(
    @feedlens.parse_with_source(
      input, "https://user|bad@example.test/feed.json",
    )
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
}
