///|
test "RSS skipHours and skipDays preserve valid direct channel hints in source order" {
  let input =
    #|<rss version="2.0" xmlns:x="urn:unrelated"><channel><title>Night desk</title><link>https://example.test/</link><description>Daily notes</description>
    #|<skipHours><hour>0</hour><x:hour>12</x:hour><hour>23</hour><wrapper><hour>11</hour></wrapper></skipHours>
    #|<skipDays><day>Sunday</day><x:day>Friday</x:day><day>Monday</day></skipDays>
    #|<item><title>Notice</title><description>Service note</description><skipHours><hour>9</hour></skipHours></item>
    #|</channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.skip_hours, [0, 23])
  assert_eq(feed.skip_days, ["Sunday", "Monday"])
  assert_eq(feed.entries.length(), 1)
  assert_eq(feed.diagnostics, [])
  guard @feedlens.parse_with_source(
      input, "https://example.test/feeds/main.xml",
    )
    is Ok(resolved) else {
    fail("expected resolved RSS")
  }
  assert_eq(resolved.skip_hours, [0, 23])
  assert_eq(resolved.skip_days, ["Sunday", "Monday"])
  assert_eq(resolved.diagnostics, [])
}

///|
test "RSS skip hints diagnose out-of-range values, nesting, and repeated containers" {
  let input =
    #|<rss version="2.0"><channel><title>Hints</title><link>https://example.test/</link><description>Notes</description>
    #|<skipHours><hour>23</hour><hour>24</hour><hour>-1</hour><hour/><hour><b>2</b></hour></skipHours>
    #|<skipHours><hour>1</hour></skipHours>
    #|<skipDays><day>Monday</day><day>sunday</day><day/></skipDays>
    #|<skipDays><day>Friday</day></skipDays></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.skip_hours, [23])
  assert_eq(feed.skip_days, ["Monday"])
  assert_eq(feed.diagnostics.length(), 8)
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("skipHours hour") && d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.UnsupportedNestedMarkup("rss hour") && d.line == 2
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("skipHours duplicate") && d.line == 3
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("skipDays day") && d.line == 4
    }),
  )
  assert_true(
    feed.diagnostics.any(fn(d) {
      d.kind is @feedlens.InvalidRssField("skipDays duplicate") && d.line == 5
    }),
  )
}

///|
test "RSS skip containers cap recognized children at 24 hours and seven days" {
  let input =
    #|<rss version="2.0"><channel><title>All week</title><link>https://example.test/</link><description>Notes</description>
    #|<skipHours><hour>0</hour><hour>1</hour><hour>2</hour><hour>3</hour><hour>4</hour><hour>5</hour><hour>6</hour><hour>7</hour><hour>8</hour><hour>9</hour><hour>10</hour><hour>11</hour><hour>12</hour><hour>13</hour><hour>14</hour><hour>15</hour><hour>16</hour><hour>17</hour><hour>18</hour><hour>19</hour><hour>20</hour><hour>21</hour><hour>22</hour><hour>23</hour><hour>0</hour></skipHours>
    #|<skipDays><day>Monday</day><day>Tuesday</day><day>Wednesday</day><day>Thursday</day><day>Friday</day><day>Saturday</day><day>Sunday</day><day>Monday</day></skipDays></channel></rss>
  guard @feedlens.parse(input) is Ok(feed) else { fail("expected RSS") }
  assert_eq(feed.skip_hours.length(), 24)
  assert_eq(feed.skip_days.length(), 7)
  assert_eq(feed.diagnostics.length(), 2)
  assert_true(
    feed.diagnostics[0].kind is @feedlens.InvalidRssField("skipHours hour"),
  )
  assert_true(
    feed.diagnostics[1].kind is @feedlens.InvalidRssField("skipDays day"),
  )
}
