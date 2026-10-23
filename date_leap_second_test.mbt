///|
fn leap_rss_sample() -> String {
  (
    #|<rss version="2.0"><channel><title>Leap second</title><link>https://example.test/</link><description>UTC leap</description><item><guid>urn:leap:2016</guid><title>One</title><pubDate>Sat, 31 Dec 2016 23:59:60 GMT</pubDate></item></channel></rss>
  )
}

///|
fn leap_atom_sample() -> String {
  (
    #|<feed xmlns="http://www.w3.org/2005/Atom"><id>urn:feed:leap</id><title>Leap second</title><updated>2017-01-01T08:59:60+09:00</updated><author><name>Editor</name></author><entry><id>urn:leap:2016</id><title>One</title><updated>2016-12-31T23:59:60Z</updated><content>Body</content></entry></feed>
  )
}

///|
fn leap_json_sample() -> String {
  (
    #|{"version":"https://jsonfeed.org/version/1.1","title":"Leap second","items":[{"id":"urn:leap:2016","title":"One","content_text":"Body","date_published":"2016-12-31T18:59:60-05:00"}]}
  )
}

///|
test "three formats normalize one announced positive leap second" {
  guard (
      @feedlens.parse(leap_rss_sample()),
      @feedlens.parse(leap_atom_sample()),
      @feedlens.parse(leap_json_sample()),
    )
    is (Ok(rss), Ok(atom), Ok(json_feed)) else {
    fail("expected three feeds")
  }
  assert_eq(rss.diagnostics, [])
  assert_eq(atom.diagnostics, [])
  assert_eq(json_feed.diagnostics, [])
  for
    (format, raw, offset) in [
      (rss.format, rss.entries[0].published_at, 0),
      (atom.format, atom.updated_at, 540),
      (json_feed.format, json_feed.entries[0].published_at, -300),
    ] {
    guard @feedlens.normalize_date(format, raw) is Ok(Some(date)) else {
      fail("expected announced leap second")
    }
    assert_eq(date.utc, "2016-12-31T23:59:60Z")
    assert_eq(date.unix_seconds, 1483228799L)
    assert_eq(date.offset_minutes, offset)
    assert_true(date.offset_known)
    assert_true(date.is_leap_second)
  }
  assert_eq(rss.entries[0].published_at, Some("Sat, 31 Dec 2016 23:59:60 GMT"))
  assert_eq(atom.updated_at, Some("2017-01-01T08:59:60+09:00"))
  assert_eq(
    json_feed.entries[0].published_at,
    Some("2016-12-31T18:59:60-05:00"),
  )
}

///|
test "all 27 announced historical positive leap seconds are accepted" {
  guard @feedlens.parse(leap_atom_sample()) is Ok(atom) else {
    fail("expected Atom feed")
  }
  let official_dates = [
    "1972-06-30", "1972-12-31", "1973-12-31", "1974-12-31", "1975-12-31", "1976-12-31",
    "1977-12-31", "1978-12-31", "1979-12-31", "1981-06-30", "1982-06-30", "1983-06-30",
    "1985-06-30", "1987-12-31", "1989-12-31", "1990-12-31", "1992-06-30", "1993-06-30",
    "1994-06-30", "1995-12-31", "1997-06-30", "1998-12-31", "2005-12-31", "2008-12-31",
    "2012-06-30", "2015-06-30", "2016-12-31",
  ]
  assert_eq(official_dates.length(), 27)
  for day in official_dates {
    let input = day + "T23:59:60Z"
    guard @feedlens.normalize_date(atom.format, Some(input)) is Ok(Some(date)) else {
      fail("expected official leap second")
    }
    assert_eq(date.utc, input)
    assert_true(date.is_leap_second)
  }
}

///|
test "leap-second fraction and unknown local offset retain their meaning" {
  guard @feedlens.parse(leap_atom_sample()) is Ok(atom) else {
    fail("expected Atom feed")
  }
  guard @feedlens.normalize_date(
      atom.format,
      Some("1990-12-31T15:59:60.123456789123-08:00"),
    )
    is Ok(Some(precise)) else {
    fail("expected offset leap second with fractional precision")
  }
  assert_eq(precise.utc, "1990-12-31T23:59:60.123456789123Z")
  assert_eq(precise.nanosecond, 123456789)
  assert_true(precise.precision is @feedlens.Fraction(12))
  assert_true(precise.is_leap_second)
  guard @feedlens.normalize_date(atom.format, Some("2016-12-31T23:59:60-00:00"))
    is Ok(Some(unknown)) else {
    fail("expected UTC leap second with unknown local zone")
  }
  assert_eq(unknown.utc, "2016-12-31T23:59:60Z")
  assert_true(!unknown.offset_known)
  assert_true(unknown.is_leap_second)
  guard @feedlens.normalize_date(atom.format, Some("2016-12-31T23:59:59Z"))
    is Ok(Some(before)) else {
    fail("expected ordinary second")
  }
  assert_eq(before.unix_seconds, unknown.unix_seconds)
  assert_true(!before.is_leap_second)
}

///|
test "unannounced or misplaced leap-second labels are invalid" {
  guard @feedlens.parse(leap_atom_sample()) is Ok(atom) else {
    fail("expected Atom feed")
  }
  for
    input in [
      "2016-12-30T23:59:60Z", "2016-12-31T23:58:60Z", "2017-01-01T23:59:60Z", "2026-12-31T23:59:60Z",
      "2016-12-31T23:59:60+01:00", "2016-12-31T23:59:61Z",
    ] {
    assert_true(
      @feedlens.normalize_date(atom.format, Some(input))
      is Err(@feedlens.InvalidCalendarDate),
    )
  }
  assert_true(
    @feedlens.normalize_date(atom.format, Some("2016-12-31T23:59:60.123+24:00"))
    is Err(@feedlens.InvalidOffset),
  )
}

///|
test "independent Atom Entry accepts announced leap second" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:leap:2016</id><title>One</title><updated>2016-12-31T23:59:60Z</updated><author><name>Editor</name></author><content>Body</content></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry")
  }
  assert_eq(diagnostics, [])
  guard @feedlens.parse(leap_atom_sample()) is Ok(atom) else {
    fail("expected Atom feed")
  }
  guard @feedlens.normalize_date(atom.format, entry.updated_at)
    is Ok(Some(date)) else {
    fail("expected valid leap second in Entry")
  }
  assert_eq(date.utc, "2016-12-31T23:59:60Z")
  assert_true(date.is_leap_second)
}
