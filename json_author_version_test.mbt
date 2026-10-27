///|
test "JSON Feed 1.0 uses singular author and inherits it" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"Legacy authors","author":{"name":"Legacy editor","url":"people/editor"},"authors":[{"name":"Future editor"}],"items":[{"id":"inherited","content_text":"A","authors":[{"name":"Future item"}]},{"id":"declared","content_text":"B","author":{"name":"Legacy writer","avatar":"avatars/writer.png"},"authors":[{"name":"Future writer"}]}]}
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected JSON Feed 1.0")
  }
  assert_eq(feed.authors.length(), 1)
  assert_eq(feed.authors[0].name, Some("Legacy editor"))
  assert_eq(feed.entries[0].authors[0].name, Some("Legacy editor"))
  assert_eq(feed.entries[1].authors[0].name, Some("Legacy writer"))
  assert_eq(feed.entries[1].authors[0].avatar, Some("avatars/writer.png"))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/main.json",
    )
    is Ok(resolved) else {
    fail("expected source-aware feed")
  }
  assert_eq(
    resolved.entries[0].authors[0].uri,
    Some("https://example.test/feeds/people/editor"),
  )
  assert_eq(
    resolved.entries[1].authors[0].avatar,
    Some("https://example.test/feeds/avatars/writer.png"),
  )
}

///|
test "JSON Feed 1.1 prefers authors and explicit empty array clears inheritance" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Current authors","author":{"name":"Legacy editor"},"authors":[{"name":"Current editor","url":"people/editor"}],"items":[{"id":"inherited","content_text":"A"},{"id":"declared","content_text":"B","author":{"name":"Legacy writer"},"authors":[{"name":"Current writer","avatar":"avatars/writer.png"}]},{"id":"explicit-none","content_text":"C","author":{"name":"Legacy writer"},"authors":[]},{"id":"legacy-only","content_text":"D","author":{"name":"Legacy writer"}}]}
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected JSON Feed 1.1")
  }
  assert_eq(feed.authors.length(), 1)
  assert_eq(feed.authors[0].name, Some("Current editor"))
  assert_eq(feed.entries[0].authors[0].name, Some("Current editor"))
  assert_eq(feed.entries[1].authors[0].name, Some("Current writer"))
  assert_eq(feed.entries[2].authors, [])
  assert_eq(feed.entries[3].authors[0].name, Some("Legacy writer"))
  assert_eq(feed.diagnostics, [])
}
