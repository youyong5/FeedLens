///|
test "aggregated Atom entry retains source identity and XHTML title" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml" xml:lang="en"><id>urn:aggregate</id><title>Aggregate</title><updated>2026-10-22T00:00:00Z</updated><author><name>Aggregator</name></author><generator uri="tools/agg" version="3">Aggregate Engine</generator>
    #|<entry><id>urn:entry</id><title>Original entry</title><updated>2026-10-21T00:00:00Z</updated><content>Body</content><source xml:lang="fr" xml:base="origins/"><id>urn:original-feed</id><title type="xhtml"><h:div>Journal <h:em>source</h:em></h:div></title><subtitle type="html">&lt;i&gt;Original&lt;/i&gt; reporting</subtitle><updated>2026-10-20T00:00:00Z</updated><generator uri="tool" version="2">Origin Engine</generator><link href="home" type="text/html"/><link rel="self" href="index.atom"/><icon xml:base="assets/">icon.png</icon><logo>logo.png</logo><author><name>Original editor</name></author><contributor><name>Origin helper</name></contributor><category term="research" scheme="urn:topics"/><rights type="html">&lt;b&gt;Reuse&lt;/b&gt;</rights></source></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  let entry = feed.entries[0]
  assert_eq(entry.title, Some("Original entry"))
  assert_eq(entry.authors[0].name, Some("Original editor"))
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.identifier, Some("urn:original-feed"))
  assert_eq(source.title, Some("Journal source"))
  assert_true(source.title_kind is @feedlens.Xhtml)
  guard source.title_xhtml is Some(fragment) else { fail("expected XHTML") }
  assert_true(fragment.markup.contains("<h:em"))
  assert_eq(fragment.language, Some("fr"))
  assert_eq(fragment.base_references, ["origins/"])
  assert_eq(source.updated_at, Some("2026-10-20T00:00:00Z"))
  assert_eq(source.subtitle, Some("<i>Original</i> reporting"))
  assert_true(source.subtitle_kind is @feedlens.Html)
  assert_eq(source.generator, Some("Origin Engine"))
  assert_eq(source.generator_uri, Some("tool"))
  assert_eq(source.generator_version, Some("2"))
  assert_eq(source.link, Some("home"))
  assert_eq(source.links.length(), 2)
  assert_eq(source.links[0].relation, "alternate")
  assert_eq(source.links[1].href, "index.atom")
  assert_eq(source.images.length(), 2)
  assert_true(source.images[0].role is @feedlens.AtomIcon)
  assert_true(source.images[1].role is @feedlens.AtomLogo)
  assert_eq(source.images[0].url, "icon.png")
  assert_eq(feed.generator_uri, Some("tools/agg"))
  assert_eq(feed.generator_version, Some("3"))
  assert_eq(source.authors[0].name, Some("Original editor"))
  assert_eq(source.contributors[0].name, Some("Origin helper"))
  assert_eq(source.categories[0].term, "research")
  assert_eq(source.categories[0].scheme, Some("urn:topics"))
  assert_eq(source.rights, Some("<b>Reuse</b>"))
  assert_true(source.rights_kind is @feedlens.Html)
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/aggregate.atom",
    )
    is Ok(resolved) else {
    fail("expected source-aware Atom")
  }
  assert_eq(resolved.generator_uri, Some("https://example.test/tools/agg"))
  guard resolved.entries[0].atom_source is Some(resolved_source) else {
    fail("expected resolved source")
  }
  assert_eq(resolved_source.link, Some("https://example.test/origins/home"))
  assert_eq(
    resolved_source.links[1].href,
    "https://example.test/origins/index.atom",
  )
  assert_eq(
    resolved_source.generator_uri,
    Some("https://example.test/origins/tool"),
  )
  assert_eq(
    resolved_source.images[0].url,
    "https://example.test/origins/assets/icon.png",
  )
  assert_eq(
    resolved_source.images[1].url,
    "https://example.test/origins/logo.png",
  )
}

