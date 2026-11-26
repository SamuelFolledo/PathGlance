# PathGlance docs

Everything written down about PathGlance lives in this folder: how each screen behaves, the pieces screens share, how a release goes out, and what is left to do. The only docs outside it are the repo [`README.md`](../README.md) and the comments beside the code.

The app is small, so there are no tickets and no board: open work is one checklist, [`todos.md`](todos.md).

## What's where

| Folder or file | What's in it | Read it when… | Changes when… |
|---|---|---|---|
| [`app/`](app/README.md) | How the app behaves **now**, one doc per tab, laid out like the screen | you want to know what a screen does and why | a decision about that screen is made |
| [`shared/`](shared/README.md) | Things used from more than one screen: the sheet, popovers, guides, rows, colours, and where the data comes from | a screen's doc links you here | a shared rule changes |
| [`glossary.md`](glossary.md) | The words used in the app and in code, and the one meaning of each | a name is unclear, or you are about to name something | a term is added or settled |
| [`process/`](process/README.md) | How a build reaches TestFlight and the site, and how the tests are run | you are about to release or test | the way we work changes |
| [`visuals/`](visuals/README.md) | Where the pictures are: icons, header options, tab ideas, wireframes | you would rather see it than read it | a design round is published |
| [`todos.md`](todos.md) | Open work and progress, as one dated checklist: open lines are what is left, ticked lines are what is done | you want to know what is left or what was finished | work starts, is decided, or is done |
| [`decisions.md`](decisions.md) | A dated log of every decision, one line each, linking to the doc that owns it | you want to know what was decided and when | a decision is made |
| [`ideas.md`](ideas.md) | Ideas nobody has agreed to yet | you have an idea, or want to see what has been floated | an idea is raised, agreed or turned down |

## Where does it go?

| You have… | Put it in… | Format |
|---|---|---|
| A decision about how a tab behaves | that tab's doc in `app/`; rewrite the section to say how it works now | ends with `(decided YYYY-MM-DD)`; say why in a clause |
| A rule used on more than one screen | `shared/ui.md` or `shared/data.md` | same |
| Something to do | `todos.md` | one dated checkbox line |
| An idea not agreed yet | `ideas.md` | one dated line |
| Any decision, once made | its owning doc, plus one line in `decisions.md` | dated, with a link |
| Something not decided yet | "Open questions" at the end of the doc that will own it, and a line in `todos.md` | the options, and the pick if there is one |
| A new word, or two words for one thing | `glossary.md` | one row |
| A step in releasing or testing | `process/` | numbered steps |

## How these docs work

- **One home per decision.** A tab's doc owns the decisions about that tab. Something reached from several places (the sheet, a guide, a row) lives in `shared/`; screens link to it instead of repeating it.
- **Laid out like the screen.** Sections follow the screen from the top, then down. Moving something on screen moves its section in the doc.
- **Every doc starts with a summary** of its key decisions, then the sections.
- **Each decision is dated** `(decided 2026-11-23)` so you can tell what is recent. A date is the day the decision was written down here, not necessarily the day it was first built.
- **Names are the real ones in code** (`TrainsView`, `Guide`, `WidgetPreset`), so docs and code can be searched together.
- **Only what the code confirms.** Anything still being chosen is under "Open questions", not written as if it were built.

## Contents

- **[The app](app/README.md)**: [Trains](app/trains.md) · [Issues](app/issues.md) · [Widget and Settings](app/widget.md) · [Welcome note and guides](app/welcome-and-guides.md)
- **[Shared](shared/README.md)**: [UI](shared/ui.md) · [Data](shared/data.md)
- [Glossary](glossary.md)
- **[Process](process/README.md)**: [Releases](process/releases.md) · [UI tests](process/ui-tests.md)
- [Visuals](visuals/README.md)
- [TODOs and progress](todos.md) · [Decisions](decisions.md) · [Ideas](ideas.md)
