///|
test "Atom external content retains src and resolves nested xml:base only with source" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="feeds/"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry xml:base="posts/"><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>Preview</summary><content xml:base="../media/" src="body.xml?x=1#part" type="Application/Atom+XML"/></entry></feed>
  guard @feedlens.parse(xml) is Ok(raw) else { fail("expected Atom") }
  let entry = raw.entries[0]
  assert_eq(entry.content, None)
  guard entry.atom_body is Some(@feedlens.External(reference)) else {
    fail("expected external body")
  }
  assert_eq(reference.src, "body.xml?x=1#part")
  assert_eq(reference.url, "body.xml?x=1#part")
  assert_eq(reference.media_type, Some("Application/Atom+XML"))
  assert_eq(reference.base_uri, None)
  assert_eq(raw.diagnostics, [])
  guard @feedlens.parse_with_source(xml, "https://example.test/root/main.atom")
    is Ok(resolved) else {
    fail("expected resolved Atom")
  }
  guard resolved.entries[0].atom_body is Some(@feedlens.External(out)) else {
    fail("expected resolved external body")
  }
  assert_eq(out.src, "body.xml?x=1#part")
  assert_eq(out.base_uri, Some("https://example.test/root/feeds/media/"))
  assert_eq(out.url, "https://example.test/root/feeds/media/body.xml?x=1#part")
  assert_eq(resolved.diagnostics, [])
}

///|
test "Atom external content rejects nonempty body and special non-MIME type" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content src="a"> </content></entry>
    #|<entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content src="b"><x/></content></entry>
    #|<entry><id>c</id><title>C</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content src="c" type="html"/></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries.length(), 3)
  for entry in feed.entries {
    assert_eq(entry.atom_body, None)
  }
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("external Atom content must be empty"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnsupportedAtomContent("external Atom content must be empty"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.UnsupportedAtomContent("invalid external Atom media type"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[1].line, 3)
  assert_eq(feed.diagnostics[2].line, 4)
}

///|
test "Atom text MIME types preserve spelling and do not claim Atom html" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><content type="TEXT/HTML"> &lt;b&gt;A&amp;B&lt;/b&gt; </content></entry>
    #|<entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><content type="text/markdown"><![CDATA[**bold**]]></content></entry>
    #|<entry><id>c</id><title>C</title><updated>2026-10-21T00:00:00Z</updated><content type="html">&lt;b&gt;HTML&lt;/b&gt;</content></entry>
    #|<entry><id>d</id><title>D</title><updated>2026-10-21T00:00:00Z</updated><content type="text/plain"/></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].content, Some(" <b>A&B</b> "))
  assert_true(feed.entries[0].content_kind is @feedlens.Text)
  assert_true(
    feed.entries[0].atom_body
    is Some(@feedlens.InlineText(" <b>A&B</b> ", "TEXT/HTML")),
  )
  assert_eq(feed.entries[1].content, Some("**bold**"))
  assert_true(
    feed.entries[1].atom_body
    is Some(@feedlens.InlineText("**bold**", "text/markdown")),
  )
  assert_true(feed.entries[2].content_kind is @feedlens.Html)
  assert_true(
    feed.entries[2].atom_body is Some(@feedlens.InlineHtml("<b>HTML</b>")),
  )
  assert_true(
    feed.entries[3].atom_body is Some(@feedlens.InlineText("", "text/plain")),
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom XML MIME body preserves namespace, attributes, mixed order and no div stripping" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:q="urn:payload" xml:lang="en" xml:base="https://example.test/"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><content type="Application/Thing+XML" xml:lang="fr" xml:base="parts/">before <q:div q:key="A&amp;B">one<q:b/>two</q:div> after</content></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  let entry = feed.entries[0]
  assert_eq(entry.content, None)
  guard entry.atom_body is Some(@feedlens.InlineXml(fragment, media_type)) else {
    fail("expected XML body")
  }
  assert_eq(media_type, "Application/Thing+XML")
  assert_eq(fragment.language, Some("fr"))
  assert_eq(fragment.base_references, ["https://example.test/", "parts/"])
  assert_eq(
    fragment.markup,
    "before <n0:div xmlns:h=\"http://www.w3.org/1999/xhtml\" xmlns:n0=\"urn:payload\" n0:key=\"A&amp;B\">one<n0:b xmlns:h=\"http://www.w3.org/1999/xhtml\" xmlns:n0=\"urn:payload\"/>two</n0:div> after",
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom Base64 provides exact bytes, requires summary and rejects malformed encoding" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="IMAGE/PNG"> AQID
    #|/w== </content></entry>
    #|<entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><content type="application/octet-stream">%%%bad</content></entry>
    #|<entry><id>c</id><title>C</title><updated>2026-10-21T00:00:00Z</updated><content type="application/octet-stream"/></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].content, None)
  guard feed.entries[0].atom_body
    is Some(@feedlens.InlineBinary(bytes, media_type)) else {
    fail("expected decoded binary")
  }
  assert_eq(media_type, "IMAGE/PNG")
  assert_eq(bytes.length(), 4)
  assert_eq(bytes[0].to_int(), 1)
  assert_eq(bytes[1].to_int(), 2)
  assert_eq(bytes[2].to_int(), 3)
  assert_eq(bytes[3].to_int(), 255)
  assert_eq(feed.entries[1].atom_body, None)
  assert_true(
    feed.entries[2].atom_body
    is Some(@feedlens.InlineBinary(_, "application/octet-stream")),
  )
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("invalid Atom Base64 content"),
  )
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingSummaryForBinaryContent(1),
  )
  assert_true(
    feed.diagnostics[2].kind is @feedlens.MissingSummaryForBinaryContent(2),
  )
  assert_eq(feed.diagnostics[0].line, 4)
}

