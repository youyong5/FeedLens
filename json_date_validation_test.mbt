///|
test "JSON Feed retains items and raw dates while diagnosing invalid RFC 3339" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Date recovery","items":[
    #|{"id":"calendar","content_text":"First","date_published":"2026-02-30T12:00:00Z","date_modified":"2026-02-28T12:00:00Z"},
    #|{"id":"offset","content_html":"<p>Second</p>","date_modified":"2026-10-24T10:00:00+25:00"},
    #|{"id":"blank","content_text":"Third","date_published":"","date_modified":42},
    #|{"id":"valid","content_text":"Fourth","date_published":"2026-10-24t10:00:00.123456789123z","date_modified":"2026-10-24T11:00:00-00:00"}
    #|]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries.length(), 4)
  assert_eq(feed.entries[0].published_at, Some("2026-02-30T12:00:00Z"))
  assert_eq(feed.entries[0].updated_at, Some("2026-02-28T12:00:00Z"))
  assert_eq(feed.entries[1].content, Some("<p>Second</p>"))
  assert_eq(feed.entries[1].updated_at, Some("2026-10-24T10:00:00+25:00"))
  assert_eq(feed.entries[2].published_at, Some(""))
  assert_eq(feed.entries[2].updated_at, None)
  assert_eq(
    feed.entries[3].published_at,
    Some("2026-10-24t10:00:00.123456789123z"),
  )
  assert_eq(feed.diagnostics.length(), 4)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidJsonFeedDate(0, "date_published"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidJsonFeedDate(1, "date_modified"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidJsonFeedDate(2, "date_published"),
  )
  assert_true(
    feed.diagnostics[3].kind
    is @feedlens.InvalidJsonFeedItem(2, "date_modified"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (1, 1))
}

///|
test "JSON Feed 1.0 also diagnoses malformed item dates without dropping items" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"Legacy dates","items":[{"id":"one","content_text":"A","date_published":"2026-10-24T10:00:00"},{"id":"two","content_text":"B","date_modified":"2026-10-24T10:00:00Z"}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed 1.0") }
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].published_at, Some("2026-10-24T10:00:00"))
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidJsonFeedDate(0, "date_published"),
  )
  assert_eq(feed.diagnostics.length(), 1)
}
