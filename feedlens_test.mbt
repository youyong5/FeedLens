///|
test "parse RSS 2.0 fields, entities, CDATA, and item order" {
  let input =
    #|<?xml version="1.0"?>
    #|<rss version="2.0">
    #|  <channel>
    #|    <title>News &amp; Notes</title>
    #|    <link>https://example.com/</link>
    #|    <description><![CDATA[Stories <em>daily</em>]]></description>
    #|    <item><guid>first</guid><title>One</title><link>https://example.com/1</link><description>First</description><pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate></item>
    #|    <item><title>Two</title><link>https://example.com/2</link></item>
    #|  </channel>
    #|</rss>
  let result = @feedlens.parse(input)
  guard result is Ok(feed) else { fail("expected a parsed feed") }
  assert_eq(feed.title, Some("News & Notes"))
  assert_eq(feed.description, Some("Stories <em>daily</em>"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].identifier, Some("first"))
  assert_eq(feed.entries[0].published_at, Some("Mon, 01 Jan 2024 00:00:00 GMT"))
  assert_eq(feed.entries[1].identifier, Some("https://example.com/2"))
  assert_true(feed.title_kind is @feedlens.Unspecified)
  assert_true(feed.description_kind is @feedlens.Unspecified)
  assert_true(feed.entries[0].description_kind is @feedlens.Unspecified)
  assert_eq(feed.entries[0].updated_at, None)
  assert_eq(feed.diagnostics, [])
}

///|
test "missing fields are recoverable and an anonymous item has a location" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0"><channel><link>https://example.com/</link>
      #|<item><title>Anonymous</title></item></channel></rss>
    ),
  )
  guard result is Ok(feed) else {
    match result {
      Err(@feedlens.InvalidXml(message, _, _)) => fail(message)
      Err(_) => fail("expected recovered feed")
      _ => fail("expected recovered feed")
    }
  }
  assert_eq(feed.title, None)
  assert_eq(feed.description, None)
  assert_eq(feed.entries[0].identifier, None)
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(feed.diagnostics[0].kind is @feedlens.MissingItemIdentifier(0))
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[0].column, 1)
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingChannelField("title"),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.MissingChannelField("description"),
  )
}

///|
test "same local names in another namespace are not RSS core fields" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:ext="urn:extension"><channel>
      #|<ext:title>Wrong title</ext:title><title>Right title</title>
      #|<link>https://example.com/</link><description>Right description</description>
      #|<item><ext:guid>wrong</ext:guid><ext:title>wrong</ext:title><link>https://example.com/item</link></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else {
    match result {
      Err(@feedlens.InvalidXml(message, _, _)) => fail(message)
      Err(_) => fail("expected a parsed feed")
      _ => fail("expected a parsed feed")
    }
  }
  assert_eq(feed.title, Some("Right title"))
  assert_eq(feed.entries[0].title, None)
  assert_eq(feed.entries[0].identifier, Some("https://example.com/item"))
}

///|
test "blank guid falls back to link and isPermaLink does not change guid" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0"><channel><title>News</title><link>https://example.com/</link><description>Feed</description>
      #|<item><guid>   </guid><link>https://example.com/fallback</link></item>
      #|<item><guid isPermaLink="true">opaque-guid</guid><link>https://example.com/not-the-id</link></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected a parsed feed") }
  assert_eq(feed.entries[0].identifier, Some("https://example.com/fallback"))
  assert_eq(feed.entries[1].identifier, Some("opaque-guid"))
}

///|
test "blank channel metadata points to its field element" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0">
      #|<channel>
      #|<title>   </title>
      #|<link>https://example.com/</link>
      #|<description><![CDATA[  ]]></description>
      #|</channel>
      #|</rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered feed") }
  assert_eq(feed.title, None)
  assert_eq(feed.description, None)
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.MissingChannelField("title"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (3, 1))
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingChannelField("description"),
  )
  assert_eq((feed.diagnostics[1].line, feed.diagnostics[1].column), (5, 1))
}

///|
test "absent channel metadata points to the channel element" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0">
      #|<channel>
      #|<title>News</title>
      #|</channel>
      #|</rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered feed") }
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(feed.diagnostics[0].kind is @feedlens.MissingChannelField("link"))
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (2, 1))
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingChannelField("description"),
  )
  assert_eq((feed.diagnostics[1].line, feed.diagnostics[1].column), (2, 1))
}

