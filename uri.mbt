///|
priv struct UriParts {
  scheme : String?
  authority : String?
  path : String
  query : String?
  fragment : String?
}

///|
fn uri_hex(character : Char) -> Bool {
  (character >= '0' && character <= '9') ||
  (character >= 'a' && character <= 'f') ||
  (character >= 'A' && character <= 'F')
}

///|
fn uri_scheme_char(character : Char, first : Bool) -> Bool {
  (character >= 'a' && character <= 'z') ||
  (character >= 'A' && character <= 'Z') ||
  (
    !first &&
    (
      (character >= '0' && character <= '9') ||
      character == '+' ||
      character == '-' ||
      character == '.'
    )
  )
}

///|
/// RFC 3986 pchar with RFC 3987's ucschar extension.
/// Percent escapes are checked separately while scanning the full input.
fn uri_path_character(c : Char) -> Bool {
  uri_reg_name_char(c) || c == ':' || c == '@' || c == '/'
}

///|
fn uri_query_character(c : Char) -> Bool {
  uri_path_character(c) || c == '?' || uri_iprivate(c.to_int())
}

///|
fn uri_fragment_character(c : Char) -> Bool {
  uri_path_character(c) || c == '?'
}

///|
fn uri_parts(text : String) -> UriParts? {
  let chars = date_chars(text)
  for index = 0; index < chars.length(); index = index + 1 {
    let character = chars[index]
    if character.to_int() <= 32 ||
      character == '<' ||
      character == '>' ||
      character == '"' ||
      character == '\\' {
      return None
    }
    if character == '%' &&
      (
        index + 2 >= chars.length() ||
        !uri_hex(chars[index + 1]) ||
        !uri_hex(chars[index + 2])
      ) {
      return None
    }
  }
  let mut fragment_start = chars.length()
  for index = 0; index < chars.length(); index = index + 1 {
    if chars[index] == '#' {
      fragment_start = index
      break
    }
  }
  let fragment = if fragment_start < chars.length() {
    Some(date_slice(chars, fragment_start + 1, chars.length()))
  } else {
    None
  }
  let mut query_start = fragment_start
  for index = 0; index < fragment_start; index = index + 1 {
    if chars[index] == '?' {
      query_start = index
      break
    }
  }
  let query = if query_start < fragment_start {
    Some(date_slice(chars, query_start + 1, fragment_start))
  } else {
    None
  }
  let end = query_start
  let mut start = 0
  let mut scheme : String? = None
  for index = 0; index < end; index = index + 1 {
    if chars[index] == '/' {
      break
    }
    if chars[index] == ':' {
      if index == 0 {
        return None
      }
      for scheme_index = 0
          scheme_index < index
          scheme_index = scheme_index + 1 {
        if !uri_scheme_char(chars[scheme_index], scheme_index == 0) {
          return None
        }
      }
      scheme = Some(date_slice(chars, 0, index))
      start = index + 1
      break
    }
  }
  let mut authority : String? = None
  if start + 1 < end && chars[start] == '/' && chars[start + 1] == '/' {
    let authority_start = start + 2
    start = authority_start
    while start < end && chars[start] != '/' {
      start = start + 1
    }
    authority = Some(date_slice(chars, authority_start, start))
  }
  let path = date_slice(chars, start, end)
  for c in date_chars(path) {
    if !uri_path_character(c) {
      return None
    }
  }
  match query {
    Some(value) =>
      for c in date_chars(value) {
        if !uri_query_character(c) {
          return None
        }
      }
    None => ()
  }
  match fragment {
    Some(value) =>
      for c in date_chars(value) {
        if !uri_fragment_character(c) {
          return None
        }
      }
    None => ()
  }
  Some({ scheme, authority, path, query, fragment, })
}

///|
fn uri_build(parts : UriParts) -> String {
  let builder = StringBuilder()
  match parts.scheme {
    Some(scheme) => {
      builder.write_string(scheme)
      builder.write_string(":")
    }
    None => ()
  }
  match parts.authority {
    Some(authority) => {
      builder.write_string("//")
      builder.write_string(authority)
    }
    None => ()
  }
  builder.write_string(parts.path)
  match parts.query {
    Some(query) => {
      builder.write_string("?")
      builder.write_string(query)
    }
    None => ()
  }
  match parts.fragment {
    Some(fragment) => {
      builder.write_string("#")
      builder.write_string(fragment)
    }
    None => ()
  }
  builder.to_string()
}

///|
fn uri_drop(text : String, count : Int32) -> String {
  let chars = date_chars(text)
  date_slice(chars, count, chars.length())
}

///|
fn uri_remove_last_segment(text : String) -> String {
  let chars = date_chars(text)
  for index = chars.length() - 1; index >= 0; index = index - 1 {
    if chars[index] == '/' {
      return date_slice(chars, 0, index)
    }
  }
  ""
}

