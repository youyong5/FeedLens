///|
test "RSS copyright generator comments and item source keep their roles" {
  let input =
    #|<rss version="2.0"><channel><title>News</title><link>https://example.test/</link><description>Updates</description><copyright>Copyright Editor</copyright><generator>Publisher 2</generator><pubDate>Wed, 21 Oct 2026 12:00:00 GMT</pubDate><lastBuildDate>Wed, 21 Oct 2026 12:30:00 GMT</lastBuildDate><ttl>45</ttl>
    #|<item><guid>one</guid><title>One</title><comments>comments/one</comments><source url="sources/one.xml">Original publisher</source></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.rights, Some("Copyright Editor"))
  assert_eq(feed.generator, Some("Publisher 2"))
  assert_eq(feed.published_at, Some("Wed, 21 Oct 2026 12:00:00 GMT"))
  assert_eq(feed.updated_at, Some("Wed, 21 Oct 2026 12:30:00 GMT"))
  assert_eq(feed.ttl_minutes, Some(45))
  assert_eq(feed.entries[0].comments_url, Some("comments/one"))
  assert_eq(feed.entries[0].source_url, Some("sources/one.xml"))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/main.xml",
    )
    is Ok(resolved) else {
    fail("expected resolved RSS")
  }
  assert_eq(
    resolved.entries[0].comments_url,
    Some("https://example.test/feeds/comments/one"),
  )
  assert_eq(
    resolved.entries[0].source_url,
    Some("https://example.test/feeds/sources/one.xml"),
  )
  let invalid =
    #|<rss version="2.0"><channel><title>N</title><link>https://example.test/</link><description>D</description><ttl>999999999999999999999999</ttl></channel></rss>
  guard @feedlens.parse(invalid) is Ok(bad) else {
    fail("expected recovered ttl")
  }
  assert_eq(bad.ttl_minutes, None)
  assert_true(bad.diagnostics[0].kind is @feedlens.InvalidRssField("ttl"))
}

///|
test "Atom rights text constructs and generator preserve usable output" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml"><id>urn:feed</id><title>Feed</title><updated>2026-10-21T00:00:00Z</updated><author><name>Editor</name></author>
    #|<generator>Feed machine</generator><rights type="xhtml"><h:div>Shared <h:b>rights</h:b></h:div></rights><contributor><name>Feed helper</name></contributor>
    #|<entry><id>urn:entry</id><title>One</title><updated>2026-10-21T00:00:00Z</updated><content>Body</content><rights type="html">&lt;b&gt;CC BY&lt;/b&gt;</rights><contributor><name>Entry helper</name></contributor></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.generator, Some("Feed machine"))
  assert_eq(feed.rights, Some("Shared rights"))
  assert_true(feed.rights_kind is @feedlens.Xhtml)
  assert_true(feed.rights_xhtml is Some(_))
  assert_eq(feed.contributors[0].name, Some("Feed helper"))
  assert_eq(feed.entries[0].rights, Some("<b>CC BY</b>"))
  assert_true(feed.entries[0].rights_kind is @feedlens.Html)
  assert_eq(feed.entries[0].contributors[0].name, Some("Entry helper"))
  assert_eq(feed.diagnostics, [])
}

///|
test "JSON Feed retains both bodies, avatar-only authors, and pagination status" {
  let input =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"News","feed_url":"https://example.test/feed.json","next_url":"older.json","expired":false,"hubs":[{"type":"WebSub","url":"hubs/main"}],"authors":[{"avatar":"avatars/editor.png"}],"items":[{"id":"one","content_html":"<b>One</b>","content_text":"One","authors":[{"name":"Writer","avatar":"avatars/writer.png"}]}]}
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected JSON Feed") }
  assert_eq(feed.next_url, Some("older.json"))
  assert_eq(feed.expired, Some(false))
  assert_eq(feed.hubs[0].transport_type, "WebSub")
  assert_eq(feed.hubs[0].url, "hubs/main")
  assert_eq(feed.authors[0].avatar, Some("avatars/editor.png"))
  assert_eq(feed.entries[0].authors[0].avatar, Some("avatars/writer.png"))
  assert_eq(feed.entries[0].content, Some("<b>One</b>"))
  assert_eq(feed.entries[0].content_html, Some("<b>One</b>"))
  assert_eq(feed.entries[0].content_text, Some("One"))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(input, "https://example.test/feed.json")
    is Ok(resolved) else {
    fail("expected resolved JSON Feed")
  }
  assert_eq(resolved.next_url, Some("https://example.test/older.json"))
  assert_eq(resolved.hubs[0].url, "https://example.test/hubs/main")
  assert_eq(
    resolved.authors[0].avatar,
    Some("https://example.test/avatars/editor.png"),
  )
  assert_eq(
    resolved.entries[0].authors[0].avatar,
    Some("https://example.test/avatars/writer.png"),
  )
  let invalid =
    #|{"version":"https://jsonfeed.org/version/1.1","title":"N","feed_url":"https://example.test/feed.json","next_url":"https://example.test/feed.json","expired":"false","items":[]}
  guard @feedlens.parse(invalid) is Ok(bad) else {
    fail("expected recoverable fields")
  }
  assert_eq(bad.next_url, None)
  assert_eq(bad.expired, None)
  assert_eq(bad.diagnostics.length(), 2)
}

///|
test "Atom repeated singleton diagnostics identify field and source location" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>Editor</name></author>
    #|<entry><id>urn:e</id><title>One</title><title>Two</title><updated>2026-10-21T00:00:00Z</updated><content>First</content><content>Second</content></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected parsed Atom") }
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("entry title") && d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("entry content") && d.line == 2
    }),
  )
}

///|
test "Atom links retain every relation and scoped source resolution" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="feeds/"><id>urn:feed</id><title>Feed</title><updated>2026-10-21T00:00:00Z</updated><author><name>Editor</name></author><link rel="self" href="index.atom" type="application/atom+xml"/>
    #|<entry xml:base="posts/"><id>urn:entry</id><title>One</title><updated>2026-10-21T00:00:00Z</updated><content>Body</content><link href="one" type="text/html" hreflang="en"/><link rel="related" href="related" title="Context"/><link rel="enclosure" href="audio.mp3" type="audio/mpeg" length="42"/></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.links.length(), 1)
  assert_eq(feed.links[0].relation, "self")
  assert_eq(feed.links[0].href, "index.atom")
  assert_eq(feed.entries[0].links.length(), 3)
  assert_eq(feed.entries[0].links[0].relation, "alternate")
  assert_eq(feed.entries[0].links[0].hreflang, Some("en"))
  assert_eq(feed.entries[0].links[1].relation, "related")
  assert_eq(feed.entries[0].links[1].title, Some("Context"))
  assert_eq(feed.entries[0].links[2].length, Some(42L))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/root/main.atom",
    )
    is Ok(resolved) else {
    fail("expected resolved Atom")
  }
  assert_eq(
    resolved.links[0].href,
    "https://example.test/root/feeds/index.atom",
  )
  assert_eq(
    resolved.entries[0].links[1].href,
    "https://example.test/root/feeds/posts/related",
  )
  assert_eq(
    resolved.entries[0].attachments[0].url,
    "https://example.test/root/feeds/posts/audio.mp3",
  )
  let repeated =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:fixture:f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><link href="one" type="text/html" hreflang="en"/><link href="two" type="text/html" hreflang="en"/></feed>
  guard @feedlens.parse(repeated) is Ok(bad) else {
    fail("expected recovered Atom")
  }
  assert_true(
    bad.diagnostics[0].kind
    is @feedlens.DuplicateAtomField("feed alternate link"),
  )
}
