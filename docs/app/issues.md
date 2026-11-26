# Issues

> **Where:** second tab · **Code:** `PathSchedule/Features/Issues/IssueViews.swift` · data: `IssueLog`, `IssueKind` (`Shared/Issues.swift`)

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

Tapping an issue opens its facts and every update PATH sent about it, newest first; the order can be flipped.

- **Bell** beside the X (`RoundButton`): mutes or unmutes every issue of this kind. Muting raises the `mute-issues` guide. Unmuting just happens, except for elevator notices, which raise `unmute-elevator` because they start muted for a reason. See [guides](welcome-and-guides.md).

## Open questions

- **Layout ideas** IA to IF are on the design page (filter tabs, status first, timeline, compact rows, your station first, Current and Archived tabs). None is chosen. "Status first" would need issues matched to lines, which the app does not do.
