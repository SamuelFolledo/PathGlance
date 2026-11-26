#!/usr/bin/env bash
# Archives PathGlance, uploads it to TestFlight, and publishes the landing site.
# The site lives on Dreamhost at samuelfolledo.com/apps/<SITE_SLUG>/.
#
# WHY: this is the one release pipeline for the app, modeled on LTPickleballHelper's
# build_release.sh, so every build goes out the same way: version and notes confirmed
# first, then archive, upload, site, commit, tag. Run it only when a release has been
# explicitly asked for -- never proactively.
#
# WHAT IT ASKS (first):
#   t  TestFlight -- archive, upload to App Store Connect, record the build in
#                    landing/releases.json, update and upload the site, commit and tag.
#   s  Site only  -- upload landing/ as it is. Nothing is built.
#   l  Link       -- put the TestFlight public link on the site's button, then upload the site.
#
# Every build has two sets of notes, both confirmed (or edited) here:
#   detailed -- the full list
#   short    -- 1-4 plain bullets: TestFlight's "What to Test" and the website
# Non-interactive runs can supply them with RELEASE_NOTES_FILE / SHORT_NOTES_FILE.
#
# First-time setup -- once:
#
#   1. App Store Connect API key (Users and Access > Integrations > Team Keys, App Manager):
#      the .p8 goes in ~/.appstoreconnect/private_keys/AuthKey_<KEY ID>.p8
#      and the Issuer ID (shown above the key list) goes in ~/.appstoreconnect/issuer_id
#
#   2. The app record must exist in App Store Connect for com.samuelfolledo.PathGlance.
#
#   3. Claude Code CLI on PATH (summarizes commits into release notes).
#
#   4. Copy scripts/release.env.example to scripts/release.local.env and fill it in.
#      The script makes the site's folder on Dreamhost itself.
#
# Usage:
#   ./scripts/build_release.sh           -- interactive
#   ./scripts/build_release.sh --dry-run -- same flow; archives and exports an .ipa to the
#                                           Desktop, but uploads, deploys, commits and tags nothing

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then DRY_RUN=true; fi

APP_NAME="PathGlance"
SCHEME="PathGlance"
TEAM_ID="9NY68F4K3P"
SITE_SLUG="path-glance"

# Account details stay out of the repo: scripts/release.local.env (gitignored) sets
# ASC_KEY_ID, DREAMHOST_USER and DREAMHOST_HOST. See scripts/release.env.example.
LOCAL_ENV="$(cd "$(dirname "$0")" && pwd)/release.local.env"
if [[ -f "$LOCAL_ENV" ]]; then source "$LOCAL_ENV"; fi
: "${ASC_KEY_ID:?Set ASC_KEY_ID in scripts/release.local.env}"
: "${DREAMHOST_USER:?Set DREAMHOST_USER in scripts/release.local.env}"
: "${DREAMHOST_HOST:?Set DREAMHOST_HOST in scripts/release.local.env}"
ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
ASC_ISSUER_FILE="$HOME/.appstoreconnect/issuer_id"

DREAMHOST_BASE="samuelfolledo.com/apps/${SITE_SLUG}"
SITE_URL="https://samuelfolledo.com/apps/${SITE_SLUG}/"
SSH_KEY="$HOME/.ssh/dreamhost_lt"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/PathGlance.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
LANDING="$REPO_ROOT/landing"
RELEASES="$LANDING/releases.json"
TOOL="$SCRIPT_DIR/release_tool.py"
WORK_DIR="$(mktemp -d /tmp/pathglance_release.XXXXXX)"
ARCHIVE="$WORK_DIR/${APP_NAME}.xcarchive"

tool() { python3 "$TOOL" "$@"; }

# ── Shared helpers ────────────────────────────────────────────────────────────

