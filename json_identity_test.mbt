///|
test "JSON Feed diagnoses repeated effective IDs and preserves every item" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Identity","items":[{"id":"post","content_text":""},{"id":"Post","content_html":"<p>Case</p>"},{"id":" post ","content_text":"Spaces"},{"id":"post","content_text":"Repeated"},{"id":12,"content_text":"Number"},{"id":"12","content_text":"Coerced collision"}]}
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected recovered JSON Feed")
  }
  assert_eq(feed.entries.length(), 6)
  assert_eq(
    feed.entries.map(fn(entry) { entry.identifier }),
    [Some("post"), Some("Post"), Some(" post "), Some("post"), Some("12"), Some("12")],
  )
  assert_eq(feed.entries[0].content, Some(""))
  assert_eq(feed.entries[3].content, Some("Repeated"))
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidJsonFeedItem(3, "duplicate id"))
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidJsonFeedItem(5, "duplicate id"))
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (1, 1))
}

///|
test "JSON Feed 1.0 checks ID collisions after coercion and skips unusable items" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"Legacy identities","items":[{"id":"recover"},{"id":"recover","content_text":"Kept"},{"id":7,"content_text":"Seven"},{"id":"7","content_text":"Again"},{"id":false,"content_text":"Boolean"},{"id":"false","content_text":"Again"}]}
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected recovered JSON Feed 1.0")
  }
  assert_eq(feed.entries.length(), 5)
  assert_eq(feed.entries[0].identifier, Some("recover"))
  assert_eq(feed.entries[1].identifier, Some("7"))
  assert_eq(feed.entries[3].identifier, Some("false"))
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidJsonFeedItem(0, "content"))
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidJsonFeedItem(3, "duplicate id"))
  assert_true(feed.diagnostics[2].kind is @feedlens.InvalidJsonFeedItem(5, "duplicate id"))
}
