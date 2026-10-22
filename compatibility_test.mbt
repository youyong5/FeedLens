///|
/// Mirrors `samples/rss2_compat.xml`. The test embeds the checked-in sample so
/// it runs identically on Wasm, JavaScript, and Native targets.
fn rss2_compatibility_sample() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<rss version="2.0"
    #|     xmlns:body="http://purl.org/rss/1.0/modules/content/"
    #|     xmlns:wrong="urn:not-content">
    #|  <channel>
    #|    <title>RSS &amp; Compatibility</title>
    #|    <link>https://feeds.example.test/rss</link>
    #|    <description><![CDATA[RSS sample description]]></description>
    #|    <category domain="https://example.test/topics">technology</category>
    #|    <item>
    #|      <guid>rss-item-1</guid>
    #|      <title>First &amp; Main</title>
    #|      <link>https://example.test/posts/1</link>
    #|      <description><![CDATA[First summary]]></description>
    #|      <author>writer@example.test</author>
    #|      <category domain="urn:example:topic">moonbit</category>
    #|      <body:encoded><![CDATA[<p>First RSS body</p>]]></body:encoded>
    #|      <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
    #|    </item>
    #|    <item>
    #|      <title>Second &amp; Reordered</title>
    #|      <description>Second summary</description>
    #|      <link>https://example.test/posts/2</link>
    #|      <wrong:encoded>must not become content</wrong:encoded>
    #|      <body:encoded>&lt;p&gt;Second &amp;amp; body&lt;/p&gt;</body:encoded>
    #|    </item>
    #|  </channel>
    #|</rss>
  )
}

///|
/// Mirrors `samples/atom1_compat.xml` and intentionally uses an Atom prefix.
fn atom1_compatibility_sample() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<a:feed xmlns:a="http://www.w3.org/2005/Atom"
    #|        xmlns:x="urn:extension">
    #|  <a:id>https://feeds.example.test/atom</a:id>
    #|  <a:title>Atom &amp; Compatibility</a:title>
    #|  <a:subtitle>Atom sample description</a:subtitle>
    #|  <a:updated>2024-01-02T00:00:00Z</a:updated>
    #|  <a:link rel="self" href="https://feeds.example.test/atom"/>
    #|  <a:link href="https://feeds.example.test/atom/home"/>
    #|  <a:author><a:name>Feed Author</a:name><a:email>feed@example.test</a:email></a:author>
    #|  <a:category term="technology" scheme="https://example.test/topics" label="Technology"/>
    #|  <a:entry>
    #|    <a:id>https://example.test/posts/1</a:id>
    #|    <a:title>Atom First</a:title>
    #|    <a:published>2024-01-01T00:00:00Z</a:published>
    #|    <a:updated>2024-01-02T00:00:00Z</a:updated>
    #|    <a:summary>Atom first summary</a:summary>
    #|    <a:link rel="alternate" href="https://example.test/posts/1"/>
    #|    <a:content type="html">&lt;p&gt;Atom body&lt;/p&gt;</a:content>
    #|    <a:author><a:name>Entry Author</a:name><a:uri>https://example.test/people/entry</a:uri></a:author>
    #|    <a:category term="moonbit" scheme="urn:example:topic" label="MoonBit"/>
    #|  </a:entry>
    #|  <a:entry>
    #|    <a:id>https://example.test/posts/2</a:id>
    #|    <a:title>Atom Second</a:title>
    #|    <a:updated>2024-01-02T01:00:00Z</a:updated>
    #|    <a:summary><![CDATA[Atom second summary]]></a:summary>
    #|    <a:link href="https://example.test/posts/2"/>
    #|    <a:content>Second Atom body</a:content>
    #|    <a:source><a:author><a:name>Source Author</a:name></a:author></a:source>
    #|    <x:category term="ignored"/>
    #|  </a:entry>
    #|</a:feed>
  )
}