///|
test "RSS core structure requires direct unnamespaced elements" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:ext="urn:extension"><channel>
      #|<wrapper><title>nested title</title><item><guid>nested-item</guid></item></wrapper>
      #|<title>News</title><link>https://example.com/</link><description>Feed</description>
      #|<ext:item><guid>extension-item</guid></ext:item>
      #|<item><guid>direct-item</guid></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected a parsed feed") }
  assert_eq(feed.title, Some("News"))
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].identifier, Some("direct-item"))

  let namespaced_root = @feedlens.parse(
    "<rss xmlns=\"urn:not-rss\" version=\"2.0\"><channel/></rss>",
  )
  assert_true(
    namespaced_root
    is Err(@feedlens.UnsupportedRoot("rss", Some("urn:not-rss"))),
  )

  let nested_channel = @feedlens.parse(
    "<rss version=\"2.0\"><wrapper><channel/></wrapper></rss>",
  )
  assert_true(nested_channel is Err(@feedlens.MissingChannel))

  let wrong_version = @feedlens.parse("<rss version=\"0.91\"><channel/></rss>")
  assert_true(
    wrong_version is Err(@feedlens.UnsupportedRssVersion(Some("0.91"))),
  )
}

///|
test "malformed XML is fatal" {
  let result = @feedlens.parse("<rss version=\"2.0\"><channel></rss>")
  assert_true(result is Err(@feedlens.InvalidXml(_, _, _)))
}

///|
test "an unsupported root is fatal" {
  let result = @feedlens.parse("<feed><channel/></feed>")
  assert_true(result is Err(@feedlens.UnsupportedRoot("feed", None)))
}

///|
test "a missing channel is fatal" {
  let result = @feedlens.parse("<rss version=\"2.0\"></rss>")
  assert_true(result is Err(@feedlens.MissingChannel))
}

///|
test "RSS nested markup never becomes core field text" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:ext="urn:extension"><channel>
      #|<title>prefix <ext:em>nested</ext:em></title><link>https://example.com/</link><description>Feed</description>
      #|<item><guid>item-1</guid><description>before <ext:em>nested</ext:em></description></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered RSS feed") }
  assert_eq(feed.title, None)
  assert_eq(feed.entries[0].description, None)
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.UnsupportedNestedMarkup("rss title"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnsupportedNestedMarkup("rss description"),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.MissingChannelField("title"),
  )
}

///|
test "RSS fields retain their normalized public mapping" {
  let result = @feedlens.parse(
    "<rss version=\"2.0\"><channel><title>Feed</title><link>https://example.com/</link><description>Channel description</description><item><guid>guid-1</guid><title>Entry</title><link>https://example.com/entry</link><description>Item description</description><pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate></item></channel></rss>",
  )
  guard result is Ok(feed) else { fail("expected RSS feed") }
  assert_true(feed.format is @feedlens.Rss2)
  assert_eq(feed.identifier, None)
  assert_eq(feed.description, Some("Channel description"))
  assert_true(feed.description_kind is @feedlens.Unspecified)
  assert_eq(feed.updated_at, None)
  assert_eq(feed.entries[0].identifier, Some("guid-1"))
  assert_eq(feed.entries[0].description, Some("Item description"))
  assert_eq(feed.entries[0].content, None)
  assert_true(feed.entries[0].content_kind is @feedlens.Unspecified)
  assert_eq(feed.entries[0].published_at, Some("Mon, 01 Jan 2024 00:00:00 GMT"))
  assert_eq(feed.entries[0].updated_at, None)
  assert_eq(feed.diagnostics, [])
}

///|
test "RSS Content Module encoded is separate from description" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:c="http://purl.org/rss/1.0/modules/content/" xmlns:body="http://purl.org/rss/1.0/modules/content/" xmlns:fake="urn:not-content"><channel>
      #|<title>Feed</title><link>https://example.com/</link><description>Feed description</description>
      #|<item><guid>one</guid><description>Summary</description><c:encoded><![CDATA[<p>CDATA body</p>]]></c:encoded></item>
      #|<item><guid>two</guid><fake:encoded>ignored</fake:encoded><body:encoded>&lt;p&gt;Entity &amp; text&lt;/p&gt;</body:encoded></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected RSS feed") }
  assert_eq(feed.entries[0].description, Some("Summary"))
  assert_eq(feed.entries[0].content, Some("<p>CDATA body</p>"))
  assert_true(feed.entries[0].content_kind is @feedlens.Unspecified)
  assert_eq(feed.entries[1].content, Some("<p>Entity & text</p>"))
  assert_eq(feed.diagnostics, [])
}

