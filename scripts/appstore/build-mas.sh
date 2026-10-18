#!/bin/bash
# Builds the Mac App Store variant of Pastronaut from the committed HEAD, without touching this checkout.
#
#   scripts/appstore/build-mas.sh [--upload]
#
# 1. Makes a throwaway git worktree and applies mas-transform.py (no Sparkle, privacy manifest, review prompt).
# 2. Archives Release and exports it with App Store Connect signing (Xcode's signed-in account, automatic signing).
# 3. Checks the result: no Sparkle inside, sandbox on, iCloud and push entitlements for production.
# With --upload the export goes straight to App Store Connect instead of a local .pkg.
#
# Versions: MAS_VERSION (default 1.0) and MAS_BUILD (default 1). Each upload needs a new MAS_BUILD.
set -euo pipefail
cd "$(dirname "$0")/../.."

MAS_VERSION="${MAS_VERSION:-1.0}"
MAS_BUILD="${MAS_BUILD:-1}"
DESTINATION=export
[[ "${1:-}" == "--upload" ]] && DESTINATION=upload

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
unset SDKROOT

OUT="$PWD/build/mas"
WORK="$OUT/src"
ARCHIVE="$OUT/Pastronaut.xcarchive"
EXPORT="$OUT/export"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Note: uncommitted changes are NOT part of this build (it uses HEAD $(git rev-parse --short HEAD))."
fi

mkdir -p "$OUT"
git worktree remove --force "$WORK" 2>/dev/null || true
rm -rf "${ARCHIVE:?}" "${EXPORT:?}"
git worktree add --detach "$WORK" HEAD >/dev/null
trap 'git worktree remove --force "$WORK"' EXIT

python3 -I scripts/appstore/mas-transform.py "$WORK" "$MAS_VERSION" "$MAS_BUILD"

xcodebuild -project "$WORK/Maccy.xcodeproj" -scheme Maccy -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates archive -quiet

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DESTINATION</string>
  <key>teamID</key><string>V88QY49A4T</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates

# Checks on the archived app, as it was signed for distribution.
APP="$ARCHIVE/Products/Applications/Pastronaut.app"
fail() { echo "CHECK FAILED: $*"; exit 1; }
[[ -e "$APP/Contents/Frameworks/Sparkle.framework" ]] && fail "Sparkle.framework is in the app"
otool -L "$APP/Contents/MacOS/Pastronaut" | grep -qi sparkle && fail "the binary links Sparkle"
plutil -p "$APP/Contents/Info.plist" | grep -q '"SU' && fail "Info.plist still has Sparkle keys"
[[ -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy" ]] || fail "privacy manifest missing"
grep -R -l -a -E 'iPhone|Mac([^a-z]|cy)' "$APP/Contents/Resources/Metadata.appintents" 2>/dev/null \
  && fail "Shortcuts metadata names an Apple product (ITMS-90626) or Maccy; check the files above."

if [[ "$DESTINATION" == export ]]; then
  PKG="$(ls "$EXPORT"/*.pkg)"
  pkgutil --check-signature "$PKG" | head -3
  echo "Entitlements of the exported app:"
  mkdir -p "$OUT/expanded"
  rm -rf "${OUT:?}/expanded/pkg"
  pkgutil --expand-full "$PKG" "$OUT/expanded/pkg"
  codesign -d --entitlements - --xml "$(find "$OUT/expanded/pkg" -name Pastronaut.app -maxdepth 3 | head -1)" 2>/dev/null \
    | plutil -p -
fi
echo "Mac App Store build $MAS_VERSION ($MAS_BUILD): $DESTINATION done. Output: $OUT"
