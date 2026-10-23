///|
/// Mirrors samples/rss2_dublin_creator.xml for offline targets.
fn rss_dublin_sample() -> String {
  (
    #|<?xml version="1.0" encoding="utf-8"?>
    #|<rss version="2.0" xmlns:d="http://purl.org/dc/elements/1.1/" xmlns:fake="https://example.test/not-dc">
    #|  <channel>
    #|    <title>Author roles</title><link>https://example.test/</link><description>RSS with creator names</description>
    #|    <d:creator>Channel creator is outside item scope</d:creator>
    #|    <item>
    #|      <title>One</title><author>one@example.test</author>
    #|      <d:creator>Jane &amp; Co</d:creator><fake:creator>Not an author</fake:creator>
    #|      <wrapper><d:creator>Nested ignored</d:creator></wrapper>
    #|      <d:creator>Second credited editor</d:creator>
    #|    </item>
    #|    <item><title>Two</title><d:creator>  Name with spaces  </d:creator><d:creator/></item>
    #|    <item><title>Three</title><d:creator><b>nested invalid</b></d:creator></item>
    #|  </channel>
    #|</rss>
  )
}

///|
test "Dublin Core creators keep names and RSS email in document order" {
  guard @feedlens.parse(rss_dublin_sample()) is Ok(feed) else {
    fail("expected RSS document")
  }
  assert_eq(feed.authors, [])
  assert_eq(feed.entries.length(), 3)
  let authors = feed.entries[0].authors
  assert_eq(authors.length(), 3)
  assert_true(authors[0].source is @feedlens.Rss2)
  assert_eq(authors[0].email, Some("one@example.test"))
  assert_eq(authors[0].name, None)
  assert_true(authors[1].source is @feedlens.DublinCore)
  assert_eq(authors[1].name, Some("Jane & Co"))
  assert_eq(authors[1].email, None)
  assert_true(authors[2].source is @feedlens.DublinCore)
  assert_eq(authors[2].name, Some("Second credited editor"))
  assert_eq(feed.entries[1].authors.length(), 1)
  assert_eq(feed.entries[1].authors[0].name, Some("  Name with spaces  "))
  assert_eq(feed.entries[2].authors, [])
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidAuthor(_))
  assert_true(feed.diagnostics[1].kind is @feedlens.UnsupportedNestedMarkup(_))
}

///|
test "Hacker News RSS projected Dublin Core creators become usable authors" {
  guard @feedlens.parse(diverse_rss_sample()) is Ok(feed) else {
    fail("expected archived RSS sample")
  }
  assert_eq(feed.entries[0].authors.length(), 1)
  assert_true(feed.entries[0].authors[0].source is @feedlens.DublinCore)
  assert_eq(feed.entries[0].authors[0].name, Some("zdw"))
  assert_eq(feed.entries[1].authors[0].name, Some("amichail"))
  assert_eq(feed.diagnostics, [])
}
