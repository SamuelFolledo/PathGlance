# Widget and Settings

> **Where:** third tab; Settings is the sheet behind its menu button · **Code:** `WidgetView`, `SettingsSheet` (`PathGlance/Features/Widget/WidgetView.swift`), `LinesShownRows`, `FavoriteStopsView` (`Sheets/OptionViews.swift`), `WidgetPreviewCard`, `RoundPreviewCard`, `PreviewFeed` · widgets: `PathGlanceWidget/PathGlanceWidget.swift` · data: `WidgetLook`, `WidgetPreset` (`Shared/WidgetSupport.swift`), `WidgetShape`, `RoundLook`, `RoundPreset`, `RoundFace` (`Shared/RoundWidget.swift`), `WidgetStyle` (`Shared/Board.swift`)

## Summary

- There are two lock screen widgets: **Rectangle**, which takes two slots, and **Round**, which takes one. iOS offers nothing wider than the rectangle. (decided 2026-11-26)
- The tab shows each as it will look, and everything that changes it. Underline tabs under the title pick the shape.
- Edits show in the preview at once but only reach the real widgets on **Save**; **Cancel** sits beside it. One Save sends both shapes.
- A preset is a ready-made look. Changing anything after choosing one makes it that shape's custom look.
- Everything that is not about the widgets' look is in the Settings sheet.

## Title and menu button

"Widget", small and centered, with the round menu button at its right. The button has room above the pinned preview. (decided 2026-11-23)

## Shape tabs

"Rectangle" and "Round" as `UnderlineTabs`, the same tabs as the lines on Trains. The two shapes are pages side by side: tap a tab, or swipe anywhere under the carousel, and the page slides across. A swipe on the carousel moves the carousel instead. (decided 2026-11-26)

## Preview and presets

The preview is a carousel of the shape's presets (`Carousel`, see [UI](../shared/ui.md)): the chosen one in the middle with a blue outline and its name under it, its neighbours peeking in at both sides, dots under the row. Swipe, or tap a neighbour, to choose. It replaces the "Presets" row and its sheet. (decided 2026-11-26)

- **Each card is the widget itself**, drawn by the widget's own view at its real size and enlarged, with live times. All cards read one `PreviewFeed`, so the live feed is fetched once.
- **The chosen rectangle card behaves like the widget:** the top row refreshes, a line opens that destination's trains. Neighbours are pictures.
- **Custom is the first card of each carousel.** A look that matches no built-in preset becomes that shape's custom look the moment it is made, before Save, so moving on to another preset does not lose it. Each shape remembers one (`customWidgetPreset`, `customRoundPreset`). The single custom look older builds kept is the rectangle's. Until there is one, the card says "Change any option below and your own look is kept here."
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
- **Times:** Full ("10:16, 10:35, 10:55") or Shortened ("10:16 :35 :55"); a stepper for the most trains per line; a check for "Arrival time of the next train" (shown as 7:16→7:35).

Round:

- **Font:** the same five.
- **Line:** "First line shown", or one destination for the circle to follow. At a station that line does not leave from, it follows the first line shown. It is not part of the look: it takes effect at once, without Save, and does not make a preset custom.

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
- **About:** Email the developer, Report a problem, Share, Help, Privacy policy, Welcome note, then one block of text with the version, the developer and the not-affiliated disclaimer (`AppInfo`).
- **Restore defaults:** always asks (`restore-defaults` guide, cannot be silenced), with three boxes for what to keep: favorite stops, muted issues, lock screen presets. All start unticked each time. (2026-11-27)

The sheet has no subtitle under its title, and no row that is only text: what a row is set to sits on a second line under its title (`DetailRow`). (2026-11-27)

## Open questions

- **Text size at "Standard":** the app draws one step above the phone's own size, because every screen was designed and approved at that size. The owner has not been asked whether "Standard" should be exactly the phone's size.
- **Round presets' fonts and pairings** with the rectangle presets, as drawn on the design page's Review tab.
- **The eleven rectangle presets** still wait for approval.
- **Not seen on a real lock screen:** the round widget has only been drawn in the app's preview.
