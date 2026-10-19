# FeedLens

`youyong5/feedlens` is a reusable MoonBit library for parsing RSS 2.0, Atom
1.0, and JSON Feed 1.0/1.1.

It gives callers one source-aware, cross-format model for the common feed
fields while preserving document order and distinguishing fatal parse failures
from recoverable feed-quality diagnostics. It is intentionally a parser and
local inspection library: it does not fetch feeds, sanitize/render HTML, or
resolve dates and URLs. `README.md` is the GitHub landing page; this document
contains the full mapping and boundary specification.

## Public model

`Feed` and `Entry` use one vocabulary across the supported formats:

| Public field | RSS 2.0 source | Atom 1.0 source | JSON Feed 1.0/1.1 source |
| --- | --- | --- | --- |
| `Feed.identifier` | none | feed `id` | `feed_url` |
| `Feed.description` | channel `description` | feed `subtitle` | `description` |
| `Feed.updated_at` | none | feed `updated` | none |
| `Entry.identifier` | non-blank `guid`, otherwise non-blank `link` | entry `id` | item `id` |
| `Entry.description` | item `description` | entry `summary` | `summary` |
| `Entry.content` | Content Module `content:encoded` | inline entry `content` | `content_html`, otherwise `content_text` |
| `Entry.published_at` | item `pubDate` | entry `published` | `date_published` |
| `Entry.updated_at` | none | entry `updated` | `date_modified` |
| `Feed.authors` | none | direct feed authors | `authors`, otherwise legacy `author` |
| `Entry.authors` | direct item authors | effective entry authors | item `authors`/`author`, otherwise feed authors |
| `Feed.categories` | direct channel categories | direct feed categories | none in supported subset |
| `Entry.categories` | direct item categories | direct entry categories | `tags` |
| `Entry.attachments` | direct item `enclosure` | direct entry `link rel="enclosure"` | item `attachments` |

`title` and `link` have the same meaning across supported formats. There are no duplicate
format-specific public values, so the normalized fields cannot drift apart. `title_kind`
and `description_kind` describe the associated string: `Unspecified` for RSS (which
does not declare a text-construct type), `Text` for Atom omitted/`text` and JSON
Feed title/summary/text content, and `Html` for Atom/JSON Feed HTML content. HTML
values retain decoded source text for XML and JSON source strings for JSON Feed;
FeedLens neither renders nor sanitizes them. `content_kind` follows the same rules.
`description` is never copied into `content`: it remains a summary/RSS description
even when no body is available.

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
duration. URL strings are not resolved or scheme-validated.

`size_in_bytes` is an optional `Int64`, accepted only for non-negative decimal
integers through `9007199254740991` (the largest integer exactly representable
by JavaScript's Number and by the CLI's JSON number output). Invalid, missing,
or larger values never wrap: RSS enclosures are skipped when a required length
is invalid; Atom/JSON Feed attachments retain their URL and receive
`InvalidAttachment` with size `None` when an optional size is invalid. For JSON
Feed, `1.0` and `1e3` are deliberately not accepted as integer byte counts.
JSON Feed durations are optional finite, non-negative `Double` seconds; invalid
values become `None` with a diagnostic. They follow ordinary IEEE 754 rounding.

## RSS 2.0

- RSS 2.0 documents with an unnamespaced `<rss version="2.0">` root.
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
- Maps feed `id`, `title`, `subtitle`, `updated`, and alternate `link` to the normalized public model; maps direct `entry` children in document order from `id`, `title`, `published`, `updated`, `summary`, and alternate `link`.
- A link with omitted `rel` or `rel="alternate"` is eligible; `rel="self"` is not. Relative `href` values are retained verbatim and are not resolved to absolute URLs.
- Required feed fields are `id`, `title`, and `updated`; required entry fields are `id`, `title`, and `updated`. Missing or blank values are recoverable diagnostics located at the field, or its feed/entry parent when absent.
- Reads direct feed/entry `author` person constructs and their direct `name`, `uri`, and `email` children. Effective entry authors use the first available layer: entry authors, then direct `entry/source` authors, then feed authors. Layers are never combined. An author lacking a non-blank direct `name` gets `InvalidAuthor` at its element; if no valid layer exists, the entry gets `MissingEntryField(_, "author")`. A feed may omit authors when every entry has a valid own/source author.
- Reads direct feed and entry `category` elements. Atom `term` is required; optional `scheme` and `label` stay distinct from RSS `domain`. Missing/blank terms receive an `InvalidCategory` at the category element.
- Reads only direct Atom entry `link` elements with `rel="enclosure"` as attachments. This does not change alternate-link selection. Missing `href` skips the attachment; invalid optional `length` is diagnosed and omitted from an otherwise valid attachment.
- An entry without a `content` element must have an alternate link. The parser tracks that presence separately from successful body extraction, so an unsupported or external content element does not incorrectly trigger `MissingAlternateLink`.
- Supports inline Atom `content` with omitted/`text` type and `html` type as `Entry.content`. Values retain XML-decoded source text and original whitespace, and `content_kind` records `Text` or `Html`.
- External Atom content (`src`) is never fetched or exposed as a body. It receives `UnsupportedAtomContent("external Atom content")`; when it lacks `summary`, it also receives the existing missing-summary diagnostic.
- XHTML/other content media types and nested XML in inline content are diagnosed as unsupported; FeedLens never strips their markup and calls it supported content. The same text-construct boundary applies to title, subtitle, and summary.

