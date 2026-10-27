///|
test "JSON Feed source-aware pagination rejects resolved self links" {
  let source = "https://example.test/feeds/feed.json"
  let declared =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Stories","feed_url":"https://example.test/feeds/feed.json","next_url":"./feed.json","items":[]}
  guard @feedlens.parse(declared) is Ok(raw) else {
    fail("expected raw JSON Feed")
  }
  assert_eq(raw.next_url, Some("./feed.json"))
  assert_eq(raw.diagnostics, [])
  guard @feedlens.parse_with_source(declared, source) is Ok(resolved) else {
    fail("expected resolved JSON Feed")
  }
  assert_eq(resolved.identifier, raw.identifier)
  assert_eq(resolved.next_url, None)
  assert_eq(resolved.diagnostics.length(), 1)
  assert_true(
    resolved.diagnostics[0].kind
    is @feedlens.InvalidJsonFeedField("next_url equals feed_url"),
  )

  let undeclared = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Stories\",\"next_url\":\"feed.json\",\"items\":[]}"
  guard @feedlens.parse_with_source(undeclared, source) is Ok(no_id) else {
    fail("expected resolved JSON Feed without feed_url")
  }
  assert_eq(no_id.next_url, None)
  assert_eq(no_id.diagnostics.length(), 1)
  assert_true(
    no_id.diagnostics[0].kind
    is @feedlens.InvalidJsonFeedField("next_url equals source_url"),
  )
  guard @feedlens.parse_document_with_source(undeclared, source)
    is Ok(@feedlens.FeedDocument(document)) else {
    fail("expected document API to return the same pagination boundary")
  }
  assert_eq(document.next_url, None)
  assert_eq(document.diagnostics, no_id.diagnostics)

  let alias = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Stories\",\"feed_url\":\"feed.json\",\"next_url\":\"https://example.test/feeds/feed.json\",\"items\":[]}"
  guard @feedlens.parse_with_source(alias, source) is Ok(alias_feed) else {
    fail("expected JSON Feed with equivalent declared URLs")
  }
  assert_eq(alias_feed.identifier, Some("feed.json"))
  assert_eq(alias_feed.next_url, None)
  assert_true(
    alias_feed.diagnostics[0].kind
    is @feedlens.InvalidJsonFeedField("next_url equals feed_url"),
  )

  let other_feed = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Stories\",\"feed_url\":\"https://mirror.test/stories\",\"next_url\":\"./feed.json\",\"items\":[]}"
  guard @feedlens.parse_with_source(other_feed, source) is Ok(mirrored) else {
    fail("expected JSON Feed from a mirror")
  }
  assert_eq(mirrored.next_url, None)
  assert_true(
    mirrored.diagnostics[0].kind
    is @feedlens.InvalidJsonFeedField("next_url equals source_url"),
  )
}

///|
test "JSON Feed distinct resolved page stays available" {
  let source = "https://example.test/feeds/feed.json?page=1"
  let input = "{\"version\":\"https://jsonfeed.org/version/1\",\"title\":\"Stories\",\"feed_url\":\"feed.json?page=1\",\"next_url\":\"feed.json?page=2\",\"items\":[]}"
  guard @feedlens.parse_with_source(input, source) is Ok(feed) else {
    fail("expected paged JSON Feed")
  }
  assert_eq(feed.identifier, Some("feed.json?page=1"))
  assert_eq(feed.next_url, Some("https://example.test/feeds/feed.json?page=2"))
  assert_eq(feed.diagnostics, [])
  let malformed = "{\"version\":\"https://jsonfeed.org/version/1\",\"title\":\"Stories\",\"next_url\":\"https://bad^host/feed.json\",\"items\":[]}"
  guard @feedlens.parse_with_source(malformed, source) is Ok(recovered) else {
    fail("expected recovered malformed pagination URL")
  }
  assert_eq(recovered.next_url, Some("https://bad^host/feed.json"))
  assert_true(
    recovered.diagnostics[0].kind
    is @feedlens.UnresolvedUri("json feed next_url"),
  )
}
