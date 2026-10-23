///|
/// The precision actually declared by a source date. UTC rendering always
/// includes seconds, but this marker distinguishes an RSS minute-only value.
/// `Fraction(digits)` retains the full count beyond nanosecond precision.
pub enum DatePrecision {
  Minute
  Second
  Fraction(Int32)
} derive(Debug, Eq)

///|
/// A validated instant. `utc` preserves declared fractional-second digits;
/// `unix_seconds` and `nanosecond` expose seconds and nanoseconds without
/// local time zones. `utc` retains any finer digits for callers that need them.
/// `nanosecond` truncates any sub-nanosecond digits; `utc` keeps them intact.
pub struct NormalizedDate {
  utc : String
  unix_seconds : Int64
  nanosecond : Int32
  offset_minutes : Int32
  precision : DatePrecision
} derive(Debug, Eq)

///|
pub enum DateError {
  InvalidSyntax
  InvalidCalendarDate
  InvalidOffset
  // Retained for API compatibility; fractional digits are now unbounded.
  UnsupportedPrecision
  UnsupportedTimeZone
  OutOfRange
} derive(Debug, Eq)

///|
pub extend DatePrecision with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DatePrecision with Eq::{not_equal, equal}

///|
pub extend NormalizedDate with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NormalizedDate with Eq::{not_equal, equal}

///|
pub extend DateError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DateError with Eq::{not_equal, equal}

///|
fn date_chars(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for character in text {
    chars.push(character)
  }
  chars
}

