///|
/// Mirrors samples/real_wptavern_rss.xml; keep synchronized for cross-target tests.
fn real_rss_sample() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<rss version="2.0">
    #|  <channel>
    #|    <title>WP Tavern</title>
    #|    <link>https://wptavern.com</link>
    #|    <description>WordPress News — Free as in Beer.</description>
    #|    <item>
    #|      <title>#237 &#8211; Robert Abela on WordPress Security and the Battle Against AI Threats</title>
    #|      <link>https://wptavern.com/podcast/237-robert-abela-on-wordpress-security-and-the-battle-against-ai-threats/</link>
    #|      <pubDate>Wed, 14 Oct 2026 13:00:00 +0000</pubDate>
    #|      <category><![CDATA[podcast]]></category>
    #|      <category><![CDATA[security]]></category>
    #|      <guid isPermaLink="false">https://wptavern.com/?post_type=podcast&#038;p=209016</guid>
    #|      <enclosure url="https://episodes.castos.com/601a97348e9993-63339407/2656179/c1e-89rgrh87qmqirmkrd-0vvdm9rvh1kp-56fstm.mp3" length="37878054" type="audio/mpeg"/>
    #|    </item>
    #|    <item>
    #|      <title>#236 &#8211; Brian Coords on WordPress as the Source of Truth</title>
    #|      <link>https://wptavern.com/podcast/236-brian-coords-on-wordpress-as-the-source-of-truth/</link>
    #|      <pubDate>Wed, 07 Oct 2026 13:00:00 +0000</pubDate>
    #|      <category><![CDATA[ai]]></category>
    #|      <category><![CDATA[podcast]]></category>
    #|      <guid isPermaLink="false">https://wptavern.com/?post_type=podcast&#038;p=208932</guid>
    #|      <enclosure url="https://episodes.castos.com/601a97348e9993-63339407/2647523/c1e-x8ojou1j6v4ck8dwr-8dm6m923bz48-xfrmnx.mp3" length="39694700" type="audio/mpeg"/>
    #|    </item>
    #|  </channel>
    #|</rss>
  )
}

///|
/// Mirrors samples/real_wptavern_atom.xml; keep synchronized for cross-target tests.
fn real_atom_sample() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<feed xmlns="http://www.w3.org/2005/Atom">
    #|  <title type="text">WP Tavern</title>
    #|  <subtitle type="text">WordPress News — Free as in Beer.</subtitle>
    #|  <updated>2026-10-13T13:39:19Z</updated>
    #|  <link rel="alternate" type="text/html" href="https://wptavern.com"/>
    #|  <id>https://wptavern.com/feed/atom/</id>
    #|  <entry>
    #|    <author><name>Nathan Wrigley</name></author>
    #|    <title type="html"><![CDATA[#237 &#8211; Robert Abela on WordPress Security and the Battle Against AI Threats]]></title>
    #|    <link rel="alternate" type="text/html" href="https://wptavern.com/podcast/237-robert-abela-on-wordpress-security-and-the-battle-against-ai-threats/"/>
    #|    <id>https://wptavern.com/?post_type=podcast&amp;p=209016</id>
    #|    <updated>2026-10-13T13:39:19Z</updated>
    #|    <published>2026-10-14T13:00:00Z</published>
    #|    <category scheme="https://wptavern.com" term="podcast"/>
    #|    <category scheme="https://wptavern.com" term="security"/>
    #|    <link rel="enclosure" href="https://episodes.castos.com/601a97348e9993-63339407/2656179/c1e-89rgrh87qmqirmkrd-0vvdm9rvh1kp-56fstm.mp3" length="37878054" type="audio/mpeg"/>
    #|  </entry>
    #|  <entry>
    #|    <author><name>Nathan Wrigley</name></author>
    #|    <title type="html"><![CDATA[#236 &#8211; Brian Coords on WordPress as the Source of Truth]]></title>
    #|    <link rel="alternate" type="text/html" href="https://wptavern.com/podcast/236-brian-coords-on-wordpress-as-the-source-of-truth/"/>
    #|    <id>https://wptavern.com/?post_type=podcast&amp;p=208932</id>
    #|    <updated>2026-10-07T10:52:47Z</updated>
    #|    <published>2026-10-07T13:00:00Z</published>
    #|    <category scheme="https://wptavern.com" term="ai"/>
    #|    <category scheme="https://wptavern.com" term="podcast"/>
    #|    <link rel="enclosure" href="https://episodes.castos.com/601a97348e9993-63339407/2647523/c1e-x8ojou1j6v4ck8dwr-8dm6m923bz48-xfrmnx.mp3" length="39694700" type="audio/mpeg"/>
    #|  </entry>
    #|</feed>
  )
}

