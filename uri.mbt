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
fn uri_valid_absolute(parts : UriParts) -> Bool {
  match parts.scheme {
    None => false
    Some(scheme) =>
      if scheme.to_lower() == "http" || scheme.to_lower() == "https" {
        match parts.authority {
          Some(authority) => uri_http_authority_valid(authority)
          None => false
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
