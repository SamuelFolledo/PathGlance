# Shared UI

> **Code:** `PathGlance/DesignSystem/`: `Tokens/Theme.swift`, `UI/Sheet/AppSheet.swift`, `UI/Popover/PopoverMenu.swift`, `UI/Popover/StationMenu.swift`, `UI/Alert/Guide.swift`, `UI/Rows/Rows.swift`

## Summary

- One sheet (`appSheet`), one popover menu (`PopoverMenu`), one guide popup (`Guide`), one set of rows. Screens are built from these, never their own.
- Explanations go in a press-and-hold popover, not in a footer under the row.
- A row is tappable across its whole width; a chevron always points right.
- A lone check box in a guide or beside a section title is square; checks and radios in a list of choices are round.
- Buttons at the bottom of a popup fill its width.
- The app's blue is PATH's logo blue, set once.

## Colour

- **Brand:** `#0095D3` in dark mode, the blue of PATH's logo (read from the logo file on Wikimedia Commons; no official Port Authority spec was found). `#0080B8` in light mode, a little darker so small blue text stays readable on white. (decided 2026-11-23)
- **Where it is set:** the `AccentColor` asset (`PathGlance/Assets.xcassets`), named as the target's global accent colour, and `.tint(Theme.Colors.brand)` at the app root (`MyApp`). Use `.tint` where the system tint is meant and `Theme.Colors.brand` where a colour must be named. Never `.blue`. (decided 2026-11-23)
- **Exception:** a third party's own colour (PayPal's blue in Support the app).
- The lock screen widget has no colour code; the lock screen draws it in one tone.

## Measurements

`Theme` holds the app's one set of numbers: `Spacing` (xs 4, sm 8, md 12, lg 16, xl 24, `contentSide` 16, `row` 11), `Radius` (card 22, sheet 28), `Size` (tabBar 54, roundButton 32, dot 8), `Motion` (sheet, content). Screens use these names, never their own numbers. `.card()` is the grouped surface rows sit on.

## Sheet

`appSheet(item:title:subtitle:accessory:…)` presents over one tab's screen and nothing else: it runs on underneath the tab bar, which stays in view and in reach.

- **Styles** (`AppSheetStyle`): from the bottom edge at about half height (pull up for full, pull down to close), or `.popup`, a small card in the middle for one quick choice (a date, a guide).
- **Accessibility:** a sheet hides the screen under it from VoiceOver. A popup does not: its card is modal, which is enough, and hiding the screen a second time over a sheet that had already hidden its own left controls with the whole screen as their frame. (2026-11-27)
- **Dragging** works the way a system sheet does, with one gesture: the content's own scroll drag (`SheetScrollBridge`). The content scrolls at either height; a pull down from its top lowers or closes the sheet, a push up from its end raises a half-height sheet to full. A drag never also taps what it started on.
- **Closing:** the X, tapping the dimmed area, VoiceOver's escape gesture.
- **Header:** grabber, title, optional subtitle saying what the sheet is for, optional accessory beside the X.

## Popovers

- **Menu** (`PopoverMenu`): a short list that points at what opened it. Choices that stay picked are `PopoverRadioRow`s; things that happen once are `PopoverActionRow`s. Sections get a small title only when there is more than one. The station list (`StationMenu`) is one.
- **Info** (`.infoPopover(title, tips…)`): press and hold a row, title or control for what it does. This replaces footer text under rows. (decided 2026-11-23)

## Guides and alerts

A `Guide` explains before an action that matters. Every one is listed in [Welcome note and guides](../app/welcome-and-guides.md).

- **Buttons fill the width** (`WideButton`): one button spans the popup; two in an `HStack` split it evenly. The confirming one is prominent; a destructive one takes the destructive role. Any popup's bottom buttons use it (guides, "Back to now" in the calendar). (decided 2026-11-23)
- **"Don't show this again"** is a square check box (below). A guide with `canBeSilenced: false` has none and always asks.

## Check marks

| Mark | When | Code |
|---|---|---|
| Round radio | one of several | `RadioRow`, `PopoverRadioRow` |
| Round check | any number of several, in a list of choices (lines preferred, muted issues) | `CheckRow` (default `shape: .round`) |
| **Square check** | a check that stands alone in an alert or guide, or beside a section title; onboarding when it exists | `CheckRow(isOn:shape: .square)` |

`CheckShape` holds the two outlines and their symbols (`checkmark.square.fill` / `square`, `checkmark.circle.fill` / `circle`). The square is the same exception usualspots makes for its "Don't show this again" box. (decided 2026-11-23)

## Rows

All in `UI/Rows/Rows.swift`.

- `RadioRow`, `CheckRow`: a mark, a label, a hairline under it.
- `DetailRow`: a row that does something, with what it is set to on a second line under its title. A fact that would be a row of its own with nothing to tap goes there instead. (2026-11-27)
- `PopoverRadioRow` can carry a `PopoverAccessory`: a small button at its end that does its own thing without picking the row or closing the popover. The station list's stars are these. (2026-11-27)
- `Shake`: a short side-to-side shake for "that cannot be done", used with the error haptic. (2026-11-27)
- `OpenRow`: title, current value, a chevron pointing right. Opens a sheet or popup.
- `LinkRow`: a coloured symbol, a title, and a mark when it opens outside the app.
- `FoldCard`: a titled group in its own card that folds away; open by default, remembered between launches; the whole title bar folds it, and folded it shows its value.
- `ToggleRow`: a switch whose whole row toggles it.
- `TabTitle` and `.pinnedBarTop { }`: a tab's small centered title, pinned with no background.
- `RoundButton`, `StationBadge`, `StatusDot`.

Elsewhere in `UI/`:

- `UnderlineTabs` (`Tabs`): plain-text tabs on a hairline; the name bold at body size, an optional smaller line under it that keeps its colour when unselected. (2026-11-26)
- `IssueBanner`, `IssueBannerStack` (`Banner`): a tinted strip with icon, title, a line under it, a time and an X; the stack pages sideways one full width at a time with dots under it. It knows nothing about issues: the screen hands it `IssueBannerItem`s. Without `onOpen` a banner is text, not a button; `name`, `noun` and `dismissLabel` say what it is for tests and VoiceOver. The Widget tab's legend is this stack in grey. (2026-11-26, 2026-11-27)
- `Tag`, `TagFlow` (`Tags`): small rounded labels that wrap onto new rows. (2026-11-26)
- `Carousel` (`UI/Carousel`): cards in a row, one centred and its neighbours peeking in at both sides by `peek` points. Swipe, one card per swipe, or tap a neighbour; the choice snaps to the centre. The selection changes only once a swipe has come to rest. The chosen card keeps its own controls; a neighbour is one tap target. Used for the widget presets of both shapes. (2026-11-26)
- `PageDots`: the dots under anything that pages, hidden when there is one page. Shared by `Carousel` and the issue banner stack, which pages a full width at a time with no peeking. (2026-11-26)

Rules:

- **The whole row is the button**, not only its label or its mark. (decided 2026-11-23)
- **Chevrons point right** on a row that opens something; a fold's chevron turns down when open. (decided 2026-11-23)
