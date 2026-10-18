#!/bin/bash
# Applies Pastronaut identity on top of upstream Maccy sources.
# Idempotent: rerun after every upstream merge, then review `git diff`.
#
# Keeps the Swift module name "Maccy" (PRODUCT_MODULE_NAME) so upstream code and
# `@testable import Maccy` keep working; only the product, bundle and UI names change.
set -euo pipefail
cd "$(dirname "$0")/.."

OLD_ID="org.p0deje.Maccy"
NEW_ID="com.xkbxyberk.pastronaut"
OLD_TEAM="MN3X4648SC"
NEW_TEAM="V88QY49A4T"
PBX="Maccy.xcodeproj/project.pbxproj"

# 1. Xcode project: bundle IDs, team, product name, test host.
perl -0pi -e "
  s/PRODUCT_BUNDLE_IDENTIFIER = \Q$OLD_ID\E;\n(\t+)PRODUCT_NAME = \"\\\$\(TARGET_NAME\)\";/PRODUCT_BUNDLE_IDENTIFIER = $NEW_ID;\n\$1PRODUCT_MODULE_NAME = Maccy;\n\$1PRODUCT_NAME = Pastronaut;/g;
  s/PRODUCT_BUNDLE_IDENTIFIER = \Q$OLD_ID\ETests;/PRODUCT_BUNDLE_IDENTIFIER = $NEW_ID.tests;/g;
  s/PRODUCT_BUNDLE_IDENTIFIER = \Q$OLD_ID\EUITests;/PRODUCT_BUNDLE_IDENTIFIER = $NEW_ID.uitests;/g;
  s/DEVELOPMENT_TEAM = $OLD_TEAM;/DEVELOPMENT_TEAM = $NEW_TEAM;/g;
  s{Maccy\.app/\\\$\(BUNDLE_EXECUTABLE_FOLDER_PATH\)/Maccy\"}{Pastronaut.app/\\\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Pastronaut\"}g;
" "$PBX"

# 2. Info.plist: copyright, update feed, update-signing key, exported pin-reorder type.
SPARKLE_PUBLIC_KEY="pnm+kxry9YU9uqHZByp3pXDQx4VYfNY8PRKBLdzQH8E="
PLIST="Maccy/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :NSHumanReadableCopyright 'Copyright © Alexey Rodionov (Maccy). Pastronaut changes © xkbxyberk.'" \
  -c "Set :SUFeedURL https://raw.githubusercontent.com/xkbxyberk/pastronaut/pastronaut/pastronaut-appcast.xml" \
  -c "Set :UTExportedTypeDeclarations:0:UTTypeIdentifier $NEW_ID.pin-reorder" \
  -c "Set :UTExportedTypeDeclarations:0:UTTypeDescription 'Pastronaut Pin Reorder Type'" \
  "$PLIST"
# Sparkle: the public half of the update-signing key (the private half is in the release Mac's keychain,
# account "pastronaut"). Add or Set, so the step is safe to repeat.
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_KEY" "$PLIST"
sed -i '' "s/UTType(exportedAs: \"$OLD_ID.pin-reorder\")/UTType(exportedAs: \"$NEW_ID.pin-reorder\")/" Maccy/Views/PinsView.swift

# 3. Visible app name in UI strings (all languages) and the list header.
find Maccy -name '*.strings' -print0 | xargs -0 sed -i '' -e "s/$OLD_ID/$NEW_ID/g" -e 's/Maccy/Pastronaut/g'
sed -i '' 's/Text("Maccy")/Text("Pastronaut")/' Maccy/Views/ListHeaderView.swift

echo "Rebrand applied. Review with: git diff --stat"

# 4. Icons: Pastronaut's own layered icon replaces Maccy's (keep ours on merge conflicts:
#    `git checkout --ours Maccy/AppIcon.icon`). Maccy's legacy icon set and its Debug-only
#    exclusion of the layered icon are removed so every configuration shows our icon.
rm -rf Maccy/Assets.xcassets/AppIcon.appiconset
perl -0pi -e 's/\t+EXCLUDED_SOURCE_FILE_NAMES = AppIcon\.icon;\n//g' Maccy.xcodeproj/project.pbxproj

# 5. Version: Pastronaut numbers its own releases (docs/pastronaut/SURUM.md). The version lines are ours since the
#    first release, so an upstream version bump shows up as a merge conflict: keep ours. Nothing to rewrite here.
grep -m1 -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION' "$PBX" >/dev/null && \
  echo "Mac version: $(grep -m1 -o 'MARKETING_VERSION = [^;]*' "$PBX") / $(grep -m1 -o 'CURRENT_PROJECT_VERSION = [^;]*' "$PBX")"

# 6. Shortcuts action descriptions (English only, in Swift) still named Maccy.
sed -i '' -e 's/Maccy clipboard history/Pastronaut clipboard history/' -e 's/Maccy settings/Pastronaut settings/' Maccy/Intents/*.swift