///|
test "stand-alone Atom source and malformed repeated metadata stay distinguishable" {
  let standalone =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-22T00:00:00Z</updated><content>Body</content><source><id>urn:origin</id><title type="html">&lt;b&gt;Origin&lt;/b&gt;</title><updated>2026-10-20T00:00:00Z</updated><author><name>Origin editor</name></author></source></entry>
  guard @feedlens.parse_document(standalone)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected independent Atom Entry")
  }
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.title, Some("<b>Origin</b>"))
  assert_true(source.title_kind is @feedlens.Html)
  assert_eq(source.authors[0].name, Some("Origin editor"))
  assert_eq(diagnostics, [])
  guard @feedlens.parse_document_with_source(
      standalone, "https://example.test/entry.atom",
    )
    is Ok(@feedlens.AtomEntryDocument(sourced, _)) else {
    fail("expected source-aware independent entry")
  }
  assert_eq(sourced.atom_source, entry.atom_source)
  let repeated =
    #|<entry xmlns="http://www.w3.org/2005/Atom"><id>urn:e</id><title>E</title><updated>2026-10-22T00:00:00Z</updated><content>Body</content><author><name>A</name></author><source><id>urn:a</id><id>urn:b</id><title type="xhtml"/></source></entry>
  guard @feedlens.parse_document(repeated)
    is Ok(@feedlens.AtomEntryDocument(bad, problems)) else {
    fail("expected recovered metadata")
  }
  guard bad.atom_source is Some(bad_source) else { fail("expected source") }
  assert_eq(bad_source.identifier, Some("urn:b"))
  assert_eq(bad_source.title, None)
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("source id") && d.line == 1
    }),
  )
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.UnsupportedTextConstruct("atom source title")
    }),
  )
}

///|
test "source rights XHTML and categories obey namespace and direct-child scope" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:wrong="urn:other"><id>urn:e</id><title>Entry</title><updated>2026-10-22T00:00:00Z</updated><author><name>Writer</name></author><content>Body</content><source><rights type="xhtml"><h:div>Reuse <h:strong>allowed</h:strong></h:div></rights><category term="valid"/><category/><wrong:id>wrong</wrong:id><wrong:category term="wrong"/></source></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, diagnostics)) else {
    fail("expected recovered Atom Entry")
  }
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.identifier, None)
  assert_eq(source.rights, Some("Reuse allowed"))
  assert_true(source.rights_kind is @feedlens.Xhtml)
  guard source.rights_xhtml is Some(fragment) else { fail("expected XHTML") }
  assert_true(fragment.markup.contains("<h:strong"))
  assert_eq(source.categories.length(), 1)
  assert_eq(source.categories[0].term, "valid")
  assert_true(
    diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidCategory("atom category missing term")
    }),
  )
}

///|
test "source optional metadata rejects invalid nesting and retains valid later fields" {
  let input =
    #|<entry xmlns="http://www.w3.org/2005/Atom" xmlns:x="urn:other"><id>urn:e</id><title>E</title><updated>2026-10-22T00:00:00Z</updated><author><name>Editor</name></author><content>Body</content><source><subtitle type="xhtml"/><subtitle>Latest</subtitle><link/><x:link href="foreign"/><link rel="self" href="index.atom"/><icon/><logo>  </logo><generator version="4">Origin</generator></source></entry>
  guard @feedlens.parse_document(input)
    is Ok(@feedlens.AtomEntryDocument(entry, problems)) else {
    fail("expected recoverable metadata")
  }
  guard entry.atom_source is Some(source) else { fail("expected source") }
  assert_eq(source.subtitle, Some("Latest"))
  assert_eq(source.links.length(), 1)
  assert_eq(source.links[0].href, "index.atom")
  assert_eq(source.images.length(), 1)
  assert_true(source.images[0].role is @feedlens.AtomIcon)
  assert_eq(source.images[0].url, "")
  assert_eq(source.generator, Some("Origin"))
  assert_eq(source.generator_version, Some("4"))
  assert_true(
    problems.any(fn(d) {
      d.kind is @feedlens.DuplicateAtomField("source subtitle")
    }),
  )
  assert_true(
    problems.any(fn(d) { d.kind is @feedlens.InvalidAtomLink("missing href") }),
  )
  assert_true(problems.any(fn(d) { d.kind is @feedlens.InvalidFeedImage(_) }))
}
