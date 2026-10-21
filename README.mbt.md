# FeedLens — MoonBit 多格式 Feed 解析库

`youyong5/feedlens` is a reusable MoonBit multi-format Feed parsing library
for documented subsets of RSS 2.0, Atom 1.0, and JSON Feed 1.0/1.1, not a
complete validator for every legal construct. Diagnostics and the local-file
CLI are supporting tools, not the primary product.

The test-linked [standard behavior matrix](docs/STANDARD_SCOPE.md) is the
precise compatibility commitment, including supported input forms, output,
diagnostics, and legal constructs that remain outside the mapped subset.

It gives callers one source-aware, cross-format model for the common feed
fields while preserving document order and distinguishing fatal parse failures
from recoverable feed-quality diagnostics. It is intentionally a parser and
local inspection library: it does not fetch feeds, sanitize/render HTML, or
guess missing dates or a document's source URL. `README.md` is the GitHub
landing page; this document contains the full mapping and boundary specification.

## Public model

`Feed` and `Entry` use one vocabulary across the supported formats:

| Public field | RSS 2.0 source | Atom 1.0 source | JSON Feed 1.0/1.1 source |
| --- | --- | --- | --- |
| `Feed.identifier` | none | feed `id` | `feed_url` |
| `Feed.description` | channel `description` | feed `subtitle` | `description` |
| `Feed.language` | channel `language` | feed `xml:lang` | `language` (1.1 only) |
| `Entry.language` | inherited channel language | inherited feed `xml:lang`, or entry override/reset | inherited feed language, or item override (1.1 only) |
| `Feed.updated_at` | none | feed `updated` | none |
| `Entry.identifier` | non-blank `guid`, otherwise non-blank `link` | entry `id` | item `id` |
| `Entry.description` | item `description` | entry `summary` | `summary` |
| `Entry.content` | Content Module `content:encoded` | inline entry `content` | `content_html`, otherwise `content_text` |
| `Entry.published_at` | item `pubDate` | entry `published` | `date_published` |
| `Entry.updated_at` | none | entry `updated` | `date_modified` |
| `Feed.authors` | none | direct feed authors | `authors`, otherwise legacy `author` |
| `Entry.authors` | direct item authors | effective entry authors | item `authors`/`author`, otherwise feed authors |
| `Feed.categories` | direct channel categories | direct feed categories | none in supported subset |
| `Feed.images` | direct channel image | direct feed icon/logo | feed icon/favicon |
| `Entry.categories` | direct item categories | direct entry categories | `tags` |
| `Entry.attachments` | direct item `enclosure` | direct entry `link rel="enclosure"` | item `attachments` |
| `Entry.external_url` | none | none | item `external_url`, separate from `url` permalink |
| `Entry.images` | none in supported core | none in supported core | item `image` (featured preview), `banner_image` (detail banner) |

`title` and `link` have the same meaning across supported formats. There are no duplicate
format-specific public values, so the normalized fields cannot drift apart. `title_kind`
and `description_kind` describe the associated string: `Unspecified` for RSS (which
does not declare a text-construct type), `Text` for Atom omitted/`text` and JSON
Feed title/summary/text content, `Html` for Atom/JSON Feed HTML content, and
`Xhtml` for supported Atom XHTML constructs. XHTML text fields expose a
displayable plain-text string plus `title_xhtml`/`description_xhtml`/
`content_xhtml` as appropriate. Each `XhtmlFragment` carries deterministic
`markup`, effective `language`, and ordered raw `base_references` from Atom
ancestors through the outer XHTML div; child `xml:base` remains in the markup.
HTML
values retain decoded source text for XML and JSON source strings for JSON Feed;
FeedLens neither renders nor sanitizes them. `content_kind` follows the same rules.
`description` is never copied into `content`: it remains a summary/RSS description
even when no body is available.

Language tags are kept as declared, without BCP 47 canonicalization or a
guessed default. `Entry.language` is the effective entry-level context: RSS
items inherit channel language; Atom entries inherit feed `xml:lang` unless
the entry declares its own. An explicit empty Atom `xml:lang` resets to
`None`. JSON Feed 1.1 items inherit feed `language` unless an item declares
its own; malformed or blank declarations are diagnosed and do not inherit.
The 1.0 format does not declare a `language` field, so those keys are ignored.
Language attributes on nested Atom text constructs are not projected into a
single entry language; XHTML fragments expose their own effective language.

