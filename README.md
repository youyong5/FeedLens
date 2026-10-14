# FeedLens

FeedLens is a reusable [MoonBit](https://www.moonbitlang.com/) library for
inspecting syndication feeds through one explicit, source-aware model. It
parses RSS 2.0, Atom 1.0, and JSON Feed 1.0/1.1 without fetching the network,
silently flattening unsupported XML markup, or exposing its XML parser as part
of the public API.

## What it covers

| Format | Implemented core | Deliberate boundaries |
| --- | --- | --- |
| RSS 2.0 | Channel/item metadata, Content Module `content:encoded`, item authors and categories | RSS versions other than 2.0; network retrieval; date/URI parsing |
| Atom 1.0 | Feed/entry metadata, alternate links, inline text/HTML content, author inheritance, categories | XHTML serialization, external-content retrieval, media metadata, URI resolution |
| JSON Feed 1.0/1.1 | Feed/items, text/HTML body choice, authors, inherited authors, tags | Attachments, pagination, icons, avatars, extension mapping, date/URI parsing |

The normalized model keeps summary/description separate from article content,
preserves author/category source semantics, retains document order, and reports
recoverable data-quality diagnostics with locations. Fatal malformed or
unsupported documents return `ParseError`.

For the complete field mapping, diagnostic rules, XML namespace boundaries, and
content-handling policy, see [README.mbt.md](README.mbt.md). This file is the
GitHub landing page; both documents describe the same supported scope.

## Library

```moonbit nocheck
match @feedlens.parse(input) {
  Ok(feed) => println(feed.entries[0].identifier.unwrap_or("(no identifier)"))
  Err(_) => println("feed parsing failed")
}
```

The library package remains portable across Wasm, JavaScript, and Native.

## Local-file CLI

The separate Native executable reads one local XML or JSON file and prints the
normalized model. It never fetches URLs.

```powershell
moon run --target native cmd/main samples/rss2_compat.xml
moon run --target native cmd/main samples/atom1_compat.xml
moon run --target native cmd/main --json samples/jsonfeed11_compat.json
moon run --target native cmd/main -- --help
```

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
The optional Python command is an independent, local-only comparison against
feedparser 6.0.11; its defined field intersection and observed results are in
[samples/COMPATIBILITY.md](samples/COMPATIBILITY.md).

The GitHub-hosted Linux CI uses the latest official MoonBit toolchain. The
locally verified `0.1.20260920` is retained for local validation, but its
versioned Linux download returned HTTP 403 when the CI was prepared; the
workflow therefore cannot honestly pin that unavailable Linux artifact.

## License

[Apache License 2.0](LICENSE).
