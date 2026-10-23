# Initial-review functionality and verification data

This is a source-linked checklist for a project application or review, not an
application form. It contains no private contact information.

| Capability to report | Implementation and evidence | Boundary to state |
| --- | --- | --- |
| Multi-format parsing | `feedlens.mbt`, `atom.mbt`, `jsonfeed.mbt`; RSS 2.0, Atom 1.0, JSON Feed 1.0/1.1 samples in `samples/` | Not every extension or feed format is supported. |
| Unified entry model | `pkg.generated.mbti`; source-preserving authors, categories, content kinds, and ordered attachments | HTML is retained, not rendered or sanitized. |
| Reader display metadata | `language_test.mbt`, `feed_image_test.mbt`, `entry_display_test.mbt`, `samples/DISPLAY_FIELD_INVENTORY.md` | Source-specific image roles and JSON outside links are kept distinct; no image is fetched. |
| Offline real-feed exercise | `samples/REAL_WORLD.md`, three `real_wptavern_*` plus three publisher-diverse projections, `real_samples_test.mbt`, `diverse_real_test.mbt` | Reduced archived projections, not complete current live feeds. xkcd is missing required Atom authors and is expected to diagnose. No runtime network dependency. |
| Date validation | `date.mbt`, `date_test.mbt`, `date_unknown_offset_test.mbt`; `normalize_date` returns a UTC instant or an explicit error | Raw dates remain unchanged; RFC 3339 `-00:00` and RSS `-0000` return UTC with `offset_known=false`; no local timezone inference; unsupported date forms remain raw. |
| Relative URL resolution | `uri.mbt`, `uri_feed.mbt`, `uri_test.mbt`; opt-in `parse_with_source` | Requires a caller-provided document URL; only documented common URL fields are resolved. |
| Local inspection | `cmd/main`, `cmd/render`, `tools/check_cli.ps1` | Native CLI reads local files only; it is not a crawler or JSON Feed converter. |
| Public-library consumer | `examples/consumer`, `tools/check_consumer.ps1` | Imports the library directly from this checkout; no published package or CLI runtime dependency. |
| Independent reference | `tools/check_compatibility.py`, `samples/reference_intersection.json`, `samples/COMPATIBILITY.md` | feedparser 6.0.11 comparison covers a declared XML field intersection, not full semantic equivalence or JSON Feed. |
| Independent Atom Entry | `parse_document`, `atom_document_test.mbt`, `samples/atom1_entry_document.xml` | `parse` remains feed-only; typed document API handles independent entries. |
| Common standard fields and constraints | `standard_fields_test.mbt`, three `samples/*standard_fields*` files, `docs/STANDARD_SCOPE.md` | Remaining legal core/optional constructs and full validation gaps are recorded, not claimed complete. |
| Cross-format independent result | `tools/check_real_cross_format.py`, `tools/check_diverse_real_reference.py`, `samples/REAL_WORLD.md` | Two matching podcast episodes and three other publisher snapshots; feedparser XML and Python JSON/date intersections only, no live feed fetch. |
| RSS creator names | `rss_dublin_creator_test.mbt`, `samples/rss2_dublin_creator.xml`, `real_hn_rss.xml`, `tools/check_diverse_real_reference.py` | Exact Dublin Core namespace, item scope and distinct `AuthorSource`; other Dublin Core terms remain unmapped. |

For repeatable verification, run `moon fmt`, `moon info`, the Wasm/JS/Native
`moon check` and `moon test` commands in the README, then
`tools/check_cli.ps1` and `tools/check_compatibility.py`. GitHub Actions run
the three library targets and Native CLI smoke cases; inspect the actual run
status rather than inferring success from a local test.