`Feed.images` is an ordered collection of `FeedImage` values with explicit
`source` and `role`: `RssImage`, `AtomIcon`, `AtomLogo`, `JsonIcon`, or
`JsonFavicon`. The RSS image retains its required URL/title/link and optional
description/declared dimensions. Atom icon and logo are kept separate, as are
JSON Feed timeline icon and source-list favicon. Missing required image data
or invalid optional dimensions are diagnosed. RSS dimensions are retained only
when valid positive declared values (width at most 144, height at most 400);
no specification defaults or actual pixel sizes are synthesized. XML images
retain source order; JSON `icon` precedes `favicon` in the public array because
JSON object member order is not semantically significant. No image is fetched, inspected,
resized, or promoted to an attachment. `parse_with_source` resolves image URLs
and the RSS image link; Atom icon/logo honor their own `xml:base` scopes.
`Entry.external_url` is not a fallback permalink. JSON Feed item images are
`EntryImage` values with `source = JsonFeed1` and distinct `JsonFeatured`/
`JsonBanner` roles; they are separate from `Entry.attachments`. Their public
array has a fixed featured-then-banner order, because JSON object member order
is not semantically significant. RSS and Atom core do not supply equivalent
item fields with these exact roles, so they remain absent there. Blank or
wrong-type JSON URL values are diagnosed and omitted; malformed URI references
remain raw with `UnresolvedUri` when `parse_with_source` is used.

### Dates without local-time guessing

The original `Feed.updated_at`, `Entry.published_at`, and `Entry.updated_at`
strings remain unchanged. Call `normalize_date(feed.format, raw_date)` to get
`Result[NormalizedDate?, DateError]`: `Ok(None)` means absent; `Err` means a
present but invalid or unsupported value. A successful result provides `utc`
(RFC 3339 UTC text), `unix_seconds`, `nanosecond`, the original
`offset_minutes`, and `precision` (`Minute`, `Second`, or `Fraction(digits)`).
This function is pure and gives the same result on Wasm, JS, and Native; it
never uses the machine's local time zone.

```moonbit nocheck
match @feedlens.normalize_date(feed.format, feed.entries[0].published_at) {
  Ok(Some(date)) => println(date.utc)
  Ok(None) => println("publication date missing")
  Err(_) => println("publication date invalid or unsupported")
}
```

RSS accepts the common RFC 822/1123 profile with a four-digit year, optional
weekday, `HH:MM` or `HH:MM:SS`, and numeric `±HHMM`, `UT`/`UTC`/`GMT`, or
US `EST`/`EDT`/`CST`/`CDT`/`MST`/`MDT`/`PST`/`PDT` zones. A stated weekday
must agree with the calendar date. Atom and JSON Feed require RFC 3339 with an
explicit offset or `Z`, and support 1–9 fractional-second digits. Calendar
dates, times, and offsets are validated. Unknown-offset `-0000`/`-00:00`,
two-digit RSS years, leap-second `:60`, and precision beyond nanoseconds are
not normalized; the raw field is still available. No date is substituted from
the file timestamp, fetch time, or local clock.

`Author` preserves source semantics through `source`, `name`, `uri`, and `email`.
RSS item authors are exposed only as their original `email` text (`source = Rss2`);
FeedLens does not infer a name from it. Atom authors are person constructs
(`source = Atom1`) with a required non-blank `name` and optional `uri`/`email`.
JSON Feed authors (`source = JsonFeed`) map `name` and `url` to `name` and `uri`;
either non-blank value is sufficient, and JSON Feed has no mapped `email` field.
`Category` has a shared `term` and source marker, but preserves RSS `domain`
separately from Atom `scheme` and `label`; those fields are never normalized into
one another. JSON Feed tags use only `term` with `source = JsonFeed1`. Author and
category arrays retain document order.

