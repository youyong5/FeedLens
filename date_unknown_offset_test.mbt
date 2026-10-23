///|
fn unknown_offset_rss_sample() -> String {
  (
    #|<rss version="2.0"><channel><title>UTC with unknown local zone</title><link>https://example.test/</link><description>Legal mail-date zone</description><item><guid>urn:story:one</guid><title>One</title><pubDate>Wed, 14 Oct 2026 13:00:00 -0000</pubDate></item></channel></rss>
  )
}

///|
fn unknown_offset_atom_sample() -> String {
  (
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed:unknown-zone</id><title>UTC with unknown local zone</title><updated>2026-10-14T13:00:00-00:00</updated><author><name>Editor</name></author><entry><id>urn:story:one</id><title>One</title><updated>2026-10-14T13:00:00-00:00</updated><content>Body</content></entry></feed>
  )
}

///|
fn unknown_offset_json_sample() -> String {
  (
    #|{"version":"https://jsonfeed.org/version/1.1","title":"UTC with unknown local zone","items":[{"id":"urn:story:one","title":"One","content_text":"Body","date_published":"2026-10-14T13:00:00-00:00"}]}
  )
}

///|
test "three feed formats normalize a known UTC time without inventing local zone" {
  guard (
      @feedlens.parse(unknown_offset_rss_sample()),
      @feedlens.parse(unknown_offset_atom_sample()),
      @feedlens.parse(unknown_offset_json_sample()),
    )
    is (Ok(rss), Ok(atom), Ok(json_feed)) else {
    fail("expected three valid feeds")
  }
  assert_eq(rss.diagnostics, [])
  assert_eq(atom.diagnostics, [])
  assert_eq(json_feed.diagnostics, [])
  for
    (format, raw) in [
      (rss.format, rss.entries[0].published_at),
      (atom.format, atom.entries[0].updated_at),
      (json_feed.format, json_feed.entries[0].published_at),
    ] {
    guard @feedlens.normalize_date(format, raw) is Ok(Some(date)) else {
      fail("expected a valid known UTC time")
    }
    assert_eq(date.utc, "2026-10-14T13:00:00Z")
    assert_eq(date.offset_minutes, 0)
    assert_true(!date.offset_known)
    assert_true(date.precision is @feedlens.Second)
  }
  assert_eq(
    rss.entries[0].published_at,
    Some("Wed, 14 Oct 2026 13:00:00 -0000"),
  )
  assert_eq(atom.entries[0].updated_at, Some("2026-10-14T13:00:00-00:00"))
  assert_eq(
    json_feed.entries[0].published_at,
    Some("2026-10-14T13:00:00-00:00"),
  )
}

///|
test "known zero offsets and unknown local offsets remain distinct" {
  guard (
      @feedlens.parse(unknown_offset_rss_sample()),
      @feedlens.parse(unknown_offset_atom_sample()),
      @feedlens.parse(unknown_offset_json_sample()),
    )
    is (Ok(rss), Ok(atom), Ok(json_feed)) else {
    fail("expected feeds for date formats")
  }
  for
    (format, known, unknown) in [
      (
        rss.format,
        "Wed, 14 Oct 2026 13:00:00 +0000",
        "Wed, 14 Oct 2026 13:00:00 -0000",
      ),
      (atom.format, "2026-10-14T13:00:00Z", "2026-10-14T13:00:00-00:00"),
      (
        json_feed.format,
        "2026-10-14T13:00:00+00:00",
        "2026-10-14T13:00:00-00:00",
      ),
    ] {
    guard (
        @feedlens.normalize_date(format, Some(known)),
        @feedlens.normalize_date(format, Some(unknown)),
      )
      is (Ok(Some(a)), Ok(Some(b))) else {
      fail("expected two valid zero UTC offsets")
    }
    assert_eq(a.utc, b.utc)
    assert_eq(a.unix_seconds, b.unix_seconds)
    assert_true(a.offset_known)
    assert_true(!b.offset_known)
  }
  assert_true(
    @feedlens.normalize_date(atom.format, Some("2026-10-14T13:00:00+24:00"))
    is Err(@feedlens.InvalidOffset),
  )
}

///|
test "stand-alone Atom Entry keeps unknown local zone semantics" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-14T13:00:00-00:00</updated><author><name>Editor</name></author><content>Body</content></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry")
  }
  assert_eq(diagnostics, [])
  guard @feedlens.parse(unknown_offset_atom_sample()) is Ok(atom) else {
    fail("expected Atom feed format")
  }
  guard @feedlens.normalize_date(atom.format, entry.updated_at)
    is Ok(Some(date)) else {
    fail("expected normalized Entry updated time")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00Z")
  assert_true(!date.offset_known)
}
