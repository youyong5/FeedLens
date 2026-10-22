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
    #|<item><guid>one</guid><title>One</title><x:enclosure url="https://example.test/wrong" length="1" type="audio/mpeg"/>
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

///|
test "Atom enclosure links keep order without replacing alternate link" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed</id><title>Feed</title><updated>2024-01-01T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>urn:entry</id><title>Entry</title><updated>2024-01-01T00:00:00Z</updated>
    #|<link rel="self" href="https://example.test/self"/><link rel="enclosure" href="media/a.mp3" type="audio/mpeg" length="42" title="A &amp; B"/>
    #|<link href="https://example.test/article"/><link rel="enclosure" href="https://example.test/b.mp3"/>
    #|</entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  let entry = feed.entries[0]
  assert_eq(entry.link, Some("https://example.test/article"))
  assert_eq(entry.attachments.length(), 2)
  assert_true(entry.attachments[0].source is @feedlens.Atom1)
  assert_eq(entry.attachments[0].url, "media/a.mp3")
  assert_eq(entry.attachments[0].media_type, Some("audio/mpeg"))
  assert_eq(entry.attachments[0].size_in_bytes, Some(42L))
  assert_eq(entry.attachments[0].title, Some("A & B"))
  assert_eq(entry.attachments[1].media_type, None)
  assert_eq(entry.attachments[1].size_in_bytes, None)
  assert_eq(feed.diagnostics, [])
}

///|
test "prefixed Atom enclosure ignores foreign and nested links" {
  let xml =
    #|<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:x="urn:wrong"><a:id>urn:feed</a:id><a:title>Feed</a:title><a:updated>2024-01-01T00:00:00Z</a:updated><a:author><a:name>A</a:name></a:author>
    #|<a:entry><a:id>urn:entry</a:id><a:title>Entry</a:title><a:updated>2024-01-01T00:00:00Z</a:updated><a:content>Body</a:content>
    #|<x:link rel="enclosure" href="wrong"/><a:source><a:link rel="enclosure" href="nested"/></a:source>
    #|<a:link rel="enclosure" href="right" length="9007199254740991"/></a:entry></a:feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].url, "right")
  assert_eq(
    feed.entries[0].attachments[0].size_in_bytes,
    Some(9007199254740991L),
  )
}

///|
test "Atom bad optional length is diagnosed but enclosure survives" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed</id><title>Feed</title><updated>2024-01-01T00:00:00Z</updated><author><name>A</name></author>
    #|<entry><id>urn:entry</id><title>Entry</title><updated>2024-01-01T00:00:00Z</updated><content>Body</content>
    #|<link rel="enclosure" href="https://example.test/a" length="-1"/><link rel="enclosure" length="4"/>
    #|</entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, None)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidAttachment("invalid length"),
  )
  assert_eq(feed.diagnostics[0].line, 3)
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidAttachment("missing Atom enclosure href"),
  )
  assert_eq(feed.diagnostics[1].line, 3)
}

///|
test "JSON Feed 1.1 attachments retain order, title, size, and fractional duration" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Audio","items":[{"id":"one","content_text":"Body","attachments":[{"url":"https://example.test/a.mp3","mime_type":"audio/mpeg","title":"First 🎵","size_in_bytes":9007199254740991,"duration_in_seconds":12.5},{"url":"https://example.test/b.mp3","mime_type":"audio/ogg"}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries.length(), 1)
  let attachments = feed.entries[0].attachments
  assert_eq(attachments.length(), 2)
  assert_true(attachments[0].source is @feedlens.JsonFeed1)
  assert_eq(attachments[0].url, "https://example.test/a.mp3")
  assert_eq(attachments[0].media_type, Some("audio/mpeg"))
  assert_eq(attachments[0].title, Some("First 🎵"))
  assert_eq(attachments[0].size_in_bytes, Some(9007199254740991L))
  assert_eq(attachments[0].duration_in_seconds, Some(12.5))
  assert_eq(attachments[1].url, "https://example.test/b.mp3")
  assert_eq(attachments[1].size_in_bytes, None)
  assert_eq(feed.diagnostics, [])
}

///|
test "JSON Feed 1.0 accepts attachments and skips only invalid attachments" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1","title":"Feed","items":[{"id":"one","content_text":"Body","attachments":[false,{"url":"","mime_type":"audio/mpeg"},{"url":"https://example.test/bad","mime_type":"audio/mpeg","size_in_bytes":9007199254740992,"duration_in_seconds":-3},{"url":"https://example.test/good","mime_type":"audio/mpeg","size_in_bytes":0,"duration_in_seconds":0.25}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].identifier, Some("one"))
  assert_eq(feed.entries[0].attachments.length(), 2)
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, None)
  assert_eq(feed.entries[0].attachments[0].duration_in_seconds, None)
  assert_eq(feed.entries[0].attachments[1].size_in_bytes, Some(0L))
  assert_eq(feed.entries[0].attachments[1].duration_in_seconds, Some(0.25))
  assert_eq(feed.diagnostics.length(), 4)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAttachment("json feed item 0 attachment 0: object"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 1: url or mime_type"
    ),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 2: size_in_bytes"
    ),
  )
  assert_true(
    feed.diagnostics[3].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 2: duration_in_seconds"
    ),
  )
  assert_eq(feed.diagnostics[0].line, 1)
  assert_eq(feed.diagnostics[0].column, 1)
}

///|
test "JSON Feed attachments array type error preserves item" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Feed","items":[{"id":"one","content_text":"Body","attachments":{"url":"wrong"}}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].attachments.length(), 0)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 0: attachments array"
    ),
  )
}

///|
test "JSON Feed rejects fractional byte sizes and invalid durations" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Feed","items":[{"id":"one","content_text":"Body","attachments":[{"url":"https://example.test/a","mime_type":"audio/mpeg","size_in_bytes":1.5,"duration_in_seconds":1e400},{"url":"https://example.test/b","mime_type":"audio/mpeg","size_in_bytes":"42","duration_in_seconds":"bad"}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.entries[0].attachments.length(), 2)
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, None)
  assert_eq(feed.entries[0].attachments[0].duration_in_seconds, None)
  assert_eq(feed.entries[0].attachments[1].size_in_bytes, None)
  assert_eq(feed.entries[0].attachments[1].duration_in_seconds, None)
  assert_eq(feed.diagnostics.length(), 4)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 0: size_in_bytes"
    ),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 0: duration_in_seconds"
    ),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 1: size_in_bytes"
    ),
  )
  assert_true(
    feed.diagnostics[3].kind
    is @feedlens.InvalidAttachment(
      "json feed item 0 attachment 1: duration_in_seconds"
    ),
  )
}
