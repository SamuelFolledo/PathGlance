# PathGlance

An iPhone app and lock screen widget that show the next PATH trains from the nearest station.

Not made, endorsed or supported by PATH or the Port Authority.

```
From J Sq: 7:05 AM ↻
33rd? 7:16 :30 :50 8:00 :10
WTC 7:08 :14 :20 :26 :32
```

## How it works

- **Schedule**: the app reads the weekday, Saturday and Sunday timetables behind PATH's
  Schedules and Maps web pages (`WebTimetableImporter`) and reduces them to a compact
  `schedule.json` in the App Group container. It re-checks about once a day, in the
  background and on launch. This is not a documented API: if the page changes shape the
  import fails and the last good schedule stays in use. Every distinct timetable is kept
  (`TimetableArchive`).
- **Holidays**: PATH does not publish holiday timetables on those pages. `DayTypeLog`
  scores each day's live arrivals against the three timetables and switches to the one
  that clearly fits. Before a holiday has live data, the timetable that ran on the same
  holiday in an earlier year is used and flagged in the app.
- **Station**: nearest of the 13 stations. The widget reads its own location when allowed,
  and the app updates it in the background through station geofences ("Always" permission).
  You can also pin a station in the app.
- **Widget**: one timeline entry per departure, so times drop off on their own.
  It reloads every 20 minutes (60 with real-time off) and whenever the station changes.
  Each line is a link to that line's list of trains through the end of tomorrow. The
  refresh button reloads it; iOS ignores widget buttons while the phone is locked.
- **Real-time**: on each reload the first time or two per line is replaced with the
  Port Authority's live prediction. Later times are scheduled.
- **Delays**: `?` after a line label means its next live train is 5 to 9 minutes behind
  the timetable, `!` means 10 or more, or that an open PATH alert names the line as
  delayed or suspended. On a line running every few minutes a long delay can look like
  the next train on time, so the alert is the more reliable signal there.
- **Issues**: PATH's alert feed is read on each widget reload and when the app opens
  (`IssueLog`). Open issues show in the app; ended ones move to Archive with their start
  and end times. Any open alert other than an elevator notice puts a warning mark in the
  widget header.

## What each station shows

These are the defaults. Settings > Lines preferred puts them in your order and turns destinations off; a station left
with one line gives it both widget rows. When the same trains serve both destinations
they are listed once under a joint label such as `JSQ+HOB`.

| Station | Lines |
| --- | --- |
| Journal Square | 33rd, WTC |
| Grove St, Newport, Christopher, 9th, 14th, 23rd | 33rd, JSQ |
| 33rd Street | JSQ, HOB |
| World Trade Center | NWK |
| Hoboken | 33rd, WTC |
| Exchange Place | WTC, JSQ |
| Newark, Harrison | WTC |

When only one destination has trains, or the same trains serve both (Journal Square via
Hoboken at night), its times fill both lines. Edit `BoardRules` in `Shared/Board.swift` to change this.

## Layout

- `PathGlance/` app (iOS 26). Three tabs: Trains (one list per destination with a column
  per favorite stop, a week back to two weeks ahead), Issues (current and archived) and
  Widget (the lock screen preview, presets and look, with Settings behind its menu button).
  - `App/` the entry point, the tab bar, the model, app facts and links
  - `Data/` the timetable import and archive, train lists, location
  - `DesignSystem/Tokens/` the one set of measurements and the brand colour (`Theme`)
  - `DesignSystem/UI/` what screens are built from: `Sheet/` (the in-tab sheet), `Popover/`
    (menus and the station list), `Alert/` (guides and their full-width buttons), `Rows/`
    (radio, check, fold, link and open rows, the press-and-hold info popover)
  - `Features/` one folder per tab
- `PathGlanceWidget/` widget extension
- `Shared/` compiled into both: stations, schedule queries, board rules, real-time feed,
  alerts and the issue log, day-type learning, widget fonts and links
- `PathGlanceTests/` unit tests. They run the real importer on a made-up timetable
  (`Fixture.swift`), so they need no network.
- `PathGlanceUITests/` UI tests that drive the app against PATH's live data.
- `Config/` entitlements and Info.plists
- `landing/` the website, and `scripts/` the release script
- `docs/` everything written down about the app

## Docs

Start at [`docs/README.md`](docs/README.md).

- How each screen behaves: [Trains](docs/app/trains.md) · [Issues](docs/app/issues.md) ·
  [Widget and Settings](docs/app/widget.md) · [Welcome note and guides](docs/app/welcome-and-guides.md)
- What screens share: [UI rules and pieces](docs/shared/ui.md) · [Where the data comes from](docs/shared/data.md)
- [Glossary](docs/glossary.md)
- How we work: [Releases](docs/process/releases.md) · [Tests](docs/process/ui-tests.md)
- [Pictures](docs/visuals/README.md): icons, header options, tab ideas, wireframes
- [What is left to do, and what is done](docs/todos.md) · [Decisions](docs/decisions.md) · [Ideas](docs/ideas.md)

## Tests

```
xcodebuild test -scheme PathGlance -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Add `-only-testing:PathGlanceTests` for the unit tests alone. Set
`TEST_RUNNER_SHOT_DIR=/some/folder` to keep a screenshot of each UI test step. More in
[`docs/process/ui-tests.md`](docs/process/ui-tests.md).

## Setup

Bundle IDs are `com.samuelfolledo.PathGlance` and `.Widget`, with App Group
`group.com.samuelfolledo.PathGlance`. If you change them, update both entitlements files
and `SharedStore.appGroup`.
