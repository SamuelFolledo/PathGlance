# Releases

> **Code:** `scripts/build_release.sh`, `scripts/release_tool.py`, `scripts/release.env.example`, `landing/`

One script takes a build to TestFlight and publishes the site, modelled on LTPickleballHelper's. Run it only when a release has been asked for.

## Status

Only the menu, cancelling and `release_tool.py` have been run. The archive, the upload and the site deploy have not been run yet, and the landing site is not deployed. See [todos](../todos.md).

## One-time setup

1. App Store Connect API key (Users and Access > Integrations > Team Keys, App Manager): the `.p8` goes in `~/.appstoreconnect/private_keys/AuthKey_<KEY ID>.p8`, and the Issuer ID in `~/.appstoreconnect/issuer_id` (or `ASC_ISSUER_ID`).
2. The app record exists in App Store Connect for `com.samuelfolledo.PathSchedule`.
3. Claude Code CLI on `PATH` (it summarizes commits into release notes).
4. Copy `scripts/release.env.example` to `scripts/release.local.env` (gitignored) and fill in `ASC_KEY_ID`, `DREAMHOST_USER`, `DREAMHOST_HOST`.

## Running it

```
./scripts/build_release.sh            # interactive
./scripts/build_release.sh --dry-run  # same flow; exports an .ipa to the Desktop, uploads and commits nothing
```

It asks first:

| Key | Does |
|---|---|
| `t` | TestFlight: archive, upload to App Store Connect, record the build in `landing/releases.json`, update and upload the site, commit and tag |
| `s` | Site only: upload `landing/` as it is |
| `l` | Put the TestFlight public link on the site's button, then upload the site |
| `x` | Cancel |

Every build has two sets of notes, both confirmed or edited in the script: **detailed** (the full list) and **short** (1 to 4 plain bullets, used for TestFlight's "What to Test" and the website). `RELEASE_NOTES_FILE` and `SHORT_NOTES_FILE` supply them without prompts.

## The site

`landing/` (`index.html`, `privacy.html`, `support.html`, `style.css`) is uploaded to `samuelfolledo.com/apps/path-glance/`. `landing/releases.json` is the record of every build, newest first; `release_tool.py` reads and writes it and the version and TestFlight link in `index.html`. The in-app links (`AppInfo.website`, privacy, support) point at the same address.