`Attachment` exposes `source` (`Rss2`, `Atom1`, or `JsonFeed1`), the original
`url`, optional `media_type`, optional `size_in_bytes`, optional `title`, and
optional `duration_in_seconds`. Attachments retain source order and are metadata
only: FeedLens never downloads or verifies the referenced resource. RSS
`enclosure` requires non-blank `url`, `length`, and `type`; Atom enclosure links
require `href` but permit absent `type` and `length`; JSON Feed attachments
require non-blank `url` and `mime_type`. Atom's optional link `title` and JSON
Feed's optional attachment `title` are preserved; only JSON Feed supplies a
duration. `parse` keeps URL references as written; `parse_with_source` can
resolve supported URL fields without downloading them.

`size_in_bytes` is an optional `Int64`, accepted only for non-negative decimal
integers through `9007199254740991` (the largest integer exactly representable
by JavaScript's Number and by the CLI's JSON number output). Invalid, missing,
or larger values never wrap: RSS enclosures are skipped when a required length
is invalid; Atom/JSON Feed attachments retain their URL and receive
`InvalidAttachment` with size `None` when an optional size is invalid. For JSON
Feed, `1.0` and `1e3` are deliberately not accepted as integer byte counts.
JSON Feed durations are optional finite, non-negative `Double` seconds; invalid
values become `None` with a diagnostic. They follow ordinary IEEE 754 rounding.

### URI references and an explicit source URL

`parse(input)` retains its existing raw-reference behavior. To resolve common
links, use `parse_with_source(input, source_url)`, where `source_url` is the
absolute HTTP(S) URL from which the document was obtained, without a fragment:

```moonbit nocheck
match @feedlens.parse_with_source(input, "https://example.org/feeds/news.atom") {
  Ok(feed) => println(feed.entries[0].link.unwrap_or("(no link)"))
  Err(_) => println("feed or source URL invalid")
}
```

The new entry point resolves `Feed.link`, `Entry.link`,
`Entry.attachments[].url`, feed-image URLs (and RSS image link), JSON item
`external_url`, and JSON item-image URLs using RFC 3986 path, root-path, query,
fragment, and dot-segment rules. RSS and JSON Feed use the caller-supplied document URL;
Atom additionally applies the inherited `xml:base` on the feed, entry, link,
and any intervening XML elements, matching the XML namespace URI rather than
an arbitrary `base` attribute. JSON Feed's declared `feed_url` and
`home_page_url` are **not** substituted as a fetch-location base. Without a
usable base, or for a malformed URI reference, the raw field is retained and
`UnresolvedUri` is recorded; XML diagnostics point to the relevant element,
whereas JSON semantic diagnostics are `(1, 1)`. An invalid explicit source URL
is a fatal `InvalidSourceUrl` error. No URI is fetched.

Identifiers (`guid`, Atom `id`, JSON Feed `id`) stay opaque and unchanged,
including the RSS link-fallback identifier. Author URIs, RSS category domains,
Atom category schemes, external Atom content `src`, and URLs inside HTML are
not resolved in this stage. Existing `parse` callers are unaffected; callers
that need the original references can continue using it.

## RSS 2.0

- RSS 2.0 documents with an unnamespaced `<rss version="2.0">` root.
- Reads direct channel `language` and direct `image` (required URL/title/link,
  optional description and declared dimensions). RSS items inherit the
  channel language; wrong-namespace lookalikes do not count.
- A direct `<channel>` child of `<rss>`; channel metadata and `<item>` elements must be direct channel children.
- Channel `title`, `link`, and `description`; item `guid`, `title`, `link`, `description`, and `pubDate`, retained in document order.
- Namespace-aware matching: elements in other namespaces, or at another hierarchy level, never fill RSS core fields.
- XML errors, unsupported roots, unsupported RSS versions, and a missing channel are fatal `ParseError` values.
- Missing or whitespace-only fields are recoverable and become `None`. `Feed.diagnostics` reports each missing required channel field and anonymous item. A blank channel field diagnostic points at that field; an absent one points at `<channel>`. An anonymous-item diagnostic points at `<item>`.
- An item's `identifier` is its non-blank `guid`, falling back to its non-blank `link`. The `guid` value is never interpreted as a URL, including when `isPermaLink` is present.
- RSS core fields containing nested XML markup are not flattened: their value becomes `None` and `UnsupportedNestedMarkup` identifies the field location. Plain text, XML entities, and CDATA remain supported.
- Supports a direct item child named `content:encoded` only when its resolved namespace URI is exactly `http://purl.org/rss/1.0/modules/content/`. Its XML-decoded text or CDATA is exposed as `Entry.content` with `content_kind = Unspecified`; it is independent from `description`. Nested XML is rejected with the same explicit nested-markup diagnostic policy.
- Reads direct channel and item `category` elements in document order. A category's non-blank text is its term and its optional `domain` remains RSS-specific. Reads direct item `author` text as an unparsed raw email value. Blank authors/categories receive source-located `InvalidAuthor`/`InvalidCategory` diagnostics; namespaced lookalikes are ignored.
- Reads only direct, unnamespaced item `enclosure` elements. `url`, `length`, and `type` are required. Invalid enclosures are skipped with source-located `InvalidAttachment`; an invalid length never overflows.
- The public API exposes FeedLens types only; it does not expose `Milky2018/xml` types.

