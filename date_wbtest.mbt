///|
test "three real WP Tavern publication dates identify one UTC instant" {
  let rss = normalize_date(Rss2, Some("Wed, 14 Oct 2026 13:00:00 +0000"))
  let atom = normalize_date(Atom1, Some("2026-10-14T13:00:00Z"))
  let json = normalize_date(JsonFeed1, Some("2026-10-14T14:00:00+01:00"))
  guard (rss, atom, json) is (Ok(Some(rss)), Ok(Some(atom)), Ok(Some(json))) else {
    fail("expected three valid dates")
  }
  assert_eq(rss.utc, "2026-10-14T13:00:00Z")
  assert_eq(atom.utc, rss.utc)
  assert_eq(json.utc, rss.utc)
  assert_eq(atom.unix_seconds, rss.unix_seconds)
  assert_eq(json.unix_seconds, rss.unix_seconds)
  assert_eq(rss.offset_minutes, 0)
  assert_eq(json.offset_minutes, 60)
  assert_true(rss.precision is Second)
}

///|
test "RSS date accepts weekday, GMT, named US zone, and minute precision" {
  guard normalize_date(Rss2, Some("Wed, 14 Oct 2026 13:00 GMT"))
    is Ok(Some(minute_date)) else {
    fail("expected minute-precision RSS date")
  }
  assert_eq(minute_date.utc, "2026-10-14T13:00:00Z")
  assert_true(minute_date.precision is Minute)
  guard normalize_date(Rss2, Some("14 Oct 2026 09:00:00 EDT"))
    is Ok(Some(named)) else {
    fail("expected EDT RSS date")
  }
  assert_eq(named.utc, "2026-10-14T13:00:00Z")
  assert_eq(named.offset_minutes, -240)
}

///|
test "RSS two-digit year boundaries use fixed RFC 2822 centuries" {
  for
    (source, expected) in [
      ("01 Jan 00 00:00:00 GMT", "2000-01-01T00:00:00Z"),
      ("01 Jan 49 00:00:00 GMT", "2049-01-01T00:00:00Z"),
      ("01 Jan 50 00:00:00 GMT", "1950-01-01T00:00:00Z"),
      ("01 Jan 99 00:00:00 GMT", "1999-01-01T00:00:00Z"),
      ("01 Jan 2049 00:00:00 GMT", "2049-01-01T00:00:00Z"),
    ] {
    guard normalize_date(Rss2, Some(source)) is Ok(Some(date)) else {
      fail("expected supported RSS year")
    }
    assert_eq(date.utc, expected)
  }
  assert_true(
    normalize_date(Rss2, Some("01 Jan 049 00:00:00 GMT")) is Err(InvalidSyntax),
  )
  assert_true(
    normalize_date(Rss2, Some("Tue, 01 Jan 00 00:00:00 GMT"))
    is Err(InvalidCalendarDate),
  )
}

///|
test "RSS date rejects impossible day, weekday mismatch, unknown zone, and missing date" {
  assert_true(
    normalize_date(Rss2, Some("Mon, 31 Feb 2026 13:00 GMT"))
    is Err(InvalidCalendarDate),
  )
  assert_true(
    normalize_date(Rss2, Some("Tue, 14 Oct 2026 13:00 GMT"))
    is Err(InvalidCalendarDate),
  )
  assert_true(
    normalize_date(Rss2, Some("14 Oct 2026 13:00 XYZ"))
    is Err(UnsupportedTimeZone),
  )
  assert_true(
    normalize_date(Rss2, Some("14 Oct 2026 13:00 -0000"))
    is Err(UnsupportedTimeZone),
  )
  assert_true(normalize_date(Rss2, None) is Ok(None))
}

///|
test "RFC 3339 offset and nanosecond precision are preserved across midnight" {
  guard normalize_date(Atom1, Some("2024-02-29T00:30:01.123456789+01:30"))
    is Ok(Some(date)) else {
    fail("expected fractional Atom date")
  }
  assert_eq(date.utc, "2024-02-28T23:00:01.123456789Z")
  assert_eq(date.nanosecond, 123456789)
  assert_eq(date.offset_minutes, 90)
  assert_true(date.precision is Fraction(9))
  guard normalize_date(JsonFeed1, Some("2024-02-28T19:00:01.123456789-04:00"))
    is Ok(Some(other)) else {
    fail("expected fractional JSON Feed date")
  }
  assert_eq(other.unix_seconds, date.unix_seconds)
  assert_eq(other.nanosecond, date.nanosecond)
}

///|
test "RFC 3339 invalid calendar, missing offset and unknown offset fail" {
  assert_true(
    normalize_date(Atom1, Some("2026-02-29T12:00:00Z"))
    is Err(InvalidCalendarDate),
  )
  assert_true(
    normalize_date(JsonFeed1, Some("2026-10-14T12:00:00")) is Err(InvalidSyntax),
  )
  assert_true(
    normalize_date(Atom1, Some("2026-10-14T12:00:00-00:00"))
    is Err(UnsupportedTimeZone),
  )
  guard normalize_date(JsonFeed1, Some("2026-10-14T12:00:00.1234567890Z"))
    is Ok(Some(precise)) else {
    fail("expected valid RFC 3339 fraction")
  }
  assert_eq(precise.utc, "2026-10-14T12:00:00.1234567890Z")
  assert_eq(precise.nanosecond, 123456789)
  assert_true(precise.precision is Fraction(10))
  assert_true(
    normalize_date(Atom1, Some("2026-10-14T12:00:60Z"))
    is Err(InvalidCalendarDate),
  )
  assert_true(normalize_date(Atom1, None) is Ok(None))
}
