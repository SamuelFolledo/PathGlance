# Tests

> **Code:** `PathGlanceTests/` (unit), `PathGlanceUITests/PathGlanceUITests.swift` (UI)

## Running

```
xcodebuild test -scheme PathGlance -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Add `-only-testing:PathGlanceTests` for the unit tests alone.

- **Unit tests** run the real importer on a made-up timetable (`Fixture.swift`), so they need no network.
- **UI tests** drive the app against PATH's live data, so they need the network and take several minutes.

## Launch arguments

| Argument | Effect |
|---|---|
| `-startTab issues` or `-startTab widget` | Opens on that tab instead of Trains |
| `-skipWelcome YES` | The welcome note does not open with the app. `launch()` in the UI tests always passes it; `testWelcomeShowsUntilSilenced` leaves it out |
| `-silencedGuides "()"` | Starts with no guide silenced |

## Screenshots

Set `TEST_RUNNER_SHOT_DIR=/some/folder` to keep a screenshot of each UI test step. They are a ready source for README and doc images.

## Known traps

- **Stale build products.** After adding or moving source files, tests can fail to find new types, or run an old app. Before a test run delete, under `~/Library/Developer/Xcode/DerivedData/PathGlance-*/Build/`: `Products/Debug-iphonesimulator/PathGlance.swiftmodule`, `Products/Debug-iphonesimulator/PathGlanceUITests-Runner.app` and `Intermediates.noindex/PathGlance.build/Debug-iphonesimulator/PathGlanceUITests.build`.
- **`testDateJumpAndBackToNow` is flaky.** It has failed and passed on the same code. See [todos](../todos.md).
- **Rows behind pinned bars** count as hittable to XCTest. Scroll the row clear first (`revealBelowPreview`, `reveal`) and filter by frame before asking `isHittable`.
- **Leftover state** from an earlier run (a custom preset, folded sections) can move rows. Tests that depend on position reveal the row first.
