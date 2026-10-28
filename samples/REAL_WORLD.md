# Real-feed offline projections

## Additional publisher corpus (pinned public archive)

The public [mojo-feed fixture archive](https://github.com/conorbronsdon/mojo-feed/tree/be9e1dbc17faea2723fa3224512f184738adb43d/test/data) contains snapshots from three other publishers. We copied them from archived commit `be9e1dbc17faea2723fa3224512f184738adb43d`; we did **not** request the publishers' current feeds in October 2026. The archive's `test_real_feed.mojo` identifies each publisher, and the snapshot contents contain the publication dates below. The archive capture timestamps are not known.

| Publisher / format | Archived original, SHA-256 | Checked-in file and transformation |
| --- | --- | --- |
| [Hacker News front page](https://hnrss.org/frontpage), RSS 2.0 | [`rss_hn.xml`](https://github.com/conorbronsdon/mojo-feed/blob/be9e1dbc17faea2723fa3224512f184738adb43d/test/data/rss_hn.xml), `70083349c25d7778751f63cccc787cb7a75df85e4fa566faaa5662300d0bfbd2` | `real_hn_rss.xml`: first two of 20 items; ElementTree rewrites prefixes, CDATA and indentation but retains selected XML values. Items dated 2026-07-05. |
| [xkcd](https://xkcd.com/atom.xml), Atom 1.0 | [`atom_xkcd.xml`](https://github.com/conorbronsdon/mojo-feed/blob/be9e1dbc17faea2723fa3224512f184738adb43d/test/data/atom_xkcd.xml), `34ca646019ac7b8974e88dd76a2abe843000a94cdcdeaec08d216b700e8f0886` | `real_xkcd_atom.xml`: all four entries, original bytes with one final newline added for the MoonBit mirror. Entries updated in July 2026. |
| [Recompiled](https://www.recompiled.dev/feed/feed.json), JSON Feed 1.1 | [`jsonfeed_recompiled.json`](https://github.com/conorbronsdon/mojo-feed/blob/be9e1dbc17faea2723fa3224512f184738adb43d/test/data/jsonfeed_recompiled.json), `92057fdcca7b6e04464733f90a0b2e7387fa0afdeefaed4437573d0caa438c85` | `real_recompiled_json.json`: first two of six items; each 26 KB HTML body reduced to its verbatim opening message block. Items dated 2024-03-19 and 2024-02-22. |

The checked-in files are small **editorial projections**, except the xkcd document's newline. `tools/project_diverse_feeds.py` deterministically regenerates the RSS and JSON files from an adjacent checkout of that exact archive commit. The three projection hashes are `648e4e9c199f159d684340d39694632b7b42cdcb2fd8120ba6184d2f1cb29d49` (RSS), `6e27227788d47220f822a8fb7687117c542a18e510d723409577d9cf62415fc0` (Atom), and `488bddb4318fcab452815b854f2616c069eeced5e4483085995806afb6138244` (JSON). No archived publisher response is a live endpoint check.

We ran the **complete archived originals** through the current Native CLI before reducing them: 20 RSS entries, four Atom entries, and six JSON items were returned. The RSS and JSON originals had no diagnostics. The xkcd original has no feed author and no entry author. Under RFC 4287's Atom author rule, that is an issue in the publisher snapshot; FeedLens retains all four usable entries and emits one feed and four entry author diagnostics. This example demonstrates diagnostic behavior, **not** acceptance of a fully valid Atom document. The earlier WP Tavern Atom projection has valid explicit entry authors and no diagnostics.

`diverse_real_test.mbt` embeds byte-matched versions of the saved files for Wasm, JS, and Native. `tools/check_diverse_real_reference.py` checks those mirrors and compares declared fields with independent feedparser 6.0.11 (RSS/Atom) and Python JSON/date parsing (JSON Feed). It checks IDs, titles, ordered links and dates; RSS channel metadata and the two preserved Dublin Core creator names (`zdw`, `amichail`); Atom HTML type and source-level absence of authors; JSON HTML and inherited author. A separate synthetic fixture tests namespace, scope, author ordering and malformed creator boundaries. The source archive's own Mojo parser is not a validator for FeedLens. Neither script compares full source documents against current publishers or proves all optional fields and extension modules.

`tools/check_full_archived_feeds.py` now runs the **complete, unedited**
archived responses from that exact source commit end-to-end. A separate CI
job checks out upstream commit `be9e1dbc17faea2723fa3224512f184738adb43d`,
verifies each full response against the three SHA-256 values above, parses all
20 RSS items, four Atom entries, and six JSON items through the Native CLI,
and compares ordered declared fields against feedparser 6.0.11, Python XML,
and Python JSON/date parsing. JSON `content_html` is compared in full, with no
body reduction. The archived xkcd document still lacks required Atom authors;
its five author diagnostics are expected. To run after an adjacent checkout:

```sh
uv run --with feedparser==6.0.11 python tools/check_full_archived_feeds.py ../mojo-feed/test/data
```

The complete responses remain in the pinned **upstream archive**, while this
repository stores the shorter cross-target projections. The CI checkout has a
network dependency; the comparison itself uses only local pinned bytes after
checkout. This is not a repeat fetch of today's live publisher endpoints and
does not recover the uncommitted complete WP Tavern responses captured earlier.

The archived Hacker News RSS channel declares one Atom-namespace `rel="self"`
link to `https://hnrss.org/frontpage`. FeedLens now retains it in `Feed.links`
without changing the RSS website `Feed.link`. ElementTree independently
selects that direct channel extension; `samples/rss2_atom_self.xml` checks
namespace and source-resolution boundaries.

## WP Tavern same-story comparison


These three small files are field-preserving, editorially reduced projections
of public WP Tavern subscriptions fetched on 2026-10-19. They are **not**
verbatim copies of the full feeds. The first two podcast entries, their IDs,
dates, alternate URLs, category order, and enclosure/attachment URL, type,
and byte size were retained. Long descriptions and transcripts were omitted;
JSON Feed's required `content_text` was shortened to its opening words.
The phase-11 projection revision restored source-present RSS language/image,
Atom root `xml:lang`/icon, and JSON Feed language/icon/item featured images;
these were omitted by the earlier reduction, not invented or fetched anew.
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

## Phase-10 result

The same two entries now validate across all three date syntaxes with
`normalize_date`: episode #237 yields `2026-10-14T13:00:00Z` in each format,
while each original date string remains available. The two episodes and their
single attachments retain their original order and respective byte counts
`37878054` and `39694700` in each projection. `parse_with_source` was also
run against these projections using the recorded subscription URLs; their
already-absolute article and media URLs remain unchanged. Relative-reference
and nested Atom `xml:base` cases are exercised separately by small synthetic
tests, because these particular live feeds did not contain such references.

No attachment parsing defect was found in these samples. The repaired parser
gap was the absence of a comparable, validated date result; explicit URI
resolution is a new opt-in library entry point, not a reinterpretation of
the CLI's local file path.

## Phase-11 display-field result

The revised projections expose only display fields verified in the captured
full responses: RSS `language=en-US` and one channel image (URL/title/link,
32 × 32 declared pixels); Atom root `xml:lang=en-US` and one icon; JSON Feed
`language=en-US`, one feed icon, and one featured item image per retained
entry. FeedLens now returns their source/role metadata, with no fetched image
bytes. No selected entry supplied JSON `external_url` or `banner_image`, and
the feed supplied no JSON `favicon` or Atom `logo`; these are tested only in
clearly synthetic cases. See `DISPLAY_FIELD_INVENTORY.md`.
