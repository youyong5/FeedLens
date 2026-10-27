///|
test "Atom MIME parameters classify bodies without losing original type" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:fixture:f</id><title>F</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>urn:fixture:text</id><title>Text</title><updated>2026-10-23T00:00:00Z</updated><content type="TEXT/PLAIN; charset=&quot;UTF-8&quot;; note=&quot;a;b\&quot;c&quot;">A &amp; B</content></entry>
    #|<entry><id>urn:fixture:xml</id><title>XML</title><updated>2026-10-23T00:00:00Z</updated><content type="Application/Thing+XML; charset=utf-8"><root xmlns="urn:payload">ok</root></content></entry>
    #|<entry><id>urn:fixture:binary</id><title>Binary</title><updated>2026-10-23T00:00:00Z</updated><summary>Binary file</summary><content type="IMAGE/PNG; name=&quot;pic;a.png&quot;">AQID/w==</content></entry>
    #|<entry><id>urn:fixture:external</id><title>External</title><updated>2026-10-23T00:00:00Z</updated><summary>Remote</summary><content src="media/pic.png" type="image/png; name=&quot;pic;a.png&quot;"/></entry>
    #|</feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries.length(), 4)
  assert_true(
    feed.entries[0].atom_body
    is Some(
      @feedlens.InlineText(
        "A & B",
        "TEXT/PLAIN; charset=\"UTF-8\"; note=\"a;b\\\"c\""
      )
    ),
  )
  assert_true(feed.entries[1].atom_body is Some(@feedlens.InlineXml(_, _)))
  assert_true(feed.entries[2].atom_body is Some(@feedlens.InlineBinary(_, _)))
  assert_eq(
    feed.entries[2].content_media_type,
    Some("IMAGE/PNG; name=\"pic;a.png\""),
  )
  assert_true(feed.entries[3].atom_body is Some(@feedlens.External(_)))
  assert_eq(feed.diagnostics, [])
}

///|
test "invalid Atom MIME parameters diagnose without swallowing other entries" {
  let xml =
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:fixture:f</id><title>F</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>urn:fixture:missing</id><title>Missing</title><updated>2026-10-23T00:00:00Z</updated><content type="text/plain; charset">bad</content></entry>
    #|<entry><id>urn:fixture:trailing</id><title>Trailing</title><updated>2026-10-23T00:00:00Z</updated><content type="image/png; name=x;">AQID</content></entry>
    #|<entry><id>urn:fixture:quote</id><title>Quote</title><updated>2026-10-23T00:00:00Z</updated><content type="application/xml; charset=&quot;UTF-8">bad</content></entry>
    #|<entry><id>urn:fixture:external</id><title>External</title><updated>2026-10-23T00:00:00Z</updated><summary>Remote</summary><content src="asset" type="image/png; name="/></entry>
    #|<entry><id>urn:fixture:good</id><title>Good</title><updated>2026-10-23T00:00:00Z</updated><content type="text/plain; charset=UTF-8">good</content></entry>
    #|</feed>
  guard @feedlens.parse(xml) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.entries.length(), 5)
  for index in 0..<4 {
    assert_eq(feed.entries[index].atom_body, None)
  }
  assert_true(
    feed.entries[4].atom_body
    is Some(@feedlens.InlineText("good", "text/plain; charset=UTF-8")),
  )
  assert_eq(feed.diagnostics.length(), 4)
  for index in 0..<3 {
    assert_true(
      feed.diagnostics[index].kind
      is @feedlens.UnsupportedAtomContent("invalid Atom content media type"),
    )
    assert_eq(feed.diagnostics[index].line, index + 2)
  }
  assert_true(
    feed.diagnostics[3].kind
    is @feedlens.UnsupportedAtomContent("invalid external Atom media type"),
  )
  assert_eq(feed.diagnostics[3].line, 5)
}

///|
test "independent Atom Entry uses the same parameterized content dispatch" {
  let xml =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:one</id><title>One</title><updated>2026-10-23T00:00:00Z</updated><author><name>N</name></author><summary>S</summary><content type="image/png; name=&quot;a;b.png&quot;">AQID/w==</content></entry>
  guard @feedlens.parse_document(xml)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected Atom Entry Document")
  }
  assert_true(
    entry.atom_body
    is Some(@feedlens.InlineBinary(_, "image/png; name=\"a;b.png\"")),
  )
  assert_eq(diagnostics, [])
}
