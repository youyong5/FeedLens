///|
fn atom_xhtml_acceptance_sample() -> String {
  (
    #|<feed xmlns="http://www.w3.org/2005/Atom">
    #|  <id>urn:example:feed</id>
    #|  <title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">Plan <em>A</em> &amp; B</div></title>
    #|  <updated>2026-10-21T00:00:00Z</updated>
    #|  <author><name>Example</name></author>
    #|  <entry>
    #|    <id>urn:example:entry:1</id>
    #|    <title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml">Race <strong>review</strong></div></title>
    #|    <updated>2026-10-21T00:00:00Z</updated>
    #|    <content type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml"><p>Lap <strong>12</strong> &amp; rain.</p></div></content>
    #|  </entry>
    #|</feed>
  )
}

///|
test "Atom XHTML retains outer div attributes without adding the wrapper to markup" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml" xml:lang="en" xml:base="https://example.test/news/"><id>urn:f</id><title type="xhtml"><h:div class="headline" title="A &amp; B">Plan <h:em>ahead</h:em></h:div></title><updated>2026-10-23T10:00:00Z</updated><author><name>Editor</name></author><entry><id>urn:e</id><title>E</title><updated>2026-10-23T10:00:00Z</updated><content type="xhtml"><h:div class="story" xml:lang="fr" xml:base="assets/"><h:p>Bonjour</h:p></h:div></content></entry></feed>
  guard @feedlens.parse_with_source(input, "https://example.test/atom.xml")
    is Ok(feed) else {
    fail("expected valid XHTML feed")
  }
  assert_eq(feed.diagnostics, [])
  assert_eq(feed.title, Some("Plan ahead"))
  guard feed.title_xhtml is Some(title) else { fail("missing title XHTML") }
  assert_eq(title.container_attributes.length(), 2)
  assert_eq(title.container_attributes[0].local_name, "class")
  assert_eq(title.container_attributes[0].namespace_uri, None)
  assert_eq(title.container_attributes[0].value, "headline")
  assert_eq(title.container_attributes[1].local_name, "title")
  assert_eq(title.container_attributes[1].value, "A & B")
  assert_eq(
    title.markup,
    "Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">ahead</h:em>",
  )
  guard feed.entries[0].content_xhtml is Some(body) else {
    fail("missing content XHTML")
  }
  assert_eq(body.container_attributes.length(), 3)
  assert_eq(body.container_attributes[0].value, "story")
  assert_eq(body.container_attributes[1].local_name, "lang")
  assert_eq(
    body.container_attributes[1].namespace_uri,
    Some("http://www.w3.org/XML/1998/namespace"),
  )
  assert_eq(body.container_attributes[1].value, "fr")
  assert_eq(body.container_attributes[2].local_name, "base")
  assert_eq(body.container_attributes[2].value, "assets/")
  assert_eq(body.language, Some("fr"))
  assert_eq(body.base_references, ["https://example.test/news/", "assets/"])
}