# confirm_notes LABEL VARNAME [OVERRIDE_FILE] -- shows the notes in VARNAME until accepted;
# 'e' opens them in $EDITOR, 'x' cancels. An override file skips the prompt.
confirm_notes() {
    local label="$1" var="$2" override="${3:-}"
    if [[ -n "$override" ]]; then
        printf -v "$var" '%s' "$(cat "$override")"
        echo "  ✓ ${label} taken from ${override}"
        return
    fi
    while true; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ${label}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "${!var}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        printf "Press Enter to proceed, 'e' to edit, or 'x' to cancel: "
        local input
        read -r input
        if [[ -z "$input" ]]; then
            break
        elif [[ "$input" == "x" || "$input" == "X" ]]; then
            echo ""; echo "  Cancelled."; exit 0
        elif [[ "$input" == "e" || "$input" == "E" ]]; then
            local tmp="$WORK_DIR/notes.md"
            echo "${!var}" > "$tmp"
            ${EDITOR:-nano} "$tmp"
            printf -v "$var" '%s' "$(cat "$tmp")"
            echo ""
        else
            echo ""
            echo "  ✗ Invalid — press Enter to accept, 'e' to edit, or 'x' to cancel."
            echo ""
        fi
    done
    echo ""
    echo "  ✓ ${label} confirmed."
    echo ""
}

# short_notes_from DETAILED -- Claude boils the detailed notes down to 1-4 plain bullets.
short_notes_from() {
    local detailed="$1"
    if ! command -v claude &>/dev/null; then echo "$detailed"; return; fi
    local prompt="These are the detailed release notes for the next TestFlight build of ${APP_NAME}, an iPhone app and lock screen widget that shows the next PATH trains from the nearest station:

${detailed}

Write a much shorter version that tells beta testers what to try.
Requirements:
- Return ONLY Markdown bullet points using \"- \" prefix, nothing else before or after
- 1 to 4 bullets, each under 12 words
- Group related changes into one theme
- Plain language, no technical terms; skip small fixes unless there is nothing else"
    claude -p "$prompt" </dev/null 2>/dev/null || echo "$detailed"
}

require_ssh_key() {
    if [[ ! -f "$SSH_KEY" ]]; then
        echo "Error: SSH key not found at $SSH_KEY"
        exit 1
    fi
}

# deploy_site -- uploads landing/ to Dreamhost.
deploy_site() {
    if [[ ! -f "$LANDING/index.html" ]]; then
        echo "Error: $LANDING/index.html not found."; exit 1
    fi
    if $DRY_RUN; then
        echo "Dry run — would upload landing/ to ${SITE_URL}"
        return
    fi
    require_ssh_key
    ssh -i "$SSH_KEY" "${DREAMHOST_USER}@${DREAMHOST_HOST}" "mkdir -p '${DREAMHOST_BASE}'"
    rsync -az --delete --exclude ".DS_Store" -e "ssh -i $SSH_KEY" \
        "$LANDING/" "${DREAMHOST_USER}@${DREAMHOST_HOST}:${DREAMHOST_BASE}/"
    echo "Uploaded landing/ → ${SITE_URL}"
}

# push_if_remote REF -- the repo may have no remote yet; then everything stays local.
push_if_remote() {
    if git -C "$REPO_ROOT" remote get-url origin &>/dev/null; then
        git -C "$REPO_ROOT" push origin "$1"
    else
        echo "No git remote — $1 kept local."
    fi
}

commit_site() {
    cd "$REPO_ROOT"
    git add landing
    git diff --cached --quiet || git commit -m "$1"
    push_if_remote main
}

# ── Snapshot the project's version (for the revert trap) ─────────────────────

CURRENT_VERSION=$(tool project-get "$PBXPROJ" MARKETING_VERSION)
OLD_BUILD=$(tool project-get "$PBXPROJ" CURRENT_PROJECT_VERSION)
PROJECT_MODIFIED=false

