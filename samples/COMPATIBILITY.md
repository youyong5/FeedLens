# Compatibility samples and reference comparison

These files are deliberately small and network-free: most are synthetic; the
`real_wptavern_*` files are reduced, source-traceable projections rather than
entire third-party feeds. They exercise only FeedLens's documented
RSS 2.0 / Atom 1.0 / JSON Feed surface.

| Sample | Purpose |
| --- | --- |
| `rss2_compat.xml` | RSS core fields, entities/CDATA, Content Module body, raw item author, categories, field reordering, and a wrong content URI. |
| `atom1_compat.xml` | Prefixed Atom namespace, alternate/self links, inline text/HTML body, direct/feed/source author layers, categories, and CDATA. |
| `atom1_xhtml.xml` | Fixed RFC 4287 XHTML acceptance document: feed/entry emphasized titles and entry paragraph/strong body. Mirrored byte-for-byte in `xhtml_test.mbt`. |
| `rss2_boundaries.xml` | Changed Content Module prefix, wrong-URI lookalikes, blank values, and nested body markup. |
| `atom1_boundaries.xml` | Wrong-namespace lookalikes, blank category, and invalid author. |
| `invalid_rss.xml` | A fatal malformed-XML case. |
| `jsonfeed11_compat.json` | JSON Feed 1.1 core fields, escaped Unicode, HTML/text body precedence, author inheritance, and tags. |
| `rss2_attachments.xml` | RSS direct item enclosures, order, byte sizes, and MIME types; parser and CLI fixture only. |
| `atom1_attachments.xml` | Atom alternate versus enclosure links, optional enclosure metadata, and order; parser and CLI fixture only. |
| `jsonfeed11_attachments.json` | JSON Feed attachment title, size, fractional duration, and order; parser and CLI fixture only. |
| `real_wptavern_rss.xml`, `real_wptavern_atom.xml`, `real_wptavern_json.json` | Editorially reduced projections of two corresponding podcast entries from live public subscriptions, with source URLs and capture hashes in `REAL_WORLD.md`; date, article link, and attachment regression cases. |
| `jsonfeed11_display.json` | Synthetic JSON Feed 1.1 fixture for language, feed icon/favicon, distinct permalink/external URL, and featured/banner item-image roles; parser and CLI fixture only. |
| `atom1_entry_document.xml` | Stand-alone Atom Entry Document with XHTML text/body, author, xml:base, alternate/enclosure links; independent feedparser and library regression. |
| `rss2_standard_fields.xml`, `atom1_standard_fields.xml`, `jsonfeed11_standard_fields.json` | Synthetic, byte-mirrored regressions for additional common fields and CLI output; not portrayed as live sources. |
| `rss2_metadata.xml` | Synthetic byte-mirrored RSS contacts, guid permalink role and source credit regression; independent feedparser intersection. |
| `rss2_anonymous_items.xml` | Synthetic byte-mirrored RSS title-only, description-only, and combined entries without guid/link; all remain usable without an identifier. Compared to feedparser 6.0.11 on title, description, and order. A separate library test checks the located diagnostic for empty and link-only items. |
| `rss2_high_precision_date.xml`, `atom1_high_precision_date.xml`, `jsonfeed11_high_precision_date.json` | Synthetic byte-mirrored cross-format dates for one UTC second. Atom and JSON retain 12/15 fractional digits with different offsets; the library regression checks complete UTC text and truncated nanosecond field. Independent feedparser/Python checks compare the common UTC second, while Python Decimal checks exact fractional values from the saved inputs; no independent library is claimed to verify the full FeedLens serialization. |
| `rss2_two_digit_years.xml` | Synthetic byte-mirrored RSS channel/item dates with legal two-digit years and offsets, including 00 and 99. Library regressions also check the 49/50 century boundary and mismatched weekday. feedparser 6.0.11 compares channel/item UTC seconds independently; raw strings remain unchanged in FeedLens. |
| `atom1_person_uris.xml` | Synthetic byte-mirrored Atom feed, entry and source Person URI scopes under nested XML Base, with independent feedparser comparison for explicit people. Source/feed author inheritance into normalized entries is checked by the library tests because feedparser 6.0.11 does not project those inherited authors on this fixture. |
| `atom1_source_metadata.xml` | Synthetic byte-mirrored Atom aggregation source metadata with XHTML title, HTML subtitle, generator, links, icon/logo, xml:lang/base and original author; independent feedparser intersection. feedparser 6.0.11 overwrites source.title with icon text on this fixture; the comparison reads title_detail.value. Source images are fixture-only assertions because its icon representation is not comparable. |