///|
test "RSS Content Module rejects nested XML and fake namespaces" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:c="http://purl.org/rss/1.0/modules/content/" xmlns:fake="urn:not-content"><channel>
      #|<title>Feed</title><link>https://example.com/</link><description>Feed description</description>
      #|<item><guid>one</guid><fake:encoded>ignored</fake:encoded><c:encoded>before <b>markup</b></c:encoded></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered RSS feed") }
  assert_eq(feed.entries[0].content, None)
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedNestedMarkup("rss content:encoded"),
  )
}

///|
test "Atom HTML text kinds retain decoded source text" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title type="html">Feed &amp; &lt;em&gt;notes&lt;/em&gt;</title><subtitle type="html">Sub &lt;b&gt;title&lt;/b&gt;</subtitle><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author>
      #|<entry><id>urn:entry</id><title type="html">Entry &lt;i&gt;title&lt;/i&gt;</title><updated>2026-10-14T00:00:00Z</updated><summary type="html">Summary &lt;strong&gt;body&lt;/strong&gt;</summary><link href="/entry"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.title, Some("Feed & <em>notes</em>"))
  assert_true(feed.title_kind is @feedlens.Html)
  assert_eq(feed.description, Some("Sub <b>title</b>"))
  assert_true(feed.description_kind is @feedlens.Html)
  assert_eq(feed.entries[0].title, Some("Entry <i>title</i>"))
  assert_true(feed.entries[0].title_kind is @feedlens.Html)
  assert_eq(feed.entries[0].description, Some("Summary <strong>body</strong>"))
  assert_true(feed.entries[0].description_kind is @feedlens.Html)
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom inline content retains text, HTML, CDATA, and whitespace" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author>
      #|<entry><id>one</id><title>One</title><updated>2026-10-14T00:00:00Z</updated><summary>Summary</summary><content>  plain &amp; text  </content></entry>
      #|<entry><id>two</id><title>Two</title><updated>2026-10-14T00:00:00Z</updated><content type="text"><![CDATA[CDATA <body>]]></content></entry>
      #|<entry><id>three</id><title>Three</title><updated>2026-10-14T00:00:00Z</updated><content type="html">&lt;p&gt;HTML &amp;amp; body&lt;/p&gt;</content></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.entries[0].description, Some("Summary"))
  assert_eq(feed.entries[0].content, Some("  plain & text  "))
  assert_true(feed.entries[0].content_kind is @feedlens.Text)
  assert_eq(feed.entries[1].content, Some("CDATA <body>"))
  assert_true(feed.entries[1].content_kind is @feedlens.Text)
  assert_eq(feed.entries[2].content, Some("<p>HTML &amp; body</p>"))
  assert_true(feed.entries[2].content_kind is @feedlens.Html)
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom XHTML content is captured while unsupported types and nested text are diagnosed" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author>
      #|<entry><id>one</id><title>One</title><updated>2026-10-14T00:00:00Z</updated><content type="xhtml"><xhtml:div>markup</xhtml:div></content></entry>
      #|<entry><id>two</id><title>Two</title><updated>2026-10-14T00:00:00Z</updated><content type="application/json">{}</content></entry>
      #|<entry><id>three</id><title>Three</title><updated>2026-10-14T00:00:00Z</updated><content>before <em>markup</em></content></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.entries[0].content, Some("markup"))
  assert_true(feed.entries[0].content_kind is @feedlens.Xhtml)
  assert_eq(feed.entries[1].content, None)
  assert_eq(feed.entries[2].content, None)
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("Atom content with unsupported type"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnsupportedAtomContent("Atom content with nested markup"),
  )
}

///|
test "Atom entry without content requires an alternate link" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(feed.diagnostics[0].kind is @feedlens.MissingAlternateLink(0))
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (3, 1))
}

///|
test "Atom external content requires a summary" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><content src="https://example.com/content"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.MissingSummaryForExternalContent(0),
  )
  assert_eq(feed.entries[0].content, None)
  assert_eq(feed.entries[0].content_source, Some("https://example.com/content"))
  assert_eq(feed.entries[0].content_media_type, None)
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (3, 85))
}

///|
test "an empty Atom author does not satisfy entry author inheritance" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author/>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAuthor("atom author missing name"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (2, 76))
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingEntryField(0, "author"),
  )
}

///|
test "an Atom author without a name does not satisfy inheritance" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><uri>https://example.com/author</uri></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidAuthor("atom author missing name"),
  )
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingEntryField(0, "author"),
  )
}

