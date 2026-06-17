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
#   Scripts/make-dmg.sh ~/Desktop/Export/TextCleaner.app TextMagicianNotary
#   Scripts/make-dmg.sh ~/Desktop/Export/TextCleaner.app    # skips DMG notarization
#
# One-time notarytool credential setup (needed only if you pass a
# profile name to notarize the DMG):
#   1. Create an app-specific password at https://appleid.apple.com
#      (Sign-In and Security → App-Specific Passwords). notarytool
#      can't do interactive 2FA, hence the app-specific password.
#   2. Store it in the keychain under a profile name:
#        xcrun notarytool store-credentials "TextMagicianNotary" \
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

# Include the user guide if it lives at the repo root. Looks for a PDF
# first (nicer for end users), falls back to the Markdown source so the
# DMG always carries some kind of documentation when it's available.
# Inside the DMG it shows up as "User Guide.<ext>" rather than the
# repo-style "USAGE.<ext>" filename.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
for candidate in "$REPO_ROOT/USAGE.pdf" "$REPO_ROOT/USAGE.md"; do
    if [[ -f "$candidate" ]]; then
        ext="${candidate##*.}"
        cp "$candidate" "$STAGING/User Guide.$ext"
        echo "  including: $(basename "$candidate") → User Guide.$ext"
        break
    fi
done

echo "› Creating $DMG_NAME…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "› Submitting DMG for notarization (profile: $NOTARY_PROFILE)…"
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "› Stapling notarization ticket to the DMG…"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
else
    echo "› No notarytool profile given — skipping DMG notarization."
    echo "  (The .app inside is still notarized/stapled from Xcode.)"
fi

echo "✓ Done: $DMG_PATH"
