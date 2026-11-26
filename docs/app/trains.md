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

Centered, at every text size, on two lines if it needs them. Tap it for the station list and favorite stops (`StationMenu`), the same list the station button beside the tab bar opens. Choosing a station is explained first by the `change-station` guide ([guides](welcome-and-guides.md)). (decided 2026-11-23)

- **Leaves on scroll:** once the row at the top of the list is later than the next train, the title goes and the date is drawn at the title's size in its place (`TrainList.isAhead`, `TrainListHeader`). (decided 2026-11-25)
- **Returns:** at the next train, at any earlier train or day, and after "Back to now". (decided 2026-11-25)

### Date

"Today · Wed, Nov 25" with a right chevron, in the brand colour on every day. It names the day at the top of the list and changes as the list scrolls. Tap for the calendar. It is never hidden. (decided 2026-11-25)

- **Calendar:** a month calendar in a small centered card (`AppSheet` style `.popup`). It opens on the day being viewed, which is highlighted; today keeps its own mark. "Back to now" is a full-width button. (decided 2026-11-23)
- **Range:** a week back to two weeks ahead. (decided 2026-11-23)

### Destination tabs

One tab per destination the station has trains to (`BoardRules` in `Shared/Board.swift`; the table is in the repo README). A destination hidden under Widget > Lines shown has no tab. (decided 2026-11-23)

- **Look:** plain text on a hairline, the selected tab underlined in the brand colour (`UnderlineTabs` in `DesignSystem/UI/Tabs`). Not a segmented control and not pills. (decided 2026-11-25)
- **Next train:** under each name, always stacked, scrolled or not: "Now", "4 min", or the clock time once it is an hour or more away; "No trains" when there is none (`TrainList.waitText`). On the selected tab it is green, or yellow when that train is running late. It uses the live feed where there is one and is worked out again every minute. (decided 2026-11-25)

### Column names

Plain text above the list card, no pill and no panel; a holiday warning sits above them when the day has one (`TrainListPage`). When scrolled on, the rows fade out under them. (decided 2026-11-25)

- **Columns:** your station, each favorite stop on the way, then the destination. Each column is exactly as wide as the widest time it can hold, and the space left over is shared equally between the columns however many there are (`TrainColumn`). Leading columns that do not fit are left out, which is what happens at large text. (decided 2026-11-23)

## Train rows

One row per train (`TrainRows`), one section per day; the line where a day ends is in the brand colour for today.

- **First column** is heavier than the arrival columns; the last column sits against the right edge.
- **Live:** the next train or two per line come from PATH's feed and carry a dot. When a train is late, the timetable time is struck through and the live time sits under it in yellow (`TrainTimeText`). See [data](../shared/data.md).
- **Tap:** opens the train's stops in a sheet. The arrows, or a sideways swipe, step to the train before or after.
- **Press and hold** (`TrainRowAction`): show every stop; hide a column; remove a favorite stop; show hidden columns; show or hide AM/PM; edit favorite stops; report this train's time by email.
- **Back to now:** once scrolled well away from the present, a way back is offered.
