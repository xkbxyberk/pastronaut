#!/usr/bin/env python3
"""Turns a Pastronaut source tree into the Mac App Store variant, in place.

Run it only on a throwaway copy (build-mas.sh makes a git worktree): the main branch keeps
Sparkle for the GitHub build, so upstream merges stay simple. Mirrors Maccy's own App Store
branch: no Sparkle (App Review guideline 2.4.5), review prompt on, plus a privacy manifest.

Usage: mas-transform.py <source-root> <marketing-version> <build-number>
Every step fails loudly if its anchor is missing, so an upstream change can't slip through.
"""
import json
import pathlib
import plistlib
import re
import shutil
import sys

root = pathlib.Path(sys.argv[1])
version, build = sys.argv[2], sys.argv[3]
here = pathlib.Path(__file__).resolve().parent


def edit(path, change):
    file = root / path
    old = file.read_text()
    new = change(old)
    if new == old:
        sys.exit(f"mas-transform: nothing changed in {path}")
    file.write_text(new)


def remove(pattern, flags=0, count=1):
    def change(text):
        new, n = re.subn(pattern, "", text, flags=flags)
        if n != count:
            sys.exit(f"mas-transform: expected {count} match(es), found {n}: {pattern}")
        return new
    return change


# 1. Xcode project: drop the Sparkle package, its product, SoftwareUpdater.swift and Maccy's appcast.
pbx = "Maccy.xcodeproj/project.pbxproj"
edit(pbx, remove(r"[^\n]*/\* Sparkle in Frameworks \*/[^\n]*\n", count=2))
edit(pbx, remove(r"[^\n]*SoftwareUpdater\.swift[^\n]*\n", count=4))
edit(pbx, remove(r"[^\n]*/\* appcast\.xml[^\n]*\n", count=4))
edit(pbx, remove(r"\t+2F39CB032AD9A93C00B749FD /\* Sparkle \*/,\n"))
edit(pbx, remove(r'\t+2F39CB022AD9A93C00B749FD /\* XCRemoteSwiftPackageReference "Sparkle" \*/,\n'))
edit(pbx, remove(r'\t\t2F39CB022AD9A93C00B749FD /\* XCRemoteSwiftPackageReference "Sparkle" \*/ = \{.*?\n\t\t\};\n', re.S))
edit(pbx, remove(r"\t\t2F39CB032AD9A93C00B749FD /\* Sparkle \*/ = \{.*?\n\t\t\};\n", re.S))
text = (root / pbx).read_text()
text = re.sub(r"MARKETING_VERSION = [0-9.]+;", f"MARKETING_VERSION = {version};", text)
text = re.sub(r"CURRENT_PROJECT_VERSION = [0-9]+;", f"CURRENT_PROJECT_VERSION = {build};", text)
(root / pbx).write_text(text)
if "Sparkle" in (root / pbx).read_text():
    sys.exit("mas-transform: Sparkle is still referenced in the project")

# 2. The privacy manifest, as a resource of the Mac app (in the Sync group).
shutil.copy(here / "PrivacyInfo.xcprivacy", root / "Maccy/Sync/PrivacyInfo.xcprivacy")
FILE, BUILD = "A1C0FFEE00000000000000F1", "A1C0FFEE00000000000000F2"


def add_manifest(text):
    def after(anchor, line):
        nonlocal text
        if text.count(anchor) != 1:
            sys.exit(f"mas-transform: anchor not unique: {anchor}")
        text = text.replace(anchor, anchor + line)
    after("/* Begin PBXBuildFile section */\n",
          f"\t\t{BUILD} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {FILE} /* PrivacyInfo.xcprivacy */; }};\n")
    after("/* Begin PBXFileReference section */\n",
          f'\t\t{FILE} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; }};\n')
    after("\t\t\t\tA1C0FFEE0000000000000011 /* Pastronaut.xcstrings */,\n",
          f"\t\t\t\t{FILE} /* PrivacyInfo.xcprivacy */,\n")
    after("\t\t\t\tDA009934256411F90030E697 /* LICENSE in Resources */,\n",
          f"\t\t\t\t{BUILD} /* PrivacyInfo.xcprivacy in Resources */,\n")
    return text


edit(pbx, add_manifest)

# 3. Resolved package versions: drop the Sparkle pin.
resolved = root / "Maccy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
data = json.loads(resolved.read_text())
pins = [p for p in data["pins"] if p["identity"].lower() != "sparkle"]
if len(pins) != len(data["pins"]) - 1:
    sys.exit("mas-transform: Sparkle pin not found")
data["pins"] = pins
resolved.write_text(json.dumps(data, indent=2) + "\n")

# 4. Code: no updater, and ask for an App Store review now and then (after 50 uses, once a month).
(root / "Maccy/SoftwareUpdater.swift").unlink()
edit("Maccy/AppDelegate.swift", remove(r"import Sparkle\n"))
edit("Maccy/AppDelegate.swift", remove(r"      SPUUpdater\(hostBundle:.*?\.automaticallyChecksForUpdates = false\n", re.S))
edit("Maccy/Settings/GeneralSettingsPane.swift", remove(r"  @State private var updater = SoftwareUpdater\(\)\n\n"))
edit("Maccy/Settings/GeneralSettingsPane.swift",
     remove(r"        Toggle\(isOn: \$updater\.automaticallyChecksForUpdates\) \{.*?\"CheckNow\", tableName: \"GeneralSettings\"\) \}\n        \)\n", re.S))
edit("Maccy/Observables/History.swift", lambda t: t.replace(
    "    Task {\n      searchQuery = \"\"\n    }\n  }\n\n  @MainActor\n  func startPasteStack(",
    "    Task {\n      searchQuery = \"\"\n    }\n\n    AppStoreReview.ask()\n  }\n\n  @MainActor\n  func startPasteStack(", 1))
for swift in (root / "Maccy").rglob("*.swift"):
    if re.search(r"\bimport Sparkle\b|\bSPU[A-Z]", swift.read_text()):
        sys.exit(f"mas-transform: Sparkle still used in {swift}")

# 5. Info.plist: no update feed or key; export compliance answered (only Apple's own encryption).
info = root / "Maccy/Info.plist"
plist = plistlib.loads(info.read_bytes())
for key in ("SUFeedURL", "SUPublicEDKey", "SUEnableDownloaderService", "SUEnableInstallerLauncherService"):
    if plist.pop(key, None) is None:
        sys.exit(f"mas-transform: {key} missing from Info.plist")
plist["ITSAppUsesNonExemptEncryption"] = False
info.write_bytes(plistlib.dumps(plist))

# 6. Entitlements: Sparkle's XPC services needed a temporary sandbox exception; App Review asks why, so drop it.
ent = root / "Maccy/Maccy.entitlements"
entitlements = plistlib.loads(ent.read_bytes())
if entitlements.pop("com.apple.security.temporary-exception.mach-lookup.global-name", None) is None:
    sys.exit("mas-transform: Sparkle mach-lookup exception missing")
ent.write_bytes(plistlib.dumps(entitlements))

print(f"mas-transform: Mac App Store variant ready ({version} ({build}))")
