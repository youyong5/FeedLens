# Legal input audit: empty text and effective rights

This is a **focused, reproducible audit**, not a claim that all three formats
are fully conformant. It checks whether existing mapping rules wrongly reject
or lose content in valid common documents. The complete list of documented
support and remaining gaps is in [STANDARD_SCOPE.md](STANDARD_SCOPE.md).

| Clause / case | Before this change | Public result now | Evidence |
| --- | --- | --- | --- |
| Atom text constructs may contain empty or whitespace-only text; an empty title is discouraged, not forbidden ([RFC 4287 §4.1.1.1](https://www.rfc-editor.org/rfc/rfc4287#section-4.1.1.1), [§3.1](https://www.rfc-editor.org/rfc/rfc4287#section-3.1)) | Empty feed/entry titles became `None` and a false missing-title diagnostic; empty summary/rights/source text disappeared. | Text/HTML/XHTML title, subtitle, summary, rights and source text preserve `Some("")` or original spaces. A truly missing title remains `None` with a diagnostic; malformed XHTML without its required div remains invalid. | `atom_legal_text_test.mbt`, `samples/atom1_legal_empty_and_rights.xml` |
| Atom external/Binary content requires a summary element, but its text is not required to be non-empty ([RFC 4287 §4.1.2](https://www.rfc-editor.org/rfc/rfc4287#section-4.1.2)) | Present empty summary was treated as missing and produced a false diagnostic. | `Some("")` marks the present summary; both external and Base64 content remain structured in `atom_body`. | Same Atom regression; CLI JSON and feedparser intersection |
| Entry without its own rights uses the containing feed's rights ([RFC 4287 §4.2.10](https://www.rfc-editor.org/rfc/rfc4287#section-4.2.10)) | Entry `rights` was absent, including when feed rights came after entries. | Effective entry `rights`, `rights_kind`, and optional XHTML fragment inherit feed values. Own rights, including `Some("")`, take precedence. Stand-alone Entry has no invented feed context; source rights remain source metadata. | Same Atom regression and CLI JSON; independent XML direct-child check |
| JSON Feed string `id` is an opaque identifier; `tags` have any plain-text values ([JSON Feed 1.1 items](https://www.jsonfeed.org/version/1.1/#items)) | Blank IDs dropped entire items; empty tag values were skipped with a diagnostic. | Exact string IDs and string tags survive, including empty and whitespace-only values. Empty `content_text`/`content_html` already remained valid. Non-string tags still diagnose. | `json_feed_test.mbt`, `samples/jsonfeed11_opaque_strings.json` |
| Atom Date construct requires uppercase `T` and `Z`; generic RFC 3339 permits lowercase ([RFC 4287 §3.3](https://www.rfc-editor.org/rfc/rfc4287#section-3.3), [RFC 3339 §5.6](https://www.rfc-editor.org/rfc/rfc3339#section-5.6)) | `normalize_date` treated Atom and JSON Feed the same and accepted lowercase in Atom. | `normalize_date` rejects lowercase `t`/`z` for Atom while accepting both for JSON Feed; stored date strings remain unmodified. | `date_author_boundary_test.mbt`, `samples/atom1_date_case.xml`, `samples/jsonfeed11_empty_author_date.json` |
| JSON Feed author `name` is an optional plain-text string ([JSON Feed 1.1 authors](https://www.jsonfeed.org/version/1.1/#the-structure-of-a-feed)) | Explicit empty/whitespace name became absent; an author with only that field was dropped. | Preserve exact declared `name` and inheritance in both versions, including empty/whitespace. A truly empty author object is still invalid. | Same JSON sample, `json_feed_test.mbt` |
| Explicit HTTP(S) source URL must have a usable authority ([RFC 3986 §3.2](https://www.rfc-editor.org/rfc/rfc3986#section-3.2)); Atom uses IRI references and `xml:base` | A nonempty authority such as `:80` or `example.test:bad` passed entry validation, then relative fields generated scattered resolution diagnostics. | Both source-aware APIs reject those malformed sources first. Common invalid ASCII host characters are rejected; Unicode IRI hosts and nested relative `xml:base` stay usable. | `uri_source_boundary_test.mbt`, `uri_wbtest.mbt`, `samples/atom1_iri_host.xml`, `tools/check_source_authority_reference.py` |
| RSS item may contain only a title or only a description ([RSS 2.0 item](https://www.rssboard.org/rss-specification#hrelementsOfLtitemgt)) | Already supported. | Existing behavior retained; no identifier is invented for an item without guid/link. | `rss_item_required_test.mbt`, `samples/rss2_anonymous_items.xml` |

`tools/check_legal_input_reference.py` checks both byte-mirrored samples.
Python feedparser 6.0.11 independently parses the Atom fixture and agrees on
entry IDs, empty display titles/summary, explicit empty rights, and source
metadata. It strips the feed title's spaces and serializes sanitized XHTML;
FeedLens retains the original spaces and an unsanitized namespaced fragment.
feedparser does not project inherited feed rights on this fixture, so Python
ElementTree checks which entries directly declare rights and the library test
asserts RFC 4287's inheritance. Python's standard JSON parser independently
checks the JSON fixture's exact IDs, content, and tags against Native CLI JSON.
This comparison does not use live network feeds or claim broad conformance.

## Still requiring audit before the application

- Atom content's common MIME parameters now have legal and invalid regression
  cases plus an independent email/feedparser intersection. MIME comments and
  extension parameter syntax, full Atom IRI and leap-second date grammar, permitted extension
  points, and remaining cardinality rules still need a larger corpus.
- RSS source-defined optional metadata is mapped; extension modules and HTML
  presentation remain outside the core reader model.
- JSON Feed extension objects may be ignored by readers, but the remaining
  author/attachment/date edge cases need a documented compatibility corpus.
- The WP Tavern projections compare matching stories across all three formats.
  Three additional publisher snapshots cover RSS channel metadata, Atom HTML
  and missing-author diagnostics, and JSON HTML with author inheritance.
  They do not prove every optional field or fully valid Atom behavior across
  a broad set of publishers; xkcd's archived Atom input lacks required authors.
