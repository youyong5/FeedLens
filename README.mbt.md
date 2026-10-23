# FeedLens — MoonBit 多格式 Feed 解析库

`youyong5/feedlens` is a reusable MoonBit multi-format Feed parsing library
for tested common behavior of RSS 2.0, Atom 1.0, and JSON Feed 1.0/1.1,
including independent Atom Entry Documents. The documented gaps still prevent
a full standards conformance claim. Diagnostics and the local-file
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
| `Feed.updated_at` | channel `lastBuildDate` | feed `updated` | none |
| `Feed.published_at`, `Feed.ttl_minutes` | channel `pubDate`, `ttl` | none | none |
| `Feed.skip_hours`, `Feed.skip_days` | direct channel `skipHours/hour` (GMT 0–23), `skipDays/day` (English weekday) | empty arrays | empty arrays |
| `Feed.docs_url`, `Feed.rating`, `Feed.cloud`, `Feed.text_input` | direct channel `docs`, raw `rating`, `cloud`, `textInput`; no registration or form submission | none | none |
| `Feed.rights`, `Feed.generator` | channel `copyright`, `generator` | feed `rights`, `generator` | none |
| `Feed.next_url`, `Feed.expired`, `Feed.hubs` | none | none | `next_url`, `expired`, `hubs` |
| `Entry.identifier` | non-blank `guid`, otherwise non-blank `link` | entry `id` | item `id` |
| `Entry.description` | item `description` | entry `summary` | `summary` |
| `Entry.content` | Content Module `content:encoded` | inline text/HTML/XHTML display string; not XML/binary/external bodies | `content_html`, otherwise `content_text` |
| `Entry.content_source` | none | external `content src`, raw with `parse`, resolved with `parse_with_source` | none |
| `Entry.content_media_type` | none | declared `content type` spelling, if present | none |
| `Entry.atom_body` | none | detailed inline or external Atom body | none |
| `Entry.atom_source` | none | original feed `source` id/title/subtitle/updated, rights, generator (including uri/version), links, images, people and categories, separately from the aggregated entry | none |
| `Author.uri` | none | feed/entry/source author or contributor `uri`; raw in `parse`, scoped by `xml:base` in `parse_with_source` | author `url` |
| `Entry.content_text`, `Entry.content_html` | none | none | both item forms independently |
| `Entry.comments_url`, `Entry.source_url`, `Entry.source_title` | item `comments`, `source/@url` and source channel title | none | none |
| `Entry.guid_is_permalink` | `guid/@isPermaLink`, default true on a usable guid | none | none |
| `Feed.managing_editor`, `Feed.webmaster` | channel editorial and technical contact text | none | none |
| `Entry.rights` | none | own `rights`, otherwise inherited feed `rights`; explicit empty text blocks inheritance | none |
| `Entry.published_at` | item `pubDate` | entry `published` | `date_published` |
| `Entry.updated_at` | none | entry `updated` | `date_modified` |
| `Feed.authors` | none | direct feed authors | `authors`, otherwise legacy `author` |
| `Entry.authors` | direct item authors | effective entry authors | item `authors`/`author`, otherwise feed authors |
| `Feed/Entry.contributors` | none | direct contributors, separate from author inheritance | none |
| `Feed/Entry.links` | none | ordered Atom link relations and common attributes | none |
| `Author.avatar` | none | none | author `avatar` URL |
| `Feed.categories` | direct channel categories | direct feed categories | none in supported subset |
| `Feed.images` | direct channel image | direct feed icon/logo | feed icon/favicon |
| `Entry.categories` | direct item categories | direct entry categories | `tags` |
| `Entry.attachments` | direct item `enclosure` | direct entry `link rel="enclosure"` | item `attachments` |
| `Entry.external_url` | none | none | item `external_url`, separate from `url` permalink |
| `Entry.images` | none in supported core | none in supported core | item `image` (featured preview), `banner_image` (detail banner) |

`title` and `link` have the same meaning across supported formats. There are no duplicate
format-specific public values for these convenience fields. Atom `links`
add the full ordered link list, while `link` remains the first alternate.
`title_kind`
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