cleanup() {
    if $PROJECT_MODIFIED; then
        echo ""
        echo "  ✗ Failed — reverting the project to $CURRENT_VERSION (build $OLD_BUILD)"
        tool project-set "$PBXPROJ" MARKETING_VERSION "$CURRENT_VERSION"
        tool project-set "$PBXPROJ" CURRENT_PROJECT_VERSION "$OLD_BUILD"
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${APP_NAME} — Release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Interactive Step 0: What to do ───────────────────────────────────────────

LAST_BUILD=$(tool last-build "$RELEASES")
LATEST_RELEASED=$(tool latest-version "$RELEASES")
echo "Project version: $CURRENT_VERSION (build $OLD_BUILD) · last TestFlight build: ${LATEST_RELEASED:-none}${LATEST_RELEASED:+ ($LAST_BUILD)}"
echo "  t / T  → TestFlight build (archive, upload, update the site)"
echo "  s / S  → upload the site only"
echo "  l / L  → set the TestFlight public link on the site"
echo "  x / X  → cancel"
echo ""
while true; do
    printf "Release: "
    read -r RELEASE_KIND
    case "$RELEASE_KIND" in
        t|T) break ;;
        s|S) deploy_site; exit 0 ;;
        l|L)
            printf "TestFlight public link (https://testflight.apple.com/join/…): "
            read -r TF_URL
            if [[ ! "$TF_URL" =~ ^https://testflight\.apple\.com/join/[A-Za-z0-9]+$ ]]; then
                echo "  ✗ That is not a TestFlight public link."; exit 1
            fi
            tool site-testflight "$LANDING/index.html" "$TF_URL"
            deploy_site
            $DRY_RUN || commit_site "Site: TestFlight public link"
            exit 0 ;;
        x|X) echo ""; echo "  Cancelled."; exit 0 ;;
        *)   echo "  ✗ Invalid — enter t, s, l, or x." ;;
    esac
done
echo ""

# Uploading needs the API key; a dry run only needs signing.
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
if [[ -z "$ASC_ISSUER_ID" && -f "$ASC_ISSUER_FILE" ]]; then
    ASC_ISSUER_ID=$(tr -d '[:space:]' < "$ASC_ISSUER_FILE")
fi
AUTH_ARGS=()
if [[ -f "$ASC_KEY_PATH" && -n "$ASC_ISSUER_ID" ]]; then
    AUTH_ARGS=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
elif ! $DRY_RUN; then
    echo "App Store Connect API key not set up. Needed once:"
    echo "  $ASC_KEY_PATH"
    echo "  $ASC_ISSUER_FILE  (the Issuer ID from Users and Access > Integrations)"
    exit 1
fi

# ── Interactive Step 0a: Version ──────────────────────────────────────────────

IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT_VERSION"
V_PATCH="${V_PATCH:-0}"
SUGGESTED="${V_MAJOR}.${V_MINOR}.$((V_PATCH + 1))"

while true; do
    echo "Current version: $CURRENT_VERSION"
    echo "  c / C      → keep $CURRENT_VERSION (new build number only)"
    echo "  y / Y      → bump to $SUGGESTED (patch)"
    echo "  x.x or x.x.x → set a version  (e.g. ${V_MAJOR}.$((V_MINOR + 1)))"
    echo "  x / X      → cancel"
    echo ""
    printf "Version: "
    read -r VERSION_INPUT
    if [[ "$VERSION_INPUT" == "x" || "$VERSION_INPUT" == "X" ]]; then
        echo ""; echo "  Cancelled."; exit 0
    elif [[ "$VERSION_INPUT" == "y" || "$VERSION_INPUT" == "Y" ]]; then
        VERSION="$SUGGESTED"; break
    elif [[ "$VERSION_INPUT" == "c" || "$VERSION_INPUT" == "C" ]]; then
        VERSION="$CURRENT_VERSION"; break
    elif [[ "$VERSION_INPUT" =~ ^[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]{1,2})?$ ]]; then
        VERSION="$VERSION_INPUT"; break
    else
        echo ""
        echo "  ✗ Invalid — enter c, y, x, or a version like 1.1 or 1.0.1."
        echo ""
    fi
done

# Build numbers only ever rise, across every version.
BUILD_NUMBER=$((LAST_BUILD + 1))
if (( OLD_BUILD > BUILD_NUMBER )); then BUILD_NUMBER=$OLD_BUILD; fi
TAG="v${VERSION}-build.${BUILD_NUMBER}"

echo ""
echo "  ✓ Version $VERSION, build $BUILD_NUMBER"
echo ""

