# Data

> **Code:** `Shared/` (compiled into the app and the widget): `ScheduleData.swift`, `Board.swift`, `Realtime.swift`, `Issues.swift`, `DayTypes.swift`, `Station.swift`, `SharedStore.swift` · app only: `PathSchedule/Data/WebTimetableImporter.swift`, `TimetableArchive.swift`, `TrainList.swift`, `LocationService.swift`

## Summary

- Train times are PATH's published timetable, read from PATH's website about once a day.
- The next train or two per line are replaced by PATH's live prediction. Everything later is the timetable.
- Nothing leaves the phone: no account, no analytics. Location is used only to pick the nearest station.

## Timetable

The app reads the weekday, Saturday and Sunday timetables behind PATH's Schedules and Maps web pages (`WebTimetableImporter`) and reduces them to a compact `schedule.json` in the App Group container. It re-checks about once a day, in the background and on launch. This is not a documented API: if the page changes shape the import fails and the last good schedule stays in use. Every distinct timetable is kept (`TimetableArchive`).

## Live times

`RealtimeFeed` (`Shared/Realtime.swift`) reads the Port Authority feed behind PATH's schedules page. It covers only the next train or two per direction. `Board.apply(realtime:)` swaps those in for the earliest scheduled times and marks them live. In the app a live train has a green dot, or a yellow one when it is late; in the widget `?` after a line label means the next live train is 5 to 9 minutes behind the timetable and `!` means 10 or more, or that an open alert names the line as delayed or suspended.

The welcome note therefore says "the next train or two", not "the next two". (decided 2026-11-23)

## Day types and holidays

PATH does not publish holiday timetables on those pages. `DayTypeLog` (`Shared/DayTypes.swift`) scores each day's live arrivals against the three timetables and switches to the one that clearly fits. Before a holiday has live data, the timetable that ran on the same holiday in an earlier year is used and flagged in the app.

## Station

Nearest of the 13 stations (`Station`). The widget reads its own location when allowed, and the app updates it in the background through station geofences with "Always" permission (`LocationService`). A station can also be pinned in the app.

## Issues

PATH's alert feed is read on each widget reload and when the app opens (`IssueLog`, `Shared/Issues.swift`). Open issues show in the app; ended ones move to Archived with their start and end times. Any open alert whose kind is not muted puts a warning mark in the widget header; elevator notices start muted.

## Privacy

`Shared/PrivacyInfo.xcprivacy`: no tracking, no collected data. The App Store answer is "Data Not Collected".
