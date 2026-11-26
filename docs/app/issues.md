# Issues

> **Where:** second tab · **Code:** `PathGlance/Features/Issues/IssueViews.swift` · data: `IssueLog`, `IssueKind` (`Shared/Issues.swift`)

## Summary

- Open issues first, then ended ones: one section per day, most recent day and end time first.
- The tab's red badge counts open issues whose kind is not muted.
- Muting a kind keeps it listed but takes it off the badge and the widget; it is explained first.
- Elevator and escalator notices start muted.

## Title

"Issues", small and centered, pinned with no background (`TabTitle`). (decided 2026-11-23)

## Current

Each open issue: its kind's icon, title, "Since …", and the start of PATH's text. When nothing is open the section says "No issues reported".

Kinds (`IssueKind`): Delay, Suspension, Planned work, Elevator or escalator, Notice. Elevator notices use the brand colour. (decided 2026-11-23)

## Archived

Ended issues, grouped by day ("Archived · Sun, Nov 22, 2026"), each with its start and end times.

## An issue's sheet

Tapping an issue, here or on a Trains banner, opens design DA (`IssueDetailView`). (decided 2026-11-25, built 2026-11-26)

- **Tags:** "Your station" or "Your line" when the text names one (`IssueMatcher`), the kind, each line with its map colour, and "Still open" or when it ended.
- **Time rail:** every update PATH sent about the incident, newest first, each with its time; the newest of an open issue has the filled dot. PATH's feed gives every update of one incident the same id, so the rail is real history, not a guess. The order can be flipped.
- **Mute alerts like this** at the bottom does what the bell does.

- **Bell** beside the X (`RoundButton`): mutes or unmutes every issue of this kind. Muting raises the `mute-issues` guide. Unmuting just happens, except for elevator notices, which raise `unmute-elevator` because they start muted for a reason. See [guides](welcome-and-guides.md).

## Open questions

- **List layout:** the options are on the design page's Review (IG, IM, IH, IJ, IK, IL). None is chosen.
- **Matching** (`IssueMatcher`): reads station names and line codes out of PATH's text. It does not read direction, and wording it does not know (a new abbreviation, a place that is not a station) matches nothing.
