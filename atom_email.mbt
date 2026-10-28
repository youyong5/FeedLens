///|
// A conservative RFC 2822 addr-spec boundary. Quoted local parts, comments
// and domain literals can contain punctuation including '@'. Do not claim to
// recognize every obsolete/CFWS form; only diagnose unmistakable failures.
fn atom_email_syntax(raw : String) -> Bool {
  let chars = raw.to_array()
  let mut at_seen = false
  let mut segment = false
  let mut quote = false
  let mut bracket = false
  let mut comment_depth = 0
  let mut escape = false
  for c in chars {
    if escape {
      escape = false
      continue
    }
    if (quote || bracket || comment_depth > 0) && c == '\\' {
      escape = true
      continue
    }
    if comment_depth > 0 {
      if c == '(' {
        comment_depth = comment_depth + 1
      } else if c == ')' {
        comment_depth = comment_depth - 1
      }
      continue
    }
    if quote {
      if c == '"' {
        quote = false
      }
      continue
    }
    if bracket {
      if c == ']' {
        bracket = false
      }
      continue
    }
    if c == '(' {
      comment_depth = 1
    } else if c == '"' {
      if at_seen {
        return false
      }
      quote = true
      segment = true
    } else if c == '[' {
      if !at_seen {
        return false
      }
      bracket = true
      segment = true
    } else if c == '@' {
      if at_seen || !segment {
        return false
      }
      at_seen = true
      segment = false
    } else if c == '.' {
      if !segment {
        return false
      }
      segment = false
    } else if atom_email_atext(c) {
      segment = true
    } else if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      () // CFWS around a component is permitted; other forms remain opaque.
    } else {
      return false
    }
  }
  at_seen && segment && !quote && !bracket && comment_depth == 0 && !escape
}

///|
fn atom_email_atext(c : Char) -> Bool {
  let code = c.to_int()
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  (
    code >= 33 &&
    code <= 126 &&
    c != '(' &&
    c != ')' &&
    c != '<' &&
    c != '>' &&
    c != '[' &&
    c != ']' &&
    c != ':' &&
    c != ';' &&
    c != '@' &&
    c != '\\' &&
    c != ',' &&
    c != '.' &&
    c != '"'
  )
}
