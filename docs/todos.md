# TODOs

Open work, in one list. No tickets, no board.

## Format

```
## Area

- [ ] What it is, in one line (YYYY-MM-DD)
	- What was built or decided, one line per point (YYYY-MM-DD)
	- [ ] A smaller TODO when it is too big for one checkbox (YYYY-MM-DD)
```

- `[ ]` open, `[x]` done. A parent is checked only when everything under it is.
- Every line ends with the date it was added. When something is done or decided later, add a new dated bullet; do not rewrite old ones.
- Indent with tabs, one per level.
- A decision goes in the doc that owns it ([`app/`](app/README.md), [`shared/`](shared/README.md)) and gets a line in [`decisions.md`](decisions.md); this file only says what is left.
- **Progress** is this file: ticked lines are what is done, with the date under each. An idea nobody has agreed to goes in [`ideas.md`](ideas.md) until it becomes a TODO.

## Design, waiting on a choice

- [x] Pick the Trains header from round six, U1 to U8, on the design page, then build it (2026-11-23)
	- U7 chosen and built: the date is the title's subtitle and takes its place when scrolled; see [`app/trains.md`](app/trains.md) (2026-11-25)
	- Rules already set: underline tabs; the next train stays stacked under each line name, scrolled or not; "From \<station\>" shows at rest at every text size, leaves on scrolling down and returns at the top or an earlier time; the date is always on screen (2026-11-23)
- [x] Pick the app icon (two-arrow set A1 to A24, PathGlance set G1 to G12), draw it at 1024 px, add it to the app and site (2026-11-23)
	- G5 chosen and added; the widget extension has no icon of its own (2026-11-26)
- [ ] Dark and tinted variants of the app icon (2026-11-26)
- [ ] Decide on the Issues tab ideas IA to IF and the Widget tab ideas WA to WF (2026-11-23)
	- Issues round two drawn (IG to IN, detail sheets DA and DB). DA chosen as the detail sheet and IN liked for the Trains tab (2026-11-25); both built 2026-11-26. The list is IG tabs with IH-b content, built 2026-11-27
	- Widget tab: drawings asked for underline tabs switching the preview between half and full width, and for a small one-slot widget; not decided (2026-11-25)
	- Widget tab decided and built: Rectangle and Round shapes behind underline tabs, a preset carousel in place of the Presets row, a custom look per shape, five round presets (2026-11-26)
	- Waiting for answers: shared settings first or last; the round presets' fonts and pairings; approval of the eleven rectangle presets (2026-11-26)
	- "Shared settings first or last" no longer applies: lines and muted issues moved to Settings, favorite stops to the station list (2026-11-27)
	- Add the round widget to a real lock screen and check it reads well at its real size (2026-11-26)

## After the look is final

- [ ] Replace the welcome note with a proper onboarding: a carousel you swipe through, one page per point, each page with a screenshot or image, and a bigger title (2026-11-23)
	- Today it is a plain `Guide` with five points and one button; see [`app/welcome-and-guides.md`](app/welcome-and-guides.md) (2026-11-23)
	- Until then the points are a numbered list (2026-11-25)
	- Asked again as a swipeable carousel with screenshots or images on each page; still waits for the look to be final (2026-11-25)
- [ ] README and docs screenshots, from `TEST_RUNNER_SHOT_DIR`, once the build is approved (2026-11-23)

## Widget

- [x] Idea, undecided: let the station or line label be bolder than the times (2026-11-23)
	- Decided and built: station names bold, times medium, in the widget, preview and every preset; see [`app/widget.md`](app/widget.md) (2026-11-25)

## Release

- [ ] First TestFlight build with `./scripts/build_release.sh` (`--dry-run` first); the archive, upload and site deploy have never been run (2026-11-23)
	- [ ] App Store Connect Issuer ID in `~/.appstoreconnect/issuer_id` (2026-11-23)
	- [ ] App record, App Privacy "Data Not Collected", privacy URL (2026-11-23)
	- [ ] Internal testers, then the external group, beta review and the public link (`l` in the script) (2026-11-23)
	- [ ] Set TestFlight's "What to Test" through the API once the first upload works (2026-11-23)
- [ ] GitHub CI workflow that runs the tests (2026-11-23)

## Settings and Trains, feedback of 2026-11-27

- [x] Two columns at least in the train list; station list with stars; Settings reworked (Preferences, Lines preferred with drag to reorder, text size follows the phone, Restore defaults keeps what is ticked); issue sheet matched to DA (2026-11-27)
- [ ] Ask the owner whether "Standard" text size should be exactly the phone's size; today it is one step above (2026-11-27)
- [ ] Check large accessibility sizes above accessibility1; the app stops there (2026-11-27)

## Widget tab, feedback of 2026-11-27

- [x] Edits stay with their preset and Custom is gone; Restore preset; "Time format" and "Show" sections with Skip the next train, AM and PM, Compress more and From station; the legend under the preview (2026-11-27)
- [ ] Owner to confirm three readings: AM and PM once per line, not after every time; "Compress more" as closer letters and no space after commas; hiding the station row leaves the freed height empty (2026-11-27)
- [ ] Owner to pick from the suggested Show toggles in [`ideas.md`](ideas.md) (2026-11-27)
- [ ] See both widgets on a real lock screen with each new option on (2026-11-27)

## Bugs found, not fixed

- [x] Settings does not open again once a guide has been shown from inside it and closed (seen with Restore defaults > Cancel and with the hide-line guide, in UI tests; the same happens on the commit before these changes). Relaunching clears it. Not yet tried by hand (2026-11-27)
	- Found and fixed. The button worked; what broke was its accessibility frame, which became the whole screen, so a UI test (and VoiceOver's focus) aimed at the middle of the screen. A popup hid the screen under it from accessibility on top of a sheet that had already hidden its own. A popup now relies on being modal and hides nothing; `testSettingsOpensAgainAfterAGuide` covers it (2026-11-27)
- [ ] `testFavoriteStopAddsAColumn` failed once in a full run at about 5:20 AM ("originMenu" not found right after launch) and passed alone; `testHeaderGivesWayToTheDateWhenScrolled` failed in the run and alone at that hour. Both look like the early-morning scroll problem below; not chased (2026-11-27)
- [x] The train list jumped hours back on the first scroll in the early morning (2026-11-27)
	- Cause: the list is lazy and guesses the height of undrawn rows from the drawn ones. A day heading or a late train's two-line row among the few on screen changed the guess for the week of rows above; when it scrolled away the list was thrown back. Seen in logs as the top row going from 6:29 AM today to 3:54 PM yesterday. Every child is now one fixed height (`rowHigh`, `rowHeight` in `TrainListPage.swift`). `testHeaderGivesWayToTheDateWhenScrolled` failed on it about every other run before 6 AM and passes since

## Tests

- [ ] `testDateJumpAndBackToNow` is flaky; find out why (2026-11-23)
- [ ] `testTrainOpensItsStopsAndStepsToTheNext` fails now and then on a row that is off screen ("No matches found" / "Failed to determine hittability"); it passes when run alone (2026-11-23)

## Last, after the session

- [ ] Rename the local folder `Desktop/StreamCodes/PathSchedule` to `PathGlance`, and move Claude's memory folder for the project with it (it is keyed to the folder's path) (2026-11-26)

## App, older open items

- Moved to [`ideas.md`](ideas.md): delay history log, red "skipped" dots, subtitles under sheet titles. None was ever agreed (2026-11-25)
