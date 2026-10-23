///|
test "RFC 3986 relative, root, query, fragment and authority references" {
  let base = "http://a/b/c/d;p?q"
  assert_eq(uri_resolve(base, "g"), Some("http://a/b/c/g"))
  assert_eq(uri_resolve(base, "../g"), Some("http://a/b/g"))
  assert_eq(uri_resolve(base, "../../g"), Some("http://a/g"))
  assert_eq(uri_resolve(base, "/g"), Some("http://a/g"))
  assert_eq(uri_resolve(base, "?y"), Some("http://a/b/c/d;p?y"))
  assert_eq(uri_resolve(base, "#s"), Some("http://a/b/c/d;p?q#s"))
  assert_eq(uri_resolve(base, "//g"), Some("http://g"))
  assert_eq(uri_resolve(base, "g?y#s"), Some("http://a/b/c/g?y#s"))
  assert_eq(uri_resolve(base, "."), Some("http://a/b/c/"))
}

///|
test "URI resolution rejects malformed references and bases" {
  assert_eq(uri_resolve("relative/feed.xml", "item"), None)
  assert_eq(uri_resolve("http:///missing-host", "item"), None)
  assert_eq(uri_resolve("http://:80/feed", "item"), None)
  assert_eq(uri_resolve("http://example.test:bad/feed", "item"), None)
  assert_eq(uri_resolve("http://bad^host/feed", "item"), None)
  assert_eq(uri_resolve("https://bad{host}/feed", "item"), None)
  assert_eq(
    uri_resolve("https://例子.test/刊物/", "../文章/一"),
    Some("https://例子.test/文章/一"),
  )
  assert_eq(uri_resolve("https://example.test/feed.xml", "bad%2G"), None)
  assert_eq(uri_resolve("https://example.test/feed.xml", "bad path"), None)
  assert_eq(
    uri_resolve("https://example.test/feed.xml", "https:///missing-host"),
    None,
  )
  assert_eq(uri_resolve("https://example.test/feed.xml", "//"), None)
}
