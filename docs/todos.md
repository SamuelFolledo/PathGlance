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
	- Issues round two drawn (IG to IN, detail sheets DA and DB). DA chosen as the detail sheet and IN liked for the Trains tab; neither is built. The list layout is still open (2026-11-25)
	- Widget tab: drawings asked for underline tabs switching the preview between half and full width, and for a small one-slot widget; not decided (2026-11-25)

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

## Tests

- [ ] `testDateJumpAndBackToNow` is flaky; find out why (2026-11-23)
- [ ] `testTrainOpensItsStopsAndStepsToTheNext` fails now and then on a row that is off screen ("No matches found" / "Failed to determine hittability"); it passes when run alone (2026-11-23)

## App, older open items

- Moved to [`ideas.md`](ideas.md): delay history log, red "skipped" dots, subtitles under sheet titles. None was ever agreed (2026-11-25)