## JSON Feed 1.0 and 1.1

- Accepts only root objects whose `version` is exactly `https://jsonfeed.org/version/1` or `https://jsonfeed.org/version/1.1`. JSON is selected whenever the first non-whitespace input character is not `<`; XML dispatch remains unchanged.
- `title` must be a string and `items` must be an array. Invalid JSON, a non-object root, absent/wrong-type `version`, absent/wrong-type `title`, absent/wrong-type `items`, and unsupported versions are fatal JSON-specific `ParseError` values, never `InvalidXml`.
- Maps `title`, `description`, `home_page_url`, and `feed_url`; maps item `id`, `url`, `title`, `summary`, `date_published`, `date_modified`, `content_text`, and `content_html`. Text fields are `Text`; `content_html` is `Html` and is retained unchanged. No URI or date parsing occurs.
- Both content fields are legal. When both are valid strings, `content_html` deliberately wins because it preserves the richer declared representation; the unified model exposes one `Entry.content`. An item must have one valid content field. A malformed/missing item `id` or content discards that item with `InvalidJsonFeedItem`; a JSON number id is retained as its JSON spelling. Optional malformed item fields are diagnosed and become `None`.
- Supports `authors` arrays and deprecated `author` objects at feed/item level. If `authors` is present it wins, even over `author`; undeclared item authors inherit feed authors. A JSON Feed author needs a non-blank `name` or `url`, and its URL is exposed through `Author.uri`.
- Maps item `tags` to ordered categories. Empty tags and malformed optional fields are diagnosed and skipped. Unknown extension keys are ignored.
- Maps each valid item `attachments` array element in order, preserving URL, MIME type, optional title, integer byte size, and floating-point duration. A malformed attachment is diagnosed without discarding its valid item. Invalid optional metadata is omitted; unknown attachment extension keys are ignored.
- JSON syntax errors retain a parser position. The core JSON DOM does not retain semantic-field spans, so JSON Feed field/item diagnostics use document position `(1, 1)`; XML diagnostics continue to point to their source elements.

## Not supported

- Attachment retrieval or verification; JSON Feed pagination following, icons, favicons, author avatars, language, expired state, and extension fields; network retrieval; date parsing; and URI resolution.
- RSS versions other than 2.0, and RSS core elements placed in a namespace.
- Atom XHTML serialization, external Atom-content retrieval, category hierarchy, and link URI resolution.

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

On Windows, from the module root:

```powershell
moon run --target native cmd/main samples/rss2_compat.xml
moon run --target native cmd/main samples/atom1_compat.xml
moon run --target native cmd/main --json samples/jsonfeed11_compat.json
moon run --target native cmd/main --json samples/jsonfeed11_attachments.json
moon run --target native cmd/main -- --help
```

The extra `--` in the help command is required by Moon 0.1.20260920 so that
`--help` reaches FeedLens rather than being consumed by `moon run` itself.

Normal output is a short, human-readable summary:

```text
Format: RSS 2.0
Title: RSS & Compatibility
Link: https://feeds.example.test/rss
Entries: 2

1. identifier: rss-item-1
   title: First & Main
   link: https://example.test/posts/1
```

`--json` writes exactly one JSON value to stdout. It contains the normalized
`Feed`/`Entry` fields, text kinds, ordered author/category/attachment arrays, and ordered
diagnostics with positions. Missing values are JSON `null`. This is FeedLens's
normalized inspection format, **not** a conversion to a JSON Feed document.
Errors (bad arguments, unreadable files, or fatal parse errors) go to stderr and
return exit code `2`; `--help` and successful parsing return `0`. Recoverable
feed diagnostics are written into normal output and still return `0`. In
`--json` mode, no status/error text is written to stdout.

The CLI is exercised on the Native backend in this environment. Its file IO and
exit implementation uses verified `moonbitlang/x@0.5.5` APIs in the executable
package only; the parser package itself does not import that dependency and is
still checked/tested on Wasm, JS, and Native.

## XML dependency

This module pins `Milky2018/xml@0.5.0`. The newer `0.6.1` was downloaded and
evaluated first, but cannot compile with this MoonBit toolchain because its source
uses the removed `Int32` type. `0.5.0` provides the same `NamespaceReader` API and
passes this project's verification, so it is the newest compatible version actually
installed here. Matching uses resolved namespace URIs instead of tag prefixes.

## Verification samples

`samples/` contains compact, synthetic RSS/Atom/JSON Feed compatibility and attachment samples
plus boundary and malformed-XML cases. `compatibility_test.mbt` embeds their
source text so Wasm, JS, and Native tests need no filesystem or network access.

For an end-to-end Native CLI check (including file IO, exit codes, stderr, and
PowerShell's standard `ConvertFrom-Json`), run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/check_cli.ps1
```

For a development-only independent comparison, use
`uv run --with feedparser==6.0.11 python tools/check_compatibility.py`.
The script compares only the declared field intersection in
`samples/reference_intersection.json`; it is not a MoonBit dependency. See
`samples/COMPATIBILITY.md` for actual reference version/results and intentional
normalization differences, including RSS link fallback for a missing guid.

GitHub-hosted Linux CI uses the latest official MoonBit toolchain. The local
toolchain remains `0.1.20260920`, but its versioned Linux download returned
HTTP 403 during CI preparation; pinning CI to that unavailable artifact would
make the workflow permanently fail.
