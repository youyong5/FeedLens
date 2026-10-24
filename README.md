# FeedLens — MoonBit 多格式 Feed 解析库

FeedLens is a reusable [MoonBit](https://www.moonbitlang.com/) multi-format
Feed parsing library. It extracts documented, tested common behavior of RSS 2.0,
Atom 1.0, and JSON Feed 1.0/1.1 into one source-aware model. It supports both
Atom Feed and stand-alone Atom Entry Documents through `parse_document`.
The remaining standard gaps are recorded explicitly; this is not yet a full
conformance claim. Diagnostics and a local-file CLI help inspect
results; the library never fetches a feed or an attachment.

## What it covers

| Format | Implemented core | Deliberate boundaries |
| --- | --- | --- |
| RSS 2.0 | Channel/item metadata and dates, TTL and advisory skip hours/days, copyright/generator, editor/webmaster contacts, guid permalink role, source credit, language, image, Content Module body, RSS email and Dublin Core creator authors, categories and enclosures | Other RSS versions, uncommon optional constructs and extension modules |
| Atom 1.0 | Feed and independent Entry documents, source identity/title/subtitle/updated, rights XHTML, generator attributes, contributors, feed/entry/source links and their common attributes, icon/logo, scoped language and person URI references, body forms, author inheritance, categories; diagnosed feed metadata after entries | Some optional metadata and structural checks, external-content retrieval, fragment rendering or sanitization |
| JSON Feed 1.0/1.1 | Feed/items, next URL and expired state, hubs, icons, external links, both item body representations, author avatars, tags and attachments; language in 1.1 | Pagination following, arbitrary extension mapping, additional version-specific checks |

The normalized model keeps summary/description separate from article content,
preserves author/category/attachment source semantics, retains document order,
and reports recoverable data-quality diagnostics with locations. Fatal malformed
or unsupported documents return `ParseError`.
Attachment URLs and metadata are parsed only; FeedLens never downloads them.
Feed and item images retain source-specific display roles; they are not
attachments. JSON Feed `external_url` stays separate from the item permalink.
Raw publication/update dates remain available; invalid Atom feed, entry, and
source dates produce located diagnostics during parsing. A separate,
cross-target API validates supported RSS or RFC 3339 dates and returns
comparable UTC instants.
Malformed JSON Feed item dates also retain their raw strings and produce
`InvalidJsonFeedDate` diagnostics without discarding the item.
`parse_with_source(input, source_url)` optionally resolves documented links,
image URLs, attachment URLs, and external Atom content references; Atom `xml:base` scopes are honored. Plain `parse(input)` keeps
raw references, and neither entry point fetches URLs.
Atom feed/entry/source `links` retain relations such as `self` and `related`; `link` remains the
alternate convenience value. Aggregated entries expose original feed metadata through
`Entry.atom_source`, including its subtitle, generator, links and images.
`parse_with_source` resolves source links, generator URI, images and author/contributor
URIs under nested `xml:base`; `parse` retains the original references. RSS and Atom rights and generator values and JSON
Feed pagination/hub declarations are visible without following any network links.
Source-aware parsing also validates bracketed IPv6/IPvFuture host syntax before resolving
relative references; `samples/atom1_ip_literals.xml` shows scoped Atom and enclosure links.
An explicit empty Atom `href=""` or external `content src=""` remains a present
IRI reference, distinct from a missing attribute. With a known source URL it
resolves against the applicable `xml:base`; the
[offline sample](samples/atom1_empty_iri_references.xml) checks feed, entry,
source, enclosure, and external body fields.
Atom Person names, category terms/labels, and link/enclosure titles also retain
declared empty or whitespace-only strings; absent required names/terms still
produce diagnostics. The [metadata sample](samples/atom1_declared_empty_metadata.xml)
tests author precedence alongside these values.

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

An Atom Entry Document has an `entry` root and no enclosing feed. Use the new
typed entry point while existing feed callers keep `parse` unchanged:

```moonbit nocheck
match @feedlens.parse_document(input) {
  Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) =>
    println(entry.title.unwrap_or("(untitled)"))
  Ok(@feedlens.FeedDocument(feed)) => println(feed.title.unwrap_or("(untitled)"))
  Err(_) => println("document parsing failed")
}
```

`parse_document_with_source(input, source_url)` also resolves independent
entry links and external body references using the entry's `xml:base` scope.
The [fixed entry sample](samples/atom1_entry_document.xml) exercises XHTML,
author, alternate and enclosure links, and source resolution.

When the caller knows the document's actual HTTP(S) URL, it can use
`parse_with_source(input, source_url)` to resolve article, image, and attachment URLs,
including external Atom content references under `xml:base`; `parse(input)`
continues to preserve raw references.
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
remain. `container_attributes` separately preserves the div's attributes in
source order with expanded namespace names. The
[container regression](samples/atom1_xhtml_container.xml) compares them to an
independent XML reader. This fragment and its attributes are **untrusted XML**,
not rendered or sanitized content.
Callers must use context-appropriate safe handling before displaying it.

Atom external `content src` is available as `Entry.content_source`, with its
declared `type` in `content_media_type`; `content` remains `None` because
the library never fetches external resources. These previously published
convenience fields remain available; the detailed representation below is
authoritative for content shape. The earlier
[source/text sample](samples/atom1_content_sources.xml) remains in the
regression suite.

`normalize_date(format, raw)` preserves the original feed field and returns a
validated UTC value when the source supplies enough information. Legal
RFC 3339 `-00:00` (Atom and JSON Feed) and RSS mail-date `-0000` yield a
known UTC time with `offset_known = false`: the source's **local** offset is
unknown. `offset_minutes = 0` only serves the UTC calculation. `Z`, `+00:00`,
and `+0000` have `offset_known = true`. See the
[cross-format date samples](samples/atom1_unknown_offset.xml) and
[independent intersection](tools/check_unknown_offset_reference.py).

Announced positive leap seconds are accepted when the parsed UTC minute
matches the [27 NIST dates in this offline snapshot](samples/LEAP_SECONDS_NIST_2026-10-23.md).
For example, Atom `2017-01-01T08:59:60+09:00` yields
`utc = "2016-12-31T23:59:60Z"`, `is_leap_second = true` and
`unix_seconds = 1483228799` (the preceding POSIX second). The flag is needed
because Unix time has no unique value for the leap second. New announcements
require updating the date table; unannounced `:60` is rejected by
`normalize_date` while its original feed field remains available.

Atom entry bodies also expose `entry.atom_body`. `InlineText(value, media_type)`
distinguishes MIME `text/*` (including `text/html`) from Atom's `InlineHtml`;
`InlineXhtml` retains the existing fragment, `InlineXml` preserves a
namespace-aware serialized XML fragment without div removal, `InlineBinary`
contains decoded `Bytes`, and `External` exposes raw `src`, current `url`,
declared `media_type`, and known absolute `base_uri`. `parse_with_source` resolves
relative external URLs under scoped `xml:base`; neither parser fetches them.
Legacy `entry.content` remains for supported inline text/HTML/XHTML display
strings. XML, binary and external bodies are only in `atom_body`; no binary
bytes are coerced into text. The [offline content sample](samples/atom1_content_forms.xml)
covers all four new forms. The CLI's normalized JSON represents binary bytes
as padded Base64 plus `byte_length`, not as a JSON Feed body.

```moonbit nocheck
match entry.atom_body {
  Some(@feedlens.InlineBinary(bytes, media_type)) =>
    println(media_type + ": " + bytes.length().to_string() + " bytes")
  Some(@feedlens.External(reference)) =>
    println("not fetched: " + reference.url)
  _ => ()
}
```

These fragments and references are untrusted input. FeedLens neither cleans
XML/HTML nor checks remote content; callers must apply their own rendering,
URI-access and download policy.

RSS 2.0 channel metadata also exposes `docs_url`, raw `rating`, `cloud`
(`RssCloud`), and `text_input` (`RssTextInput`). These are descriptive values:
no cloud registration or search form submission occurs. Relative `docs_url`
and `text_input.link` resolve only through `parse_with_source`; the fixture
[`rss2_optional_channel.xml`](samples/rss2_optional_channel.xml) and
[`jsonfeed10_legacy_ids.json`](samples/jsonfeed10_legacy_ids.json) cover these
RSS fields and JSON Feed 1.0's required non-string item-ID coercion. The
[standard behavior matrix](docs/STANDARD_SCOPE.md) states their validation
boundaries and the remaining limits.

The [legal-input audit](docs/LEGAL_INPUT_AUDIT.md) covers additional valid
Atom and JSON Feed boundaries: empty text constructs remain distinct from
missing fields, Atom entries inherit feed rights when they have no rights of
their own, and JSON Feed preserves opaque string IDs and tag values. The
saved fixtures and independent reader comparison are runnable offline.

## Local-file CLI

The separate Native executable reads one local XML or JSON file and prints the
normalized model. It does not infer a source URL from the file path and never
fetches URLs. These checked-in files include [source-traceable projections](samples/REAL_WORLD.md)
of WP Tavern's three subscriptions and archived feeds from other publishers:

```powershell
moon run --target native cmd/main samples/real_wptavern_rss.xml
moon run --target native cmd/main samples/real_wptavern_atom.xml
moon run --target native cmd/main --json samples/real_wptavern_json.json
moon run --target native cmd/main --json samples/real_hn_rss.xml
moon run --target native cmd/main --json samples/real_xkcd_atom.xml
moon run --target native cmd/main --json samples/real_recompiled_json.json
moon run --target native cmd/main --json samples/atom1_xhtml.xml
moon run --target native cmd/main --json samples/atom1_content_forms.xml
moon run --target native cmd/main -- --help
```

The three additional [archived publisher projections](samples/REAL_WORLD.md)
exercise RSS metadata and creator names, Atom HTML summaries, and JSON author inheritance.
The xkcd snapshot lacks required Atom authors, so its five author diagnostics
are expected even though its four entries remain available.

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
For `samples/atom1_content_forms.xml`, these two actual `atom_body` values
are shown as an excerpt array:

```json
[
  {"kind":"external","src":"entry.xml","url":"entry.xml","base_uri":"https://example.test/feeds/media/","media_type":"application/xml"},
  {"kind":"inline_binary","base64":"AQID/w==","byte_length":4,"media_type":"IMAGE/PNG"}
]
```

The full CLI stdout remains one JSON feed object containing these values in
its ordered `entries` array.
For the XHTML sample, this is an exact feed-title field excerpt from the
CLI's normalized JSON (other fields omitted here):

```json
{"title":"Plan A & B","title_kind":"xhtml","title_xhtml":{"markup":"Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em> &amp; B","language":null,"base_references":[],"container_attributes":[]}}
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
uv run --with feedparser==6.0.11 python tools/check_leap_second_reference.py
uv run --with feedparser==6.0.11 python tools/check_real_cross_format.py
```

`samples/` contains small checked-in inputs used by the cross-target tests.
The three real-feed projections retain selected metadata but omit long bodies;
their original URLs, capture date, response hashes, and baseline findings are
recorded in [samples/REAL_WORLD.md](samples/REAL_WORLD.md). The optional Python
script also checks that the cross-target embedded mirrors match these files.
The optional Python command is an independent, local-only comparison against
feedparser 6.0.11; its defined field intersection and observed results are in
[samples/COMPATIBILITY.md](samples/COMPATIBILITY.md).
The cross-format script independently checks the two saved real-world episodes
against feedparser for XML and Python JSON/date parsing for JSON Feed. It also
checks the independent Atom Entry with feedparser and verifies seven new
sample/test mirrors. It fetches no live subscriptions.
The XHTML comparison checks eight declared intersection values and separately
records feedparser's default sanitization; FeedLens intentionally returns
unsanitized namespace-qualified XML. Its contribution is MoonBit-native,
cross-target consumption with a source-aware model, explicit diagnostics and
offline inspection—not a new XML algorithm or broader format coverage than feedparser.

GitHub Actions checks Wasm, JS, and Native, Native CLI JSON, and the offline
independent reference. The local toolchain used for this revision is recorded
in the verification result; CI uses the latest downloadable MoonBit release.

## License

[Apache License 2.0](LICENSE).
