#!/usr/bin/env python3
"""Reads and writes the files build_release.sh keeps up to date.

landing/releases.json is the record of every build sent to TestFlight, newest first. Each
entry carries two sets of notes, as markdown bullets:
  short_notes     1-4 plain bullets -- TestFlight's "What to Test" and the website
  detailed_notes  the full list

Subcommands:
  last-build      RELEASES              -> highest build number recorded (0 if none)
  latest-version  RELEASES              -> version of the newest entry, or nothing
  notes           RELEASES VERSION KIND -> newest notes recorded for VERSION (KIND: short|detailed)
  upsert          RELEASES ITEM_JSON    -> add the entry (or replace the one with the same build)
  project-get     PBXPROJ KEY           -> first value of a build setting (MARKETING_VERSION, ...)
  project-set     PBXPROJ KEY VALUE     -> set that build setting in every configuration
  site-version    INDEX_HTML VERSION    -> the text inside the element with id="app-version"
  site-testflight INDEX_HTML URL        -> point id="testflight" at URL and hide id="testflight-note"
"""
import json
import os
import re
import sys


def load(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return json.load(f)


def save(path, releases):
    releases.sort(key=lambda r: int(r["build"]), reverse=True)
    with open(path, "w") as f:
        json.dump(releases, f, indent=2, ensure_ascii=False)
        f.write("\n")


def project_get(text, key):
    m = re.search(r"\b" + re.escape(key) + r" = ([^;]+);", text)
    return m.group(1).strip().strip('"') if m else ""


def project_set(text, key, value):
    new, count = re.subn(r"(\b" + re.escape(key) + r" = )[^;]+;", lambda m: m.group(1) + value + ";", text)
    if count == 0:
        sys.exit(f"{key} not found in the project file")
    return new


def site_version(html, version):
    new, count = re.subn(r'(id="app-version"[^>]*>)[^<]*(<)', lambda m: m.group(1) + version + m.group(2), html)
    if count == 0:
        sys.exit('landing/index.html has no element with id="app-version"')
    return new


def site_testflight(html, url):
    tag = re.search(r'<a\b[^>]*\bid="testflight"[^>]*>', html)
    if not tag:
        sys.exit('landing/index.html has no link with id="testflight"')
    new_tag = re.sub(r'href="[^"]*"', 'href="' + url + '"', tag.group(0), count=1)
    html = html.replace(tag.group(0), new_tag)
    # The "opens soon" line goes once there is a real link.
    note = re.search(r'<(\w+)\b[^>]*\bid="testflight-note"[^>]*>', html)
    if note and " hidden" not in note.group(0):
        html = html.replace(note.group(0), note.group(0)[:-1] + " hidden>")
    return html


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    command, path, args = argv[1], argv[2], argv[3:]

    if command == "last-build":
        print(max([int(r["build"]) for r in load(path)] or [0]))
    elif command == "latest-version":
        releases = load(path)
        if releases:
            print(max(releases, key=lambda r: int(r["build"]))["version"])
    elif command == "notes":
        version, kind = args
        matching = [r for r in load(path) if r["version"] == version]
        if matching:
            print(max(matching, key=lambda r: int(r["build"]))[kind + "_notes"])
    elif command == "upsert":
        with open(args[0]) as f:
            item = json.load(f)
        releases = [r for r in load(path) if int(r["build"]) != int(item["build"])]
        releases.append(item)
        save(path, releases)
        print(f"releases.json: v{item['version']} build {item['build']} recorded")
    elif command == "project-get":
        with open(path) as f:
            print(project_get(f.read(), args[0]))
    elif command in ("project-set", "site-version", "site-testflight"):
        with open(path) as f:
            text = f.read()
        if command == "project-set":
            text = project_set(text, args[0], args[1])
        elif command == "site-version":
            text = site_version(text, args[0])
        else:
            text = site_testflight(text, args[0])
        with open(path, "w") as f:
            f.write(text)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