///|
/// Mirrors samples/real_wptavern_json.json; keep synchronized for cross-target tests.
fn real_json_sample() -> String {
  (
    #|{
    #|  "version": "https://jsonfeed.org/version/1.1",
    #|  "title": "WP Tavern",
    #|  "home_page_url": "https://wptavern.com",
    #|  "feed_url": "https://wptavern.com/feed/json",
    #|  "description": "WordPress News — Free as in Beer.",
    #|  "items": [
    #|    {
    #|      "id": "https://wptavern.com/?post_type=podcast&#038;p=209016",
    #|      "title": "#237 – Robert Abela on WordPress Security and the Battle Against AI Threats",
    #|      "url": "https://wptavern.com/podcast/237-robert-abela-on-wordpress-security-and-the-battle-against-ai-threats/",
    #|      "date_published": "2026-10-14T14:00:00+01:00",
    #|      "date_modified": "2026-10-13T14:39:19+01:00",
    #|      "content_text": "Transcript\n[00:00:19] Nathan Wrigley: Welcome to the Jukebox Podcast from WP Tavern. My name is Nathan Wrigley.",
    #|      "authors": [{"name": "Nathan Wrigley", "url": "https://wptavern.com/author/nathanwrigley/"}],
    #|      "tags": ["podcast", "security"],
    #|      "attachments": [{"url": "https://episodes.castos.com/601a97348e9993-63339407/2656179/c1e-89rgrh87qmqirmkrd-0vvdm9rvh1kp-56fstm.mp3", "mime_type": "audio/mpeg", "size_in_bytes": 37878054}]
    #|    },
    #|    {
    #|      "id": "https://wptavern.com/?post_type=podcast&#038;p=208932",
    #|      "title": "#236 – Brian Coords on WordPress as the Source of Truth",
    #|      "url": "https://wptavern.com/podcast/236-brian-coords-on-wordpress-as-the-source-of-truth/",
    #|      "date_published": "2026-10-07T14:00:00+01:00",
    #|      "date_modified": "2026-10-07T11:52:47+01:00",
    #|      "content_text": "Transcript",
    #|      "authors": [{"name": "Nathan Wrigley", "url": "https://wptavern.com/author/nathanwrigley/"}],
    #|      "tags": ["ai", "podcast"],
    #|      "attachments": [{"url": "https://episodes.castos.com/601a97348e9993-63339407/2647523/c1e-x8ojou1j6v4ck8dwr-8dm6m923bz48-xfrmnx.mp3", "mime_type": "audio/mpeg", "size_in_bytes": 39694700}]
    #|    }
    #|  ]
    #|}
  )
}

///|
test "real WP Tavern RSS projection preserves ordered enclosures and raw dates" {
  guard @feedlens.parse(real_rss_sample()) is Ok(feed) else {
    fail("expected RSS projection")
  }
  assert_true(feed.format is @feedlens.Rss2)
  assert_eq(feed.title, Some("WP Tavern"))
  assert_eq(feed.entries.length(), 2)
  assert_eq(
    feed.entries[0].published_at,
    Some("Wed, 14 Oct 2026 13:00:00 +0000"),
  )
  assert_eq(feed.entries[0].categories.length(), 2)
  assert_eq(feed.entries[0].categories[0].term, "podcast")
  assert_eq(feed.entries[0].attachments.length(), 1)
  assert_eq(feed.entries[0].attachments[0].media_type, Some("audio/mpeg"))
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, Some(37878054L))
  assert_eq(feed.entries[1].attachments[0].size_in_bytes, Some(39694700L))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected valid RSS publication date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00Z")
}

///|
test "real WP Tavern Atom projection preserves alternate and enclosure links" {
  guard @feedlens.parse(real_atom_sample()) is Ok(feed) else {
    fail("expected Atom projection")
  }
  assert_true(feed.format is @feedlens.Atom1)
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].published_at, Some("2026-10-14T13:00:00Z"))
  assert_eq(
    feed.entries[0].link,
    Some(
      "https://wptavern.com/podcast/237-robert-abela-on-wordpress-security-and-the-battle-against-ai-threats/",
    ),
  )
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, Some(37878054L))
  assert_eq(feed.entries[1].attachments[0].size_in_bytes, Some(39694700L))
  assert_eq(feed.entries[0].authors[0].name, Some("Nathan Wrigley"))
  assert_eq(feed.diagnostics, [])
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected valid Atom publication date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00Z")
}

///|
test "real WP Tavern JSON projection preserves attachment metadata and offsets" {
  guard @feedlens.parse(real_json_sample()) is Ok(feed) else {
    fail("expected JSON Feed projection")
  }
  assert_true(feed.format is @feedlens.JsonFeed1)
  assert_eq(feed.entries.length(), 2)
  assert_eq(feed.entries[0].published_at, Some("2026-10-14T14:00:00+01:00"))
  assert_eq(
    feed.entries[0].attachments[0].url,
    "https://episodes.castos.com/601a97348e9993-63339407/2656179/c1e-89rgrh87qmqirmkrd-0vvdm9rvh1kp-56fstm.mp3",
  )
  assert_eq(feed.entries[0].attachments[0].size_in_bytes, Some(37878054L))
  assert_eq(feed.entries[1].attachments[0].size_in_bytes, Some(39694700L))
  assert_eq(feed.entries[0].authors[0].name, Some("Nathan Wrigley"))
  assert_eq(feed.entries[0].categories[0].term, "podcast")
  assert_eq(feed.diagnostics, [])
  guard @feedlens.normalize_date(feed.format, feed.entries[0].published_at)
    is Ok(Some(date)) else {
    fail("expected valid JSON Feed publication date")
  }
  assert_eq(date.utc, "2026-10-14T13:00:00Z")
}
