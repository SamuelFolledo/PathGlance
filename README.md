# PathSchedule

Lock screen widget that shows the next PATH trains from the nearest station.

```
From J Sq: 7:05
33rd 7:10 :30 :50 8:00 :10
WTC 7:08 :14 :20 :26 :32
```

## How it works

- **Schedule**: the app downloads PATH's published GTFS feed, reduces it to a compact
  `schedule.json` in the App Group container, and refreshes it weekly on launch.
  If the download fails, save the GTFS zip to Files and use "Import GTFS zip from Files".
- **Station**: nearest of the 13 stations. The widget reads its own location when allowed,
  and the app updates it in the background through station geofences ("Always" permission).
  You can also pin a station in the app.
- **Widget**: one timeline entry per departure, so times drop off on their own.
  It reloads every 20 minutes (60 with real-time off) and whenever the station changes.
- **Real-time**: on each reload the first time or two per line is replaced with the
  Port Authority's live prediction. Later times are scheduled.

## What each station shows

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

- `PathSchedule/` app: GTFS import, location, settings
- `PathScheduleWidget/` widget extension
- `Shared/` compiled into both: stations, schedule queries, board rules, real-time feed
- `Config/` entitlements and the widget Info.plist

## Setup

Bundle IDs are `com.samuelfolledo.PathSchedule` and `.Widget`, with App Group
`group.com.samuelfolledo.PathSchedule`. If you change them, update both entitlements files
and `SharedStore.appGroup`.
