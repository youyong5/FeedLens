# FeedLens — MoonBit 多格式 Feed 解析库

FeedLens is a reusable [MoonBit](https://www.moonbitlang.com/) multi-format
Feed parsing library. It extracts RSS 2.0, Atom 1.0, and JSON Feed 1.0/1.1
into one source-aware model. Diagnostics and a local-file CLI help inspect
results; the library never fetches a feed or an attachment.

## What it covers

| Format | Implemented core | Deliberate boundaries |
| --- | --- | --- |
| RSS 2.0 | Channel/item metadata, Content Module `content:encoded`, authors, categories, item enclosures | RSS versions other than 2.0; network retrieval; unsupported URI fields |
| Atom 1.0 | Feed/entry metadata, alternate/enclosure links, inline text/HTML content, author inheritance, categories | XHTML serialization, external-content retrieval, HTML-contained URLs |
| JSON Feed 1.0/1.1 | Feed/items, text/HTML body choice, authors, inherited authors, tags, attachments | Pagination, icons, avatars, extension mapping, unsupported URI fields |

The normalized model keeps summary/description separate from article content,
preserves author/category/attachment source semantics, retains document order,
and reports recoverable data-quality diagnostics with locations. Fatal malformed
or unsupported documents return `ParseError`.
Attachment URLs and metadata are parsed only; FeedLens never downloads them.
Raw publication/update dates remain available; a separate, cross-target API
validates supported RSS or RFC 3339 dates and returns comparable UTC instants.
`parse_with_source(input, source_url)` optionally resolves feed/entry links and
attachment URLs; Atom `xml:base` scopes are honored. Plain `parse(input)` keeps
raw references, and neither entry point fetches URLs.

For the complete field mapping, diagnostic rules, XML namespace boundaries, and
content-handling policy, see [README.mbt.md](README.mbt.md). This file is the
GitHub landing page; both documents describe the same supported scope.

## Library

```moonbit nocheck
match @feedlens.parse(input) {
  Ok(feed) => {
    let entry = feed.entries[0]
    println(entry.identifier.unwrap_or("(no identifier)"))
    match @feedlens.normalize_date(feed.format, entry.published_at) {
      Ok(Some(date)) => println(date.utc)
      _ => ()
    }
  }
  Err(_) => println("feed parsing failed")
}
```

When the caller knows the document's actual HTTP(S) URL, it can use
`parse_with_source(input, source_url)` to resolve article and attachment URLs,
including Atom `xml:base`; `parse(input)` continues to preserve raw references.
The library package remains portable across Wasm, JavaScript, and Native.

## Local-file CLI

The separate Native executable reads one local XML or JSON file and prints the
normalized model. It does not infer a source URL from the file path and never
fetches URLs. These checked-in files are [small, source-traceable projections](samples/REAL_WORLD.md)
of WP Tavern's real RSS, Atom, and JSON Feed subscriptions:

```powershell
moon run --target native cmd/main samples/real_wptavern_rss.xml
moon run --target native cmd/main samples/real_wptavern_atom.xml
moon run --target native cmd/main --json samples/real_wptavern_json.json
moon run --target native cmd/main -- --help
```

The first RSS episode reports `Entries: 2` and an `audio/mpeg` enclosure of
`37878054` bytes. The Atom and JSON Feed projections expose the same media URL
and byte count. Their differently formatted publication dates normalize to
`2026-10-14T13:00:00Z` through the library date API. The snapshots are offline;
the publisher's full live feeds are not bundled.

`--json` writes FeedLens's normalized inspection JSON, not a converted JSON
Feed document. Errors use stderr and a non-zero exit status; recoverable feed
diagnostics still result in success.

## Verification

```powershell
moon fmt
moon info
moon check --target wasm; moon test --target wasm
moon check --target js; moon test --target js
moon check --target native; moon test --target native
powershell -ExecutionPolicy Bypass -File tools/check_cli.ps1
uv run --with feedparser==6.0.11 python tools/check_compatibility.py
```

`samples/` contains small checked-in inputs used by the cross-target tests.
The three real-feed projections retain selected metadata but omit long bodies;
their original URLs, capture date, response hashes, and baseline findings are
recorded in [samples/REAL_WORLD.md](samples/REAL_WORLD.md). The optional Python
script also checks that the cross-target embedded mirrors match these files.
The optional Python command is an independent, local-only comparison against
feedparser 6.0.11; its defined field intersection and observed results are in
[samples/COMPATIBILITY.md](samples/COMPATIBILITY.md).

The GitHub-hosted Linux CI uses the latest official MoonBit toolchain. The
locally verified `0.1.20260920` is retained for local validation, but its
versioned Linux download returned HTTP 403 when the CI was prepared; the
workflow therefore cannot honestly pin that unavailable Linux artifact.

## License

[Apache License 2.0](LICENSE).
