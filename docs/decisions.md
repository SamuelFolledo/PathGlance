# Decisions

A dated log, newest first: one line per decision and a link to the doc that owns it. The owning doc says how it works now and why; this page only says what was decided and when. When the two disagree, the owning doc is right.

Add a line here in the same change that rewrites the owning doc. A choice made from a drawing that is not built yet is marked **drawing only**.

## 2026-11-26

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
