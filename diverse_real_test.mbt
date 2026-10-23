///|
/// Mirrors samples/real_hn_rss.xml for cross-target offline tests.
fn diverse_rss_sample() -> String {
  (
    #|<?xml version="1.0" encoding="utf-8"?>
    #|<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:ns0="http://www.w3.org/2005/Atom" version="2.0">
    #|  <channel>
    #|    <title>Hacker News: Front Page</title>
    #|    <link>https://news.ycombinator.com/</link>
    #|    <description>Hacker News RSS</description>
    #|    <docs>https://hnrss.org/</docs>
    #|    <generator>hnrss v2.1.1</generator>
    #|    <lastBuildDate>Sun, 05 Jul 2026 16:40:24 +0000</lastBuildDate>
    #|    <ns0:link href="https://hnrss.org/frontpage" rel="self" type="application/rss+xml" />
    #|    <item>
    #|      <title>The Plight of the Martian Farmer</title>
    #|      <description>
    #|&lt;p&gt;Article URL: &lt;a href="https://mceglowski.substack.com/p/the-plight-of-the-martian-farmer"&gt;https://mceglowski.substack.com/p/the-plight-of-the-martian-farmer&lt;/a&gt;&lt;/p&gt;
    #|&lt;p&gt;Comments URL: &lt;a href="https://news.ycombinator.com/item?id=48795303"&gt;https://news.ycombinator.com/item?id=48795303&lt;/a&gt;&lt;/p&gt;
    #|&lt;p&gt;Points: 8&lt;/p&gt;
    #|&lt;p&gt;# Comments: 2&lt;/p&gt;
    #|</description>
    #|      <pubDate>Sun, 05 Jul 2026 16:04:23 +0000</pubDate>
    #|      <link>https://mceglowski.substack.com/p/the-plight-of-the-martian-farmer</link>
    #|      <dc:creator>zdw</dc:creator>
    #|      <comments>https://news.ycombinator.com/item?id=48795303</comments>
    #|      <guid isPermaLink="false">https://news.ycombinator.com/item?id=48795303</guid>
    #|    </item>
    #|    <item>
    #|      <title>Autonomous flying umbrella follows and shields users from rain and sunlight</title>
    #|      <description>
    #|&lt;p&gt;Article URL: &lt;a href="https://www.designboom.com/technology/autonomous-flying-umbrella-follows-users-rain-sunlight-i-build-stuff-01-13-2026/"&gt;https://www.designboom.com/technology/autonomous-flying-umbrella-follows-users-rain-sunlight-i-build-stuff-01-13-2026/&lt;/a&gt;&lt;/p&gt;
    #|&lt;p&gt;Comments URL: &lt;a href="https://news.ycombinator.com/item?id=48795174"&gt;https://news.ycombinator.com/item?id=48795174&lt;/a&gt;&lt;/p&gt;
    #|&lt;p&gt;Points: 13&lt;/p&gt;
    #|&lt;p&gt;# Comments: 3&lt;/p&gt;
    #|</description>
    #|      <pubDate>Sun, 05 Jul 2026 15:49:18 +0000</pubDate>
    #|      <link>https://www.designboom.com/technology/autonomous-flying-umbrella-follows-users-rain-sunlight-i-build-stuff-01-13-2026/</link>
    #|      <dc:creator>amichail</dc:creator>
    #|      <comments>https://news.ycombinator.com/item?id=48795174</comments>
    #|      <guid isPermaLink="false">https://news.ycombinator.com/item?id=48795174</guid>
    #|    </item>
    #|  </channel>
    #|</rss>
  )
}

///|
/// Mirrors samples/real_xkcd_atom.xml for cross-target offline tests.
fn diverse_atom_sample() -> String {
  (
    #|<?xml version="1.0" encoding="utf-8"?>
    #|<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en"><title>xkcd.com</title><link href="https://xkcd.com/" rel="alternate"></link><id>https://xkcd.com/</id><updated>2026-07-03T00:00:00Z</updated><entry><title>Types of Tornado Alert</title><link href="https://xkcd.com/3267/" rel="alternate"></link><updated>2026-07-03T00:00:00Z</updated><id>https://xkcd.com/3267/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/types_of_tornado_alert.png" title="I hate the unearthly sound my phone makes when the weather service issues a tornado harbinger." alt="I hate the unearthly sound my phone makes when the weather service issues a tornado harbinger." /&gt;</summary></entry><entry><title>Holes</title><link href="https://xkcd.com/3266/" rel="alternate"></link><updated>2026-07-01T00:00:00Z</updated><id>https://xkcd.com/3266/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/holes.png" title="If you're thinking 'Wait, a giant crystal cave in Mexico? What's that?' then I'm SO excited for the image search you're about to do." alt="If you're thinking 'Wait, a giant crystal cave in Mexico? What's that?' then I'm SO excited for the image search you're about to do." /&gt;</summary></entry><entry><title>Asteroid Threat</title><link href="https://xkcd.com/3265/" rel="alternate"></link><updated>2026-06-29T00:00:00Z</updated><id>https://xkcd.com/3265/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/asteroid_threat.png" title="Paleontologists have long worried that the dinosaurs blasted into space 66 million years ago will one day complete their orbits and fall back down." alt="Paleontologists have long worried that the dinosaurs blasted into space 66 million years ago will one day complete their orbits and fall back down." /&gt;</summary></entry><entry><title>720 Ollie</title><link href="https://xkcd.com/3264/" rel="alternate"></link><updated>2026-06-26T00:00:00Z</updated><id>https://xkcd.com/3264/</id><summary type="html">&lt;img src="https://imgs.xkcd.com/comics/720_ollie.png" title="This discovery was key to his demonstration of regular/goofy symmetry violation, which won him gold in the theory portion of the X Games." alt="This discovery was key to his demonstration of regular/goofy symmetry violation, which won him gold in the theory portion of the X Games." /&gt;</summary></entry></feed>
  )
}