# ── Interactive Step 0b: Release notes ────────────────────────────────────────

cd "$REPO_ROOT"
# Everything since the last published build of any kind.
BASE=$(git log --grep='^Release v' -n 1 --format=%h) || true

RAW_COMMITS=""
if [[ -z "$BASE" ]]; then
    RAW_COMMITS=$(git log --pretty=format:"%s" | head -30) || true
else
    echo "Collecting commits after ${BASE}..."
    RAW_COMMITS=$(git log "${BASE}..HEAD" --pretty=format:"%s" \
        | grep -iv "^merge\|bump build\|Co-Authored\|^Release v\|^Site:") || true
fi

# Notes already published for this version (an earlier build of it).
EXISTING_NOTES_MD=$(tool notes "$RELEASES" "$VERSION" detailed) || true
EXISTING_SHORT_MD=$(tool notes "$RELEASES" "$VERSION" short) || true

if [[ -z "$RAW_COMMITS" ]]; then
    echo "No new commits since ${BASE} — keeping the notes as they are."
    DETAILED_NOTES_MD="${EXISTING_NOTES_MD:-"- Bug fixes and improvements"}"
elif ! command -v claude &>/dev/null; then
    echo "Warning: claude CLI not found — using raw commit messages."
    DETAILED_NOTES_MD="${EXISTING_NOTES_MD:+$EXISTING_NOTES_MD$'\n'}$(echo "$RAW_COMMITS" | sed 's/^/- /')"
else
    if [[ -n "$EXISTING_NOTES_MD" ]]; then
        echo "Merging the existing v${VERSION} notes with new commits..."
        PROMPT="These are the already-published release notes for ${APP_NAME} v${VERSION}, an iPhone app and lock screen widget that shows the next PATH trains from the nearest station:

${EXISTING_NOTES_MD}

These are additional git commits made since that build (they ship as the same version with a higher build number):

${RAW_COMMITS}

Merge them into one updated set of release notes for end users.
Requirements:
- Return ONLY Markdown bullet points using \"- \" prefix, nothing else before or after
- 3 to 8 bullets maximum
- Plain language a commuter would understand
- Preserve all previously published changes and incorporate the new commits
- Skip merge commits, version bumps, tests, release tooling, website changes and internal refactors
- Start each bullet with an action verb: Added, Fixed, Improved, Updated"
    else
        echo "Generating release notes from commits after ${BASE:-the beginning}..."
        PROMPT="These are git commit messages for the next TestFlight build of ${APP_NAME}, an iPhone app and lock screen widget that shows the next PATH trains from the nearest station.

Convert them into concise, friendly release notes for end users.
Requirements:
- Return ONLY Markdown bullet points using \"- \" prefix, nothing else before or after
- 3 to 8 bullets maximum
- Plain language a commuter would understand
- Focus on user-visible improvements and fixes
- Skip merge commits, version bumps, tests, release tooling, website changes and internal refactors
- Start each bullet with an action verb: Added, Fixed, Improved, Updated

Raw commits:
${RAW_COMMITS}"
    fi
    DETAILED_NOTES_MD=$(claude -p "$PROMPT" </dev/null 2>/dev/null \
        || echo "$RAW_COMMITS" | sed 's/^/- /')
fi

confirm_notes "Detailed release notes, commits after ${BASE:-the beginning}" DETAILED_NOTES_MD "${RELEASE_NOTES_FILE:-}"

if [[ -n "${SHORT_NOTES_FILE:-}" ]]; then
    SHORT_NOTES_MD=""
elif [[ -z "$RAW_COMMITS" && -n "$EXISTING_SHORT_MD" ]]; then
    SHORT_NOTES_MD="$EXISTING_SHORT_MD"
else
    echo "Writing the short release notes..."
    SHORT_NOTES_MD=$(short_notes_from "$DETAILED_NOTES_MD")
fi
confirm_notes "Short release notes (TestFlight \"What to Test\")" SHORT_NOTES_MD "${SHORT_NOTES_FILE:-}"

# ── Apply the version (revert trap is now armed) ──────────────────────────────

