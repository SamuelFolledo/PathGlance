# Widget and Settings

> **Where:** third tab; Settings is the sheet behind its menu button · **Code:** `WidgetView`, `SettingsSheet` (`PathGlance/Features/Widget/WidgetView.swift`), `LinesShownRows`, `FavoriteStopsView` (`Sheets/OptionViews.swift`), `WidgetPreviewCard`, `RoundPreviewCard`, `PreviewFeed` · widgets: `PathGlanceWidget/PathGlanceWidget.swift` · data: `WidgetLook`, `WidgetPreset` (`Shared/WidgetSupport.swift`), `WidgetShape`, `RoundLook`, `RoundPreset`, `RoundFace` (`Shared/RoundWidget.swift`), `WidgetStyle` (`Shared/Board.swift`), `PresetBook` (`PathGlance/Data/PresetBook.swift`)

## Summary

- There are two lock screen widgets: **Rectangle**, which takes two slots, and **Round**, which takes one. iOS offers nothing wider than the rectangle. (decided 2026-11-26)
- The tab shows each as it will look, and everything that changes it. Underline tabs under the title pick the shape.
- Edits show in the preview at once but only reach the real widgets on **Save**; **Cancel** sits beside it. One Save sends both shapes.
- A preset is a ready-made look. Changing anything changes the preset in hand, and Save keeps the change with that preset. There is no separate custom look. (2026-11-27)
- Everything that is not about the widgets' look is in the Settings sheet.

## Title and menu button

"Widget", small and centered, with the round menu button at its right. The button has room above the pinned preview. (decided 2026-11-23)

## Shape tabs

"Rectangle" and "Round" as `UnderlineTabs`, the same tabs as the lines on Trains. The two shapes are pages side by side: tap a tab, or swipe anywhere under the carousel, and the page slides across. A swipe on the carousel moves the carousel instead. (decided 2026-11-26)

## Preview and presets

The preview is a carousel of the shape's presets (`Carousel`, see [UI](../shared/ui.md)): the chosen one in the middle with a blue outline and its name under it, its neighbours peeking in at both sides, dots under the row. Swipe, or tap a neighbour, to choose. It replaces the "Presets" row and its sheet. (decided 2026-11-26)

- **Each card is the widget itself**, drawn by the widget's own view at its real size and enlarged, with live times. All cards read one `PreviewFeed`, so the live feed is fetched once.
- **The chosen rectangle card behaves like the widget:** the top row refreshes, a line opens that destination's trains. Neighbours are pictures.
- **Edits stay with their preset.** An option changed while a preset is in the middle changes that preset: the card stays where it is and its name gains "· Edited". Save sends it to the widget and keeps it with the preset (`PresetBook.edits`, by preset id, one book per shape). A preset back at its built-in values has no entry. (decided 2026-11-27, replacing the Custom card of 2026-11-26)
- **Turning to another preset drops what was not saved** on the one left behind, with no question asked. Edits that were saved wait with their preset and show again when it is turned back to.
- **Restore preset**, the last row under each shape's settings, puts the preset in hand back to its built-in values. It is an edit like any other: the preview shows it at once, Save sends it, Cancel undoes it. It is greyed out when the preset has nothing to restore.
- **Taking over from older builds** (`PresetBook.resolve`): a saved look that matches no preset becomes edits on the first preset of its shape (Default, Minutes). The spare custom look those builds kept does too, unless the first preset is the one in use as built: what the widget shows is kept. The old keys (`customWidgetPreset`, `customRoundPreset`) are read once and removed.
- **Pinned:** the carousel stays under the tabs while the settings scroll beneath; a phone on its side has too little height for that, so there it scrolls with the rest. (decided 2026-11-23)
- **Station names are heavier than times:** the station in the header ("From **J Sq**: 9:04 PM") and each line's destination with its delay mark ("**33rd?**") are bold; the times stay medium (`WidgetFontStyle.nameWeight`, `BoardLine.nameLength`). It applies to both widgets, the previews and every preset. The lock screen keeps weights but not colours, which is why this is done with weight. (decided 2026-11-25)

