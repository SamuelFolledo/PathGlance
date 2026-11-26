# Glossary

One meaning per word, in the app, in code and in these docs.

| Word | Meaning | In code |
|---|---|---|
| Station | Where you start from. Nearest follows your location; a chosen one stays. | `Station`, `AppModel.station(nearest:)` |
| Destination, line | Where a train from your station ends up; one destination tab and one widget row each. | `BoardRules`, `target` |
| Favorite stop | A stop on the way that gets its own column in the train list. | `favoriteStops` |
| Column | One stop's times in the train list: your station, favorite stops, the destination. | `TrainColumn` |
| Live | A time from PATH's feed rather than the timetable. Only the next train or two per line. | `isLive`, `RealtimeFeed` |
| Timetable | PATH's published weekday, Saturday or Sunday schedule. | `ScheduleData`, `TimetableArchive` |
| Day type | Which of the three timetables a day runs on, including what was learned for holidays. | `DayTypeLog` |
| Issue | One PATH alert, open or ended. | `Issue`, `IssueLog` |
| Kind | What an issue is about: delay, suspension, planned work, elevator or escalator, notice. | `IssueKind` |
| Muted | A kind that is listed but not counted on the badge or shown on the widget. | `mutedKinds` |
| Look | Everything about how the widget appears: font plus style. What Save writes. | `WidgetLook` |
| Preset | A named look to start from. | `WidgetPreset` |
| Guide | A popup that explains before an action, with "Don't show this again". | `Guide` |
| Welcome note | The guide shown when the app opens. | `Guide.welcome` |
| Sheet | The app's own card over one tab, half or full height. | `appSheet` |
| Popup | The small centered card: a date, a guide. | `AppSheetStyle.popup` |
| Fold card | A titled group that folds away. | `FoldCard` |
| Brand colour | PATH's logo blue. | `AccentColor`, `Theme.Colors.brand` |