///|
test "parse Atom default namespace core fields and alternate links" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title type="html">Feed &amp; &lt;em&gt;notes&lt;/em&gt;</title><subtitle>Sub</subtitle><updated>2026-10-14T00:00:00Z</updated>
      #|<link rel="self" href="https://example.com/self"/><link href="/relative-alternate"/><author><name>Feed author</name></author>
      #|<entry><id>urn:entry:1</id><title>First</title><published>2026-10-13T00:00:00Z</published><updated>2026-10-14T00:00:00Z</updated><summary>One</summary><link rel="self" href="https://example.com/entry-self"/><link rel="alternate" href="/entries/1"/></entry>
      #|<entry><id>urn:entry:2</id><title>Second</title><updated>2026-10-14T01:00:00Z</updated><summary><![CDATA[Second <safe>summary</safe>]]></summary><link href="/entries/2"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_true(feed.format is @feedlens.Atom1)
  assert_eq(feed.identifier, Some("urn:feed"))
  assert_eq(feed.title, Some("Feed & <em>notes</em>"))
  assert_true(feed.title_kind is @feedlens.Html)
  assert_eq(feed.description, Some("Sub"))
  assert_true(feed.description_kind is @feedlens.Text)
  assert_eq(feed.link, Some("/relative-alternate"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].identifier, Some("urn:entry:1"))
  assert_eq(feed.entries[0].link, Some("/entries/1"))
  assert_eq(feed.entries[0].published_at, Some("2026-10-13T00:00:00Z"))
  assert_eq(feed.entries[1].description, Some("Second <safe>summary</safe>"))
  assert_eq(feed.diagnostics, [])
}

///|
test "parse Atom prefixed namespace and reject other namespace fields" {
  let result = @feedlens.parse(
    (
      #|<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:x="urn:extension">
      #|<x:id>wrong</x:id><a:id>urn:feed</a:id><a:title>Feed</a:title><a:updated>2026-10-14T00:00:00Z</a:updated>
      #|<a:entry><x:id>wrong</x:id><a:id>urn:entry</a:id><a:title>Entry</a:title><a:updated>2026-10-14T00:00:00Z</a:updated><a:link href="/entry"/><a:author><a:name>Author</a:name></a:author></a:entry>
      #|</a:feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.identifier, Some("urn:feed"))
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].identifier, Some("urn:entry"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom missing fields have source locations and feed author is inherited" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id> </id>
      #|<author><name>Feed author</name></author>
      #|<entry><title>Entry</title><link href="/entry"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.diagnostics.length(), 5)
  assert_true(feed.diagnostics[0].kind is @feedlens.MissingEntryField(0, "id"))
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (4, 1))
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingEntryField(0, "updated"),
  )
  assert_eq((feed.diagnostics[1].line, feed.diagnostics[1].column), (4, 1))
  assert_true(feed.diagnostics[2].kind is @feedlens.MissingFeedField("id"))
  assert_eq((feed.diagnostics[2].line, feed.diagnostics[2].column), (2, 1))
  assert_true(feed.diagnostics[3].kind is @feedlens.MissingFeedField("title"))
  assert_eq((feed.diagnostics[3].line, feed.diagnostics[3].column), (1, 1))
  assert_true(feed.diagnostics[4].kind is @feedlens.MissingFeedField("updated"))
  assert_eq((feed.diagnostics[4].line, feed.diagnostics[4].column), (1, 1))
}

///|
test "Atom XHTML title and external content have independent outcomes" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      #|<id>urn:feed</id><title type="xhtml"><xhtml:div>markup</xhtml:div></title><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><content src="https://example.com/content"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.title, Some("markup"))
  assert_true(feed.title_kind is @feedlens.Xhtml)
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.MissingSummaryForExternalContent(0),
  )
  assert_eq(feed.entries[0].content_source, Some("https://example.com/content"))
}