## Atom 1.0

- Accepts only `<feed>` in the `http://www.w3.org/2005/Atom` namespace, whether declared as the default namespace or through a prefix.
- Reads feed/entry `xml:lang` in the XML namespace, with feed-to-entry
  inheritance and explicit entry override/reset. Direct feed `icon` and
  `logo` remain separate image roles; each honors its own `xml:base` scope
  under `parse_with_source`.
- Maps feed `id`, `title`, `subtitle`, `updated`, and alternate `link` to the normalized public model; maps direct `entry` children in document order from `id`, `title`, `published`, `updated`, `summary`, and alternate `link`.
- A link with omitted `rel` or `rel="alternate"` is eligible; `rel="self"` is not. `parse` retains relative `href` values verbatim; `parse_with_source` resolves supported links with the applicable `xml:base` scope.
- Required feed fields are `id`, `title`, and `updated`; required entry fields are `id`, `title`, and `updated`. Missing or blank values are recoverable diagnostics located at the field, or its feed/entry parent when absent.
- Reads direct feed/entry `author` person constructs and their direct `name`, `uri`, and `email` children. Effective entry authors use the first available layer: entry authors, then direct `entry/source` authors, then feed authors. Layers are never combined. An author lacking a non-blank direct `name` gets `InvalidAuthor` at its element; if no valid layer exists, the entry gets `MissingEntryField(_, "author")`. A feed may omit authors when every entry has a valid own/source author.
- Reads direct feed and entry `category` elements. Atom `term` is required; optional `scheme` and `label` stay distinct from RSS `domain`. Missing/blank terms receive an `InvalidCategory` at the category element.
- Reads only direct Atom entry `link` elements with `rel="enclosure"` as attachments. This does not change alternate-link selection. Missing `href` skips the attachment; invalid optional `length` is diagnosed and omitted from an otherwise valid attachment.
- An entry without a `content` element must have an alternate link. The parser tracks that presence separately from successful body extraction, so an unsupported or external content element does not incorrectly trigger `MissingAlternateLink`.
- Supports inline Atom `content` with omitted/`text`, `html`, and `xhtml` types as `Entry.content`. Text/HTML values retain XML-decoded source text and original whitespace. For XHTML, `content` is the concatenated display text while `content_xhtml.markup` retains the XML child structure and whitespace; `content_kind = Xhtml` prevents mistaking it for HTML or plain text.
- External Atom content (`src`) is never fetched or exposed as a body. It receives `UnsupportedAtomContent("external Atom content")`; when it lacks `summary`, it also receives the existing missing-summary diagnostic.
- Atom `title`, `subtitle`, `summary`, and inline `content` accept a single `div` in the exact XHTML namespace URI for `type="xhtml"`, regardless of prefix. The outer `div` is not part of `markup`; descendant elements/attributes/namespaces, mixed text, comments, processing instructions, and meaningful in-div whitespace are retained in deterministic XML serialization. `language` and `base_references` retain effective `xml:lang` and the inherited `xml:base` declaration chain even when declared on the removed div. Missing/wrong-namespace/multiple div roots or non-whitespace text outside div are diagnosed at the Atom field; no false complete value is exposed. Unhandled media types and nested XML inside `text`/`html` constructs remain diagnosed. The serialization preserves XML content semantics, not original byte spelling of entities, prefixes, quote style, or attribute order independent of the parser. It is **not sanitized**; callers must apply safe rendering, escaping, and URI policy themselves. Neither entry point rewrites links inside XHTML markup.

