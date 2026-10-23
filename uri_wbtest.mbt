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

///|
test "HTTP IP-literal hosts follow IPv6 and IPvFuture shapes" {
  for
    host in [
      "[::]", "[::1]", "[2001:db8::1]", "[0:1:2:3:4:5:6:7]", "[::ffff:192.0.2.128]",
      "[2001:db8:0:0:0:0:192.0.2.128]", "[v1.a]", "[Vf.a:b-._~!$&'()*+,;=]",
    ] {
    assert_eq(
      uri_resolve("https://" + host + ":8080/feeds/main.xml", "../post"),
      Some("https://" + host + ":8080/post"),
    )
  }
  for
    host in [
      "[text]", "[1]", "[2001:db8:::1]", "[1:2:3:4:5:6:7]", "[1:2:3:4:5:6:7:8:9]",
      "[1:2:3:4:5:6:7::8]", "[1::2::3]", "[::ffff:256.0.0.1]", "[::ffff:01.2.3.4]",
      "[::ffff:1.2.3]", "[fe80::1%25eth0]", "[v.]", "[vG.a]", "[v1.]", "[v1.a%20]",
      "[v1.a/]",
    ] {
    assert_eq(uri_resolve("https://" + host + "/feed", "post"), None)
    assert_eq(uri_resolve("https://ok.test/feed", "//" + host + "/post"), None)
  }
}
