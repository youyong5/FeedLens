# FeedLens — MoonBit 多格式 Feed 解析库

FeedLens is a reusable [MoonBit](https://www.moonbitlang.com/) multi-format
Feed parsing library. It extracts the documented, tested subsets of RSS 2.0,
Atom 1.0, and JSON Feed 1.0/1.1 into one source-aware model; this is not a
claim of full conformance with every legal construct. Diagnostics and a local-file CLI help inspect
results; the library never fetches a feed or an attachment.

## What it covers

| Format | Implemented core | Deliberate boundaries |
| --- | --- | --- |
| RSS 2.0 | Channel/item metadata, language, channel image, Content Module body, authors, categories, item enclosures | RSS versions other than 2.0; network retrieval; unsupported extensions |
| Atom 1.0 | Feed/entry metadata, scoped language, icon/logo, alternate/enclosure links, inline text/HTML/XHTML and text/* MIME content, external content source/type, author inheritance, categories | External-content retrieval, binary/XML media decoding, XHTML rendering/sanitization, HTML-contained URLs |
| JSON Feed 1.0/1.1 | Feed/items, icon/favicon, item external URL and featured/banner images, text/HTML body choice, authors, tags, attachments; language in 1.1 | Pagination, author avatars, extension mapping, unsupported URI fields |

The normalized model keeps summary/description separate from article content,
preserves author/category/attachment source semantics, retains document order,
and reports recoverable data-quality diagnostics with locations. Fatal malformed
or unsupported documents return `ParseError`.
Attachment URLs and metadata are parsed only; FeedLens never downloads them.
Feed and item images retain source-specific display roles; they are not
attachments. JSON Feed `external_url` stays separate from the item permalink.
Raw publication/update dates remain available; a separate, cross-target API
validates supported RSS or RFC 3339 dates and returns comparable UTC instants.
`parse_with_source(input, source_url)` optionally resolves documented links,
image URLs, attachment URLs, and Atom external content references; Atom `xml:base` scopes are honored. Plain `parse(input)` keeps
raw references, and neither entry point fetches URLs.

For the [standard behavior matrix](docs/STANDARD_SCOPE.md), complete field mapping,
diagnostic rules, XML namespace boundaries, and content-handling policy, see
[README.mbt.md](README.mbt.md). This file is the
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
`parse_with_source(input, source_url)` to resolve article, image, and attachment URLs,
including Atom `xml:base`; `parse(input)` continues to preserve raw references.
The library package remains portable across Wasm, JavaScript, and Native.
A separate [consumer example](examples/consumer/main.mbt) imports only the
public parser package. Run `moon run --target native examples/consumer` or
`powershell -ExecutionPolicy Bypass -File tools/check_consumer.ps1`; neither
command requires a published Mooncakes package or a network request.

Atom XHTML titles have a directly readable plain-text `title`, `title_kind = Xhtml`,
and a `title_xhtml` fragment. For the fixed
[acceptance input](samples/atom1_xhtml.xml), the actual library result is
`feed.title = Some("Plan A & B")`, `feed.title_xhtml.markup =
"Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em> &amp; B"`;
its entry has `title = Some("Race review")` and `content_kind = Xhtml` with
`content_xhtml.markup` containing `<h:p>` and `<h:strong>`. The required outer
`div` is removed; namespace-qualified child markup and meaningful whitespace
remain. This fragment is **untrusted XML**, not rendered or sanitized content.
Callers must use context-appropriate safe handling before displaying it.

Atom external `content src` is available as `Entry.content_source`, with its
declared `type` in `content_media_type`; `content` remains `None` because
the library never fetches external resources. Inline `text/*` MIME content
is decoded into `content` as text. See the
[offline content sample](samples/atom1_content_sources.xml) and the
[scope matrix](docs/STANDARD_SCOPE.md) for the exact boundary.

## Local-file CLI

The separate Native executable reads one local XML or JSON file and prints the
normalized model. It does not infer a source URL from the file path and never
fetches URLs. These checked-in files are [small, source-traceable projections](samples/REAL_WORLD.md)
of WP Tavern's real RSS, Atom, and JSON Feed subscriptions:

```powershell
moon run --target native cmd/main samples/real_wptavern_rss.xml
moon run --target native cmd/main samples/real_wptavern_atom.xml
moon run --target native cmd/main --json samples/real_wptavern_json.json
moon run --target native cmd/main --json samples/atom1_xhtml.xml
moon run --target native cmd/main -- --help
```

The first RSS episode reports `Entries: 2` and an `audio/mpeg` enclosure of
`37878054` bytes. The Atom and JSON Feed projections expose the same media URL
and byte count. Their differently formatted publication dates normalize to
`2026-10-14T13:00:00Z` through the library date API. The snapshots are offline;
the publisher's full live feeds are not bundled.
The real projections also retain RSS channel language/image, Atom root
language/icon, and JSON Feed language/icon and item featured images. Roles,
missing-field policy, and synthetic cases for favicon, logo, external URL,
and banner image are detailed in [the inventory](samples/DISPLAY_FIELD_INVENTORY.md).

`--json` writes FeedLens's normalized inspection JSON, not a converted JSON
Feed document. Errors use stderr and a non-zero exit status; recoverable feed
diagnostics still result in success.
For the XHTML sample, this is an exact feed-title field excerpt from the
CLI's normalized JSON (other fields omitted here):

```json
{"title":"Plan A & B","title_kind":"xhtml","title_xhtml":{"markup":"Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em> &amp; B","language":null,"base_references":[]}}
```

## Verification

```powershell
moon fmt
moon info
moon check --target wasm; moon test --target wasm
moon check --target js; moon test --target js
moon check --target native; moon test --target native
powershell -ExecutionPolicy Bypass -File tools/check_cli.ps1
powershell -ExecutionPolicy Bypass -File tools/check_consumer.ps1
uv run --with feedparser==6.0.11 python tools/check_compatibility.py
uv run --with feedparser==6.0.11 python tools/check_xhtml_reference.py
```

`samples/` contains small checked-in inputs used by the cross-target tests.
The three real-feed projections retain selected metadata but omit long bodies;
their original URLs, capture date, response hashes, and baseline findings are
recorded in [samples/REAL_WORLD.md](samples/REAL_WORLD.md). The optional Python
script also checks that the cross-target embedded mirrors match these files.
The optional Python command is an independent, local-only comparison against
feedparser 6.0.11; its defined field intersection and observed results are in
[samples/COMPATIBILITY.md](samples/COMPATIBILITY.md).
The XHTML comparison checks eight declared intersection values and separately
records feedparser's default sanitization; FeedLens intentionally returns
unsanitized namespace-qualified XML. Its contribution is MoonBit-native,
cross-target consumption with a source-aware model, explicit diagnostics and
offline inspection—not a new XML algorithm or broader format coverage than feedparser.

The GitHub-hosted Linux CI uses the latest official MoonBit toolchain. The
locally verified `0.1.20260920` is retained for local validation, but its
versioned Linux download returned HTTP 403 when the CI was prepared; the
workflow therefore cannot honestly pin that unavailable Linux artifact.

## License

[Apache License 2.0](LICENSE).
