///|
test "RSS optional channel metadata is direct, ordered, and source aware" {
  let input =
    #|<rss version="2.0" xmlns:x="urn:unrelated"><channel>
    #|<title>Morning desk</title><link>https://example.test/news/</link><description>Bulletins</description>
    #|<docs>../spec/rss.html</docs><rating>(PICS-1.1 "https://ratings.example.test/")</rating>
    #|<cloud domain="notify.example.test" port="80" path="/RPC2" registerProcedure="pingMe" protocol="xml-rpc"/>
    #|<textInput><title>Search stories</title><description>Look up past issues</description><name>query</name><link>../search?q=latest</link></textInput>
    #|<item><title>One</title><description>News</description><docs>ignore nested</docs></item>
    #|<x:docs>ignore foreign</x:docs>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("RSS parse") }
  assert_eq(feed.docs_url, Some("../spec/rss.html"))
  assert_eq(feed.rating, Some("(PICS-1.1 \"https://ratings.example.test/\")"))
  guard feed.cloud is Some(cloud) else { fail("cloud") }
  assert_eq(cloud.domain, "notify.example.test")
  assert_eq(cloud.port, 80)
  assert_eq(cloud.protocol, "xml-rpc")
  guard feed.text_input is Some(form) else { fail("textInput") }
  assert_eq(form.title, "Search stories")
  assert_eq(form.name, "query")
  assert_eq(form.link, "../search?q=latest")
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/daily.xml",
    )
    is Ok(resolved) else {
    fail("resolved")
  }
  assert_eq(resolved.docs_url, Some("https://example.test/spec/rss.html"))
  guard resolved.text_input is Some(resolved_form) else {
    fail("resolved form")
  }
  assert_eq(resolved_form.link, "https://example.test/search?q=latest")
  assert_eq(resolved.diagnostics, [])
}

///|
test "RSS optional channel invalid children diagnose without dropping a feed" {
  let input =
    #|<rss version="2.0" xmlns:x="urn:foreign"><channel><title>T</title><link>https://example.test/</link><description>D</description>
    #|<docs>../reference</docs><docs>second</docs><rating><x:b>nested</x:b></rating>
    #|<cloud domain="notify.example.test" port="65536" path="/RPC2" registerProcedure="ping" protocol="xml-rpc"/>
    #|<textInput><title>T</title><title>Again</title><description>D</description><name>q</name><link>../search</link></textInput>
    #|<textInput><title>ignored</title></textInput>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("RSS parse") }
  assert_eq(feed.docs_url, Some("../reference"))
  assert_eq(feed.rating, None)
  assert_eq(feed.cloud, None)
  guard feed.text_input is Some(form) else { fail("first complete form") }
  assert_eq(form.title, "T")
  assert_eq(feed.diagnostics.length(), 5)
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("cloud") && d.line == 3
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("textInput title duplicate") &&
      d.line == 4
    }),
  )
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/daily.xml",
    )
    is Ok(resolved) else {
    fail("resolved")
  }
  assert_eq(resolved.diagnostics.length(), 5)
}
