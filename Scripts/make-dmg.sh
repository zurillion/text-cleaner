#!/usr/bin/env bash
#
# make-dmg.sh — package a notarized .app into a distributable DMG.
#
# Run this AFTER exporting a Developer-ID-signed, notarized app from
# Xcode (Organizer → Distribute App → Direct Distribution → Export).
# Xcode already staples the exported .app; this script wraps it in a
# DMG with a drag-to-Applications layout, then notarizes and staples
# the DMG itself so Gatekeeper validates the container on download.
#
# Usage:
#   Scripts/make-dmg.sh <path-to-.app> [notarytool-profile]
#
# Examples:
#   Scripts/make-dmg.sh ~/Desktop/Export/TextCleaner.app NotaryToolMacbookAirM2
#   Scripts/make-dmg.sh ~/Desktop/Export/TextCleaner.app    # skips DMG notarization
#
# The notarytool-profile name is whatever you chose when you ran
# `xcrun notarytool store-credentials`. Per-Mac naming (e.g.
# NotaryToolMacbookAirM2, NotaryToolMacMini) is convenient because the
# app-specific password isn't synced via iCloud Keychain — every Mac
# you build from needs its own store-credentials invocation.
#
# One-time notarytool credential setup (needed only if you pass a
# profile name to notarize the DMG):
#   1. Create an app-specific password at https://appleid.apple.com
#      (Sign-In and Security → App-Specific Passwords). notarytool
#      can't do interactive 2FA, hence the app-specific password.
#   2. Store it in the keychain under a profile name (your choice):
#        xcrun notarytool store-credentials "NotaryToolMacbookAirM2" \
#          --apple-id "you@example.com" \
#          --team-id "ABCDE12345" \
#          --password "xxxx-xxxx-xxxx-xxxx"
#      (team-id is the 10-char Team Identifier from your Developer
#       account / `codesign -dv` output.)
#
# If you omit the profile, the script still builds the DMG but skips
# DMG notarization — fine for local testing, but for public download
# you want the DMG notarized too.

set -euo pipefail

APP_PATH="${1:-}"
NOTARY_PROFILE="${2:-}"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "error: pass the path to the exported .app as the first argument" >&2
    echo "usage: $0 <path-to-.app> [notarytool-profile]" >&2
    exit 1
fi

# Cosmetic name shown as the DMG volume and in the file name. Decoupled
# from the on-disk bundle name (which stays TextCleaner.app because that
# is the Xcode PRODUCT_NAME).
VOLUME_NAME="TextMagician"
APP_NAME="$(basename "$APP_PATH")"

# Pull the marketing version out of the bundle so the DMG file name
# carries it, e.g. TextMagician-1.2.dmg.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "")"
DMG_NAME="${VOLUME_NAME}${VERSION:+-$VERSION}.dmg"

OUT_DIR="$(cd "$(dirname "$APP_PATH")" && pwd)"
DMG_PATH="$OUT_DIR/$DMG_NAME"

echo "› Verifying the app is Developer-ID signed and stapled…"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
# Gatekeeper assessment: should say "accepted / Notarized Developer ID".
spctl --assess --type execute --verbose=4 "$APP_PATH" || {
    echo "warning: spctl assessment failed — is the .app notarized & stapled?" >&2
}

echo "› Building DMG staging folder…"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Include the user guide(s) if they live at the repo root. Looks for the
# English (USAGE.{pdf,md}) and Italian (USAGE.it.{pdf,md}) versions
# separately, preferring PDF over Markdown for each. Inside the DMG the
# files show up with friendly names ("User Guide.pdf", "Guida d'uso.pdf")
# rather than the repo-style USAGE.* convention.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

include_guide() {
    local label="$1"; shift
    local candidate
    for candidate in "$@"; do
        if [[ -f "$candidate" ]]; then
            local ext="${candidate##*.}"
            cp "$candidate" "$STAGING/$label.$ext"
            echo "  including: $(basename "$candidate") → $label.$ext"
            return
        fi
    done
}

include_guide "User Guide" \
    "$REPO_ROOT/USAGE.pdf" \
    "$REPO_ROOT/USAGE.md"

include_guide "Guida d'uso" \
    "$REPO_ROOT/USAGE.it.pdf" \
    "$REPO_ROOT/USAGE.it.md"

echo "› Creating ${DMG_NAME}…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "› Submitting DMG for notarization (profile: $NOTARY_PROFILE)…"
    echo "  Notarization usually takes 1–5 minutes (occasionally up to 15+"
    echo "  if Apple's queue is busy). Heartbeat every 15s below."

    START_TS="$(date +%s)"

    # Submit without --wait so we can poll the status ourselves and
    # show a visible heartbeat. notarytool's own --wait stays mute
    # for the entire processing window, which feels like a hang.
    SUBMIT_OUT="$(xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" 2>&1)" || {
        echo "$SUBMIT_OUT" >&2
        echo "error: notarytool submit failed" >&2
        exit 1
    }

    SUBMISSION_ID="$(printf '%s\n' "$SUBMIT_OUT" \
        | sed -nE 's/^[[:space:]]+id:[[:space:]]+(.+)$/\1/p' \
        | head -1)"
    if [[ -z "$SUBMISSION_ID" ]]; then
        echo "error: couldn't parse submission ID from notarytool output:" >&2
        printf '%s\n' "$SUBMIT_OUT" >&2
        exit 1
    fi
    echo "  submission id: $SUBMISSION_ID"

    while true; do
        elapsed=$(( $(date +%s) - START_TS ))
        printf -v elapsed_fmt "%02d:%02d" $(( elapsed / 60 )) $(( elapsed % 60 ))

        INFO_OUT="$(xcrun notarytool info "$SUBMISSION_ID" \
            --keychain-profile "$NOTARY_PROFILE" 2>&1)" || {
            echo "  [$elapsed_fmt] status check failed — retrying in 15s" >&2
            sleep 15
            continue
        }

        STATUS="$(printf '%s\n' "$INFO_OUT" \
            | sed -nE 's/^[[:space:]]+status:[[:space:]]+(.+)$/\1/p' \
            | head -1)"
        STATUS="${STATUS:-Unknown}"

        printf "  [%s] status: %s\n" "$elapsed_fmt" "$STATUS"

        case "$STATUS" in
            Accepted)
                break
                ;;
            "In Progress")
                sleep 15
                ;;
            *)
                # Invalid / Rejected / unexpected — dump the log so the
                # user can see what Apple objected to.
                echo "error: notarization ended with status \"$STATUS\"." >&2
                echo "       Fetching the full log from Apple…" >&2
                xcrun notarytool log "$SUBMISSION_ID" \
                    --keychain-profile "$NOTARY_PROFILE" >&2 || true
                exit 1
                ;;
        esac
    done

    echo "› Stapling notarization ticket to the DMG…"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
else
    echo "› No notarytool profile given — skipping DMG notarization."
    echo "  (The .app inside is still notarized/stapled from Xcode.)"
fi

echo "✓ Done: $DMG_PATH"
