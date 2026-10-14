///|
test "JSON Feed 1.1 maps normalized fields, Unicode, authors, tags, and order" {
  let result = @feedlens.parse(
    (
      #|{
      #|  "version": "https://jsonfeed.org/version/1.1",
      #|  "title": "Feed \u2603",
      #|  "description": "A plain summary",
      #|  "home_page_url": "https://example.test/",
      #|  "feed_url": "https://example.test/feed.json",
      #|  "author": {"name": "Legacy feed author"},
      #|  "authors": [{"name": "Feed author", "url": "https://example.test/people/feed"}],
      #|  "items": [
      #|    {
      #|      "id": "first",
      #|      "url": "https://example.test/1",
      #|      "title": "First",
      #|      "summary": "First summary",
      #|      "date_published": "2026-10-01T00:00:00Z",
      #|      "date_modified": "2026-10-02T00:00:00Z",
      #|      "content_text": "Plain body",
      #|      "content_html": "<p>HTML &amp; body</p>",
      #|      "author": {"name": "Ignored item legacy author"},
      #|      "authors": [{"url": "https://example.test/people/only-url"}],
      #|      "tags": ["moonbit", "feeds"]
      #|    },
      #|    {"id": "second", "content_text": "Second body"}
      #|  ]
      #|}
    ),
  )
  guard result is Ok(feed) else { fail("expected JSON Feed 1.1") }
  assert_true(feed.format is @feedlens.JsonFeed1)
  assert_eq(feed.identifier, Some("https://example.test/feed.json"))
  assert_eq(feed.title, Some("Feed ☃"))
  assert_true(feed.title_kind is @feedlens.Text)
  assert_eq(feed.description, Some("A plain summary"))
  assert_true(feed.description_kind is @feedlens.Text)
  assert_eq(feed.link, Some("https://example.test/"))
  assert_eq(feed.authors.length(), 1)
  assert_eq(feed.authors[0].name, Some("Feed author"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].identifier, Some("first"))
  assert_eq(feed.entries[0].description, Some("First summary"))
  assert_true(feed.entries[0].description_kind is @feedlens.Text)
  assert_eq(feed.entries[0].content, Some("<p>HTML &amp; body</p>"))
  assert_true(feed.entries[0].content_kind is @feedlens.Html)
  assert_eq(feed.entries[0].authors.length(), 1)
  assert_eq(feed.entries[0].authors[0].name, None)
  assert_eq(
    feed.entries[0].authors[0].uri,
    Some("https://example.test/people/only-url"),
  )
  assert_eq(feed.entries[0].categories.length(), 2)
  assert_true(feed.entries[0].categories[0].source is @feedlens.JsonFeed1)
  assert_eq(feed.entries[0].categories[0].term, "moonbit")
  assert_eq(feed.entries[1].identifier, Some("second"))
  assert_eq(feed.entries[1].authors[0].name, Some("Feed author"))
  assert_eq(feed.entries[1].content, Some("Second body"))
  assert_true(feed.entries[1].content_kind is @feedlens.Text)
  assert_eq(feed.diagnostics, [])
}

///|
test "JSON Feed 1.0 accepts legacy author and numeric item id" {
  let result = @feedlens.parse(
    (
      #|{
      #|  "version": "https://jsonfeed.org/version/1",
      #|  "title": "Version one",
      #|  "author": {"name": "Only legacy", "url": "https://example.test/legacy"},
      #|  "items": [{
      #|    "id": 42,
      #|    "title": "A title",
      #|    "summary": "A summary",
      #|    "content_text": "A body",
      #|    "date_published": "2026-10-03T00:00:00Z",
      #|    "date_modified": "2026-10-04T00:00:00Z"
      #|  }]
      #|}
    ),
  )
  guard result is Ok(feed) else { fail("expected JSON Feed 1.0") }
  assert_eq(feed.authors[0].name, Some("Only legacy"))
  assert_eq(feed.authors[0].uri, Some("https://example.test/legacy"))
  assert_true(feed.authors[0].source is @feedlens.JsonFeed)
  assert_eq(feed.entries[0].identifier, Some("42"))
  assert_eq(feed.entries[0].title, Some("A title"))
  assert_true(feed.entries[0].title_kind is @feedlens.Text)
  assert_eq(feed.entries[0].published_at, Some("2026-10-03T00:00:00Z"))
  assert_eq(feed.entries[0].updated_at, Some("2026-10-04T00:00:00Z"))
  assert_eq(feed.entries[0].authors[0].name, Some("Only legacy"))
  assert_eq(feed.diagnostics, [])
}

