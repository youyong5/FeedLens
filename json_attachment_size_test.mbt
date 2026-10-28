///|
test "JSON Feed attachment sizes accept exact integer-valued JSON numbers" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Numeric forms","items":[{"id":"episode","content_text":"Audio","attachments":[{"url":"a","mime_type":"audio/mpeg","size_in_bytes":1e3},{"url":"b","mime_type":"audio/mpeg","size_in_bytes":42.0},{"url":"c","mime_type":"audio/mpeg","size_in_bytes":4.2e1},{"url":"d","mime_type":"audio/mpeg","size_in_bytes":9.007199254740991e15},{"url":"e","mime_type":"audio/mpeg","size_in_bytes":0e300},{"url":"f","mime_type":"audio/mpeg","size_in_bytes":4.2e0},{"url":"g","mime_type":"audio/mpeg","size_in_bytes":9.007199254740992e15},{"url":"h","mime_type":"audio/mpeg","size_in_bytes":1e-3},{"url":"i","mime_type":"audio/mpeg","size_in_bytes":1e400}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  let attachments = feed.entries[0].attachments
  assert_eq(attachments.length(), 9)
  assert_eq(attachments[0].size_in_bytes, Some(1000L))
  assert_eq(attachments[1].size_in_bytes, Some(42L))
  assert_eq(attachments[2].size_in_bytes, Some(42L))
  assert_eq(attachments[3].size_in_bytes, Some(9007199254740991L))
  assert_eq(attachments[4].size_in_bytes, Some(0L))
  for index = 5; index < 9; index = index + 1 {
    assert_eq(attachments[index].size_in_bytes, None)
  }
  assert_eq(feed.diagnostics.length(), 4)
  for problem in feed.diagnostics {
    assert_true(
      problem.kind
      is @feedlens.InvalidAttachment(
        "json feed item 0 attachment 5: size_in_bytes"
      ) ||
      problem.kind
      is @feedlens.InvalidAttachment(
        "json feed item 0 attachment 6: size_in_bytes"
      ) ||
      problem.kind
      is @feedlens.InvalidAttachment(
        "json feed item 0 attachment 7: size_in_bytes"
      ) ||
      problem.kind
      is @feedlens.InvalidAttachment(
        "json feed item 0 attachment 8: size_in_bytes"
      ),
    )
  }
}

///|
test "JSON Feed 1.0 also accepts exponent integer sizes without rounding" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"Older","items":[{"id":"one","content_text":"Audio","attachments":[{"url":"audio","mime_type":"audio/mpeg","size_in_bytes":5.00e2}]}]}
  guard @feedlens.parse(input) is Ok(feed) else {
    fail("expected JSON Feed 1.0")
  }
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, Some(500L))
  assert_eq(feed.diagnostics, [])
}

///|
test "long fractional mantissas cannot hide an oversized exponent" {
  let mut mantissa = "0."
  for index = 0; index < 1100; index = index + 1 {
    mantissa += "0"
  }
  let input = "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Long\",\"items\":[{\"id\":\"one\",\"content_text\":\"Audio\",\"attachments\":[{\"url\":\"a\",\"mime_type\":\"audio/mpeg\",\"size_in_bytes\":" +
    mantissa +
    "1e2000}]}]}"
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, None)
  assert_true(feed.diagnostics[0].kind is @feedlens.InvalidAttachment(_))
}