///|
/// RFC 3986 section 5.2.4, retaining empty path segments rather than
/// collapsing repeated slashes.
fn uri_remove_dot_segments(path : String) -> String {
  let mut input = path
  let mut output = ""
  while !input.is_empty() {
    if input.has_prefix("../") {
      input = uri_drop(input, 3)
    } else if input.has_prefix("./") {
      input = uri_drop(input, 2)
    } else if input.has_prefix("/./") {
      input = uri_drop(input, 2)
    } else if input == "/." {
      input = "/"
    } else if input.has_prefix("/../") {
      input = uri_drop(input, 3)
      output = uri_remove_last_segment(output)
    } else if input == "/.." {
      input = "/"
      output = uri_remove_last_segment(output)
    } else if input == "." || input == ".." {
      input = ""
    } else {
      let chars = date_chars(input)
      let mut stop = 0
      if chars[0] == '/' {
        stop = 1
      }
      while stop < chars.length() && chars[stop] != '/' {
        stop = stop + 1
      }
      output = output + date_slice(chars, 0, stop)
      input = date_slice(chars, stop, chars.length())
    }
  }
  output
}

///|
fn uri_merge(base : UriParts, path : String) -> String {
  if base.authority is Some(_) && base.path.is_empty() {
    return "/" + path
  }
  let chars = date_chars(base.path)
  for index = chars.length() - 1; index >= 0; index = index - 1 {
    if chars[index] == '/' {
      return date_slice(chars, 0, index + 1) + path
    }
  }
  path
}

///|
fn uri_ipv4_address_valid(text : String) -> Bool {
  let chars = date_chars(text)
  let mut index = 0
  for group = 0; group < 4; group = group + 1 {
    let start = index
    let mut value = 0
    while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
      value = value * 10 + (chars[index].to_int() - 48)
      index = index + 1
      if index - start > 3 || value > 255 {
        return false
      }
    }
    if index == start || (index - start > 1 && chars[start] == '0') {
      return false
    }
    if group < 3 {
      if index >= chars.length() || chars[index] != '.' {
        return false
      }
      index = index + 1
    }
  }
  index == chars.length()
}

///|
/// Count 16-bit groups in one side of an IPv6 address. An IPv4 tail is
/// permitted only at the very end of the entire address and consumes two.
fn uri_ipv6_groups(part : String, allow_ipv4 : Bool) -> Int32? {
  let chars = date_chars(part)
  if chars.is_empty() {
    return Some(0)
  }
  let mut index = 0
  let mut groups = 0
  while index < chars.length() {
    let start = index
    while index < chars.length() && chars[index] != ':' {
      index = index + 1
    }
    if index == start {
      return None
    }
    let value = date_slice(chars, start, index)
    if value.contains(".") {
      if !allow_ipv4 ||
        index != chars.length() ||
        !uri_ipv4_address_valid(value) {
        return None
      }
      groups = groups + 2
    } else {
      if index - start > 4 {
        return None
      }
      for position = start; position < index; position = position + 1 {
        if !uri_hex(chars[position]) {
          return None
        }
      }
      groups = groups + 1
    }
    if index < chars.length() {
      index = index + 1
      if index == chars.length() {
        return None
      }
    }
  }
  Some(groups)
}

///|
fn uri_ipv6_valid(text : String) -> Bool {
  let chars = date_chars(text)
  let mut compressed_at = -1
  for index = 0; index + 1 < chars.length(); index = index + 1 {
    if chars[index] == ':' && chars[index + 1] == ':' {
      if compressed_at >= 0 {
        return false
      }
      compressed_at = index
    }
  }
  if compressed_at < 0 {
    return uri_ipv6_groups(text, true) == Some(8)
  }
  let left = date_slice(chars, 0, compressed_at)
  let right = date_slice(chars, compressed_at + 2, chars.length())
  match (uri_ipv6_groups(left, false), uri_ipv6_groups(right, true)) {
    (Some(left_count), Some(right_count)) => left_count + right_count < 8
    _ => false
  }
}

