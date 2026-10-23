# Announced positive leap seconds used by the offline date audit

Source: [NIST leap-second table](https://www.nist.gov/pml/time-and-frequency-division/time-realization/leap-seconds), checked 2026-10-23. The dates below are UTC dates whose final minute contained `23:59:60`. This is an auditable snapshot of **27 past events**, not a schedule of future seconds. IERS Bulletin C announcements must be checked before extending it.

```text
1972-06-30
1972-12-31
1973-12-31
1974-12-31
1975-12-31
1976-12-31
1977-12-31
1978-12-31
1979-12-31
1981-06-30
1982-06-30
1983-06-30
1985-06-30
1987-12-31
1989-12-31
1990-12-31
1992-06-30
1993-06-30
1994-06-30
1995-12-31
1997-06-30
1998-12-31
2005-12-31
2008-12-31
2012-06-30
2015-06-30
2016-12-31
```

`NormalizedDate.utc` preserves the leap-second label. `unix_seconds` uses the previous POSIX second, so `is_leap_second` is required to distinguish the two. The format parser keeps the source date unchanged; normalization is a separate call. Python/feedparser cannot serve as a leap-second-aware timestamp oracle: the offline script compares feed IDs/raw dates and independently checks the UTC positions against this snapshot.
