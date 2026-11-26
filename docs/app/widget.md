# Widget and Settings

> **Where:** third tab; Settings is the sheet behind its menu button · **Code:** `WidgetView`, `SettingsSheet` (`PathGlance/Features/Widget/WidgetView.swift`), `LinesShownRows`, `FavoriteStopsView` (`Sheets/OptionViews.swift`), `WidgetPreviewCard` · widget: `PathGlanceWidget/PathGlanceWidget.swift` · data: `WidgetLook`, `WidgetPreset` (`Shared/WidgetSupport.swift`), `WidgetStyle` (`Shared/Board.swift`)

## Summary

- The tab shows the lock screen widget as it will look, and everything that changes it.
- Edits show in the preview at once but only reach the real widget on **Save**; **Cancel** sits beside it.
- A preset is a ready-made look. Changing anything after choosing one makes it a custom look.
- Everything that is not about the widget's look is in the Settings sheet.

## Title and menu button

"Widget", small and centered, with the round menu button at its right. The button has room above the pinned preview. (decided 2026-11-23)

## Preview

The widget on a stand-in lock screen, behaving as the widget does. It is pinned under the title while the settings scroll beneath; a phone on its side has too little height for that, so there it scrolls with the rest. (decided 2026-11-23)

- **Station names are heavier than times:** the station in the header ("From **J Sq**: 9:04 PM") and each line's destination with its delay mark ("**33rd?**") are bold; the times stay medium (`WidgetFontStyle.nameWeight`, `BoardLine.nameLength`). It applies to the widget itself, the preview and every preset. The lock screen keeps weights but not colours, which is why this is done with weight. (decided 2026-11-25)

## Presets

One row ("Presets", the current name, a chevron) opens the list: the last custom look saved, then the built-in looks, each drawn as it would appear. The name reads "Default", "Large", "Custom", or "Custom, not saved" while being edited.

| Preset (`id`) | Detail shown | Font | Size | Times | Arrival | Most trains per line |
|---|---|---|---|---|---|---|
| Default (`default`) | Full times, compact | Standard | Compact | Full | no | as many as fit |
| Packed (`packed`) | Shortened times, as many trains as fit | Condensed | Compact | Shortened | no | as many as fit |
| Large (`large`) | Bigger text, fewer trains | Rounded | Regular | Shortened | no | 3 |
| Next train (`arrivals`) | The next train and when it arrives | Standard | Regular | Full | yes | 2 |
| Departure board (`board`) | Monospaced, columns line up | Monospaced | Compact | Shortened | no | as many as fit |
| Timetable (`timetable`) | Serif, like a printed timetable | Serif | Compact | Full | no | as many as fit |
| Soft (`soft`) | Rounded text, full times | Rounded | Compact | Full | no | as many as fit |
| Commuter (`commuter`) | When the next train arrives, then as many as fit | Condensed | Compact | Full | yes | as many as fit |
| Next two (`nexttwo`) | Big and rounded, only the next two trains | Rounded | Regular | Full | no | 2 |
| Terminal (`terminal`) | Big monospaced text, up to four trains | Monospaced | Regular | Shortened | no | 4 |
| Headline (`headline`) | Big serif text, up to three trains | Serif | Regular | Shortened | no | 3 |

Source: `WidgetPreset.builtIn`. (decided 2026-11-23)

## Look settings

Each group is a `FoldCard` that folds away and remembers it; folded, it shows its current value.

- **Font:** Standard, Rounded, Monospaced, Condensed, Serif (`WidgetFontStyle`). Sets the typeface of the whole widget.
- **Size:** Compact ("Smaller text, more trains") or Regular ("Larger text, fewer trains"). The text is never shrunk to fit: larger text simply shows fewer trains.
- **Times:** Full ("10:16, 10:35, 10:55") or Shortened ("10:16 :35 :55"); a stepper for the most trains per line; a check for "Arrival time of the next train" (shown as 7:16→7:35).
- **Lines shown:** one check per destination. Hiding one raises the `hide-line` guide.
- **Muted issues:** one check per issue kind.
- **Favorite stops:** listed here inline, the same data as the Trains tab's columns (`FavoriteStopsView`); it does not switch tab or open a sheet. "Clear all" raises `clear-favorites`. (decided 2026-11-23)

## The widget itself

Families: `accessoryRectangular` (lock screen) and `systemMedium`. Name in the gallery: "Next PATH trains". One timeline entry per departure, so times drop off on their own. The refresh button reloads it; iOS ignores widget buttons while the phone is locked. Each line links to that line's list in the app (`AppLink`).

## Settings sheet

Opened by the menu button (`SettingsSheet`). Groups, top to bottom:

- **Station:** From (Nearest or a station), Detected, Location access; "Turn on location in Settings" when access is denied.
- **Schedule:** the timetable in use and when it was checked.
- **Text size:** steps for text throughout the app; the widget has its own Size.
- **Timetables:** every distinct timetable downloaded (`ArchiveViews.swift`).
- **Learned day types:** what the app has worked out about holidays.
- **Support the app:** Buy Me a Coffee, PayPal, Venmo, Cash App. Each opens outside the app; nothing is locked behind a tip. (decided 2026-11-23)
- **About:** Email the developer, Report a problem, Share, Help, Privacy policy, Welcome note, Version, Developer, and the not-affiliated disclaimer (`AppInfo`).
- **Restore defaults:** always asks (`restore-defaults` guide, cannot be silenced).

## Open questions

- **Layout ideas** WA to WF are on the design page (lock screen hero, preset carousel, settings in tabs, one screen of rows, setup steps, preview the states). None is chosen.
