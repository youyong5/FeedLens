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
  assert_eq(diagnostics.length(), 0)
  guard entries[0] is { "identifier": Null, "title": String(title), .. } else {
    fail("expected null identifier")
  }
  assert_eq(title, "Anonymous")
}

///|
test "render_json locates an RSS item missing both title and description" {
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>Feed</title><link>https://example.test/</link><description>News</description><item/></channel></rss>",
    )
    is Ok(feed) else {
    fail("expected recovered RSS")
  }
  guard @json.parse(@render.render_json(feed))
    is { "diagnostics": Array(diagnostics), .. } else {
    fail("expected diagnostics array")
  }
  assert_eq(diagnostics.length(), 1)
  guard diagnostics[0]
    is {
      "kind": { "type": String(kind), "index": Number(index, ..), .. },
      "line": Number(line, ..),
      "column": Number(column, ..),
      ..
    } else {
    fail("expected located diagnostic")
  }
  assert_eq(kind, "MissingItemContent")
  assert_eq(index, 0)
  assert_eq(line, 1)
  assert_true(column > 0)
}

///|
test "render_json exposes unsanitized Atom XHTML text kind and fragments" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">Plan <em>A</em></div></title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p>Body</p></div></content></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  let rendered = @render.render_json(feed)
  guard @json.parse(rendered)
    is {
      "title": String(title),
      "title_kind": String(kind),
      "title_xhtml": { "markup": String(markup), .. },
      "entries": Array(entries),
      ..
    } else {
    fail("expected XHTML JSON fields")
  }
  assert_eq(title, "Plan A")
  assert_eq(kind, "xhtml")
  assert_eq(
    markup, "Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em>",
  )
  guard entries[0]
    is {
      "content_kind": String(content_kind),
      "content_xhtml": { "markup": String(body), .. },
      ..
    } else {
    fail("expected XHTML body JSON fields")
  }
  assert_eq(content_kind, "xhtml")
  assert_eq(body, "<h:p xmlns:h=\"http://www.w3.org/1999/xhtml\">Body</h:p>")
}

///|
test "render_json exposes binary bytes as Base64 and external references without fetching" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="image/png">AQID/w==</content></entry><entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content src="/body" type="application/xml"/></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  let human = @render.render_human(feed)
  assert_true(
    human.contains("Atom content: binary; media type: image/png; bytes: 4"),
  )
  assert_true(
    human.contains(
      "Atom content: external (not fetched); src: /body; URL: /body",
    ),
  )
  let json = @render.render_json(feed)
  guard @json.parse(json) is { "entries": Array(entries), .. } else {
    fail("expected JSON entries")
  }
  guard entries[0]
    is {
      "atom_body": {
        "kind": String(binary_kind),
        "base64": String(base64),
        "byte_length": Number(size, ..),
        ..
      },
      "content": Null,
      ..
    } else {
    fail("expected binary JSON")
  }
  assert_eq(binary_kind, "inline_binary")
  assert_eq(base64, "AQID/w==")
  assert_eq(size, 4)
  guard entries[1]
    is {
      "atom_body": {
        "kind": String(external_kind),
        "src": String(src),
        "url": String(url),
        "base_uri": Null,
        ..
      },
      "content": Null,
      ..
    } else {
    fail("expected external JSON")
  }
  assert_eq(external_kind, "external")
  assert_eq(src, "/body")
  assert_eq(url, "/body")
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
test "render_json keeps feed image roles and RSS metadata" {
  guard @feedlens.parse(
      "<rss version=\"2.0\"><channel><title>T</title><link>L</link><description>D</description><image><url>https://example.test/icon.png</url><title>Badge</title><link>https://example.test</link><width>32</width></image></channel></rss>",
    )
    is Ok(feed) else {
    fail("expected RSS")
  }
  guard @json.parse(@render.render_json(feed))
    is {
      "images": Array(
        [
          {
            "role": String(role),
            "source": String(source),
            "title": String(title),
            "width": Number(width, ..),
            "height": Null,
            ..
          },
        ]
      ),
      ..
    } else {
    fail("expected RSS image metadata")
  }
  assert_eq(role, "rss_image")
  assert_eq(source, "rss2")
  assert_eq(title, "Badge")
  assert_eq(width, 32)
  assert_true(
    @render.render_human(feed).contains(
      "rss_image: https://example.test/icon.png",
    ),
  )
}

///|
test "render_json distinguishes Dublin Core creator names from RSS email" {
  let input =
    #|<rss version="2.0" xmlns:d="http://purl.org/dc/elements/1.1/"><channel><title>T</title><link>L</link><description>D</description><item><title>I</title><author>a@example.test</author><d:creator>Writer</d:creator></item></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  guard @json.parse(@render.render_json(feed))
    is { "entries": Array([{ "authors": Array(authors), .. }]), .. } else {
    fail("expected JSON authors")
  }
  guard authors[0] is { "source": String(first), "email": String(email), .. } else {
    fail("expected RSS email")
  }
  guard authors[1] is { "source": String(second), "name": String(name), .. } else {
    fail("expected Dublin Core name")
  }
  assert_eq(first, "rss2")
  assert_eq(email, "a@example.test")
  assert_eq(second, "dublin_core")
  assert_eq(name, "Writer")
}

///|
test "render_json separates JSON item permalink, external URL, images, and attachments" {
  guard @feedlens.parse(
      "{\"version\":\"https://jsonfeed.org/version/1.1\",\"title\":\"T\",\"items\":[{\"id\":\"one\",\"content_text\":\"B\",\"url\":\"https://example.test/post\",\"external_url\":\"https://outside.test/story\",\"image\":\"https://example.test/preview.png\",\"banner_image\":\"https://example.test/banner.png\"}]}",
    )
    is Ok(feed) else {
    fail("expected JSON Feed")
  }
  guard @json.parse(@render.render_json(feed))
    is {
      "entries": Array(
        [
          {
            "link": String(link),
            "external_url": String(external_url),
            "images": Array(images),
            "attachments": Array(attachments),
            ..
          },
        ]
      ),
      ..
    } else {
    fail("expected separate item display fields")
  }
  assert_eq(link, "https://example.test/post")
  assert_eq(external_url, "https://outside.test/story")
  assert_eq(images.length(), 2)
  assert_eq(attachments.length(), 0)
  guard images[0] is { "role": String(role), "url": String(url), .. } else {
    fail("expected featured image")
  }
  assert_eq(role, "json_featured")
  assert_eq(url, "https://example.test/preview.png")
  assert_true(
    @render.render_human(feed).contains(
      "external URL: https://outside.test/story",
    ),
  )
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

///|
test "render_json exposes Atom content source and declared media type" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>A</name></author><entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>Abstract</summary><content type="application/pdf" src="issue.pdf"/></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  guard @json.parse(@render.render_json(feed))
    is { "entries": Array(entries), .. } else {
    fail("expected JSON entries")
  }
  guard entries[0]
    is {
      "content_source": String(source),
      "content_media_type": String(media_type),
      "content": Null,
      ..
    } else {
    fail("expected external content fields")
  }
  assert_eq(source, "issue.pdf")
  assert_eq(media_type, "application/pdf")
}