///|
test "Atom XHTML acceptance fixture has display text and deterministic markup" {
  guard @feedlens.parse(atom_xhtml_acceptance_sample()) is Ok(feed) else {
    fail("expected Atom XHTML feed")
  }
  assert_eq(feed.title, Some("Plan A & B"))
  assert_true(feed.title_kind is @feedlens.Xhtml)
  guard feed.title_xhtml is Some(feed_title) else {
    fail("expected feed XHTML title")
  }
  assert_eq(
    feed_title.markup,
    "Plan <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">A</h:em> &amp; B",
  )
  let entry = feed.entries[0]
  assert_eq(entry.title, Some("Race review"))
  assert_true(entry.title_kind is @feedlens.Xhtml)
  guard entry.title_xhtml is Some(entry_title) else {
    fail("expected entry XHTML title")
  }
  assert_eq(
    entry_title.markup,
    "Race <h:strong xmlns:h=\"http://www.w3.org/1999/xhtml\">review</h:strong>",
  )
  assert_eq(entry.content, Some("Lap 12 & rain."))
  assert_true(entry.content_kind is @feedlens.Xhtml)
  guard entry.content_xhtml is Some(content) else {
    fail("expected entry XHTML body")
  }
  assert_eq(
    content.markup,
    "<h:p xmlns:h=\"http://www.w3.org/1999/xhtml\">Lap <h:strong xmlns:h=\"http://www.w3.org/1999/xhtml\">12</h:strong> &amp; rain.</h:p>",
  )
  assert_true(entry.atom_body is Some(@feedlens.InlineXhtml(_)))
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom XHTML supports prefixes, attributes, summary, whitespace and div context" {
  let input =
    #|<a:feed xmlns:a="http://www.w3.org/2005/Atom" xmlns:x="http://www.w3.org/1999/xhtml" xml:lang="en" xml:base="https://example.test/root/">
    #|<a:id>urn:fixture:f</a:id><a:title type="xhtml"><x:div>F</x:div></a:title><a:subtitle type="xhtml"><x:div xml:lang="fr" xml:base="sub/">Intro <x:em class="lead">ici</x:em> !</x:div></a:subtitle><a:updated>2026-10-21T00:00:00Z</a:updated><a:author><a:name>N</a:name></a:author>
    #|<a:entry xml:base="entry/"><a:id>urn:fixture:e</a:id><a:title type="xhtml"><x:div> E </x:div></a:title><a:updated>2026-10-21T00:00:00Z</a:updated><a:summary type="xhtml" xml:lang="de"><x:div xml:lang="it" xml:base="summary/"> A <x:b title="&amp;">B</x:b> C </x:div></a:summary><a:content type="xhtml"><x:div><x:p xml:base="image/">body</x:p></x:div></a:content></a:entry>
    #|</a:feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.description, Some("Intro ici !"))
  assert_true(feed.description_kind is @feedlens.Xhtml)
  guard feed.description_xhtml is Some(subtitle) else {
    fail("expected XHTML subtitle")
  }
  assert_eq(subtitle.language, Some("fr"))
  assert_eq(subtitle.base_references, ["https://example.test/root/", "sub/"])
  assert_eq(
    subtitle.markup,
    "Intro <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\" class=\"lead\">ici</h:em> !",
  )
  let entry = feed.entries[0]
  assert_eq(entry.description, Some(" A B C "))
  assert_true(entry.description_kind is @feedlens.Xhtml)
  guard entry.description_xhtml is Some(summary) else {
    fail("expected XHTML summary")
  }
  assert_eq(summary.language, Some("it"))
  assert_eq(summary.base_references, [
    "https://example.test/root/", "entry/", "summary/",
  ])
  assert_eq(
    summary.markup,
    " A <h:b xmlns:h=\"http://www.w3.org/1999/xhtml\" title=\"&amp;\">B</h:b> C ",
  )
  guard entry.content_xhtml is Some(body) else { fail("expected XHTML body") }
  assert_eq(
    body.markup,
    "<h:p xmlns:h=\"http://www.w3.org/1999/xhtml\" xml:base=\"image/\">body</h:p>",
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom XHTML rejects absent div, wrong namespace and multiple roots with positions" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:fake="urn:fake">
    #|<id>urn:fixture:f</id><title type="xhtml">plain</title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author>
    #|<entry><id>urn:fixture:e</id><title type="xhtml"><fake:div>wrong</fake:div></title><updated>2026-10-21T00:00:00Z</updated><summary type="xhtml"><h:div>A</h:div><h:div>B</h:div></summary><content type="xhtml"><h:div>okay</h:div></content></entry>
    #|</feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.title, None)
  assert_eq(feed.entries[0].title, None)
  assert_eq(feed.entries[0].description, None)
  assert_eq(feed.entries[0].content, Some("okay"))
  assert_true(feed.diagnostics[0].kind is @feedlens.UnsupportedTextConstruct(_))
  assert_eq(feed.diagnostics[0].line, 2)
  assert_true(feed.diagnostics[0].column > 0)
  assert_true(feed.diagnostics[1].kind is @feedlens.UnsupportedTextConstruct(_))
  assert_eq(feed.diagnostics[1].line, 3)
  assert_true(feed.diagnostics[1].column > 0)
  assert_true(feed.diagnostics[2].kind is @feedlens.UnsupportedTextConstruct(_))
  assert_eq(feed.diagnostics[2].line, 3)
  assert_true(feed.diagnostics[2].column > 0)
}

///|
test "Atom XHTML preserves unsafe attributes and XML comments without sanitizing" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://example.test/base/" xml:lang="en"><id>urn:fixture:f</id><title type="xhtml"><div xmlns="http://www.w3.org/1999/xhtml" xml:base="parts/">Hi <span onclick="alert(1)" data-x="&amp;">X</span><!-- note --><?pi ok?>!</div></title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author></feed>
  guard @feedlens.parse_with_source(input, "https://example.test/feed.atom")
    is Ok(feed) else {
    fail("expected Atom")
  }
  assert_eq(feed.title, Some("Hi X!"))
  guard feed.title_xhtml is Some(fragment) else {
    fail("expected XHTML fragment")
  }
  assert_eq(fragment.language, Some("en"))
  assert_eq(fragment.base_references, ["https://example.test/base/", "parts/"])
  assert_eq(
    fragment.markup,
    "Hi <h:span xmlns:h=\"http://www.w3.org/1999/xhtml\" onclick=\"alert(1)\" data-x=\"&amp;\">X</h:span><!-- note --><?pi ok?>!",
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "Atom empty XHTML construct is diagnosed, but an empty XHTML div is retained" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml"><id>urn:fixture:f</id><title type="xhtml"/><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author><entry><id>urn:fixture:e</id><title>E</title><updated>2026-10-21T00:00:00Z</updated><content type="xhtml"><h:div/></content></entry></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.title, None)
  assert_true(feed.diagnostics[0].kind is @feedlens.UnsupportedTextConstruct(_))
  assert_true(feed.diagnostics[1].kind is @feedlens.MissingFeedField("title"))
  assert_eq(feed.entries[0].content, Some(""))
  assert_true(feed.entries[0].content_kind is @feedlens.Xhtml)
  guard feed.entries[0].content_xhtml is Some(fragment) else {
    fail("expected empty XHTML fragment")
  }
  assert_eq(fragment.markup, "")
}

///|
test "Atom XHTML serializes foreign nested namespaces without conflating them" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:f="urn:foreign"><id>urn:fixture:f</id><title type="xhtml"><h:div>A<f:em f:role="label">B</f:em>C</h:div></title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.title, Some("ABC"))
  guard feed.title_xhtml is Some(fragment) else {
    fail("expected XHTML fragment")
  }
  assert_eq(
    fragment.markup,
    "A<n0:em xmlns:h=\"http://www.w3.org/1999/xhtml\" xmlns:n0=\"urn:foreign\" n0:role=\"label\">B</n0:em>C",
  )
}

///|
test "Atom XHTML decodes CDATA and entities while retaining mixed whitespace" {
  let input =
    #|<feed xmlns="http://www.w3.org/2005/Atom" xmlns:h="http://www.w3.org/1999/xhtml"><id>urn:fixture:f</id><title type="xhtml"><h:div> A <![CDATA[<&>]]> &amp; <h:em>B</h:em> </h:div></title><updated>2026-10-21T00:00:00Z</updated><author><name>N</name></author></feed>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected Atom") }
  assert_eq(feed.title, Some(" A <&> & B "))
  guard feed.title_xhtml is Some(fragment) else {
    fail("expected XHTML fragment")
  }
  assert_eq(
    fragment.markup,
    " A &lt;&amp;&gt; &amp; <h:em xmlns:h=\"http://www.w3.org/1999/xhtml\">B</h:em> ",
  )
  assert_eq(feed.diagnostics, [])
}
