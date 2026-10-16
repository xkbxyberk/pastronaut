#!/bin/bash
# Regenerates Maccy/Acknowledgements.txt from the Maccy license and the license file of
# every resolved Swift package. Run after changing package dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DEVELOPER_DIR:=/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
PACKAGES="$(mktemp -d)/SourcePackages"
OUT="Maccy/Acknowledgements.txt"

xcodebuild -resolvePackageDependencies -project Maccy.xcodeproj -scheme Maccy \
  -clonedSourcePackagesDirPath "$PACKAGES" >/dev/null

{
  echo "Pastronaut is based on Maccy (https://github.com/p0deje/Maccy) and is not affiliated with it."
  echo "Pastronaut source: https://github.com/xkbxyberk/pastronaut"
  echo
  echo "================================================================================"
  echo "Maccy"
  echo "================================================================================"
  cat LICENSE
  for dir in "$PACKAGES"/checkouts/*; do
    license="$(find "$dir" -maxdepth 1 -iname 'licen[cs]e*' | head -1)"
    [ -n "$license" ] || { echo "warning: no license file in $(basename "$dir")" >&2; continue; }
    echo
    echo "================================================================================"
    echo "$(basename "$dir")"
    echo "================================================================================"
    cat "$license"
  done
} > "$OUT"

echo "Wrote $OUT"
