# The app

> **Code:** `ContentView` (`PathGlance/App/ContentView.swift`), `AppModel`, `MyApp`

## Summary

- Three tabs: **Trains**, **Issues**, **Widget**. Settings is a sheet opened from the Widget tab's menu button, not a tab. (decided 2026-11-23)
- The tab bar is the app's own, not the system's, for two things the system's cannot do: a station button beside it, and sheets that run on underneath it while it stays in view. (decided 2026-11-23)
- The station button sits at the left of the tab bar and opens the station list (`StationMenu`). Tapping the tab already showing resets it. (decided 2026-11-23)
- Tapped from the Issues or Widget tab, the station button first brings the Trains tab forward, then opens the list over it: choosing a station is about the trains. (decided 2026-11-25)
- Issues and Widget have a small centered title pinned over the content with no background, so the list shows through above it (`pinnedBarTop`, `TabTitle`). (decided 2026-11-23)
- The first thing a new user sees is the welcome note. See [Welcome note and guides](welcome-and-guides.md). (decided 2026-11-23)

## Pages

| Doc | Screen | Code |
|---|---|---|
| [Trains](trains.md) | The home tab: trains from your station, per destination | `TrainsView`, `TrainListPage` |
| [Issues](issues.md) | PATH's open and ended alerts | `IssueViews.swift` |
| [Widget and Settings](widget.md) | The lock screen widget's look, presets, and the Settings sheet | `WidgetView`, `OptionViews.swift` |
| [Welcome note and guides](welcome-and-guides.md) | Every popup that explains before acting | `Guide`, `GuideView` |

## Name

The app's name is **PathGlance** everywhere: display name, Xcode project, targets, folders, bundle IDs (`com.samuelfolledo.PathGlance`, `.Widget`), App Group (`group.com.samuelfolledo.PathGlance`), site and GitHub repo. (decided 2026-11-23; project and IDs renamed 2026-11-26)

## Open questions

- The app icon: candidates are on the design page ([visuals](../visuals/README.md)).
