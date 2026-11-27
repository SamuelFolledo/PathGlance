# Trains

> **Where:** first tab · **Code:** `TrainsView` (`PathGlance/Features/Trains/TrainsView.swift`), `TrainListPage`, `TrainRows`, `TrainColumn` (`TrainListPage.swift`) · data: `TrainListCache` (`Data/TrainList.swift`), `Board` (`Shared/Board.swift`)

## Summary

- The station is the title, with the date under it in the brand colour. Under that, underline tabs for the destinations, each with its next train. Under that, the column names, then the trains, day after day.
- Scrolled on past the next train, the station title leaves and the date takes its place. Back at now or earlier, the title returns.
- The date is always on screen: it is the way to the calendar.
- Swiping sideways turns to the next destination at the same time of the same day.
- Live trains carry a dot: green on time, yellow when late.
- A train row opens its stops; press and hold a row for what else can be done.

## Header (design U7)

Chosen from round six on the design page. (decided 2026-11-25)

### Title: "From Journal Square"

Centered, at every text size, on two lines if it needs them. Tap it for the station list (`StationMenu`), the same list the station button beside the tab bar and Settings open. Each station has a star at its end: tap it to make that station a favorite stop, with its own column of arrival times. The star does not choose the station and does not close the list; "Clear favorite stops" at the bottom appears once there is one. (star decided 2026-11-27) Choosing a station is explained first by the `change-station` guide ([guides](welcome-and-guides.md)). (decided 2026-11-23)

- **Leaves on scroll:** once the row at the top of the list is later than the next train, the title goes and the date is drawn at the title's size in its place (`TrainList.isAhead`, `TrainListHeader`). (decided 2026-11-25)
- **Returns:** at the next train, at any earlier train or day, and after "Back to now". (decided 2026-11-25)

### Date

"Today · Wed, Nov 25" with a right chevron, in the brand colour on every day. It names the day at the top of the list and changes as the list scrolls. Tap for the calendar. It is never hidden. (decided 2026-11-25)

- **Calendar:** a month calendar in a small centered card (`AppSheet` style `.popup`). It opens on the day being viewed, which is highlighted; today keeps its own mark. "Back to now" is a full-width button. (decided 2026-11-23)
- **Range:** a week back to two weeks ahead. (decided 2026-11-23)

### Destination tabs

One tab per destination the station has trains to (`BoardRules` in `Shared/Board.swift`; the table is in the repo README). A destination hidden under Settings > Lines preferred has no tab, and the order set there is the order of the tabs, so the line put first is the one the tab opens on. (decided 2026-11-23, order 2026-11-27)

- **Look:** plain text on a hairline, the selected tab underlined in the brand colour (`UnderlineTabs` in `DesignSystem/UI/Tabs`). Not a segmented control and not pills. (decided 2026-11-25)
- **Next train:** under each name, always stacked, scrolled or not: "Now", "4 min", or the clock time once it is an hour or more away; "No trains" when there is none (`TrainList.waitText`). It is green, or yellow when that train is running late, on every tab; an unselected tab keeps the hue, only quieter. It uses the live feed where there is one and is worked out again every minute. (decided 2026-11-25; colour kept on unselected tabs 2026-11-26)
- **Type:** the name is body size and bold, the wait under it is smaller and not bold. Set in `UnderlineTabs`, so every use of the tabs matches. (decided 2026-11-26)

### Banners

Under the tabs, above the column names: one strip per thing worth knowing before you read the times (`IssueBannerStack` in `DesignSystem/UI/Banner`, design IN). (decided 2026-11-26)

- **What shows:** open issues whose kind is not muted and whose text names this station or a line from it to the destination on screen (`IssueMatcher` in `Data/IssueMatch.swift`), the station's own first; then the holiday-timetable note for the day on screen. An issue whose text names neither stays on the Issues tab only.
- **One at a time:** each banner is the full width, with no peek of the next. Swipe sideways for the next or back; dots under them say how many there are.
- **Each banner:** icon, title, PATH's latest words, when they came, and an X.
- **X:** puts that banner away until tomorrow (`AppModel.dismissBanner`), here and in the stops sheet. Restore defaults brings them back.
- **Tap:** opens the issue's sheet (see [Issues](issues.md)); the holiday note opens a short explanation.
- The same banners, less the holiday note, sit at the top of a train's stops sheet.

### Column names

Plain text above the list card, no pill and no panel (`TrainListPage`). When scrolled on, the rows fade out under them. (decided 2026-11-25) The holiday warning that sat above them is now a banner. (2026-11-26)

- **Tap a name** to hide that stop's column. Hidden names wait in a "Hidden" line above, struck through; tap one to bring its column back. Your own station, the first column, cannot be hidden. The choice is remembered (`hiddenColumns`) and Restore defaults clears it. (decided 2026-11-26)
- **Two columns at least.** One column of times says when a train leaves and nothing about where it gets to. A tap that would hide the last column beside your station is refused: the name shakes and the phone gives its error tap (`AppModel.canHideColumn`, `Shake`). The same goes for "Hide" in a row's press-and-hold menu. (decided 2026-11-27)

- **Columns:** your station, each favorite stop on the way, then the destination. Each column is exactly as wide as the widest time it can hold, and the space left over is shared equally between the columns however many there are (`TrainColumn`). Leading columns that do not fit are left out, which is what happens at large text. (decided 2026-11-23)

## Train rows

One row per train (`TrainRows`), one section per day; the line where a day ends is in the brand colour for today.

- **First column** is heavier than the arrival columns; the last column sits against the right edge.
- **Live:** the next train or two per line come from PATH's feed and carry a dot. The dot sits in the row's left margin, level with the middle of the row, so every time lines up with the rows that have none. (dot moved left 2026-11-26) When a train is late, the timetable time is struck through and the live time sits under it in yellow (`TrainTimeText`). See [data](../shared/data.md).
- **Tap:** opens the train's stops in a sheet. The arrows, or a sideways swipe, step to the train before or after.
- **Press and hold** (`TrainRowAction`): show every stop; hide a column; remove a favorite stop; show hidden columns; show or hide AM/PM; edit favorite stops; report this train's time by email.
- **Back to now:** once scrolled well away from the present, a way back is offered.

## Row heights

Every child of the list (a train, a late train with its two lines, a day heading, a route note) is one fixed height that grows with the text size (`rowHeight`). This is not a look choice: the list is lazy, and unequal heights made it jump hours back on the first scroll. (decided 2026-11-27)