///|
/// Mirrors samples/real_recompiled_json.json for cross-target offline tests.
fn diverse_json_sample() -> String {
  (
    #|{
    #|  "version": "https://jsonfeed.org/version/1.1",
    #|  "title": "Recompiled",
    #|  "language": "en",
    #|  "home_page_url": "https://www.recompiled.dev/",
    #|  "feed_url": "https://www.recompiled.dev/feed/feed.json",
    #|  "description": "I write about compilers and JavaScript",
    #|  "author": {
    #|    "name": "Sathya Gunasekaran",
    #|    "url": ""
    #|  },
    #|  "items": [
    #|    {
    #|      "id": "https://www.recompiled.dev/blog/type-system/",
    #|      "url": "https://www.recompiled.dev/blog/type-system/",
    #|      "title": "Type system of the React compiler",
    #|      "content_html": "<div class=\"message-box\">\n\t<p><em>If you're wondering what the React compiler is, I recommend reading our recent <a href=\"https://react.dev/blog/2024/02/15/react-labs-what-we-have-been-working-on-february-2024#react-compiler\">update post</a> for some background. This post is for anyone curious about the compiler theory behind it. Don't feel pressured to understand everything in this post in order to use the compiler. </em></p>\n</div>",
    #|      "date_published": "2024-03-19T16:45:37Z"
    #|    },
    #|    {
    #|      "id": "https://www.recompiled.dev/blog/ssa/",
    #|      "url": "https://www.recompiled.dev/blog/ssa/",
    #|      "title": "Compiler Theory and Reactivity",
    #|      "content_html": "<div class=\"message-box\">\n\t<p><em>If you're wondering what the React compiler is, I recommend reading our recent <a href=\"https://react.dev/blog/2024/02/15/react-labs-what-we-have-been-working-on-february-2024#react-compiler\">update post</a> for some background. This post is for anyone curious about the compiler theory behind it. Don't feel pressured to understand everything in this post in order to use the compiler. </em></p>\n</div>",
    #|      "date_published": "2024-02-22T16:45:37Z"
    #|    }
    #|  ]
    #|}
  )
}

///|
test "Hacker News RSS projection retains direct metadata and ordered story links" {
  guard @feedlens.parse(diverse_rss_sample()) is Ok(feed) else {
    fail("expected RSS document")
  }
  assert_true(feed.format is @feedlens.Rss2)
  assert_eq(feed.title, Some("Hacker News: Front Page"))
  assert_eq(feed.docs_url, Some("https://hnrss.org/"))
  assert_eq(feed.generator, Some("hnrss v2.1.1"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].title, Some("The Plight of the Martian Farmer"))
  assert_eq(
    feed.entries[0].link,
    Some("https://mceglowski.substack.com/p/the-plight-of-the-martian-farmer"),
  )
  assert_eq(
    feed.entries[0].identifier,
    Some("https://news.ycombinator.com/item?id=48795303"),
  )
  assert_eq(
    feed.entries[0].published_at,
    Some("Sun, 05 Jul 2026 16:04:23 +0000"),
  )
  assert_eq(
    feed.entries[1].published_at,
    Some("Sun, 05 Jul 2026 15:49:18 +0000"),
  )
  assert_eq(feed.diagnostics, [])
}

///|
test "xkcd Atom snapshot preserves four entries and locates missing authors" {
  guard @feedlens.parse(diverse_atom_sample()) is Ok(feed) else {
    fail("expected Atom document")
  }
  assert_true(feed.format is @feedlens.Atom1)
  assert_eq(feed.title, Some("xkcd.com"))
  assert_eq(feed.link, Some("https://xkcd.com/"))
  assert_eq(feed.entries.length(), 4)
  assert_eq(feed.entries[0].title, Some("Types of Tornado Alert"))
  assert_eq(feed.entries[0].identifier, Some("https://xkcd.com/3267/"))
  assert_eq(feed.entries[0].updated_at, Some("2026-07-03T00:00:00Z"))
  assert_eq(feed.entries[0].published_at, None)
  assert_true(feed.entries[0].description_kind is @feedlens.Html)
  assert_eq(feed.diagnostics.length(), 5)
  assert_true(feed.diagnostics[0].kind is @feedlens.MissingFeedField("author"))
  assert_true(
    feed.diagnostics[1].kind is @feedlens.MissingEntryField(0, "author"),
  )
}

///|
test "Recompiled JSON Feed projection retains HTML and inherited author" {
  guard @feedlens.parse(diverse_json_sample()) is Ok(feed) else {
    fail("expected JSON Feed document")
  }
  assert_true(feed.format is @feedlens.JsonFeed1)
  assert_eq(feed.title, Some("Recompiled"))
  assert_eq(feed.language, Some("en"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.authors[0].name, Some("Sathya Gunasekaran"))
  assert_eq(feed.entries[0].authors[0].name, Some("Sathya Gunasekaran"))
  assert_eq(feed.entries[0].title, Some("Type system of the React compiler"))
  assert_eq(
    feed.entries[0].link,
    Some("https://www.recompiled.dev/blog/type-system/"),
  )
  assert_eq(feed.entries[0].published_at, Some("2024-03-19T16:45:37Z"))
  assert_true(feed.entries[0].content_kind is @feedlens.Html)
  assert_eq(feed.entries[1].title, Some("Compiler Theory and Reactivity"))
  assert_eq(feed.diagnostics, [])
}
