# PathSchedule

Lock screen widget that shows the next PATH trains from the nearest station.

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

These are the defaults. Settings > Destinations lets you list preferred destinations
(a line's end or any stop); the widget then shows the first two that trains from the
current station reach.

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

- `PathSchedule/` app (iOS 26): three tabs. Trains (lock screen preview, then trains by
  station, destination and day), Issues (current and archived) and Settings. Also the
  timetable import and archive, and location
- `PathScheduleWidget/` widget extension
- `Shared/` compiled into both: stations, schedule queries, board rules, real-time feed,
  alerts and the issue log, day-type learning, widget fonts and links
- `Config/` entitlements and Info.plists

## Setup

Bundle IDs are `com.samuelfolledo.PathSchedule` and `.Widget`, with App Group
`group.com.samuelfolledo.PathSchedule`. If you change them, update both entitlements files
and `SharedStore.appGroup`.