For the fixed [Atom XHTML acceptance sample](samples/atom1_xhtml.xml), actual
public values include:

```text
feed.title = Some("Plan A & B")
feed.title_kind = Xhtml
feed.title_xhtml.markup = "Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em> &amp; B"
entry.title = Some("Race review")
entry.content = Some("Lap 12 & rain.")
entry.content_kind = Xhtml
entry.content_xhtml.markup = "<h:p xmlns:h=\"http://www.w3.org/1999/xhtml\">Lap <h:strong xmlns:h=\"http://www.w3.org/1999/xhtml\">12</h:strong> &amp; rain.</h:p>"
```

`XhtmlFragment.base_references` retains raw scoped declarations rather than
guessing an absolute base from a local filename. Even with `parse_with_source`,
callers must combine that chain with the known source URL and nested child
`xml:base` before interpreting relative links in the fragment. The removed
outer div's non-inherited style/class attributes are not projected.

## JSON Feed 1.0 and 1.1

- Accepts only root objects whose `version` is exactly `https://jsonfeed.org/version/1` or `https://jsonfeed.org/version/1.1`. JSON is selected whenever the first non-whitespace input character is not `<`; XML dispatch remains unchanged.
- `title` must be a string and `items` must be an array. Invalid JSON, a non-object root, absent/wrong-type `version`, absent/wrong-type `title`, absent/wrong-type `items`, and unsupported versions are fatal JSON-specific `ParseError` values, never `InvalidXml`.
- Maps `title`, `description`, `home_page_url`, `feed_url`, `icon`, and `favicon`; maps item `id`, `url`, `external_url`, `image`, `banner_image`, `title`, `summary`, `date_published`, `date_modified`, `content_text`, and `content_html`. Version 1.1 also maps feed/item `language`. Text fields are `Text`; `content_html` is `Html` and is retained unchanged. Raw date strings can be independently validated through `normalize_date`; no URI resolution occurs during `parse`.
- `url` stays the item permalink, while `external_url` points to an outside
  page; a missing permalink is not replaced by the external URL. Featured and
  banner images are presentation hints, never attachments. JSON Feed 1.0
  does not define `language`, so 1.0 keys of that name are ignored.
- Both content fields are legal. When both are valid strings, `content_html` deliberately wins because it preserves the richer declared representation; the unified model exposes one `Entry.content`. An item must have one valid content field. A malformed/missing item `id` or content discards that item with `InvalidJsonFeedItem`; a JSON number id is retained as its JSON spelling. Optional malformed item fields are diagnosed and become `None`.
- Supports `authors` arrays and deprecated `author` objects at feed/item level. If `authors` is present it wins, even over `author`; undeclared item authors inherit feed authors. A JSON Feed author needs a non-blank `name` or `url`, and its URL is exposed through `Author.uri`.
- Maps item `tags` to ordered categories. Empty tags and malformed optional fields are diagnosed and skipped. Unknown extension keys are ignored.
- Maps each valid item `attachments` array element in order, preserving URL, MIME type, optional title, integer byte size, and floating-point duration. A malformed attachment is diagnosed without discarding its valid item. Invalid optional metadata is omitted; unknown attachment extension keys are ignored.
- JSON syntax errors retain a parser position. The core JSON DOM does not retain semantic-field spans, so JSON Feed field/item diagnostics use document position `(1, 1)`; XML diagnostics continue to point to their source elements.

## Not supported

- Attachment/image retrieval or verification; JSON Feed pagination following, author avatars, expired state, and extension fields; network retrieval and unscoped URI/IRI fields listed above.
- RSS versions other than 2.0, and RSS core elements placed in a namespace.
- Atom external-content retrieval, other media-type decoding, full XHTML rendering/sanitization, and resolution inside HTML/XHTML or unsupported constructs.

## Example

```moonbit nocheck
match @feedlens.parse(input) {
  Ok(feed) => println(feed.entries[0].identifier.unwrap_or("(no identifier)"))
  Err(_) => println("feed parsing failed")
}
```

## Local-file CLI

`cmd/main` is a separate executable package. The reusable root package remains
the cross-target parser; only the CLI package imports local-file IO and process
exit support. It reads one UTF-8 local file and never performs a network request.