///|
fn uri_ipvfuture_valid(text : String) -> Bool {
  let chars = date_chars(text)
  if chars.length() < 4 || (chars[0] != 'v' && chars[0] != 'V') {
    return false
  }
  let mut index = 1
  while index < chars.length() && uri_hex(chars[index]) {
    index = index + 1
  }
  if index == 1 || index + 1 >= chars.length() || chars[index] != '.' {
    return false
  }
  for position = index + 1; position < chars.length(); position = position + 1 {
    let c = chars[position]
    let ascii = (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9')
    let permitted = "-._~!$&'()*+,;=:"
    if !ascii && !permitted.contains(c.to_string()) {
      return false
    }
  }
  true
}

///|
fn uri_ip_literal_valid(text : String) -> Bool {
  let chars = date_chars(text)
  if !chars.is_empty() && (chars[0] == 'v' || chars[0] == 'V') {
    uri_ipvfuture_valid(text)
  } else {
    uri_ipv6_valid(text)
  }
}

///|
fn uri_http_authority_valid(authority : String) -> Bool {
  let chars = date_chars(authority)
  if chars.is_empty() {
    return false
  }
  let mut host_start = 0
  for index = 0; index < chars.length(); index = index + 1 {
    if chars[index] == '@' {
      if host_start != 0 {
        return false
      }
      for position = 0; position < index; position = position + 1 {
        if !uri_reg_name_char(chars[position]) && chars[position] != ':' {
          return false
        }
      }
      host_start = index + 1
    }
  }
  if host_start >= chars.length() {
    return false
  }
  let mut port_start = chars.length()
  if chars[host_start] == '[' {
    let mut close = host_start + 1
    while close < chars.length() && chars[close] != ']' {
      close = close + 1
    }
    if close == host_start + 1 || close == chars.length() {
      return false
    }
    if !uri_ip_literal_valid(date_slice(chars, host_start + 1, close)) {
      return false
    }
    if close + 1 < chars.length() {
      if chars[close + 1] != ':' {
        return false
      }
      port_start = close + 2
    }
  } else {
    let mut colon_seen = false
    for index = host_start; index < chars.length(); index = index + 1 {
      if chars[index] == '[' || chars[index] == ']' {
        return false
      }
      if chars[index] == ':' {
        if colon_seen || index == host_start {
          return false
        }
        colon_seen = true
        port_start = index + 1
      } else if !uri_reg_name_char(chars[index]) {
        return false
      }
    }
  }
  for index = port_start; index < chars.length(); index = index + 1 {
    if chars[index] < '0' || chars[index] > '9' {
      return false
    }
  }
  true
}

///|
/// RFC 3987 ucschar; noncharacters at the end of each plane are excluded.
fn uri_ucschar(code : Int32) -> Bool {
  if (code >= 0xA0 && code <= 0xD7FF) ||
    (code >= 0xF900 && code <= 0xFDCF) ||
    (code >= 0xFDF0 && code <= 0xFFEF) {
    return true
  }
  let plane_tail = code % 0x10000
  plane_tail <= 0xFFFD &&
  ((code >= 0x10000 && code <= 0xDFFFD) || (code >= 0xE1000 && code <= 0xEFFFD))
}

///|
/// RFC 3987 iprivate is allowed in the query alone.
fn uri_iprivate(code : Int32) -> Bool {
  (code >= 0xE000 && code <= 0xF8FF) ||
  (code >= 0xF0000 && code <= 0xFFFFD) ||
  (code >= 0x100000 && code <= 0x10FFFD)
}

///|
/// RFC 3986 reg-name ASCII syntax plus RFC 3987 iunreserved characters.
fn uri_reg_name_char(c : Char) -> Bool {
  let code = c.to_int()
  if code >= 128 {
    return uri_ucschar(code)
  }
  match c {
    'a'..<='z'
    | 'A'..<='Z'
    | '0'..<='9'
    | '-'
    | '.'
    | '_'
    | '~'
    | '%'
    | '!'
    | '$'
    | '&'
    | '\''
    | '('
    | ')'
    | '*'
    | '+'
    | ','
    | ';'
    | '=' => true
    _ => false
  }
}

///|
fn uri_valid_absolute(parts : UriParts) -> Bool {
  match parts.scheme {
    None => false
    Some(scheme) =>
      if scheme.to_lower() == "http" || scheme.to_lower() == "https" {
        match parts.authority {
          Some(authority) => uri_http_authority_valid(authority)
          // RFC 3986 allows a rootless absolute URI such as "http:g" as a
          // reference. Document source URLs are checked separately and must
          // still have a valid HTTP(S) authority.
          None => !parts.path.is_empty() && !parts.path.has_prefix("/")
        }
      } else {
        true
      }
  }
}

///|
fn uri_resolve(base : String, reference : String) -> String? {
  guard uri_parts(base) is Some(base_parts) else { return None }
  if !uri_valid_absolute(base_parts) {
    return None
  }
  guard uri_parts(reference) is Some(ref_parts) else { return None }
  if ref_parts.scheme is Some(_) {
    if !uri_valid_absolute(ref_parts) {
      return None
    }
    return Some(
      uri_build({
        scheme: ref_parts.scheme,
        authority: ref_parts.authority,
        path: uri_remove_dot_segments(ref_parts.path),
        query: ref_parts.query,
        fragment: ref_parts.fragment,
      }),
    )
  }
  if ref_parts.authority is Some(_) {
    let target = {
      scheme: base_parts.scheme,
      authority: ref_parts.authority,
      path: uri_remove_dot_segments(ref_parts.path),
      query: ref_parts.query,
      fragment: ref_parts.fragment,
    }
    return if uri_valid_absolute(target) {
      Some(uri_build(target))
    } else {
      None
    }
  }
  if ref_parts.path.is_empty() {
    return Some(
      uri_build({
        scheme: base_parts.scheme,
        authority: base_parts.authority,
        path: base_parts.path,
        query: match ref_parts.query {
          Some(_) => ref_parts.query
          None => base_parts.query
        },
        fragment: ref_parts.fragment,
      }),
    )
  }
  let path = if ref_parts.path.has_prefix("/") {
    uri_remove_dot_segments(ref_parts.path)
  } else {
    uri_remove_dot_segments(uri_merge(base_parts, ref_parts.path))
  }
  Some(
    uri_build({
      scheme: base_parts.scheme,
      authority: base_parts.authority,
      path,
      query: ref_parts.query,
      fragment: ref_parts.fragment,
    }),
  )
}
