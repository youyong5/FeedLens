# Real-feed offline projections (2026-10-19 UTC)

These three small files are field-preserving, editorially reduced projections
of public WP Tavern subscriptions fetched on 2026-10-19. They are **not**
verbatim copies of the full feeds. The first two podcast entries, their IDs,
dates, alternate URLs, category order, and enclosure/attachment URL, type,
and byte size were retained. Long descriptions and transcripts were omitted;
JSON Feed's required `content_text` was shortened to its opening words.
XML whitespace and some equivalent entity spellings were compacted. No media
files were fetched. The original live documents each contained 30 entries.

| Format | Original subscription URL | Checked-in projection | SHA-256 of full response at capture |
| --- | --- | --- | --- |
| RSS 2.0 | <https://wptavern.com/feed/> | `real_wptavern_rss.xml` | `B91411E918E5980D9715BA6414E37E1E6E0ACDFFC76B7491D71E21234BD92BD5` |
| Atom 1.0 | <https://wptavern.com/feed/atom> | `real_wptavern_atom.xml` | `FC6E823ED4A2263B9F20E197DBD4EFD1A305CE63CA3FE5636E7384D7B45D2E5C` |
| JSON Feed 1.1 | <https://wptavern.com/feed/json> | `real_wptavern_json.json` | `0596CD41122BC5F7E24683838D903D2093E3B034FEB72178E85A5C987BFD61E5` |

The selected entries are WP Tavern podcast episodes #237 and #236. They are
representative of the publisher's three-format output and expose the *same*
audio files in RSS `enclosure`, Atom `link rel="enclosure"`, and JSON Feed
`attachments`. The first file has `audio/mpeg`, `37878054` bytes; the second
has `audio/mpeg`, `39694700` bytes. Each entry has one attachment; the
existing synthetic `*_attachments` samples exercise multiple attachments
within one entry and their order.

## Baseline before phase-10 parser changes

The unedited full responses were run through `moon run --target native cmd/main
<local-captured-file>` before implementation. Each exited `0` and produced
30 entries. The first two entries retained their original order, distinct
article links, and attachment URL/type/size. The checked-in projections also
passed 64/64 Native tests (61 earlier tests plus three real-sample tests).

Two actionable gaps were visible:

- Dates were raw strings only: episode #237 was `Wed, 14 Oct 2026 13:00:00
  +0000` in RSS, `2026-10-14T13:00:00Z` in Atom, and
  `2026-10-14T14:00:00+01:00` in JSON Feed. Callers had no shared, validated
  instant for comparison. The live JSON Feed also has `date_modified` with a
  `+01:00` offset.
- The parser preserved URI references without resolution. These three live
  feeds used absolute article and attachment URLs, so relative-URI behavior
  must be checked with explicit offline boundary samples rather than falsely
  attributed to this publisher.

Two differences are publisher/source semantics, not parser defects: WP Tavern
JSON Feed puts the literal HTML entity `&#038;` in an `id`, while XML parsing
decodes its equivalent to `&`; FeedLens intentionally treats JSON IDs as
opaque strings. Atom's `type="html"` titles contain text such as `&#8211;`,
which FeedLens preserves as HTML source text rather than rendering it.

`real_samples_test.mbt` embeds byte-matched mirrors of these files for Wasm,
JS, and Native; `tools/check_compatibility.py` verifies the mirrors offline.
The existing independent feedparser comparison remains limited to its declared
older XML intersection fixtures; these editorial projections are parser
regression samples, not new feedparser reference claims.