///|
fn date_digits(chars : Array[Char], start : Int32, count : Int32) -> Int32? {
  if start < 0 || count < 1 || start + count > chars.length() {
    return None
  }
  let mut value = 0
  for index = start; index < start + count; index = index + 1 {
    let digit = chars[index].to_int() - 48
    if digit < 0 || digit > 9 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
fn date_literal(chars : Array[Char], index : Int32, expected : Char) -> Bool {
  index < chars.length() && chars[index] == expected
}

///|
fn date_slice(chars : Array[Char], start : Int32, stop : Int32) -> String {
  let builder = StringBuilder()
  for index = start; index < stop; index = index + 1 {
    builder.write_char(chars[index])
  }
  builder.to_string()
}

///|
fn normalized_date(
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  nanosecond : Int32,
  fraction : String,
  offset_minutes : Int32,
  precision : DatePrecision,
  weekday : @time.Weekday?,
) -> Result[NormalizedDate, DateError] {
  if year < 1 || year > 9999 || second > 59 {
    return Err(InvalidCalendarDate)
  }
  let local_date = @time.PlainDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
  ) catch {
    _ => return Err(InvalidCalendarDate)
  }
  match weekday {
    Some(expected) if local_date.weekday() != expected =>
      return Err(InvalidCalendarDate)
    _ => ()
  }
  let unix_seconds = local_date.to_unix_second() -
    offset_minutes.to_int64() * 60L
  let utc = @time.PlainDateTime::from_unix_second(
    unix_seconds, 0, @time.utc_offset,
  ) catch {
    _ => return Err(OutOfRange)
  }
  if utc.year() < 1 || utc.year() > 9999 {
    return Err(OutOfRange)
  }
  Ok({
    utc: utc.to_string() + fraction + "Z",
    unix_seconds,
    nanosecond,
    offset_minutes,
    precision,
  })
}

///|
fn normalize_rfc3339(
  text : String,
  atom_case : Bool,
) -> Result[NormalizedDate, DateError] {
  let chars = date_chars(text)
  if chars.length() < 20 ||
    !date_literal(chars, 4, '-') ||
    !date_literal(chars, 7, '-') ||
    (chars[10] != 'T' && chars[10] != 't') ||
    (atom_case && chars[10] != 'T') ||
    !date_literal(chars, 13, ':') ||
    !date_literal(chars, 16, ':') {
    return Err(InvalidSyntax)
  }
  let year = date_digits(chars, 0, 4)
  let month = date_digits(chars, 5, 2)
  let day = date_digits(chars, 8, 2)
  let hour = date_digits(chars, 11, 2)
  let minute = date_digits(chars, 14, 2)
  let second = date_digits(chars, 17, 2)
  guard (year, month, day, hour, minute, second)
    is (
      Some(year),
      Some(month),
      Some(day),
      Some(hour),
      Some(minute),
      Some(second),
    ) else {
    return Err(InvalidSyntax)
  }
  let mut index = 19
  let mut fraction = ""
  let mut nanosecond = 0
  let mut precision = Second
  if date_literal(chars, index, '.') {
    index = index + 1
    let first = index
    while index < chars.length() {
      let digit = chars[index].to_int() - 48
      if digit < 0 || digit > 9 {
        break
      }
      if index - first < 9 {
        nanosecond = nanosecond * 10 + digit
      }
      index = index + 1
    }
    let digits = index - first
    if digits == 0 {
      return Err(InvalidSyntax)
    }
    precision = Fraction(digits)
    fraction = "." + date_slice(chars, first, index)
    let mut padding = if digits < 9 { digits } else { 9 }
    while padding < 9 {
      nanosecond = nanosecond * 10
      padding = padding + 1
    }
  }
  if index >= chars.length() {
    return Err(InvalidSyntax)
  }
  let offset_minutes = if chars[index] == 'Z' || chars[index] == 'z' {
    if atom_case && chars[index] != 'Z' {
      return Err(InvalidSyntax)
    }
    if index + 1 != chars.length() {
      return Err(InvalidSyntax)
    }
    0
  } else if chars[index] == '+' || chars[index] == '-' {
    if index + 6 != chars.length() || !date_literal(chars, index + 3, ':') {
      return Err(InvalidOffset)
    }
    guard (date_digits(chars, index + 1, 2), date_digits(chars, index + 4, 2))
      is (Some(offset_hour), Some(offset_minute)) else {
      return Err(InvalidOffset)
    }
    if offset_hour > 23 || offset_minute > 59 {
      return Err(InvalidOffset)
    }
    // RFC 3339's -00:00 says the local offset is unknown, not UTC.
    if chars[index] == '-' && offset_hour == 0 && offset_minute == 0 {
      return Err(UnsupportedTimeZone)
    }
    (offset_hour * 60 + offset_minute) *
    (if chars[index] == '-' { -1 } else { 1 })
  } else {
    return Err(InvalidOffset)
  }
  normalized_date(
    year,
    month,
    day,
    hour,
    minute,
    second,
    nanosecond,
    fraction,
    offset_minutes,
    precision,
    None,
  )
}

///|
fn rss_date_tokens(text : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut current = StringBuilder()
  for character in text {
    if character == ' ' ||
      character == '\t' ||
      character == '\r' ||
      character == '\n' {
      let token = current.to_string()
      if !token.is_empty() {
        tokens.push(token)
      }
      current = StringBuilder()
    } else {
      current.write_char(character)
    }
  }
  let token = current.to_string()
  if !token.is_empty() {
    tokens.push(token)
  }
  tokens
}

///|
fn rss_month(month : String) -> Int32? {
  match month {
    "Jan" => Some(1)
    "Feb" => Some(2)
    "Mar" => Some(3)
    "Apr" => Some(4)
    "May" => Some(5)
    "Jun" => Some(6)
    "Jul" => Some(7)
    "Aug" => Some(8)
    "Sep" => Some(9)
    "Oct" => Some(10)
    "Nov" => Some(11)
    "Dec" => Some(12)
    _ => None
  }
}

///|
fn rss_weekday(day : String) -> @time.Weekday? {
  match day {
    "Mon," => Some(@time.Monday)
    "Tue," => Some(@time.Tuesday)
    "Wed," => Some(@time.Wednesday)
    "Thu," => Some(@time.Thursday)
    "Fri," => Some(@time.Friday)
    "Sat," => Some(@time.Saturday)
    "Sun," => Some(@time.Sunday)
    _ => None
  }
}

///|
fn rss_offset(zone : String) -> Result[Int32, DateError] {
  match zone {
    "UT" | "UTC" | "GMT" => return Ok(0)
    "EST" => return Ok(-300)
    "EDT" => return Ok(-240)
    "CST" => return Ok(-360)
    "CDT" => return Ok(-300)
    "MST" => return Ok(-420)
    "MDT" => return Ok(-360)
    "PST" => return Ok(-480)
    "PDT" => return Ok(-420)
    _ => ()
  }
  let chars = date_chars(zone)
  if chars.length() != 5 || (chars[0] != '+' && chars[0] != '-') {
    return Err(UnsupportedTimeZone)
  }
  guard (date_digits(chars, 1, 2), date_digits(chars, 3, 2))
    is (Some(hour), Some(minute)) else {
    return Err(InvalidOffset)
  }
  if hour > 23 || minute > 59 {
    return Err(InvalidOffset)
  }
  // The mail-date -0000 convention likewise does not assert UTC.
  if chars[0] == '-' && hour == 0 && minute == 0 {
    return Err(UnsupportedTimeZone)
  }
  Ok((hour * 60 + minute) * (if chars[0] == '-' { -1 } else { 1 }))
}

///|
fn normalize_rss_date(text : String) -> Result[NormalizedDate, DateError] {
  let tokens = rss_date_tokens(text)
  let mut start = 0
  let mut weekday : @time.Weekday? = None
  if tokens.length() == 6 {
    weekday = rss_weekday(tokens[0])
    if weekday is None {
      return Err(InvalidSyntax)
    }
    start = 1
  } else if tokens.length() != 5 {
    return Err(InvalidSyntax)
  }
  let day_chars = date_chars(tokens[start])
  let year_chars = date_chars(tokens[start + 2])
  if day_chars.length() < 1 ||
    day_chars.length() > 2 ||
    (year_chars.length() != 2 && year_chars.length() != 4) {
    return Err(InvalidSyntax)
  }
  guard (
      date_digits(day_chars, 0, day_chars.length()),
      rss_month(tokens[start + 1]),
      date_digits(year_chars, 0, year_chars.length()),
    )
    is (Some(day), Some(month), Some(raw_year)) else {
    return Err(InvalidSyntax)
  }
  // RSS 2.0 permits two- and four-digit years. RFC 2822 supplies a stable
  // interpretation for the former without reference to the current year.
  let year = if year_chars.length() == 2 {
    raw_year + (if raw_year < 50 { 2000 } else { 1900 })
  } else {
    raw_year
  }
  let time = date_chars(tokens[start + 3])
  if (time.length() != 5 && time.length() != 8) ||
    !date_literal(time, 2, ':') ||
    (time.length() == 8 && !date_literal(time, 5, ':')) {
    return Err(InvalidSyntax)
  }
  guard (date_digits(time, 0, 2), date_digits(time, 3, 2))
    is (Some(hour), Some(minute)) else {
    return Err(InvalidSyntax)
  }
  let second = if time.length() == 8 {
    match date_digits(time, 6, 2) {
      Some(second) => second
      None => return Err(InvalidSyntax)
    }
  } else {
    0
  }
  let offset_minutes = match rss_offset(tokens[start + 4]) {
    Ok(offset) => offset
    Err(error) => return Err(error)
  }
  normalized_date(
    year,
    month,
    day,
    hour,
    minute,
    second,
    0,
    "",
    offset_minutes,
    if time.length() == 8 {
      Second
    } else {
      Minute
    },
    weekday,
  )
}

///|
/// Validate an optional source date without changing the raw feed field.
/// RSS uses the supported RFC 822/1123 profile; Atom and JSON Feed use RFC
/// 3339. Atom additionally requires uppercase `T` and `Z`. A missing date
/// is `Ok(None)`, while malformed dates are `Err`.
pub fn normalize_date(
  format : FeedFormat,
  raw : String?,
) -> Result[NormalizedDate?, DateError] {
  match raw {
    None => Ok(None)
    Some(text) => {
      let date = match format {
        Rss2 => normalize_rss_date(text)
        Atom1 => normalize_rfc3339(text, true)
        JsonFeed1 => normalize_rfc3339(text, false)
      }
      match date {
        Ok(value) => Ok(Some(value))
        Err(error) => Err(error)
      }
    }
  }
}