///|
test "Atom Base64 rejects interior spaces, missing padding, and nested XML" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="application/octet-stream">AQ ID</content></entry>
    #|<entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="application/octet-stream">AQI</content></entry>
    #|<entry><id>c</id><title>C</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="application/octet-stream"><b>AQID</b></content></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  for entry in feed.entries {
    assert_eq(entry.atom_body, None)
  }
  assert_eq(feed.diagnostics.length(), 3)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("invalid Atom Base64 content"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnsupportedAtomContent("invalid Atom Base64 content"),
  )
  assert_true(
    feed.diagnostics[2].kind
    is @feedlens.UnsupportedAtomContent("Atom content with nested markup"),
  )
}

///|
test "Atom content requires correct namespace and rejects composite MIME type" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:other="urn:other"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><link href="https://example.test/a"/><other:content>ignored</other:content></entry>
    #|<entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content type="multipart/mixed">AA==</content></entry>
    #|<entry><id>c</id><title>C</title><updated>2026-10-21T00:00:00Z</updated><content other:src="not-an-external-reference">inline</content></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].atom_body, None)
  assert_eq(feed.entries[1].atom_body, None)
  assert_true(
    feed.entries[2].atom_body
    is Some(@feedlens.InlineText("inline", "text/plain")),
  )
  assert_eq(feed.diagnostics.length(), 1)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("invalid Atom content media type"),
  )
  assert_eq(feed.diagnostics[0].line, 3)
}

///|
test "Atom external body keeps raw src and reports unresolved scoped base" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry xml:base="http:///bad"><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content src="body.xml" type="application/xml"/></entry></feed>
  guard @feedlens.parse_with_source(xml, "https://example.test/feed.atom")
    is Ok(feed) else {
    fail("expected recoverable URI diagnostics")
  }
  assert_eq(feed.entries[0].content_source, Some("body.xml"))
  guard feed.entries[0].atom_body is Some(@feedlens.External(reference)) else {
    fail("expected raw external body")
  }
  assert_eq(reference.src, "body.xml")
  assert_eq(reference.url, "body.xml")
  assert_eq(reference.base_uri, None)
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.UnresolvedUri("atom xml:base"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnresolvedUri("atom entry 0 content src"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[1].line, 2)
}

///|
test "Atom XML media keeps comments, processing instructions and several roots" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:p="urn:p"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><content type="text/xml"><p:a/>mid<!--note--><?step go?><p:b/></content></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  guard feed.entries[0].atom_body
    is Some(@feedlens.InlineXml(fragment, "text/xml")) else {
    fail("expected XML body")
  }
  assert_true(fragment.markup.contains("<n0:a"))
  assert_true(fragment.markup.contains("/>mid<!--note--><?step go?><n0:b"))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom blank external src and nested MIME text get positioned diagnostics" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>a</id><title>A</title><updated>2026-10-21T00:00:00Z</updated><summary>S</summary><content src=" " type="application/xml"/></entry>
    #|<entry><id>b</id><title>B</title><updated>2026-10-21T00:00:00Z</updated><content type="text/markdown">one<b>two</b></content></entry></feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries[0].atom_body, None)
  assert_eq(feed.entries[1].atom_body, None)
  assert_eq(feed.entries[1].content, None)
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind
    is @feedlens.UnsupportedAtomContent("empty external Atom src"),
  )
  assert_true(
    feed.diagnostics[1].kind
    is @feedlens.UnsupportedAtomContent("Atom content with nested markup"),
  )
  assert_eq(feed.diagnostics[0].line, 2)
  assert_eq(feed.diagnostics[1].line, 3)
}

///|
test "malformed inline XML is a fatal XML error" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>f</id><title>F</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><content type="application/xml"><a></content></entry></feed>
  assert_true(@feedlens.parse(xml) is Err(@feedlens.InvalidXml(_, _, _)))
}