///|
test "RSS compatibility sample matches the declared intersection" {
  guard @feedlens.parse(rss2_compatibility_sample()) is Ok(feed) else {
    fail("expected RSS compatibility sample")
  }
  assert_true(feed.format is @feedlens.Rss2)
  assert_eq(feed.title, Some("RSS & Compatibility"))
  assert_eq(feed.link, Some("https://feeds.example.test/rss"))
  assert_eq(feed.description, Some("RSS sample description"))
  assert_eq(feed.categories[0].term, "technology")
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].identifier, Some("rss-item-1"))
  assert_eq(feed.entries[0].title, Some("First & Main"))
  assert_eq(feed.entries[0].content, Some("<p>First RSS body</p>"))
  assert_eq(feed.entries[0].authors[0].email, Some("writer@example.test"))
  assert_eq(feed.entries[1].identifier, Some("https://example.test/posts/2"))
  assert_eq(feed.entries[1].content, Some("<p>Second &amp; body</p>"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom compatibility sample matches the declared intersection" {
  guard @feedlens.parse(atom1_compatibility_sample()) is Ok(feed) else {
    fail("expected Atom compatibility sample")
  }
  assert_true(feed.format is @feedlens.Atom1)
  assert_eq(feed.identifier, Some("https://feeds.example.test/atom"))
  assert_eq(feed.title, Some("Atom & Compatibility"))
  assert_eq(feed.link, Some("https://feeds.example.test/atom/home"))
  assert_eq(feed.description, Some("Atom sample description"))
  assert_eq(feed.authors[0].name, Some("Feed Author"))
  assert_eq(feed.categories[0].label, Some("Technology"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].link, Some("https://example.test/posts/1"))
  assert_eq(feed.entries[0].content, Some("<p>Atom body</p>"))
  assert_true(feed.entries[0].content_kind is @feedlens.Html)
  assert_eq(feed.entries[0].authors[0].name, Some("Entry Author"))
  assert_eq(feed.entries[1].content, Some("Second Atom body"))
  assert_true(feed.entries[1].content_kind is @feedlens.Text)
  assert_eq(feed.entries[1].authors[0].name, Some("Source Author"))
  assert_eq(feed.diagnostics, [])
}

///|
/// Mirrors `samples/jsonfeed11_compat.json`. It remains embedded so all
/// MoonBit targets execute the same input without filesystem access.
fn jsonfeed11_compatibility_sample() -> String {
  (
    #|{
    #|  "version": "https://jsonfeed.org/version/1.1",
    #|  "title": "JSON Feed \u2603 Compatibility",
    #|  "description": "A compact JSON Feed sample",
    #|  "home_page_url": "https://feeds.example.test/json",
    #|  "feed_url": "https://feeds.example.test/json/feed.json",
    #|  "authors": [
    #|    { "name": "Feed Author", "url": "https://example.test/people/feed" }
    #|  ],
    #|  "items": [
    #|    {
    #|      "id": "json-item-1",
    #|      "url": "https://example.test/posts/json-1",
    #|      "title": "First JSON entry",
    #|      "summary": "First JSON summary",
    #|      "content_text": "Plain fallback body",
    #|      "content_html": "<p>JSON HTML body</p>",
    #|      "tags": ["moonbit", "feeds"]
    #|    },
    #|    {
    #|      "id": 2,
    #|      "content_text": "Second JSON body"
    #|    }
    #|  ]
    #|}
  )
}

///|
test "JSON Feed compatibility sample maps the declared JSON subset" {
  guard @feedlens.parse(jsonfeed11_compatibility_sample()) is Ok(feed) else {
    fail("expected JSON Feed compatibility sample")
  }
  assert_true(feed.format is @feedlens.JsonFeed1)
  assert_eq(feed.title, Some("JSON Feed ☃ Compatibility"))
  assert_eq(feed.link, Some("https://feeds.example.test/json"))
  assert_eq(feed.identifier, Some("https://feeds.example.test/json/feed.json"))
  assert_eq(feed.authors[0].name, Some("Feed Author"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].identifier, Some("json-item-1"))
  assert_eq(feed.entries[0].content, Some("<p>JSON HTML body</p>"))
  assert_true(feed.entries[0].content_kind is @feedlens.Html)
  assert_eq(feed.entries[0].categories[1].term, "feeds")
  assert_eq(feed.entries[1].identifier, Some("2"))
  assert_eq(feed.entries[1].authors[0].name, Some("Feed Author"))
  assert_eq(feed.diagnostics, [])
}

///|
test "compatibility boundary samples preserve diagnostics and locations" {
  let rss = @feedlens.parse(
    (
      #|<rss version="2.0" xmlns:c="http://purl.org/rss/1.0/modules/content/" xmlns:x="urn:not-content">
      #|  <channel>
      #|    <title>Boundary RSS</title><link>https://feeds.example.test/boundary</link><description>Boundary description</description>
      #|    <x:category>ignored</x:category><category>   </category>
      #|    <item><guid>boundary</guid><x:author>ignored</x:author><author> </author><x:encoded>ignored</x:encoded><c:encoded>before <b>nested</b></c:encoded></item>
      #|  </channel>
      #|</rss>
    ),
  )
  guard rss is Ok(rss_feed) else { fail("expected recovered boundary RSS") }
  assert_eq(rss_feed.entries[0].content, None)
  assert_eq(rss_feed.diagnostics.length(), 3)
  assert_true(
    rss_feed.diagnostics[0].kind
    is @feedlens.InvalidCategory("rss category missing term"),
  )
  assert_eq(
    (rss_feed.diagnostics[0].line, rss_feed.diagnostics[0].column),
    (4, 37),
  )
  assert_true(
    rss_feed.diagnostics[1].kind
    is @feedlens.InvalidAuthor("rss author missing email"),
  )
  assert_true(
    rss_feed.diagnostics[2].kind
    is @feedlens.UnsupportedNestedMarkup("rss content:encoded"),
  )

  let atom = @feedlens.parse(
    (
      #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:extension">
      #|  <id>urn:boundary</id><title>Boundary Atom</title><updated>2024-01-02T00:00:00Z</updated>
      #|  <x:author><x:name>ignored</x:name></x:author><category/>
      #|  <entry><id>urn:entry</id><title>Entry</title><updated>2024-01-02T00:00:00Z</updated><link href="https://example.test/entry"/><author><email>missing-name@example.test</email></author><x:category term="ignored"/></entry>
      #|</feed>
    ),
  )
  guard atom is Ok(atom_feed) else { fail("expected recovered boundary Atom") }
  assert_eq(atom_feed.diagnostics.length(), 4)
  assert_true(
    atom_feed.diagnostics[0].kind
    is @feedlens.InvalidCategory("atom category missing term"),
  )
  assert_eq(
    (atom_feed.diagnostics[0].line, atom_feed.diagnostics[0].column),
    (3, 48),
  )
  assert_true(
    atom_feed.diagnostics[1].kind
    is @feedlens.InvalidAuthor("atom author missing name"),
  )
  assert_true(
    atom_feed.diagnostics[2].kind is @feedlens.MissingFeedField("author"),
  )
  assert_true(
    atom_feed.diagnostics[3].kind is @feedlens.MissingEntryField(0, "author"),
  )
}

///|
test "compatibility invalid XML sample is fatal with a source position" {
  let result = @feedlens.parse(
    "<rss version=\"2.0\"><channel><title>Broken</title></rss>",
  )
  assert_true(result is Err(@feedlens.InvalidXml(_, 1, _)))
}
