///|
test "leading UTF-8 BOM works for RSS, Atom, and JSON Feed entry points" {
  let bom = "\uFEFF"
  let rss = "<rss version=\"2.0\"><channel><title>RSS</title><link>https://example.test/</link><description>News</description><item><title>One</title><link>posts/one</link></item></channel></rss>"
  guard @feedlens.parse(bom + rss) is Ok(rss_feed) else {
    fail("expected RSS with BOM")
  }
  assert_eq(rss_feed.title, Some("RSS"))
  assert_eq(rss_feed.entries[0].link, Some("posts/one"))
  guard @feedlens.parse_with_source(
      bom + rss,
      "https://example.test/feeds/index.xml",
    )
    is Ok(resolved_rss) else {
    fail("expected source-aware RSS with BOM")
  }
  assert_eq(
    resolved_rss.entries[0].link,
    Some("https://example.test/feeds/posts/one"),
  )

  let atom = "<?xml version=\"1.0\"?><entry xmlns=\"http://www.w3.org/2005/Atom\" xml:base=\"posts/\"><id>urn:one</id><title>One</title><updated>2026-10-27T00:00:00Z</updated><author><name>Editor</name></author><link href=\"one\"/></entry>"
  guard @feedlens.parse_document(bom + atom)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry with BOM")
  }
  assert_eq(entry.identifier, Some("urn:one"))
  assert_eq(diagnostics, [])
  guard @feedlens.parse_document_with_source(
      bom + atom,
      "https://example.test/feed.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(resolved_entry, problems)) else {
    fail("expected source-aware Atom Entry with BOM")
  }
  assert_eq(resolved_entry.link, Some("https://example.test/posts/one"))
  assert_eq(problems, [])

  let json = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"JSON\",\"items\":[{\"id\":\"one\",\"content_text\":\"Hi\"}]}"
  guard @feedlens.parse(bom + json) is Ok(json_feed) else {
    fail("expected JSON Feed with BOM")
  }
  assert_eq(json_feed.title, Some("JSON"))
  assert_eq(json_feed.entries[0].content, Some("Hi"))
  guard @feedlens.parse_with_source(
      bom + json,
      "https://example.test/feed.json",
    )
    is Ok(resolved_json) else {
    fail("expected source-aware JSON Feed with BOM")
  }
  assert_eq(resolved_json.entries[0].identifier, Some("one"))
}

///|
test "BOM handling is limited to the first character" {
  let bom = "\uFEFF"
  let json = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Mid" +
    bom +
    "dle\",\"items\":[]}"
  guard @feedlens.parse(json) is Ok(feed) else {
    fail("expected JSON content with U+FEFF")
  }
  assert_eq(feed.title, Some("Mid" + bom + "dle"))
  assert_true(@feedlens.parse(" " + bom + json) is Err(_))
  assert_true(@feedlens.parse(bom + bom + json) is Err(_))
  assert_true(
    @feedlens.parse_with_source(
      bom + bom + json, "https://example.test/feed.json",
    ) is Err(_),
  )
  assert_true(@feedlens.parse_document(bom + bom + json) is Err(_))
  assert_true(
    @feedlens.parse_document_with_source(
      bom + bom + json, "https://example.test/feed.json",
    ) is Err(_),
  )
}
