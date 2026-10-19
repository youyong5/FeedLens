///|
test "RSS enclosures preserve order, required metadata, and item fields" {
  let xml =
    #|<rss version="2.0"><channel><title>Audio</title><link>https://example.test/</link><description>Episodes</description>
    #|<item><guid>episode-1</guid><title>Episode</title><description>Summary</description>
    #|<enclosure url="https://example.test/a.mp3?x=1&amp;y=2" length="0" type="audio/mpeg"/>
    #|<enclosure url="https://example.test/b.mp3" length="9007199254740991" type="audio/mpeg"/>
    #|</item></channel></rss>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected RSS") }
  let entry = feed.entries[0]
  assert_eq(entry.identifier, Some("episode-1"))
  assert_eq(entry.title, Some("Episode"))
  assert_eq(entry.description, Some("Summary"))
  assert_eq(entry.attachments.length(), 2)
  assert_true(entry.attachments[0].source is @feedlens.Rss2)
  assert_eq(entry.attachments[0].url, "https://example.test/a.mp3?x=1&y=2")
  assert_eq(entry.attachments[0].media_type, Some("audio/mpeg"))
  assert_eq(entry.attachments[0].size_in_bytes, Some(0L))
  assert_eq(entry.attachments[0].title, None)
  assert_eq(entry.attachments[0].duration_in_seconds, None)
  assert_eq(entry.attachments[1].size_in_bytes, Some(9007199254740991L))
  assert_eq(feed.diagnostics, [])
}

///|
test "RSS enclosure namespace and hierarchy collisions are ignored" {
  let xml =
    #|<rss version="2.0" xmlns:x="urn:other"><channel><title>Feed</title><link>https://example.test/</link><description>Desc</description>
    #|<enclosure url="https://example.test/channel" length="1" type="audio/mpeg"/>
    #|<item><guid>one</guid><x:enclosure url="https://example.test/wrong" length="1" type="audio/mpeg"/>
    #|<wrapper><enclosure url="https://example.test/nested" length="1" type="audio/mpeg"/></wrapper>
    #|<enclosure url="https://example.test/right" length="2" type="audio/mpeg"/></item></channel></rss>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].url, "https://example.test/right")
  assert_eq(feed.diagnostics, [])
}

///|
test "RSS invalid enclosure is skipped with source position and no integer overflow" {
  let xml =
    #|<rss version="2.0"><channel><title>Feed</title><link>https://example.test/</link><description>Desc</description>
    #|<item><guid>one</guid><enclosure url="https://example.test/bad" length="9007199254740992" type="audio/mpeg"/>
    #|<enclosure url="https://example.test/missing" type="audio/mpeg"/>
    #|<enclosure url="https://example.test/good" length="3" type="audio/mpeg"/></item></channel></rss>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, Some(3L))
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidAttachment("invalid length"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[0].column, 23)
  assert_true(feed.diagnostics[1].kind is @feedlens.InvalidAttachment(_))
}