///|
test "Atom entry authors take precedence over feed authors in order" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Feed author</name><email>feed@example.com</email></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/><author><name>First</name><uri>https://example.com/first</uri></author><author><name>Second</name><email>second@example.com</email></author><source><author><name>Ignored source author</name></author></source></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.authors.length(), 1)
  assert_eq(feed.authors[0].name, Some("Feed author"))
  assert_eq(feed.entries[0].authors.length(), 2)
  assert_eq(feed.entries[0].authors[0].name, Some("First"))
  assert_eq(feed.entries[0].authors[0].uri, Some("https://example.com/first"))
  assert_eq(feed.entries[0].authors[1].name, Some("Second"))
  assert_eq(feed.entries[0].authors[1].email, Some("second@example.com"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom feed authors are inherited only when entry has no own or source author" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Feed author</name></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.entries[0].authors.length(), 1)
  assert_eq(feed.entries[0].authors[0].name, Some("Feed author"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom source authors take precedence over feed authors" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Feed author</name></author>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/><source><author><name>Source author</name><uri>https://example.com/source</uri></author></source></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.entries[0].authors.length(), 1)
  assert_eq(feed.entries[0].authors[0].name, Some("Source author"))
  assert_eq(feed.entries[0].authors[0].uri, Some("https://example.com/source"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom feed may omit authors when every entry has a valid own author" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated>
      #|<entry><id>one</id><title>One</title><updated>2026-10-14T00:00:00Z</updated><link href="/one"/><author><name>One author</name></author></entry>
      #|<entry><id>two</id><title>Two</title><updated>2026-10-14T00:00:00Z</updated><link href="/two"/><author><name>Two author</name></author></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.authors, [])
  assert_eq(feed.entries[0].authors[0].name, Some("One author"))
  assert_eq(feed.entries[1].authors[0].name, Some("Two author"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom categories preserve term scheme label and document order" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><author><name>Author</name></author><category term="feed-one" scheme="urn:feed" label="Feed one"/><category term="feed-two"/>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/><category term="entry-one" scheme="urn:entry" label="Entry one"/><category term="entry-two"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected Atom feed") }
  assert_eq(feed.categories.length(), 2)
  assert_eq(feed.categories[0].term, "feed-one")
  assert_eq(feed.categories[0].scheme, Some("urn:feed"))
  assert_eq(feed.categories[0].label, Some("Feed one"))
  assert_eq(feed.entries[0].categories.length(), 2)
  assert_eq(feed.entries[0].categories[0].term, "entry-one")
  assert_eq(feed.entries[0].categories[0].scheme, Some("urn:entry"))
  assert_eq(feed.entries[0].categories[1].term, "entry-two")
  assert_eq(feed.entries[0].categories[1].label, None)
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom invalid authors and categories have element diagnostics" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:extension">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated><x:author><x:name>ignored</x:name></x:author><category/>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/><author><email>no-name@example.com</email></author><x:category term="ignored"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.entries[0].authors, [])
  assert_eq(feed.categories, [])
  assert_eq(feed.entries[0].categories, [])
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidCategory("atom category missing term"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (2, 121))
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidAuthor("atom author missing name"),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.MissingEntryField(0, "author"),
  )
}

///|
test "Atom entry with no available author has a missing-author diagnostic" {
  let result = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom">
      #|<id>urn:feed</id><title>Feed</title><updated>2026-10-14T00:00:00Z</updated>
      #|<entry><id>urn:entry</id><title>Entry</title><updated>2026-10-14T00:00:00Z</updated><link href="/entry"/></entry>
      #|</feed>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered Atom feed") }
  assert_eq(feed.entries[0].authors, [])
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.MissingEntryField(0, "author"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (3, 1))
}

///|
test "RSS authors and categories retain raw values and domains" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0"><channel><title>Feed</title><link>https://example.com/</link><description>Description</description><category domain="https://example.com/topics">Technology</category><category>News</category>
      #|<item><guid>item</guid><author>Jane Doe &lt;jane@example.com&gt;</author><category domain="urn:topic">MoonBit</category><category>Language</category></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected RSS feed") }
  assert_eq(feed.authors, [])
  assert_eq(feed.categories.length(), 2)
  assert_eq(feed.categories[0].term, "Technology")
  assert_eq(feed.categories[0].domain, Some("https://example.com/topics"))
  assert_eq(feed.categories[1].term, "News")
  assert_eq(feed.entries[0].authors.length(), 1)
  assert_true(feed.entries[0].authors[0].source is @feedlens.Rss2)
  assert_eq(feed.entries[0].authors[0].name, None)
  assert_eq(
    feed.entries[0].authors[0].email,
    Some("Jane Doe <jane@example.com>"),
  )
  assert_eq(feed.entries[0].categories.length(), 2)
  assert_eq(feed.entries[0].categories[0].domain, Some("urn:topic"))
  assert_eq(feed.entries[0].categories[1].term, "Language")
  assert_eq(feed.diagnostics, [])
}

///|
test "RSS namespace collisions and empty author or category are diagnosed" {
  let result = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:x="urn:extension"><channel><title>Feed</title><link>https://example.com/</link><description>Description</description><x:category>ignored</x:category><category>   </category>
      #|<item><guid>item</guid><x:author>ignored</x:author><x:category>ignored</x:category><author><![CDATA[ ]]></author><category/></item>
      #|</channel></rss>
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered RSS feed") }
  assert_eq(feed.categories, [])
  assert_eq(feed.entries[0].authors, [])
  assert_eq(feed.entries[0].categories, [])
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.InvalidCategory("rss category missing term"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.InvalidAuthor("rss author missing email"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidCategory("rss category missing term"),
  )
}