On Windows, from the module root, run the source-traceable offline projections
of WP Tavern's three real public subscriptions:

```powershell
moon run --target native cmd/main samples/real_wptavern_rss.xml
moon run --target native cmd/main samples/real_wptavern_atom.xml
moon run --target native cmd/main --json samples/real_wptavern_json.json
moon run --target native cmd/main --json samples/atom1_xhtml.xml
moon run --target native cmd/main -- --help
```

The extra `--` in the help command is required by Moon 0.1.20260920 so that
`--help` reaches FeedLens rather than being consumed by `moon run` itself.

Normal output is a short, human-readable summary:

```text
FeedLens — MoonBit multi-format Feed parser library
Format: RSS 2.0
Title: WP Tavern
Link: https://wptavern.com
Entries: 2

1. identifier: https://wptavern.com/?post_type=podcast&p=209016
   title: #237 – Robert Abela on WordPress Security and the Battle Against AI Threats
   link: https://wptavern.com/podcast/237-robert-abela-on-wordpress-security-and-the-battle-against-ai-threats/
   attachments: 1
```

`--json` writes exactly one JSON value to stdout. It contains the normalized
`Feed`/`Entry` fields, text kinds, XHTML fragment objects (or `null`), ordered
author/category/attachment arrays, and ordered
diagnostics with positions. Missing values are JSON `null`. This is FeedLens's
normalized inspection format, **not** a conversion to a JSON Feed document.
Errors (bad arguments, unreadable files, or fatal parse errors) go to stderr and
return exit code `2`; `--help` and successful parsing return `0`. Recoverable
feed diagnostics are written into normal output and still return `0`. In
`--json` mode, no status/error text is written to stdout.

The CLI is exercised on the Native backend in this environment. File IO and
process exit use verified `moonbitlang/x@0.5.5` APIs only in the executable
package. The parser now also imports the pure `moonbitlang/x/time` package for
date validation; it does not import file IO and remains checked/tested on
Wasm, JS, and Native. A local file path is never treated as a source URL, so
the CLI uses `parse`, not `parse_with_source`.

## XML dependency

This module pins `Milky2018/xml@0.5.0`. The newer `0.6.1` was downloaded and
evaluated first, but cannot compile with this MoonBit toolchain because its source
uses the removed `Int32` type. `0.5.0` provides the same `NamespaceReader` API and
passes this project's verification, so it is the newest compatible version actually
installed here. Matching uses resolved namespace URIs instead of tag prefixes.

## Verification samples

`samples/` contains compact synthetic compatibility/boundary cases and three
[real-feed offline projections](samples/REAL_WORLD.md) with source URLs,
capture date, response hashes, reduction policy, and baseline findings.
`compatibility_test.mbt` and `real_samples_test.mbt` embed checked-in XML/JSON
samples so Wasm, JS, and Native tests need no filesystem or network access.
`samples/DISPLAY_FIELD_INVENTORY.md` distinguishes display fields in the
original captured feeds from specification-defined fields exercised only by
synthetic fixtures. `examples/consumer` imports the public library without
the CLI or XML implementation; run `moon run --target native examples/consumer`
or `powershell -ExecutionPolicy Bypass -File tools/check_consumer.ps1`.

For an end-to-end Native CLI check (including file IO, exit codes, stderr, and
PowerShell's standard `ConvertFrom-Json`), run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/check_cli.ps1
```

For a development-only independent comparison, use
`uv run --with feedparser==6.0.11 python tools/check_compatibility.py`.
Run `uv run --with feedparser==6.0.11 python tools/check_xhtml_reference.py`
for the separately declared Atom XHTML text/type intersection. Both scripts
read local samples only; the XHTML script also runs the local Native CLI.
The script checks the real-sample mirrors and compares the older independent
XML reference only on the declared field intersection in
`samples/reference_intersection.json`; it is not a MoonBit dependency. See
`samples/COMPATIBILITY.md` for actual reference version/results and intentional
normalization differences, including RSS link fallback for a missing guid.

GitHub-hosted Linux CI uses the latest official MoonBit toolchain. The local
toolchain remains `0.1.20260920`, but its versioned Linux download returned
HTTP 403 during CI preparation; pinning CI to that unavailable artifact would
make the workflow permanently fail.
