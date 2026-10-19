# Initial-review functionality and verification data

This is a source-linked checklist for a project application or review, not an
application form. It contains no private contact information.

| Capability to report | Implementation and evidence | Boundary to state |
| --- | --- | --- |
| Multi-format parsing | `feedlens.mbt`, `atom.mbt`, `jsonfeed.mbt`; RSS 2.0, Atom 1.0, JSON Feed 1.0/1.1 samples in `samples/` | Not every extension or feed format is supported. |
| Unified entry model | `pkg.generated.mbti`; source-preserving authors, categories, content kinds, and ordered attachments | HTML is retained, not rendered or sanitized. |
| Offline real-feed exercise | `samples/REAL_WORLD.md`, three `real_wptavern_*` projections, `real_samples_test.mbt` | Reduced projections of two entries, not complete live feeds. No runtime network dependency. |
| Date validation | `date.mbt`, `date_test.mbt`; `normalize_date` returns a UTC instant or an explicit error | Raw dates remain unchanged; no local timezone inference; unsupported date forms remain raw. |
| Relative URL resolution | `uri.mbt`, `uri_feed.mbt`, `uri_test.mbt`; opt-in `parse_with_source` | Requires a caller-provided document URL; only documented common URL fields are resolved. |
| Local inspection | `cmd/main`, `cmd/render`, `tools/check_cli.ps1` | Native CLI reads local files only; it is not a crawler or JSON Feed converter. |
| Independent reference | `tools/check_compatibility.py`, `samples/reference_intersection.json`, `samples/COMPATIBILITY.md` | feedparser 6.0.11 comparison covers a declared XML field intersection, not full semantic equivalence or JSON Feed. |

For repeatable verification, run `moon fmt`, `moon info`, the Wasm/JS/Native
`moon check` and `moon test` commands in the README, then
`tools/check_cli.ps1` and `tools/check_compatibility.py`. GitHub Actions run
the three library targets and Native CLI smoke cases; inspect the actual run
status rather than inferring success from a local test.
