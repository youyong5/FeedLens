# Reader display metadata: phase-11 inventory

The source documents are the three public WP Tavern subscriptions captured on
2026-10-19 UTC, identified with full-response hashes in `REAL_WORLD.md`. The
checked-in projections preserve only selected fields; this table separates
what appeared in those full responses from specification-defined cases that
require synthetic fixtures. The values below were checked against the saved
local full responses before editing the projections.

| Format | Already parsed before phase 11 | Present in captured source but not parsed | Specified, not present in selected source/entries |
| --- | --- | --- | --- |
| RSS 2.0 | Channel title/link/description; item IDs, dates, authors/categories, body, enclosure | Direct channel `language=en-US`; direct channel `image` with URL, title, link and 32 × 32 dimensions | Blank or malformed image/language; wrong-namespace lookalikes |
| Atom 1.0 | Feed/entry core, authors/categories, body, alternate/enclosure links | Feed `xml:lang=en-US`; direct feed `icon` URL | Feed `logo`; entry `xml:lang` override/reset; nested scoped `xml:base` on icon/logo; wrong namespace |
| JSON Feed 1.1 | Feed/item core, authors/tags, body, attachments | Feed `language=en-US`, `icon`; item `image` for both selected entries | Feed `favicon`; item `language`, `external_url`, `banner_image`; wrong types |

RSS image is channel identification, Atom distinguishes small square `icon`
from wider `logo`, and JSON Feed distinguishes timeline `icon` from source-list
`favicon`. JSON item `image` is a featured preview, while `banner_image` is
for the detail view. JSON `external_url` is a related outside page, not the
item's permalink. Those roles must not be collapsed into existing attachment
or permalink fields. RSS and Atom have no standardized item field with exactly
the JSON `external_url`/featured/banner meanings in the supported core.

Scope decision: implement these direct, standard fields only. Preserve
case/spelling of nonblank language tags instead of guessing or canonicalizing
them. JSON Feed `language` belongs to 1.1, not 1.0. Feed and entry languages
will be effective values: an explicit entry value overrides feed inheritance;
an explicit empty Atom `xml:lang` resets inherited language to unknown.
Fields absent from the real source are covered by clearly synthetic samples.

Primary specifications: [RSS 2.0](https://www.rssboard.org/rss-specification),
[Atom RFC 4287](https://www.rfc-editor.org/rfc/rfc4287),
[JSON Feed 1.0](https://www.jsonfeed.org/version/1/), and
[JSON Feed 1.1](https://www.jsonfeed.org/version/1.1/).
