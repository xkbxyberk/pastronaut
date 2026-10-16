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

# 2. Info.plist: copyright, update feed, exported pin-reorder type.
PLIST="Maccy/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :NSHumanReadableCopyright 'Copyright © Alexey Rodionov (Maccy). Pastronaut changes © xkbxyberk.'" \
  -c "Set :SUFeedURL https://raw.githubusercontent.com/xkbxyberk/pastronaut/pastronaut/pastronaut-appcast.xml" \
  -c "Set :UTExportedTypeDeclarations:0:UTTypeIdentifier $NEW_ID.pin-reorder" \
  -c "Set :UTExportedTypeDeclarations:0:UTTypeDescription 'Pastronaut Pin Reorder Type'" \
  "$PLIST"
sed -i '' "s/UTType(exportedAs: \"$OLD_ID.pin-reorder\")/UTType(exportedAs: \"$NEW_ID.pin-reorder\")/" Maccy/Views/PinsView.swift

# 3. Visible app name in UI strings (all languages) and the list header.
find Maccy -name '*.strings' -print0 | xargs -0 sed -i '' -e "s/$OLD_ID/$NEW_ID/g" -e 's/Maccy/Pastronaut/g'
sed -i '' 's/Text("Maccy")/Text("Pastronaut")/' Maccy/Views/ListHeaderView.swift

echo "Rebrand applied. Review with: git diff --stat"
