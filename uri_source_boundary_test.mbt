///|
test "source-aware Atom IRI resolves Unicode host and scoped base" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://例子.test/刊物/"><id>urn:feed:iri</id><title>International Feed</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author>
    #|<entry xml:base="章节/"><id>urn:entry:iri</id><title>Entry</title><updated>2026-10-23T00:00:00Z</updated><content>Body</content><link href="../文章/一?版=全#段"/><link rel="enclosure" href="音频/一.mp3" type="audio/mpeg"/></entry>
    #|</feed>
  guard @feedlens.parse_with_source(xml, "https://origin.test/feeds/main.atom")
    is Ok(feed) else {
    fail("expected resolved Atom IRI")
  }
  assert_eq(
    feed.entries[0].link,
    Some("https://例子.test/刊物/文章/一?版=全#段"),
  )
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://例子.test/刊物/章节/音频/一.mp3",
  )
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(xml) is Ok(raw) else { fail("expected raw Atom") }
  assert_eq(raw.entries[0].link, Some("../文章/一?版=全#段"))
}

///|
test "source URL rejects malformed authority before resolving any fields" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed</id><title>F</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author><entry><id>urn:entry</id><title>E</title><updated>2026-10-23T00:00:00Z</updated><content>Body</content><link href="post"/></entry></feed>
  for
    bad in [
      "https://:80/feed.atom", "https://example.test:bad/feed.atom", "https://bad^host/feed.atom",
      "https://bad{host}/feed.atom", "https://example.test/feed.atom#fragment", "https:///feed.atom",
      "https://[text]/feed.atom", "https://[2001:db8:::1]/feed.atom", "https://[fe80::1%25eth0]/feed.atom",
      "https://[vG.no]/feed.atom",
    ] {
    assert_true(
      @feedlens.parse_with_source(xml, bad)
      is Err(@feedlens.InvalidSourceUrl(_)),
    )
  }
  let entry = "<entry xmlns=\"http://www.w3.org/2005/Atom\"><id>urn:entry</id><title>E</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author><content>Body</content></entry>"
  assert_true(
    @feedlens.parse_document_with_source(entry, "https://:80/entry.atom")
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
  assert_true(
    @feedlens.parse_with_source(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"F\",\"items\":[]}",
      "https://example.test:bad/feed.json",
    )
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
  assert_true(
    @feedlens.parse_with_source(
      "<rss version=\"2.0\"><channel><title>F</title><link>home</link><description>D</description></channel></rss>",
      "https://bad^host/feed.xml",
    )
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
  guard @feedlens.parse_with_source(
      xml, "https://user:pass@[2001:db8::1]:8080/feeds/main.atom",
    )
    is Ok(valid) else {
    fail("expected legal bracketed IPv6 authority")
  }
  assert_eq(
    valid.entries[0].link,
    Some("https://user:pass@[2001:db8::1]:8080/feeds/post"),
  )
  assert_eq(valid.diagnostics, [])
  guard @feedlens.parse_with_source(
      xml, "https://[::ffff:192.0.2.128]/feeds/main.atom",
    )
    is Ok(mapped) else {
    fail("expected IPv4-mapped IPv6 source")
  }
  assert_eq(
    mapped.entries[0].link,
    Some("https://[::ffff:192.0.2.128]/feeds/post"),
  )
  guard @feedlens.parse_with_source(xml, "https://[v1.a:b]/feeds/main.atom")
    is Ok(future) else {
    fail("expected syntactically valid IPvFuture source")
  }
  assert_eq(future.entries[0].link, Some("https://[v1.a:b]/feeds/post"))
  guard @feedlens.parse_with_source(xml, "https://例子.test/刊物/feed.atom")
    is Ok(iri_source) else {
    fail("expected Unicode IRI document source")
  }
  assert_eq(iri_source.entries[0].link, Some("https://例子.test/刊物/post"))
  assert_true(
    @feedlens.parse_document_with_source(entry, "https://[text]/entry.atom")
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
  guard @feedlens.parse_document_with_source(
      entry, "https://[::1]:8443/feeds/entry.atom",
    )
    is Ok(_) else {
    fail("expected independent Atom Entry with IPv6 source")
  }
  assert_true(
    @feedlens.parse_with_source(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"F\",\"items\":[]}",
      "https://[2001:db8:::1]/feed.json",
    )
    is Err(@feedlens.InvalidSourceUrl(_)),
  )
  guard @feedlens.parse_with_source(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"F\",\"home_page_url\":\"home\",\"items\":[]}",
      "https://[::1]/feeds/feed.json",
    )
    is Ok(json) else {
    fail("expected JSON Feed with IPv6 source")
  }
  assert_eq(json.link, Some("https://[::1]/feeds/home"))
  guard @feedlens.parse_with_source(
      "<rss version=\"2.0\"><channel><title>F</title><link>home</link><description>D</description></channel></rss>",
      "https://[::1]/feeds/feed.xml",
    )
    is Ok(rss) else {
    fail("expected RSS with IPv6 source")
  }
  assert_eq(rss.link, Some("https://[::1]/feeds/home"))
}

///|
test "source-aware Atom entry resolves IPv6 authorities and preserves raw links" {
  let xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="../archive/">
    #|  <id>urn:feed:ip-literal</id><title>Literal host</title>
    #|  <updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author>
    #|  <entry>
    #|    <id>urn:entry:ip-literal</id><title>Post</title>
    #|    <updated>2026-10-23T00:00:00Z</updated><content>Body</content>
    #|    <link href="post"/>
    #|    <link rel="enclosure" type="audio/mpeg" href="//[::ffff:192.0.2.128]/media.mp3"/>
    #|  </entry>
    #|</feed>
  guard @feedlens.parse_with_source(
      xml, "https://[2001:db8::1]:8080/feeds/root.atom",
    )
    is Ok(feed) else {
    fail("expected IPv6 source")
  }
  assert_eq(
    feed.entries[0].link,
    Some("https://[2001:db8::1]:8080/archive/post"),
  )
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://[::ffff:192.0.2.128]/media.mp3",
  )
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse(xml) is Ok(raw) else { fail("expected raw Atom") }
  assert_eq(raw.entries[0].link, Some("post"))
  assert_eq(
    raw.entries[0].attachments[0].url,
    "//[::ffff:192.0.2.128]/media.mp3",
  )
}
