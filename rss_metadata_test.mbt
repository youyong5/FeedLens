///|
test "RSS guid role, source credit, and channel contacts" {
  let input =
    #|<rss version="2.0"><channel><title>News</title><link>https://example.test/</link><description>Updates</description><managingEditor>editor@example.test</managingEditor><webMaster>ops@example.test</webMaster>
    #|<item><guid isPermaLink="false">urn:story:1</guid><title>First</title><source url="../origin.xml">Original &amp; source</source></item><item><guid>https://example.test/second</guid><title>Second</title></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.managing_editor, Some("editor@example.test"))
  assert_eq(feed.webmaster, Some("ops@example.test"))
  assert_eq(feed.entries[0].identifier, Some("urn:story:1"))
  assert_eq(feed.entries[0].guid_is_permalink, Some(false))
  assert_eq(feed.entries[0].source_url, Some("../origin.xml"))
  assert_eq(feed.entries[0].source_title, Some("Original & source"))
  assert_eq(feed.entries[1].guid_is_permalink, Some(true))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/main.xml",
    )
    is Ok(resolved) else {
    fail("expected resolved RSS")
  }
  assert_eq(resolved.entries[0].identifier, Some("urn:story:1"))
  assert_eq(resolved.entries[0].source_title, Some("Original & source"))
  assert_eq(
    resolved.entries[0].source_url,
    Some("https://example.test/origin.xml"),
  )
}

///|
test "RSS malformed guid role and source credit report their own locations" {
  let input =
    #|<rss version="2.0"><channel><title>N</title><link>https://example.test/</link><description>D</description>
    #|<item><guid isPermaLink="maybe">opaque</guid><source url="">  </source></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.entries[0].identifier, Some("opaque"))
  assert_eq(feed.entries[0].guid_is_permalink, None)
  assert_eq(feed.entries[0].source_url, None)
  assert_eq(feed.entries[0].source_title, None)
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("guid isPermaLink") && d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("source url") && d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("source title") && d.line == 2
    }),
  )
}
