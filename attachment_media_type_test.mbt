///|
test "RSS enclosure keeps malformed MIME declaration with a located warning" {
  let xml =
    #|<rss version="2.0"><channel><title>F</title><link>https://example.test/</link><description>Episodes</description>
    #|<item><title>E</title><enclosure url="media/one.mp3" length="7" type="audio"/><enclosure url="media/two.txt" length="8" type="text/plain; charset=&quot;utf-8&quot;"/><enclosure url="media/three.mp3" length="9" type="AUDIO/MPEG"/></item></channel></rss>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected RSS") }
  let attachments = feed.entries[0].attachments
  assert_eq(attachments.length(), 3)
  assert_eq(attachments[0].media_type, Some("audio"))
  assert_eq(attachments[1].media_type, Some("text/plain; charset=\"utf-8\""))
  assert_eq(attachments[2].media_type, Some("AUDIO/MPEG"))
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAttachment("invalid RSS enclosure type"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  guard @feedlens.parse_with_source(xml, "https://example.test/feeds/rss.xml")
    is Ok(resolved) else {
    fail("expected source-aware RSS")
  }
  assert_eq(
    resolved.entries[0].attachments[0].url,
    "https://example.test/feeds/media/one.mp3",
  )
  assert_eq(resolved.entries[0].attachments[0].media_type, Some("audio"))
}

///|
test "JSON Feed attachment keeps malformed MIME text and valid quoted parameters" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"F","items":[{"id":"e","content_text":"Body","attachments":[{"url":"media/one.mp3","mime_type":"audio/"},{"url":"media/two.txt","mime_type":"text/plain; charset=\"utf-8\""},{"url":"media/three.mp3","mime_type":"AUDIO/MPEG"}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  let attachments = feed.entries[0].attachments
  assert_eq(attachments.length(), 3)
  assert_eq(attachments[0].media_type, Some("audio/"))
  assert_eq(attachments[1].media_type, Some("text/plain; charset=\"utf-8\""))
  assert_eq(attachments[2].media_type, Some("AUDIO/MPEG"))
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 0: invalid mime_type"
    ),
  )
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/feed.json",
    )
    is Ok(resolved) else {
    fail("expected source-aware JSON Feed")
  }
  assert_eq(
    resolved.entries[0].attachments[0].url,
    "https://example.test/feeds/media/one.mp3",
  )
  assert_eq(resolved.entries[0].attachments[0].media_type, Some("audio/"))
}

///|
test "JSON Feed 1.0 attachment uses the same MIME recovery boundary" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"F","items":[{"id":"e","content_text":"Body","attachments":[{"url":"one.mp3","mime_type":"audio/"}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected 1.0") }
  assert_eq(feed.entries[0].attachments[0].media_type, Some("audio/"))
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 0: invalid mime_type"
    ),
  )
}
