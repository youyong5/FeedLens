///|
test "RSS source-aware IRI accepts Unicode host and query private use only" {
  let xml =
    #|<rss version="2.0"><channel><title>F</title><link>首页</link><description>D</description>
    #|<item><title>E</title><link>文章&#xE000;</link><enclosure url="音频.mp3?token=&#xE000;" type="audio/mpeg" length="4"/></item></channel></rss>
  guard @feedlens.parse_with_source(xml, "https://例子.test/刊物/feed.xml")
    is Ok(feed) else {
    fail("expected RSS with Unicode source")
  }
  assert_eq(feed.link, Some("https://例子.test/刊物/首页"))
  assert_eq(feed.entries[0].link, Some("文章\uE000"))
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://例子.test/刊物/音频.mp3?token=\uE000",
  )
  assert_true(
    feed.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
  guard @feedlens.parse(xml) is Ok(raw) else { fail("expected raw RSS") }
  assert_eq(raw.entries[0].attachments[0].url, "音频.mp3?token=\uE000")
}

///|
test "Atom scoped IRI retains invalid fragment and resolves valid Unicode" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://例子.test/刊物/"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><link href="文章#段&#xE000;"/><link rel="enclosure" href="音频.mp3?token=&#xE000;" type="audio/mpeg"/></entry></feed>
  guard @feedlens.parse_with_source(xml, "https://origin.test/feed.atom")
    is Ok(feed) else {
    fail("expected Atom with Unicode base")
  }
  assert_eq(feed.entries[0].link, Some("文章#段\uE000"))
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://例子.test/刊物/音频.mp3?token=\uE000",
  )
  assert_true(
    feed.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
}

///|
test "Atom invalid Unicode xml:base cannot resolve a relative child" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-27T00:00:00Z</updated><author><name>A</name></author>
    #|<entry xml:base="https://cdn.test/&#xE000;/"><id>urn:e</id><title>E</title><updated>2026-10-27T00:00:00Z</updated><content>Body</content><link href="relative"/></entry></feed>
  guard @feedlens.parse_with_source(xml, "https://origin.test/feed.atom")
    is Ok(feed) else {
    fail("expected recoverable invalid Atom base")
  }
  assert_eq(feed.entries[0].link, Some("relative"))
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnresolvedUri("atom xml:base")
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
}

///|
test "JSON Feed IRI private use is query-only and invalid source is fatal" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"F","home_page_url":"首页","items":[{"id":"e","url":"文章\uFDD0","content_text":"Body","attachments":[{"url":"音频.mp3?token=\uE000","mime_type":"audio/mpeg"}]}]}
  guard @feedlens.parse_with_source(
      input, "https://例子.test/刊物/feed.json",
    )
    is Ok(feed) else {
    fail("expected JSON Feed with Unicode source")
  }
  assert_eq(feed.link, Some("https://例子.test/刊物/首页"))
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].link, Some("文章\uFDD0"))
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://例子.test/刊物/音频.mp3?token=\uE000",
  )
  assert_true(
    feed.diagnostics.any(fn(d) { d.kind is @feedlens.UnresolvedUri(_) }),
  )
  assert_true(
    @feedlens.parse_with_source(input, "https://\uE000.test/feed.json")
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
  guard @feedlens.parse(input) is Ok(raw) else {
    fail("expected raw JSON Feed")
  }
  assert_eq(raw.entries[0].attachments[0].url, "音频.mp3?token=\uE000")
}
