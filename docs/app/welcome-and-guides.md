# Welcome note and guides

> **Code:** `Guide`, `GuideView`, `WideButton` (`PathGlance/DesignSystem/UI/Alert/Guide.swift`) · raised with `AppModel.ask(_:)` · shown in an `AppSheet` popup

## Summary

- A **guide** is a short explanation shown before an action that matters: a title, one point per line, then the buttons.
- Most can be ticked **"Don't show this again"**; the tick is a square check box ([UI rules](../shared/ui.md#check-marks)). A destructive, irreversible one always asks.
- Buttons fill the popup's width: one spans it, two split it evenly (`WideButton`). (decided 2026-11-23)
- Silenced guides are kept under the `silencedGuides` key in `UserDefaults`; **Restore defaults** clears it, so they all show again.
- The **welcome note** is a guide with one button, shown when the app opens until it is silenced.

## Welcome note (`welcome`)

- **Raised:** when the app opens (`AppModel` init, `Guide.showsWelcomeAtLaunch`), every launch until silenced; and from Settings > About > Welcome note at any time. The `-skipWelcome YES` launch argument suppresses the launch showing, for UI tests and screenshots.
- **Title:** "Welcome to PathGlance" (the app's display name).
- **Points:**
  1. "This is an independent app. It is not made, endorsed or supported by PATH or the Port Authority (yet)."
  2. "The next train or two on each line are live from PATH's own feed. They have a green dot, or a yellow one when running late."
  3. "Every other time is PATH's published timetable. PATH can change it, and trains can run early or late."
  4. "Your location is only used to pick the nearest station, and it stays on your phone."
  5. "Add the lock screen widget from the Widget tab, and press and hold almost anything for more."
- **Numbered:** the points are drawn as a numbered list, 1 to 5 (`Guide.isNumbered`); other guides stay plain paragraphs. (decided 2026-11-25)
- **Buttons:** "Got it" (one, full width). **Can be silenced:** yes.

(decided 2026-11-23)

A fuller onboarding (a swipeable carousel, one page per point, each with a picture) is planned for after the look is final; see [`todos.md`](../todos.md).

## Guides before an action

| `id` | Raised from | Title | Buttons | Can be silenced |
|---|---|---|---|---|
| `change-station` | `StationMenu` (Trains title, station button) | "Start from \<station\>?" | Cancel · Change | yes |
| `hide-line` | Settings > Lines preferred (`LinesPreferredRows`) | "Hide trains to \<station\>?" | Cancel · Hide | yes |
| `clear-favorites` | Station list > Clear favorite stops (`AppModel.clearFavorites`) | "Clear all favorite stops?" | Cancel · Clear (destructive) | yes |
| `mute-issues` | "Mute alerts like this" in an issue's sheet | "Mute \<kind, plural\>?" | Cancel · Mute | yes |
| `unmute-elevator` | The same row, unmuting elevator notices | "Unmute elevator and escalator notices?" | Cancel · Unmute | yes |
| `restore-defaults` | Settings > Restore defaults | "Restore defaults?" | Cancel · Restore (destructive) | no |
| `hide-widget-header` | Widget tab > Show > unticking "From station" (`WidgetView.hideHeaderGuide`) | "Hide the station row?" | Cancel · Hide | yes |

### Points, as in code

**`change-station`**
- "The Trains tab and the lock screen widget will both show trains from \<station\>."
- Nearest: "The station follows your location from now on." A station: "It stays on this station until you choose another or go back to Nearest."

**`hide-line`**
- "They leave the lock screen widget and the destination tabs."
- "A station left with one line gives it both widget rows, with more times."
- "A station whose only line this is still shows it."

**`clear-favorites`**
- "The train list goes back to two columns: your station and the destination."
- "You can pick favorites again at any time."

**`mute-issues`**
- "Issues of this kind will still be listed in the Issues tab."
- "They will no longer count on the Issues badge."
- "They will no longer show on the lock screen widget." For delays, also: "That includes the ? and ! delay marks."
- "Unmute here or in Settings, under Muted issues."

**`unmute-elevator`**
- "PATH posts these often, and several are usually open at once."
- "Each will count on the Issues badge and put the alert mark on the lock screen widget."

**`restore-defaults`**
- Every setting goes back to how a fresh install has it (the full sentence is in `WidgetView.swift`).
- "Explanations you ticked "Don't show this again" on will show again."
- "The timetable, the issue history and what the app has learned about holidays are kept."

**`hide-widget-header`** (2026-11-27)
- "The widget will show only its train lines, with nothing above them."
- "This suits you if you always ride from the same station, or only care about certain lines."
- "The time it last updated, the refresh tap and the alert mark are on that row, so they go too."
- "Tick From station again to bring the row back."

## Open questions

- **Welcome note redesign**, once the app's look is final: scrollable, several pages, an image or screenshot separating each point, a bigger title. Recorded in [todos](../todos.md); not built.

## Boxes to tick before confirming

A guide can carry `options`: square check boxes above its buttons, all unticked each time it opens, handed to `onConfirm` when the confirming button is tapped. Restore defaults is the one that has them: "Keep favorite stops", "Keep muted issues", "Keep lock screen presets". (2026-11-27)

What Restore defaults always resets, whatever is ticked: the station, the lines preferred and their order, text size, hidden columns (unless favorite stops are kept), folded sections, banners put away today, and every "Don't show this again". What it never touches: the timetable, the issue history and the learned day types.