`compatibility_test.mbt` embeds the primary and boundary XML text so every
MoonBit target can run without filesystem access. The reference script byte-
checks the two primary embedded `#|` mirrors against their XML files before it
runs feedparser; assertions use the same field values and source-line layout
for diagnostic-location checks.

## Independent reference

The development-only reference is Python `feedparser==6.0.11`, declared in
`tools/requirements-reference.txt`; it is not a MoonBit dependency and no
MoonBit test invokes it. Re-run the comparison with:

```powershell
uv run --with feedparser==6.0.11 python tools/check_compatibility.py
uv run --with feedparser==6.0.11 python tools/check_xhtml_reference.py
```

It reads only the two primary local XML files and compares the explicitly
declared intersection in `reference_intersection.json`:

- RSS: feed title/link/description; entry guid-derived id when present,
  title/link/description/pubDate.
- Atom: feed id/title/alternate link/subtitle/updated; entry
  id/title/alternate link/summary/published/updated.

Reference run in this environment on 2026-10-14:

```text
feedparser 6.0.11
PASS mirror rss2_compat.xml
PASS mirror atom1_compat.xml
PASS rss2_compat.xml
PASS atom1_compat.xml
```

On 2026-10-21, the separate XHTML comparison used the installed
`feedparser 6.0.11` and the byte-identical `samples/atom1_xhtml.xml` /
`xhtml_test.mbt` mirror. All eight declared intersections agreed: feed id,
display-title text and XHTML media type; entry id, display-title text and
XHTML media type; entry body display text and XHTML media type. The script
also confirmed FeedLens returned namespaced child XML fragments. Exact
serialization was intentionally **not** compared because feedparser returns
sanitized HTML-like values (`Plan <em>A</em> &amp; B` and
`<p>Lap <strong>12</strong> &amp; rain.</p>`), whereas FeedLens returns
canonical namespace-qualified XML (`h:` prefix) without sanitization.
In an independent unsafe-attribute probe, feedparser removed `onclick` from
`<span onclick="alert(1)">`, while FeedLens's MoonBit regression confirms
the original XML attribute remains. Rendering FeedLens fragments therefore
requires an application-level sanitizer/URI policy; no safety equivalence is
claimed.

A repeat run on 2026-10-19 with the same feedparser 6.0.11 also passed all
five checked-in/embedded mirrors (the two original XML cases and three real
projections) and both declared XML intersection comparisons. The script
performs no network request during the comparison.

## Intentional differences

- FeedLens assigns an RSS item's `identifier` from `link` when `guid` is
  absent. feedparser leaves its `id` absent in that case, so the field is
  outside the comparison intersection for such entries.
- FeedLens rejects malformed XML and reports source-located diagnostics for
  blank/unsupported structures. feedparser's tolerant recovery is not a
  compatibility target.
- FeedLens retains source-specific author/category metadata and HTML/body text
  kinds; those fields are intentionally outside this small cross-library
  intersection.
- XHTML text/kind agrees on the safe acceptance fixture, but the serialized
  markup differs by design: FeedLens retains resolved namespace semantics and
  unsafe attributes; feedparser's default sanitizer may alter or remove them.
- `jsonfeed11_compat.json` is a parser regression sample only. The independent
  `feedparser` reference intentionally covers its XML formats, not JSON Feed.

No parser defect was found by this reference comparison. The identified RSS
identifier difference is documented, pre-existing FeedLens behavior.

The original `check_compatibility.py` does not compare real projections with
feedparser. The new `tools/check_real_cross_format.py` independently parses
their saved XML projections with feedparser 6.0.11 and their JSON projection
with Python's standard JSON/date libraries, then compares the declared
intersection with Native CLI output: two ordered article permalinks, UTC
publication instants, audio URLs and integer byte sizes. It separately uses
feedparser's Atom Entry Document support to check the independent fixture's
ID, XHTML display text, `xml:base` link references and enclosure. Seven new
file/test mirrors are checked byte-for-byte. The Atom Person URI fixture compares
feed, entry and source explicit people against feedparser and independently
checks URI joining with Python; inherited entry authors remain library regression
assertions. It does not compare omitted long
bodies, claim equivalence of opaque XML/JSON IDs, or fetch live sources.
The phase-11 display metadata and JSON Feed fixture are parser regressions,
not part of the older feedparser XML intersection.
