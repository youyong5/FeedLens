///|
test "parse_args accepts help, normal, and JSON modes" {
  assert_true(
    @render.help_text().contains("MoonBit multi-format Feed parser library"),
  )
  assert_true(@render.parse_args(["--help"]) is Ok(@render.Help))
  assert_true(
    @render.parse_args(["sample.xml"]) is Ok(@render.Parse("sample.xml", false)),
  )
  assert_true(
    @render.parse_args(["--json", "sample.json"])
    is Ok(@render.Parse("sample.json", true)),
  )
  assert_true(@render.parse_args([]) is Err("missing input file path"))
  assert_true(
    @render.parse_args(["--json"])
    is Err("expected one input path, optionally preceded by --json"),
  )
}

///|
test "render_json preserves normalized values, nulls, and diagnostic order" {
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>Feed &amp; Notes</title><link>https://example.test/</link><description>Description</description><item><title>Anonymous</title></item></channel></rss>",
    )
    is Ok(feed) else {
    fail("expected recovered RSS feed")
  }
  let rendered = @render.render_json(feed)
  let parsed = @json.parse(rendered)
  guard parsed
    is {
      "format": String(format),
      "entries": Array(entries),
      "diagnostics": Array(diagnostics),
      ..
    } else {
    fail("expected rendered JSON object")
  }
  assert_eq(format, "rss2")
  assert_eq(entries.length(), 1)
  assert_eq(diagnostics.length(), 1)
  guard entries[0] is { "identifier": Null, "title": String(title), .. } else {
    fail("expected null identifier")
  }
  assert_eq(title, "Anonymous")
  guard diagnostics[0]
    is {
      "kind": { "type": String(kind), "index": Number(index, ..), .. },
      "line": Number(line, ..),
      "column": Number(column, ..),
      ..
    } else {
    fail("expected serialized diagnostic")
  }
  assert_eq(kind, "MissingItemIdentifier")
  assert_eq(index, 0)
  assert_eq(line, 1)
  assert_eq(column, 132)
}

///|
test "render_human lists entries and source locations" {
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>Feed</title><link>https://example.test/</link><description>Description</description><item><guid>entry</guid><title>Entry</title><link>https://example.test/entry</link></item></channel></rss>",
    )
    is Ok(feed) else {
    fail("expected RSS feed")
  }
  let rendered = @render.render_human(feed)
  assert_true(
    rendered.has_prefix("FeedLens — MoonBit multi-format Feed parser library"),
  )
  assert_true(rendered.contains("Format: RSS 2.0"))
  assert_true(rendered.contains("Language: (none)"))
  assert_true(rendered.contains("Entries: 1"))
  assert_true(rendered.contains("1. identifier: entry"))
  assert_true(rendered.contains("Diagnostics: none"))
}

///|
test "render_json escapes normalized JSON Feed strings without changing them" {
  guard @feedlens.parse(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Quoted: \\\"yes\\\"\\nnext\",\"items\":[{\"id\":\"item\",\"content_text\":\"line one\\nline two\"}]}",
    )
    is Ok(feed) else {
    fail("expected JSON Feed")
  }
  let rendered = @render.render_json(feed)
  guard @json.parse(rendered)
    is {
      "title": String(title),
      "entries": Array([{ "content": String(content), .. }]),
      ..
    } else {
    fail("expected escaped JSON output")
  }
  assert_eq(title, "Quoted: \"yes\"\nnext")
  assert_eq(content, "line one\nline two")
}

///|
test "render_json exposes declared and inherited language" {
  guard @feedlens.parse(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"T\",\"language\":\"en-US\",\"items\":[{\"id\":\"one\",\"content_text\":\"B\"},{\"id\":\"two\",\"content_text\":\"B\",\"language\":\"fr\"}]}",
    )
    is Ok(feed) else {
    fail("expected JSON Feed")
  }
  guard @json.parse(@render.render_json(feed))
    is {
      "language": String(language),
      "entries": Array(
        [{ "language": String(first), .. }, { "language": String(second), .. }]
      ),
      ..
    } else {
    fail("expected normalized language fields")
  }
  assert_eq(language, "en-US")
  assert_eq(first, "en-US")
  assert_eq(second, "fr")
}

///|
test "render_json includes ordered attachment metadata and nulls" {
  guard @feedlens.parse(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"Media\",\"items\":[{\"id\":\"item\",\"content_text\":\"Body\",\"attachments\":[{\"url\":\"https://example.test/one.mp3\",\"mime_type\":\"audio/mpeg\",\"title\":\"Quoted \\\"episode\\\"\",\"size_in_bytes\":9007199254740991,\"duration_in_seconds\":12.5},{\"url\":\"https://example.test/two.mp3\",\"mime_type\":\"audio/mpeg\"}]}]}",
    )
    is Ok(feed) else {
    fail("expected JSON Feed")
  }
  guard @json.parse(@render.render_json(feed))
    is { "entries": Array([{ "attachments": Array(attachments), .. }]), .. } else {
    fail("expected attachment array")
  }
  assert_eq(attachments.length(), 2)
  guard attachments[0]
    is {
      "source": String(source),
      "url": String(url),
      "media_type": String(media_type),
      "title": String(title),
      "size_in_bytes": Number(size, ..),
      "duration_in_seconds": Number(duration, ..),
      ..
    } else {
    fail("expected first attachment metadata")
  }
  assert_eq(source, "jsonfeed1")
  assert_eq(url, "https://example.test/one.mp3")
  assert_eq(media_type, "audio/mpeg")
  assert_eq(title, "Quoted \"episode\"")
  assert_eq(size, 9007199254740991.0)
  assert_eq(duration, 12.5)
  guard attachments[1]
    is {
      "url": String(second_url),
      "title": Null,
      "size_in_bytes": Null,
      "duration_in_seconds": Null,
      ..
    } else {
    fail("expected null optional metadata")
  }
  assert_eq(second_url, "https://example.test/two.mp3")
}

///|
test "render_human lists attachment URLs in order" {
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>Media</title><link>https://example.test/</link><description>Feed</description><item><guid>one</guid><enclosure url=\"https://example.test/one.mp3\" length=\"12\" type=\"audio/mpeg\"/><enclosure url=\"https://example.test/two.mp3\" length=\"24\" type=\"audio/mpeg\"/></item></channel></rss>",
    )
    is Ok(feed) else {
    fail("expected RSS feed")
  }
  let rendered = @render.render_human(feed)
  assert_true(rendered.contains("attachments: 2"))
  assert_true(
    rendered.contains(
      "url: https://example.test/one.mp3; media type: audio/mpeg; size (bytes): 12",
    ),
  )
  assert_true(
    rendered.contains(
      "url: https://example.test/two.mp3; media type: audio/mpeg; size (bytes): 24",
    ),
  )
}