### Rectangle presets

| Preset (`id`) | Detail | Font | Size | Times | Arrival | Most trains per line |
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

Source: `WidgetPreset.builtIn`. (decided 2026-11-23; still waiting for the owner's approval of the set)

### Round presets

| Preset (`id`) | What the circle shows | Font |
|---|---|---|
| Minutes (`minutes`) | the line, the minutes until its next train, "min" | Standard |
| Clock time (`clock`) | the line and when its next train leaves | Standard |
| Countdown ring (`ring`) | a ring that empties as the train nears (full at 20 minutes or more), the minutes and the line inside | Standard |
| Next two (`nexttwo`) | the line and the minutes until its next two trains ("4, 14") | Rounded |
| Two lines (`twolines`) | two lines, each with the minutes until its next train | Condensed |

Source: `RoundPreset.builtIn`; the wording is worked out by `RoundFace.make`. Under a minute reads "Now"; an hour or more away reads as a clock time. (built 2026-11-26. **The fonts are a default waiting for the owner's answer.**)

## Look settings

Each group is a `FoldCard` that folds away and remembers it; folded, it shows its current value. Only the shape's own groups are here. What both shapes share (the lines, muted issues) is in the Settings sheet, and favorite stops are starred in the station list. (2026-11-27)

Rectangle:

- **Font:** Standard, Rounded, Monospaced, Condensed, Serif (`WidgetFontStyle`). Sets the typeface of the whole widget.
- **Size:** Compact ("Smaller text, more trains") or Regular ("Larger text, fewer trains"). The text is never shrunk to fit: larger text simply shows fewer trains.
- **Time format** (was "Times"): Full ("10:16, 10:35, 10:55") or Shortened ("10:16 :35 :55"). Only the two radio rows. (2026-11-27)
- **Show:** what the lines carry, each its own row. (2026-11-27)
	- A stepper for the most trains per line.
	- **Arrival time of the next train**, shown as 7:16→7:35.
	- **Skip the next train:** each line starts from its second train, for a walk too long to catch the next one. A line down to its last train still shows it. Off by default.
	- **AM and PM:** after each line's first time, and again where the times cross noon or midnight ("11:50 AM, 12:05 PM, 12:20"). With an arrival it follows the arrival ("7:16→7:35 AM"). Off by default.
	- **Compress more:** the letters sit closer and the space after each comma goes, which often fits one more train. Off by default.
	- **From station:** the top row ("From J Sq: 9:04 PM"). On by default. Turning it off raises the `hide-widget-header` guide first, because the last-updated time, the refresh tap and the alert mark are on that row and go with it.
- **Restore preset**, described above.

Round:

- **Font:** the same five.
- **Line:** "First line shown", or one destination for the circle to follow. At a station that line does not leave from, it follows the first line shown. It is not part of the look: it takes effect at once, without Save, and does not count as an edit to a preset.
- **Show:** "Skip the next train", and "AM and PM", which only shows on a preset that draws a clock time (Clock time). (2026-11-27)
- **Restore preset.**

All of Show is part of the look (`WidgetStyle`, `RoundLook`), so it is saved with the preset in hand. A look saved before an option existed still reads, with that option at its default.

## Legend

A grey strip under the carousel, above the settings, saying what each mark in the widget means, one mark per page: swipe sideways, dots under it. It is the issue banner (`IssueBannerStack`, see [UI](../shared/ui.md)) with nothing to open. (2026-11-27)

- **Rectangle:** the top row and its time; ? and ! after a line; the warning triangle; the arrival arrow; bold names.
- **Round:** Now, minutes and clock times; ? and !; the ring; bold names.
- **The X closes the whole legend for good**, on both shapes. "Widget legend" under About in Settings brings it back and returns to the Widget tab; so does Restore defaults.

## The widgets themselves

Two entries in the widget gallery, in one bundle (`PathGlanceWidgets`):

- **"Next PATH trains"** (`PathBoard`): `accessoryRectangular` (lock screen) and `systemMedium`. One timeline entry per departure, so times drop off on their own. The refresh button reloads it; iOS ignores widget buttons while the phone is locked. Each line links to that line's list in the app (`AppLink`).
- **"Next PATH train"** (`PathRound`): `accessoryCircular`. It counts minutes, so its timeline has an entry for every whole minute until the next reload (20 minutes with live times), plus ten minutes of slack. Tapping it opens its line's list in the app. It is a second widget and not a third family of the first, so each keeps its own timeline.

Both read the same station, live times and issues (`BoardProvider.plan`).

## Settings sheet

Opened by the menu button (`SettingsSheet`). Groups, top to bottom:

- **Preferences** (was "Station"):
	- **From \<station\>**, with where it comes from and what the phone last found nearest on the line under it. Opens the station list.
	- **Location access**, with its state under it. A tap asks for the next step up: While Using, then Always. iOS asks each of those once, so after that, and when access is off, the tap opens the Settings app. With Always it reads "Always allowed" and does nothing.
	- **Muted issues**, with the muted kinds under it. A tap opens the checks in place. (moved from the Widget tab 2026-11-27)
- **Lines preferred** (was "Lines shown" on the Widget tab): a row per line with a drag handle, then a round check (`LinesPreferredRows`). Starts folded. Dragging sets the order of the Trains tabs, the rectangle widget's rows and the round widget's first line; the check hides a line from all three and raises `hide-line`. It is one list in `AppModel` (`lineOrder`, `hiddenTargets`), stored in the App Group so the widgets read the same one. The order never adds a line to a widget: it only arranges the lines the station's rules give it. The standard order leaves every station exactly as it was. (2026-11-27)
- **Schedule:** "Last updated" and "Schedule" (the timetable's name), and "Update schedule now". When more than one timetable has been downloaded, they are listed below with the days each was in use; one alone is just the one already named. (2026-11-27)
- **Text size:** the app follows the phone's text size. The slider moves it up to three steps either way from there, and "Back to standard" returns to following it (`AppModel.textSize(system:offset:)`). It stops at the smallest and largest sizes the layouts are made for. The widgets have their own Size. (2026-11-27)
- **Learned day types:** which timetable PATH really ran on each day, worked out by the widget from live arrivals. Hidden until there is at least one day in it. (2026-11-27)
- **Support the app:** Buy Me a Coffee, PayPal, Venmo, Cash App. Each opens outside the app; nothing is locked behind a tip. (decided 2026-11-23)
- **About:** Email the developer, Report a problem, Share, Help, Privacy policy, Welcome note, Widget legend, then one block of text with the version, the developer and the not-affiliated disclaimer (`AppInfo`).
- **Restore defaults:** always asks (`restore-defaults` guide, cannot be silenced), with three boxes for what to keep: favorite stops, muted issues, lock screen presets. All start unticked each time. (2026-11-27)

The sheet has no subtitle under its title, and no row that is only text: what a row is set to sits on a second line under its title (`DetailRow`). (2026-11-27)

## Open questions

- **Text size at "Standard":** the app draws one step above the phone's own size, because every screen was designed and approved at that size. The owner has not been asked whether "Standard" should be exactly the phone's size.
- **Round presets' fonts and pairings** with the rectangle presets, as drawn on the design page's Review tab.
- **Hiding the station row frees no room for the lines:** they stay two lines at the same size, with the space above them empty. The owner was told it "gives the lines more room"; that is not what was built.
- **AM and PM is said once per line**, not after every time, to keep room for trains. The owner asked for it "on the train times" and has not seen this reading.
- **"Compress more"** is read as closer letters and no space after commas.
- **More toggles suggested, not built:** see [`ideas.md`](../ideas.md).
- **The eleven rectangle presets** still wait for approval.
- **Not seen on a real lock screen:** the round widget has only been drawn in the app's preview.
