# Template — Event Promotion

Webinars, AMAs, launch livestreams, conference days.

## When to use

- Scheduled live event with registration URL
- Countdown series (announce → educate → remind → live)

## Required customization

1. `strategy.message` — event title, date/time, timezone
2. Replace `EVENT_URL`, `CALENDAR_URL`, `STREAM_URL` in posts
3. Schedule `ev-05-live` at event start (UTC in `scheduledAt`)
4. Event banner via Canva `event-banner` template

## Timeline tip

| Days before event | Suggested rows |
|-------------------|----------------|
| 7+ | ev-01 announce |
| 3–5 | ev-02 agenda |
| 1 | ev-03 reminder |
| 0 | ev-05 join-live |

Matrix reference: `CONTENT_MATRIX.md` (event-promotion section).
