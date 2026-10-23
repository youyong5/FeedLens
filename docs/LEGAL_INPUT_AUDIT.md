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
  extension parameter syntax, Atom IRI and date grammar, permitted extension
  points, and remaining cardinality rules still need a larger corpus.
- RSS source-defined optional metadata is mapped; extension modules and HTML
  presentation remain outside the core reader model.
- JSON Feed extension objects may be ignored by readers, but the remaining
  author/attachment/date edge cases need a documented compatibility corpus.
- Cross-format real projections cover ordered podcast entries, dates, links,
  and audio enclosures. They do not independently prove every optional field
  or the absence of false diagnostics across a broad set of publishers.
