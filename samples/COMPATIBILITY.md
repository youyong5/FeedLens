# Compatibility samples and reference comparison

These files are deliberately small, synthetic, and network-free. They exercise
only FeedLens's documented RSS 2.0 / Atom 1.0 / JSON Feed surface; they are not copies of
third-party feeds.

| Sample | Purpose |
| --- | --- |
| `rss2_compat.xml` | RSS core fields, entities/CDATA, Content Module body, raw item author, categories, field reordering, and a wrong content URI. |
| `atom1_compat.xml` | Prefixed Atom namespace, alternate/self links, inline text/HTML body, direct/feed/source author layers, categories, and CDATA. |
| `rss2_boundaries.xml` | Changed Content Module prefix, wrong-URI lookalikes, blank values, and nested body markup. |
| `atom1_boundaries.xml` | Wrong-namespace lookalikes, blank category, and invalid author. |
| `invalid_rss.xml` | A fatal malformed-XML case. |
| `jsonfeed11_compat.json` | JSON Feed 1.1 core fields, escaped Unicode, HTML/text body precedence, author inheritance, and tags. |

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
- `jsonfeed11_compat.json` is a parser regression sample only. The independent
  `feedparser` reference intentionally covers its XML formats, not JSON Feed.

No parser defect was found by this reference comparison. The identified RSS
identifier difference is documented, pre-existing FeedLens behavior.