`AtomBody` is the detailed, independent Atom body union: `InlineText(value,
media_type)` (including case-insensitive MIME `text/*`), `InlineHtml(value)`
(only Atom's literal `type="html"`), `InlineXhtml(fragment)`,
`InlineXml(XmlFragment, media_type)`, `InlineBinary(Bytes, media_type)`, and
`External(AtomExternalContent)`. `XmlFragment.markup` is deterministic,
namespace-qualified XML serialization retaining child elements, attributes,
mixed text, comments, processing instructions, and meaningful whitespace;
unlike XHTML it does not strip a div. Its `language` and ordered raw
`base_references` retain the content construct's inherited context. The
external struct has raw `src`, current `url`, optional declared `media_type`,
and `base_uri` only when an absolute effective base is known. `parse(input)`
keeps the source spelling in `src` and `url`; `parse_with_source` resolves `url`
against the supplied document URL and scoped `xml:base` while retaining `src`.
The already-public `content_source`/`content_media_type` convenience fields
remain for existing callers; `content_source` follows the current resolved URL
and therefore does not itself retain raw `src` after `parse_with_source`.
An absolute `xml:base` can provide a known `base_uri` even for `parse(input)`.
No external content is retrieved. `Bytes` supplies exact decoded octets on
all targets; the CLI emits padded Base64 and `byte_length`, never a lossy JSON
string. XML and binary bodies leave legacy `Entry.content = None`; existing
inline text/HTML/XHTML strings retain their previous meaning.

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

RSS accepts the common RFC 822/1123 profile with a two- or four-digit year, optional
weekday, `HH:MM` or `HH:MM:SS`, and numeric `±HHMM`, `UT`/`UTC`/`GMT`, or
US `EST`/`EDT`/`CST`/`CDT`/`MST`/`MDT`/`PST`/`PDT` zones. A stated weekday
must agree with the calendar date. Atom and JSON Feed require RFC 3339 with an
explicit offset or `Z`, and support any positive number of fractional-second
digits. `utc` preserves every digit; `nanosecond` retains the first nine digits
(zero-padded when needed) and truncates finer precision, while
`Fraction(digits)` reports the declared count. Calendar dates, times, and
offsets are validated. Two-digit RSS years `00–49` map to `2000–2049` and
`50–99` to `1950–1999`, following RFC 2822's obsolete-year interpretation.
Unknown-offset `-0000`/`-00:00` and leap-second `:60` are not normalized;
the raw field is still available.
No date is substituted from
the file timestamp, fetch time, or local clock.

`Author` preserves source semantics through `source`, `name`, `uri`, and `email`.
RSS core item `author` values are exposed only as their original `email` text (`source = Rss2`);
FeedLens does not infer a name from it. A direct item Dublin Core `creator`
under the exact `http://purl.org/dc/elements/1.1/` namespace maps to
`name` with `source = DublinCore`; both kinds retain document order. Atom authors are person constructs
(`source = Atom1`) with a required `name` element (which may be empty) and optional `uri`/`email`.
JSON Feed authors (`source = JsonFeed`) map `name` and `url` to `name` and `uri`;
a declared name (including an empty string), a non-blank URL, or a non-blank avatar suffices; JSON Feed has no mapped `email` field.
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
declare non-blank `url` and `mime_type`. When JSON Feed omits or misstates the
required `mime_type`, the reader retains the attachment URL with `media_type =
None` and an `InvalidAttachment` diagnostic; a missing/blank URL still drops
that attachment. Atom's optional link `title` and JSON
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

The opt-in source entry point resolves `Feed.link`, `Entry.link`,
`Entry.attachments[].url`, feed-image URLs (and RSS image link), JSON item
`external_url`, JSON item-image URLs, next/hub URLs and author avatars using RFC 3986 path, root-path, query,
fragment, and dot-segment rules. RSS and JSON Feed use the caller-supplied document URL;
Atom additionally applies the inherited `xml:base` on the feed, entry, link,
and any intervening XML elements, matching the XML namespace URI rather than
an arbitrary `base` attribute. JSON Feed's declared `feed_url` and
`home_page_url` are **not** substituted as a fetch-location base. Without a
usable base, or for a malformed URI reference, the raw field is retained and
`UnresolvedUri` is recorded; XML diagnostics point to the relevant element,
whereas JSON semantic diagnostics are `(1, 1)`. An invalid explicit source URL
is a fatal `InvalidSourceUrl` error. No URI is fetched.
Bracketed HTTP(S) hosts require an IPv6 or RFC 3986 IPvFuture literal; malformed
brackets, invalid IPv6 and the old `%25ZoneID` URI form are rejected. IPvFuture
is syntax-checked only; FeedLens never dereferences that address mechanism.

Identifiers (`guid`, Atom `id`, JSON Feed `id`) stay opaque and unchanged when
usable, including the RSS link-fallback identifier. JSON Feed items with blank
IDs are discarded with a diagnostic; nonblank IDs retain surrounding spaces.
JSON author URLs and avatars,
RSS comments/source URLs and every direct Atom link are resolved; Atom author/contributor URIs use their own element-scoped `xml:base`;
RSS category domains, Atom category schemes and URLs inside HTML are not resolved.
Atom content `src` uses its own `xml:base` scope.
Existing `parse` callers are unaffected; callers
that need the original references can continue using it.

`parse_document(input)` adds a typed `FeedDocument(feed)` / `AtomEntryDocument(entry,
diagnostics)` result for stand-alone Atom Entry Documents. It uses the same
content and author logic as a feed entry, without inventing feed fields.
`parse_document_with_source` applies source and entry `xml:base` to its links.
The original `parse` and `parse_with_source` feed return types remain unchanged.

## RSS 2.0

- RSS 2.0 documents with an unnamespaced `<rss version="2.0">` root.
- Reads direct channel `language` and direct `image` (required URL/title/link,
  optional description and declared dimensions). RSS items inherit the
  channel language; wrong-namespace lookalikes do not count.
- A direct `<channel>` child of `<rss>`; channel metadata and `<item>` elements must be direct channel children.
- Channel `title`, `link`, and `description`; item `guid`, `title`, `link`, `description`, and `pubDate`, retained in document order.
- Channel `pubDate`, `lastBuildDate`, `copyright`, `generator` and nonnegative
  `ttl`; item `comments` and source `url`. Invalid TTL gets a located diagnostic.
- Direct channel `skipHours` and `skipDays` are advisory GMT polling hints, kept in source order in `Feed.skip_hours` and `Feed.skip_days`. A blank/invalid child, more than 24 hours or seven days, or a repeated container gets a located diagnostic; valid earlier values remain usable. Foreign-namespace or nested lookalikes are ignored. The library does not schedule network requests.
- Namespace-aware matching: elements in other namespaces, or at another hierarchy level, never fill RSS core fields.
- XML errors, unsupported roots, unsupported RSS versions, and a missing channel are fatal `ParseError` values.
- Missing or whitespace-only fields are recoverable and become `None`. `Feed.diagnostics` reports each missing required channel field and an item with neither a usable title nor a description. A blank channel field diagnostic points at that field; an absent one points at `<channel>`. An item-content diagnostic points at `<item>`. A valid title-only or description-only item may have no identifier.
- An item's `identifier` is its non-blank `guid`, falling back to its non-blank `link`. The `guid` value remains opaque; `guid_is_permalink` preserves the declared `isPermaLink` role (default true for a usable guid), without fetching or resolving the identifier. Unknown attribute values receive `InvalidRssField`.
- RSS item source credit keeps the source channel title separately from its required `url`. The channel's `managingEditor` and `webMaster` contact texts remain separate from entry authors.
- RSS core fields containing nested XML markup are not flattened: their value becomes `None` and `UnsupportedNestedMarkup` identifies the field location. Plain text, XML entities, and CDATA remain supported.
- Supports a direct item child named `content:encoded` only when its resolved namespace URI is exactly `http://purl.org/rss/1.0/modules/content/`. Its XML-decoded text or CDATA is exposed as `Entry.content` with `content_kind = Unspecified`; it is independent from `description`. Nested XML is rejected with the same explicit nested-markup diagnostic policy.
- Reads direct channel and item `category` elements in document order. A category's non-blank text is its term and its optional `domain` remains RSS-specific. Reads direct item `author` text as an unparsed raw email value, and direct Dublin Core `creator` as an author name with a distinct source. Empty or nested creators get located diagnostics; wrong-namespace and nested lookalikes are ignored. Blank core authors/categories receive source-located `InvalidAuthor`/`InvalidCategory` diagnostics.
- Reads only direct, unnamespaced item `enclosure` elements. `url`, `length`, and `type` are required. Invalid enclosures are skipped with source-located `InvalidAttachment`; an invalid length never overflows.
- The public API exposes FeedLens types only; it does not expose `Milky2018/xml` types.

## Atom 1.0

- Accepts both `<feed>` and independent `<entry>` roots in the `http://www.w3.org/2005/Atom` namespace, whether declared as the default namespace or through a prefix. The established `parse` API remains feed-only; `parse_document` accepts both.
- Reads feed/entry `xml:lang` in the XML namespace, with feed-to-entry
  inheritance and explicit entry override/reset. Direct feed `icon` and
  `logo` remain separate image roles; each honors its own `xml:base` scope
  under `parse_with_source`.
- Maps feed `id`, `title`, `subtitle`, `updated`, and alternate `link` to the normalized public model; maps direct `entry` children in document order from `id`, `title`, `published`, `updated`, `summary`, and alternate `link`.
- A link with omitted `rel`, `rel="alternate"`, or the RFC 4287 registered equivalent `rel="http://www.iana.org/assignments/relation/alternate"` is eligible for the convenience `link`; all direct valid links are also kept in the ordered `links` array with their declared relation, href, type, hreflang, title and length. Equivalent alternate spellings share duplicate-link checks. `parse_with_source` resolves these links in their `xml:base` scope.
- Required feed fields are `id`, `title`, and `updated`; required entry fields are `id`, `title`, and `updated`. Missing or blank values are recoverable diagnostics located at the field, or its feed/entry parent when absent.
- Reads direct feed/entry `author` and `contributor` person constructs and their direct `name`, `uri`, and `email` children. Contributors remain separate from authors. Effective entry authors use the first available layer: entry authors, then direct `entry/source` authors, then feed authors. Layers are never combined. A missing direct `name` gets `InvalidAuthor` at its element; a present empty/whitespace name stays an author and blocks fallback to another layer. If no valid layer exists, the entry gets `MissingEntryField(_, "author")`. A feed may omit authors only when every entry has an own valid author; a standalone entry may use its source author.
- `Entry.atom_source` preserves the original feed's declared id, updated time, authors, contributors, categories, and text/HTML/XHTML title and rights, including XHTML fragments' language and base references. It does not replace the entry's own title or id. A source may omit all of these fields. Repeated source id/title/updated/rights and malformed source XHTML receive located diagnostics.
- Reads direct feed, entry and source `category` elements. Atom `term` is required but may be the empty string; optional `scheme` and `label` stay distinct from RSS `domain`. A missing term receives `InvalidCategory` at the category element. Declared `term`, `label`, `scheme`, link `title` and enclosure `title` retain their source strings, including empty/whitespace values.
- Reads only direct Atom entry `link` elements with `rel="enclosure"` or its registered IRI equivalent as attachments. This does not change alternate-link selection. Missing `href` skips the attachment; invalid optional `length` is diagnosed and omitted from an otherwise valid attachment. The original relation spelling stays in `links`; unrelated relation IRIs are not treated as enclosures.
- An entry without a `content` element must have an alternate link. The parser tracks that presence separately from successful body extraction, so an invalid or external content element does not incorrectly trigger `MissingAlternateLink`.
- Supports inline Atom `content` with omitted/`text`, `html`, and `xhtml` types as `Entry.content`. Text/HTML values retain XML-decoded source text and original whitespace. For XHTML, `content` is the concatenated display text while `content_xhtml.markup` retains the XML child structure and whitespace; `content_kind = Xhtml` prevents mistaking it for HTML or plain text.
- External Atom content (`src`) is exposed through the existing `content_source`/`content_media_type` convenience fields and as an `External` reference with raw and optionally resolved URL, optional MIME type, and known effective absolute base. It is not fetched. An explicitly empty `src=""` is a valid same-document IRI reference, distinct from a missing attribute; `href=""` in Atom links/enclosures follows the same rule. Nonempty external content or invalid whitespace-only `src`/media type receives a positioned diagnostic; a missing summary receives `MissingSummaryForExternalContent`.
- Other case-insensitive `text/*` MIME types retain decoded text and their exact declared media-type spelling as `InlineText`; MIME `text/html` is not mislabeled as Atom's special `type="html"`. XML media types ending `/xml` or `+xml` expose `InlineXml` without stripping a wrapper. Other non-composite MIME types are Base64-decoded to `InlineBinary(Bytes, media_type)`; bad encoding produces `UnsupportedAtomContent("invalid Atom Base64 content")`, not a text body. Binary content lacking `summary` gets `MissingSummaryForBinaryContent`. MIME token/major-type checks are applied, but parameters are not fully validated against the MIME grammar.
- Atom `title`, `subtitle`, `summary`, and inline `content` accept a single `div` in the exact XHTML namespace URI for `type="xhtml"`, regardless of prefix. The outer `div` is not part of `markup`; descendant elements/attributes/namespaces, mixed text, comments, processing instructions, and meaningful in-div whitespace are retained in deterministic XML serialization. `language` and `base_references` retain effective `xml:lang` and the inherited `xml:base` declaration chain even when declared on the removed div. Missing/wrong-namespace/multiple div roots or non-whitespace text outside div are diagnosed at the Atom field; no false complete value is exposed. Nested XML inside `text`/`html` constructs remains diagnosed. The serialization preserves XML content semantics, not original byte spelling of entities, prefixes, quote style, or attribute order independent of the parser. It is **not sanitized**; callers must apply safe rendering, escaping, and URI policy themselves. Neither entry point rewrites links inside XHTML markup.

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
entry.atom_body = Some(InlineXhtml(...))
```

`XhtmlFragment.base_references` retains raw scoped declarations rather than
guessing an absolute base from a local filename. Even with `parse_with_source`,
callers must combine that chain with the known source URL and nested child
`xml:base` before interpreting relative links in the fragment. The removed
outer div's non-inherited style/class attributes are not projected.

For the fixed [four-form Atom body sample](samples/atom1_content_forms.xml),
the public union has `External(src="entry.xml", url="entry.xml",
media_type=Some("application/xml"), base_uri=Some("https://example.test/feeds/media/"))`,
`InlineText("**Text & more**", "TEXT/MARKDOWN")`, an `InlineXml`
fragment containing `<n0:root ... n0:key="A&amp;B">one<n0:child .../>two</n0:root>`,
and `InlineBinary` with bytes `[1, 2, 3, 255]` and media type `IMAGE/PNG`.
The CLI exposes these respectively as `kind = external`, `inline_text`,
`inline_xml`, and `inline_binary`; the last has `base64 = "AQID/w=="` and
`byte_length = 4`. The CLI uses `parse`, so the external `url` is raw here;
the known absolute `xml:base` supplies `base_uri`. `parse_with_source` resolves
relative `src` from the caller's real document URL. All fragments and decoded
bytes are untrusted; FeedLens performs no sanitization, XML-media validation,
network access, or HTML rendering.

## JSON Feed 1.0 and 1.1

- Accepts only root objects whose `version` is exactly `https://jsonfeed.org/version/1` or `https://jsonfeed.org/version/1.1`. JSON is selected whenever the first non-whitespace input character is not `<`; XML dispatch remains unchanged.
- `title` must be a string and `items` must be an array. Invalid JSON, a non-object root, absent/wrong-type `version`, absent/wrong-type `title`, absent/wrong-type `items`, and unsupported versions are fatal JSON-specific `ParseError` values, never `InvalidXml`.
- Maps `title`, `description`, `home_page_url`, `feed_url`, `icon`, and `favicon`; maps item `id`, `url`, `external_url`, `image`, `banner_image`, `title`, `summary`, `date_published`, `date_modified`, `content_text`, and `content_html`. Version 1.1 also maps feed/item `language`. Text fields are `Text`; `content_html` is `Html` and is retained unchanged. Raw date strings can be independently validated through `normalize_date`; no URI resolution occurs during `parse`.
- `url` stays the item permalink, while `external_url` points to an outside
  page; a missing permalink is not replaced by the external URL. Featured and
  banner images are presentation hints, never attachments. JSON Feed 1.0
  does not define `language`, so 1.0 keys of that name are ignored.
- Both content fields are legal and independently exposed as `Entry.content_html` and `Entry.content_text`; `Entry.content` remains the HTML-preferred convenience field. An item must have one valid content field. A malformed/missing item `id` or content discards that item with `InvalidJsonFeedItem`; a JSON number id is retained as its JSON spelling. Optional malformed item fields are diagnosed and become `None`.
- Supports `authors` arrays and deprecated `author` objects at feed/item level. If `authors` is present it wins, even over `author`; undeclared item authors inherit feed authors. A JSON Feed author needs a non-blank `name`, `url`, or `avatar`; URL and avatar remain separate public fields.
- `next_url`, `expired`, and ordered `hubs` are parsed but never followed or subscribed to. An equal `feed_url`/`next_url` is diagnosed.
- Maps item `tags` to ordered categories. Empty tags and malformed optional fields are diagnosed and skipped. Unknown extension keys are ignored.
- Maps each valid item `attachments` array element in order, preserving URL, MIME type, optional title, integer byte size, and floating-point duration. A malformed attachment is diagnosed without discarding its valid item. Invalid optional metadata is omitted; unknown attachment extension keys are ignored.
- JSON syntax errors retain a parser position. The core JSON DOM does not retain semantic-field spans, so JSON Feed field/item diagnostics use document position `(1, 1)`; XML diagnostics continue to point to their source elements.

## Not supported

- Attachment/image retrieval or verification; JSON Feed pagination following and extension fields; network retrieval and unscoped URI/IRI fields listed above.
- RSS versions other than 2.0, and RSS core elements placed in a namespace.
- Atom external-content retrieval, comprehensive MIME-parameter validation, full XHTML/XML rendering or sanitization, and resolution inside HTML/XHTML or unsupported constructs. Some full-document ordering constraints, IRI/date grammar checks, and optional extension metadata remain outside the mapped behavior.

## Example

```moonbit nocheck
match @feedlens.parse(input) {
  Ok(feed) => {
    let entry = feed.entries[0]
    println(entry.identifier.unwrap_or("(no identifier)"))
    match entry.atom_body {
      Some(@feedlens.InlineBinary(bytes, media_type)) =>
        println(media_type + ": " + bytes.length().to_string() + " bytes")
      Some(@feedlens.External(reference)) =>
        println("external, not fetched: " + reference.url)
      _ => ()
    }
  }
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
moon run --target native cmd/main --json samples/atom1_content_forms.xml
moon run --target native cmd/main --json samples/rss2_optional_channel.xml
moon run --target native cmd/main --json samples/jsonfeed10_legacy_ids.json
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
`Feed`/`Entry` fields, text kinds, XHTML fragment objects and detailed Atom
body variants (or `null`), ordered
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
Run `uv run --with feedparser==6.0.11 python tools/check_real_cross_format.py`
for the two saved real-world entries across three formats and the independent
Atom Entry fixture. The JSON side uses Python's standard JSON and date parsers;
all inputs are local, editorially reduced samples.

GitHub-hosted Linux CI uses the latest downloadable MoonBit toolchain and has
an offline independent-reference job. Record the tested local MoonBit version
alongside the relevant CI run for any submission.
