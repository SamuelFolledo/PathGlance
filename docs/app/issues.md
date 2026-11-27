# Issues

> **Where:** second tab · **Code:** `PathGlance/Features/Issues/IssuesView.swift` (the tab), `IssueViews.swift` (rows, the sheet) · data: `IssueLog`, `IssueKind` (`Shared/Issues.swift`), `IssueBoard`, `IssueMatcher` (`PathGlance/Data/`)

## Summary

- A tab per line; under it the line drawn as its stops, with every open issue written out at the stop it names. (decided and built 2026-11-27: design IG's tabs with IH-b's content)
- Tapping an issue opens its sheet.
- The tab's red badge counts open issues whose kind is not muted.
- Muting a kind keeps it listed but takes it off the badge, the tabs' counts and the widget; it is explained first.
- Elevator and escalator notices start muted.

## Title

"Issues", small and centered (`TabTitle`). (decided 2026-11-23)

## Tabs

Underline tabs (`UnderlineTabs`), the same as on Trains, with pages that slide sideways by tap or swipe.

- **Three tabs:** JSQ–33rd, NWK–WTC, and Hoboken, which holds the two Hoboken lines (HOB–33rd, then HOB–WTC), each under its own small heading.
- **Under each name:** "Good" in green, or "2 issues" in orange: the open issues on that tab's lines whose kind is not muted. Issues in "Other" are no line's and are not counted.
- **Order** follows Settings > Lines preferred: a tab stands where the first of its lines' ends stands in that list (`IssueBoard.tabs`). The standard order gives the three above.

## A line's card

The line's stops on a vertical rail in its map colour (`IssueStrip`).

- **A stop with nothing wrong** is one dim line. Your station carries a "You" tag.
- **A stop with an issue** gets a filled marker in the kind's colour, and under its name each issue: icon, title, then every update PATH sent, newest first, each with its time (the day too when it is not today). PATH's own leading time is dropped, as in the sheet.
- **"Whole line"**, above the stops, holds issues that name the line and none of its stops.
- **"Good service"** heads a card with no issues at all.
- **A muted kind** is still written out, with a struck bell.
- **JSQ–33rd shows Hoboken** only when an issue on that line names it; the line calls there only at nights and weekends.

### Where an issue goes (`IssueBoard`)

| PATH's text names | It shows |
|---|---|
| A line and one or more of its stops | At those stops, on that line only |
| A line and no stop | Under "Whole line" on that line |
| A station and no line (an elevator) | At that stop on every line that calls there |
| Neither | Under "Other" on every tab |

A delay the app noticed itself sits at the station it was seen from.

## Other

Issues whose wording names no line and no station, listed under every tab so nothing PATH says is hidden.

## Archived

One row at the bottom of every tab, with the count. It opens a sheet of ended issues grouped by day, most recent first; tapping one opens its sheet.

## An issue's sheet

Tapping an issue, here or on a Trains banner, opens design DA (`IssueDetailView`). (decided 2026-11-25, built 2026-11-26)

- **Tags:** "Your station" or "Your line" when the text names one (`IssueMatcher`), the kind, each line with its map colour, and "Still open" or when it ended.
- **Time rail:** every update PATH sent about the incident, newest first, each with its time on the left; the day is added only when it is not today. The newest of an open issue has the filled dot. PATH's feed gives every update of one incident the same id, so the rail is real history, not a guess.
- **PATH's own time is dropped.** PATH starts each message with the time ("04:12 PM: JSQ-33 delayed"). The rail already shows it, so the text starts after it (`IssueUpdate.body`). The banners do the same. (decided 2026-11-27)
- **Mute alerts like this** at the bottom mutes or unmutes every issue of this kind. Muting raises the `mute-issues` guide. Unmuting just happens, except for elevator notices, which raise `unmute-elevator` because they start muted for a reason. See [guides](welcome-and-guides.md).
- **Not there, on purpose:** a subtitle under the title, a sort button, and a bell beside the X. The drawing has none of them, and the row at the bottom does the bell's job. (removed 2026-11-27)

## Open questions

- **A long incident makes a long stop.** Every update is written out at each stop the issue names, so an issue naming two stops is written twice. Collapsing older updates is an idea, not asked for.
- **Press and hold** on an issue does nothing; muting is in the issue's sheet. Issues never had a press-and-hold menu.
- **Matching** (`IssueMatcher`): reads station names and line codes out of PATH's text. It does not read direction, and wording it does not know (a new abbreviation, a place that is not a station) matches nothing.
