# Process

| Doc | What's in it |
|---|---|
| [Releases](releases.md) | From a commit to TestFlight and the site, with `scripts/build_release.sh` |
| [UI tests](ui-tests.md) | Running the unit and UI tests, screenshots, launch arguments, known traps |

## A change, start to finish

1. Build it; keep the tests passing.
2. In the same change, rewrite the section of the doc that owns the decision and date it `(decided YYYY-MM-DD)`.
3. Tick or add the line in [`todos.md`](../todos.md).
4. Commit and push only when asked. A release is run only when asked.