echo "  Updating the project ($CURRENT_VERSION build $OLD_BUILD → $VERSION build $BUILD_NUMBER)..."
PROJECT_MODIFIED=true
tool project-set "$PBXPROJ" MARKETING_VERSION "$VERSION"
tool project-set "$PBXPROJ" CURRENT_PROJECT_VERSION "$BUILD_NUMBER"
echo "  ✓ Project updated. Starting the archive..."
echo ""

# ── Step 1: Archive ───────────────────────────────────────────────────────────

echo "=== Step 1: Archive (Release, iOS device) ==="
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
    archive > "$WORK_DIR/archive.log" 2>&1 </dev/null \
    || { tail -40 "$WORK_DIR/archive.log"; cp "$WORK_DIR/archive.log" "$HOME/Desktop/${APP_NAME}-archive.log"; echo "Archive failed — full log on the Desktop."; exit 1; }
echo "Archived."

# ── Step 2: Export, and upload unless this is a dry run ───────────────────────

echo ""
if $DRY_RUN; then
    echo "=== Step 2: Export .ipa (dry run, no upload) ==="
    DESTINATION="export"
else
    echo "=== Step 2: Upload to App Store Connect ==="
    DESTINATION="upload"
fi
cat > "$WORK_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>${DESTINATION}</string>
    <key>teamID</key><string>${TEAM_ID}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$WORK_DIR/export" \
    -exportOptionsPlist "$WORK_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
    > "$WORK_DIR/export.log" 2>&1 </dev/null \
    || { tail -40 "$WORK_DIR/export.log"; cp "$WORK_DIR/export.log" "$HOME/Desktop/${APP_NAME}-export.log"; echo "Export failed — full log on the Desktop."; exit 1; }

if $DRY_RUN; then
    cp "$WORK_DIR/export/"*.ipa "$HOME/Desktop/${APP_NAME}-${VERSION}-${BUILD_NUMBER}.ipa"
    echo ""
    echo "Dry run — nothing uploaded, deployed, committed or tagged."
    echo "  .ipa: ~/Desktop/${APP_NAME}-${VERSION}-${BUILD_NUMBER}.ipa"
    exit 0   # the trap puts the project's version back
fi
echo "Uploaded v$VERSION build $BUILD_NUMBER. Apple processes it for 5–30 minutes."

# ── Step 3: Record the build, update the site ─────────────────────────────────

echo ""
echo "=== Step 3: Record the build + update the site ==="
ITEM_FILE="$WORK_DIR/item.json"
python3 -c '
import json, sys
keys = ["version", "build", "date", "short_notes", "detailed_notes"]
json.dump(dict(zip(keys, sys.argv[2:])), open(sys.argv[1], "w"))
' "$ITEM_FILE" "$VERSION" "$BUILD_NUMBER" "$(date -u "+%Y-%m-%d")" "$SHORT_NOTES_MD" "$DETAILED_NOTES_MD"
tool upsert "$RELEASES" "$ITEM_FILE"
tool site-version "$LANDING/index.html" "$VERSION"
deploy_site

# Commit the project + site so the tag points at exactly what shipped.
cd "$REPO_ROOT"
git add "$PBXPROJ" landing
git diff --cached --quiet || git commit -m "Release v$VERSION: build $OLD_BUILD → $BUILD_NUMBER, update releases"
push_if_remote main

if git rev-parse "$TAG" &>/dev/null; then
    echo "Tag $TAG already exists — skipping."
else
    git tag "$TAG"
    push_if_remote "$TAG"
    echo "Tagged $TAG."
fi

# Success — disarm the revert
PROJECT_MODIFIED=false

printf '%s' "$SHORT_NOTES_MD" | pbcopy || true
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done! v$VERSION build $BUILD_NUMBER is on its way to TestFlight."
echo "  Site: ${SITE_URL}"
echo ""
echo "  \"What to Test\" (copied to the clipboard — paste it on the build's"
echo "  page in App Store Connect > TestFlight once processing finishes):"
echo ""
echo "$SHORT_NOTES_MD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