///|
test "JSON Feed drops malformed items and retains item diagnostics" {
  let result = @feedlens.parse(
    (
      #|{
      #|  "version": "https://jsonfeed.org/version/1.1",
      #|  "title": "Recoverable items",
      #|  "items": [
      #|    {"id": "   ", "content_text": "ignored"},
      #|    {"id": 7, "content_text": "kept"},
      #|    {"id": {}, "content_text": "ignored"},
      #|    {"id": "no-content"},
      #|    "not an item"
      #|  ]
      #|}
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered JSON Feed") }
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].identifier, Some("7"))
  assert_eq(feed.diagnostics.length(), 4)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidJsonFeedItem(0, "id"),
  )
  assert_true(
    feed.diagnostics[1].kind is @feedlens.InvalidJsonFeedItem(2, "id"),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.InvalidJsonFeedItem(3, "content"),
  )
  assert_true(
    feed.diagnostics[3].kind is @feedlens.InvalidJsonFeedItem(4, "item"),
  )
  assert_eq((feed.diagnostics[0].line, feed.diagnostics[0].column), (1, 1))
}

///|
test "JSON Feed diagnoses optional field types, invalid authors, and tags" {
  let result = @feedlens.parse(
    (
      #|{
      #|  "version": "https://jsonfeed.org/version/1.1",
      #|  "title": "Field types",
      #|  "home_page_url": 2,
      #|  "items": [{
      #|    "id": "item",
      #|    "title": false,
      #|    "content_html": false,
      #|    "content_text": "fallback body",
      #|    "authors": [{"name": " "}],
      #|    "tags": ["", 3]
      #|  }]
      #|}
    ),
  )
  guard result is Ok(feed) else { fail("expected recovered JSON Feed") }
  assert_eq(feed.link, None)
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.entries[0].title, None)
  assert_eq(feed.entries[0].content, Some("fallback body"))
  assert_eq(feed.entries[0].authors, [])
  assert_eq(feed.entries[0].categories, [])
  assert_eq(feed.diagnostics.length(), 6)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidJsonFeedField("home_page_url"),
  )
  assert_true(
    feed.diagnostics[1].kind is @feedlens.InvalidJsonFeedItem(0, "content_html"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.InvalidAuthor("json feed author missing name or url"),
  )
  assert_true(
    feed.diagnostics[3].kind is @feedlens.InvalidJsonFeedItem(0, "title"),
  )
  assert_true(
    feed.diagnostics[4].kind
    is @feedlens.InvalidCategory("json feed tag missing term"),
  )
  assert_true(
    feed.diagnostics[5].kind is @feedlens.InvalidJsonFeedItem(0, "tags"),
  )
}

///|
test "JSON syntax, root, version, and required structural errors are fatal" {
  let invalid_json = @feedlens.parse("{\"version\":")
  assert_true(invalid_json is Err(@feedlens.InvalidJson(_, _, _)))
  let non_object = @feedlens.parse("[]")
  assert_true(
    non_object
    is Err(@feedlens.InvalidJsonFeed("JSON Feed root must be an object")),
  )
  let missing_version = @feedlens.parse("{\"title\":\"x\",\"items\":[]}")
  assert_true(
    missing_version
    is Err(@feedlens.InvalidJsonFeed("JSON Feed version is required")),
  )
  let unsupported = @feedlens.parse(
    "{\"version\":\"https://jsonfeed.org/version/2\",\"title\":\"x\",\"items\":[]}",
  )
  assert_true(
    unsupported
    is Err(
      @feedlens.UnsupportedJsonFeedVersion(
        Some("https://jsonfeed.org/version/2")
      )
    ),
  )
  let title_type = @feedlens.parse(
    "{\"version\":\"https://jsonfeed.org/version/1\",\"title\":1,\"items\":[]}",
  )
  assert_true(
    title_type
    is Err(@feedlens.InvalidJsonFeed("JSON Feed title must be a string")),
  )
  let items_type = @feedlens.parse(
    "{\"version\":\"https://jsonfeed.org/version/1\",\"title\":\"x\",\"items\":{}}",
  )
  assert_true(
    items_type
    is Err(@feedlens.InvalidJsonFeed("JSON Feed items must be an array")),
  )
}

///|
test "XML dispatch remains RSS and Atom compatible" {
  let rss = @feedlens.parse(
    "<rss version=\"2.0\"><channel><title>RSS</title><link>https://example.test/</link><description>RSS description</description></channel></rss>",
  )
  guard rss is Ok(rss_feed) else { fail("expected RSS regression feed") }
  assert_true(rss_feed.format is @feedlens.Rss2)
  let atom = @feedlens.parse(
    "<feed xmlns=\"http://www.w3.org/2005/Atom\"><id>urn:atom</id><title>Atom</title><updated>2026-10-14T00:00:00Z</updated></feed>",
  )
  guard atom is Ok(atom_feed) else { fail("expected Atom regression feed") }
  assert_true(atom_feed.format is @feedlens.Atom1)
}
