///|
test "RSS permalink guid fills only a missing item link" {
  let input =
    #|<rss version="2.0"><channel><title>Stories</title><link>https://example.test/</link><description>News</description>
    #|<item><title>Default permalink</title><guid>https://example.test/posts/one#part</guid></item>
    #|<item><title>Explicit permalink</title><guid isPermaLink="true">https://example.test/posts/two</guid></item>
    #|<item><title>Opaque identifier</title><guid isPermaLink="false">https://example.test/posts/three</guid></item>
    #|<item><title>Unusable default</title><guid>story-four</guid></item>
    #|<item><title>Separate link</title><guid>https://example.test/posts/five</guid><link>articles/five</link></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.diagnostics, [])
  assert_eq(feed.entries.length(), 5)
  assert_eq(feed.entries[0].link, Some("https://example.test/posts/one#part"))
  assert_eq(feed.entries[1].link, Some("https://example.test/posts/two"))
  assert_eq(feed.entries[2].link, None)
  assert_eq(feed.entries[3].link, None)
  assert_eq(feed.entries[4].link, Some("articles/five"))
  assert_eq(feed.entries[4].identifier, Some("https://example.test/posts/five"))
  assert_eq(
    feed.entries[2].identifier,
    Some("https://example.test/posts/three"),
  )
  assert_eq(feed.entries[2].guid_is_permalink, Some(false))
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/main.xml",
    )
    is Ok(resolved) else {
    fail("expected source-aware RSS")
  }
  assert_eq(resolved.entries[0].link, feed.entries[0].link)
  assert_eq(resolved.entries[1].link, feed.entries[1].link)
  assert_eq(resolved.entries[2].link, None)
  assert_eq(resolved.entries[3].link, None)
  assert_eq(
    resolved.entries[4].link,
    Some("https://example.test/feeds/articles/five"),
  )
  assert_eq(resolved.diagnostics, [])
}
