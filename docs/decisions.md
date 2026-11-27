# Decisions

A dated log, newest first: one line per decision and a link to the doc that owns it. The owning doc says how it works now and why; this page only says what was decided and when. When the two disagree, the owning doc is right.

Add a line here in the same change that rewrites the owning doc. A choice made from a drawing that is not built yet is marked **drawing only**.

## 2026-11-27

- The train list always shows at least two columns: your station and one more. A tap that would hide the last other column is refused with a shake and an error tap. Built. → [Trains](app/trains.md)
- The station list is one popover, the same from the Trains title, the station button and Settings. Each station has a star that makes it a favorite stop without closing the list. Favorite stops leave the Widget tab. Built. → [Trains](app/trains.md), [UI](shared/ui.md)
- Settings sheet reworked: no subtitle under its title; "Station" is "Preferences" and holds From, Location access and Muted issues; a new "Lines preferred" group follows it; no row is only text. Built. → [Widget](app/widget.md#settings-sheet)
- "Lines shown" is "Lines preferred": it moved from the Widget tab to Settings, starts folded, and its rows can be dragged into the order you want. The order leads the Trains tabs, the rectangle widget's rows and the round widget's first line. Built. → [Widget](app/widget.md#settings-sheet)
- With Lines, Muted issues and Favorite stops gone from the Widget tab, its "Both widgets" group is gone too, which settles the "shared settings first or last" question. → [Widget](app/widget.md)
- Text size follows the phone: the slider adds steps to, or takes them from, the phone's own text size. Built. → [Widget](app/widget.md#settings-sheet)
- Restore defaults asks what to keep: favorite stops, muted issues, lock screen presets. All three boxes start unticked every time. Built. → [Welcome note and guides](app/welcome-and-guides.md)
- "Learned day types" is hidden until there is something in it. "Timetables" is folded into Schedule and only listed when there is more than one. Schedule's rows are "Last updated" and "Schedule". Built. → [Widget](app/widget.md#settings-sheet)
- Issue sheet brought to the DA drawing: no subtitle, no sort row, no bell beside the X; the time PATH puts in front of its text is dropped, since the rail shows it; the day shows only when it is not today. Built. → [Issues](app/issues.md)
- **The owner has not seen this one yet:** the app still draws one step above the phone's text size at "Standard", because that is the size every screen was designed and approved at. → [Widget](app/widget.md#open-questions)

## 2026-11-26

- Two lock screen widgets: Rectangle (the existing one) and Round (one slot). Apple's WidgetKit has nothing wider than the rectangle, so a full-width widget is dropped. Round has five presets: Minutes, Clock time, Countdown ring, Next two, Two lines. Built. → [Widget](app/widget.md)
- The Widget tab's preview is a carousel of presets with the neighbours peeking in; it replaces the Presets row and its sheet. Underline tabs pick the shape and the pages slide like the Trains lines. Built. → [Widget](app/widget.md), [UI](shared/ui.md)
- Each shape remembers one custom look, kept the moment a preset is changed. Built. → [Widget](app/widget.md)
- **Default, waiting for the owner's answer:** the settings both shapes share sit last, under "Both widgets"; and the round presets' fonts (Standard, Standard, Standard, Rounded, Condensed). → [Widget](app/widget.md#open-questions)
- Trains tab shows banners (design IN) for issues at your station or on the line on screen, plus the holiday note: one at a time, swipe for the next, dots, an X that hides one until tomorrow, tap for details. Also at the top of the stops sheet. Built. → [Trains](app/trains.md#banners)
- An issue opens as design DA: tags, a time rail of PATH's updates, mute at the bottom. Built. → [Issues](app/issues.md)
- The live dot sits in the row's left margin so times line up. Built. → [Trains](app/trains.md)
- A tab's wait keeps its green or yellow when the tab is not selected, only quieter; tab names are bigger and bold, the line under them smaller and not bold, everywhere the tabs are used. Built. → [Trains](app/trains.md), [UI](shared/ui.md)
- Tapping a column's name hides that stop's column; hidden names wait above and a tap brings one back. Built. → [Trains](app/trains.md)

- The app icon is G5: eyes peeking over the silver, a blue arrow below. In the app and on the site. Dark and tinted variants are not drawn. → [The app](app/README.md)
- Everything is named PathGlance: the Xcode project, targets, folders, bundle IDs (`com.samuelfolledo.PathGlance`, `.Widget`), the App Group (`group.com.samuelfolledo.PathGlance`) and the GitHub repo. This replaces the 2026-11-23 note that the project kept its first name. → [The app](app/README.md)
- Widget: station names heavier than times is confirmed for every widget and preset. → [Widget](app/widget.md)
- Checks in a list of choices stay round; the lone box in a popup or beside a section title stays a rounded square. Confirmed. → [UI](shared/ui.md#check-marks)

## 2026-11-25

- Trains header is U7: the date is the title's subtitle and takes its place when scrolled; underline tabs with the next train stacked under each. Built. → [Trains](app/trains.md)
- The station button, tapped from Issues or Widget, brings the Trains tab forward before opening the station list. Built. → [The app](app/README.md)
- Widget: station names are bold and times medium, in the widget, the preview and every preset. Built. → [Widget](app/widget.md)
- Welcome note's points are a numbered list until the onboarding carousel replaces it. Built. → [Welcome note and guides](app/welcome-and-guides.md)
- Issues detail sheet is DA, the timeline. **Drawing only.** → will be owned by [Issues](app/issues.md); tracked in [`todos.md`](todos.md)
- IN (issue strip on the Trains tab) is liked. **Drawing only**, not yet agreed to build. → [`ideas.md`](ideas.md)

## 2026-11-23

- The app is named PathGlance. → [The app](app/README.md)
- Three tabs, the app's own tab bar, the station button beside it; Settings is a sheet from the Widget tab. → [The app](app/README.md)
- The welcome note is the first thing a new user sees, every launch until silenced. → [Welcome note and guides](app/welcome-and-guides.md)
- Popup buttons fill the width: one spans it, two split it. → [UI](shared/ui.md)
- Check boxes in a popup or beside a section title are rounded squares; checks in a list stay round. → [UI](shared/ui.md#check-marks)
- The brand colour is PATH's logo blue, used in place of system blue. → [UI](shared/ui.md)
- Press-and-hold popovers replace footer text; whole rows are the button; chevrons point right. → [UI](shared/ui.md)
- The welcome note says "the next train or two", because that is what the live feed covers. → [Data](shared/data.md)
- Eleven built-in widget presets. → [Widget](app/widget.md)
- Docs live in `docs/`, modelled on usualspots without tickets. → [docs README](README.md)
