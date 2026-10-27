///|
test "RFC 3986 relative, root, query, fragment and authority references" {
  let base = "http://a/b/c/d;p?q"
  assert_eq(uri_resolve(base, "g"), Some("http://a/b/c/g"))
  assert_eq(uri_resolve(base, "../g"), Some("http://a/b/g"))
  assert_eq(uri_resolve(base, "../../g"), Some("http://a/g"))
  assert_eq(uri_resolve(base, "/g"), Some("http://a/g"))
  assert_eq(uri_resolve(base, "?y"), Some("http://a/b/c/d;p?y"))
  assert_eq(uri_resolve(base, ""), Some(base))
  assert_eq(
    uri_resolve("http://a/b/c/d;p?q#old", ""),
    Some("http://a/b/c/d;p?q"),
  )
  assert_eq(uri_resolve(base, "#s"), Some("http://a/b/c/d;p?q#s"))
  assert_eq(uri_resolve(base, "//g"), Some("http://g"))
  assert_eq(uri_resolve(base, "g?y#s"), Some("http://a/b/c/g?y#s"))
  assert_eq(uri_resolve(base, "."), Some("http://a/b/c/"))
}

///|
/// RFC 3986 section 5.4.1: each expected URI is the published resolution
/// result for the document base, including empty and query-only references.
test "RFC 3986 section 5.4.1 normal reference examples" {
  let base = "http://a/b/c/d;p?q"
  for
    (reference, expected) in [
      ("g:h", "g:h"),
      ("g", "http://a/b/c/g"),
      ("./g", "http://a/b/c/g"),
      ("g/", "http://a/b/c/g/"),
      ("/g", "http://a/g"),
      ("//g", "http://g"),
      ("?y", "http://a/b/c/d;p?y"),
      ("g?y", "http://a/b/c/g?y"),
      ("#s", "http://a/b/c/d;p?q#s"),
      ("g#s", "http://a/b/c/g#s"),
      ("g?y#s", "http://a/b/c/g?y#s"),
      (";x", "http://a/b/c/;x"),
      ("g;x", "http://a/b/c/g;x"),
      ("g;x?y#s", "http://a/b/c/g;x?y#s"),
      ("", "http://a/b/c/d;p?q"),
      (".", "http://a/b/c/"),
      ("./", "http://a/b/c/"),
      ("..", "http://a/b/"),
      ("../", "http://a/b/"),
      ("../g", "http://a/b/g"),
      ("../..", "http://a/"),
      ("../../", "http://a/"),
      ("../../g", "http://a/g"),
    ] {
    assert_eq(uri_resolve(base, reference), Some(expected))
  }
}

///|
/// RFC 3986 section 5.4.2: dot segments in path are handled separately
/// from lookalike names and from slash or dot text in query and fragment.
test "RFC 3986 section 5.4.2 abnormal reference examples" {
  let base = "http://a/b/c/d;p?q"
  for
    (reference, expected) in [
      ("../../../g", "http://a/g"),
      ("../../../../g", "http://a/g"),
      ("/./g", "http://a/g"),
      ("/../g", "http://a/g"),
      ("g.", "http://a/b/c/g."),
      (".g", "http://a/b/c/.g"),
      ("g..", "http://a/b/c/g.."),
      ("..g", "http://a/b/c/..g"),
      ("./../g", "http://a/b/g"),
      ("./g/.", "http://a/b/c/g/"),
      ("g/./h", "http://a/b/c/g/h"),
      ("g/../h", "http://a/b/c/h"),
      ("g;x=1/./y", "http://a/b/c/g;x=1/y"),
      ("g;x=1/../y", "http://a/b/c/y"),
      ("g?y/./x", "http://a/b/c/g?y/./x"),
      ("g?y/../x", "http://a/b/c/g?y/../x"),
      ("g#s/./x", "http://a/b/c/g#s/./x"),
      ("g#s/../x", "http://a/b/c/g#s/../x"),
      ("http:g", "http:g"),
    ] {
    assert_eq(uri_resolve(base, reference), Some(expected))
  }
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
test "RFC 3986 ASCII path query and fragment character boundaries" {
  let base = "https://example.test/feeds/feed.xml"
  for
    bad in [
      "post[1]", "post|one", "post^one", "post`one", "post{one}", "post?value=[one]",
      "post?value=one|two", "post#part#two", "post#part[one]", "post#part^one", "https://example.test/feeds/{one}",
    ] {
    assert_eq(uri_resolve(base, bad), None)
  }
  for
    (reference, expected) in [
      ("post%5B1%5D", "https://example.test/feeds/post%5B1%5D"),
      (
        "post?value=%5Bone%5D", "https://example.test/feeds/post?value=%5Bone%5D",
      ),
      ("post#part%23two", "https://example.test/feeds/post#part%23two"),
      (
        "post?x=1/2?y=3#part/one?two", "https://example.test/feeds/post?x=1/2?y=3#part/one?two",
      ),
      ("https://[::1]/post", "https://[::1]/post"),
    ] {
    assert_eq(uri_resolve(base, reference), Some(expected))
  }
  assert_eq(uri_resolve("https://example.test/feeds/[raw]", "post"), None)
  assert_eq(uri_resolve("https://example.test/feeds/?x={raw}", "post"), None)
  assert_eq(uri_resolve("https://user|name@example.test/feed", "post"), None)
  assert_eq(uri_resolve(base, "https://user[name]@example.test/post"), None)
  assert_eq(
    uri_resolve("https://user%7Cname:pass@example.test/feed", "post"),
    Some("https://user%7Cname:pass@example.test/post"),
  )
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
