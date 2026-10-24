#!/usr/bin/env python3 -I
"""Two-device sync test: drives a Debug Mac build and an iPhone, and checks they converge.

Mac:    clipboard writes through NSPasteboard, actions through E2EControl (Maccy/Sync/SyncBridge.swift),
        state from `PTEST-STATE` lines in the unified log.
iPhone: one XCUITest step per action (iOS/UITests/SyncStepTests.swift), state from the App Group files
        fetched with `devicectl`.

Both apps must be Debug builds signed for the same iCloud account (CloudKit Development environment).
Keep the iPhone unlocked and connected. Usage:

    scripts/e2e/sync_e2e.py --mac-app <Pastronaut.app> --xctestrun <file.xctestrun> --device <UDID>
"""

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unicodedata

BUNDLE_ID = "com.xkbxyberk.pastronaut"
APP_GROUP = "group.com.xkbxyberk.pastronaut"
COMMAND = "com.xkbxyberk.pastronaut.e2e.command"
DEV = {**os.environ, "DEVELOPER_DIR": os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")}

args = None
results = []
work = tempfile.mkdtemp(prefix="pastronaut-e2e-")


def log(message):
    print(f"[{time.strftime('%H:%M:%S')}] {message}", flush=True)


# MARK: - Mac

def mac_post(command):
    script = ('function run(argv){ObjC.import("Foundation");'
              '$.NSDistributedNotificationCenter.defaultCenter'
              '.postNotificationNameObjectUserInfoDeliverImmediately(argv[0], argv[1], $(), true)}')
    subprocess.run(["osascript", "-l", "JavaScript", "-e", script, COMMAND, json.dumps(command)],
                   check=True, capture_output=True)


def mac_copy(text, concealed=False):
    script = ('function run(argv){ObjC.import("AppKit");var pb=$.NSPasteboard.generalPasteboard;'
              'pb.clearContents;pb.setStringForType(argv[0],"public.utf8-plain-text");'
              'if(argv[1]=="1"){pb.setStringForType("","org.nspasteboard.ConcealedType")}}')
    subprocess.run(["osascript", "-l", "JavaScript", "-e", script, text, "1" if concealed else "0"],
                   check=True, capture_output=True)


def mac_copy_image(text):
    """An image with `text` drawn large on it, as a screenshot would be copied (1.3)."""
    script = ('function run(argv){ObjC.import("AppKit");var w=1400,h=320;'
              'var img=$.NSImage.alloc.initWithSize($.NSMakeSize(w,h));img.lockFocus;'
              '$.NSColor.whiteColor.setFill;$.NSRectFill($.NSMakeRect(0,0,w,h));'
              'var attrs=$.NSDictionary.dictionaryWithObjectForKey($.NSFont.boldSystemFontOfSize(72),$.NSFontAttributeName);'
              '$(argv[0]).drawAtPointWithAttributes($.NSMakePoint(40,110),attrs);img.unlockFocus;'
              'var rep=$.NSBitmapImageRep.imageRepWithData(img.TIFFRepresentation);'
              'var png=rep.representationUsingTypeProperties(4,$());'
              'var pb=$.NSPasteboard.generalPasteboard;pb.clearContents;pb.setDataForType(png,"public.png")}')
    subprocess.run(["osascript", "-l", "JavaScript", "-e", script, text], check=True, capture_output=True)


def mac_copy_pdf(path):
    """PDF data on the clipboard as Preview copies a selection: the PDF and a picture of it (1.3). A PDF alone
    isn't among the types the history keeps."""
    script = ('function run(argv){ObjC.import("AppKit");var data=$.NSData.dataWithContentsOfFile(argv[0]);'
              'var img=$.NSImage.alloc.initWithData(data);var pb=$.NSPasteboard.generalPasteboard;pb.clearContents;'
              'pb.setDataForType(data,"com.adobe.pdf");pb.setDataForType(img.TIFFRepresentation,"public.tiff")}')
    subprocess.run(["osascript", "-l", "JavaScript", "-e", script, path], check=True, capture_output=True)


def mac_copy_file(path):
    """A file on the clipboard the way Finder copies it (a file URL) (1.3)."""
    script = ('function run(argv){ObjC.import("AppKit");var pb=$.NSPasteboard.generalPasteboard;pb.clearContents;'
              'pb.writeObjects($([$.NSURL.fileURLWithPath(argv[0])]))}')
    subprocess.run(["osascript", "-l", "JavaScript", "-e", script, path], check=True, capture_output=True)


def make_pdf(text, path):
    """A one-page PDF with `text` in Helvetica, written by hand so nothing else is needed."""
    content = f"BT /F1 28 Tf 72 700 Td ({text}) Tj ET".encode()
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length " + str(len(content)).encode() + b" >>\nstream\n" + content + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    with open(path, "wb") as file:
        file.write(out)
    return bytes(out)


_dump_counter = 0


def mac_state(prefix="PTEST", op="dump", text=None, **extra):
    """Sends a command and returns the state the Mac logs right after it."""
    global _dump_counter
    _dump_counter += 1
    tag = f"d{_dump_counter}"
    command = {"op": op, "prefix": prefix, "tag": tag, **extra}
    if text is not None:
        command["text"] = text
    mac_post(command)
    for _ in range(10):
        time.sleep(1)
        out = subprocess.run(
            ["/usr/bin/log", "show", "--last", "30s", "--style", "ndjson", "--predicate",
             'process == "Pastronaut" AND eventMessage BEGINSWITH "PTEST-STATE"'],
            capture_output=True, text=True).stdout
        parts = {}
        for line in out.splitlines():
            try:
                message = json.loads(line).get("eventMessage", "")
            except json.JSONDecodeError:
                continue
            # "PTEST-STATE <tag> <i>/<n> <json part>" (see E2EControl.dump)
            fields = message.split(" ", 3)
            if len(fields) == 4 and fields[0] == "PTEST-STATE" and fields[1] == tag:
                index, count = map(int, fields[2].split("/"))
                parts[index] = fields[3]
                if len(parts) == count:
                    return json.loads("".join(parts[i] for i in range(1, count + 1)))
    raise RuntimeError("Mac did not answer (is the Debug build running?)")


def mac_item(state, match):
    return next((item for item in state["history"] if match in item["text"]), None)


def mac_wait(description, predicate, timeout, prefix="PTEST"):
    start = time.time()
    state = None
    while time.time() - start < timeout:
        state = mac_state(prefix)
        if predicate(state):
            return True, round(time.time() - start), state
        time.sleep(2)
    return False, round(time.time() - start), state


def mac_quit():
    subprocess.run(["osascript", "-e", f'tell application id "{BUNDLE_ID}" to quit'], capture_output=True)
    for _ in range(10):
        if subprocess.run(["pgrep", "-x", "Pastronaut"], capture_output=True).returncode != 0:
            return
        time.sleep(1)
    subprocess.run(["pkill", "-x", "Pastronaut"])


def mac_launch():
    subprocess.run(["open", args.mac_app], check=True)
    for _ in range(30):
        try:
            return mac_state()
        except RuntimeError:
            time.sleep(2)
    raise RuntimeError("Mac app did not start")


# MARK: - iPhone

def ios_step(op, text="", match="", timeout=30, on_ready=None, action=""):
    """Runs one XCUITest step and returns its PTEST-RESULT dict. `on_ready` runs once the app is waiting.

    xcodebuild sometimes hangs before the test starts (seen once with the iPhone connected and unlocked);
    such a step is stopped and tried once more instead of blocking the whole run."""
    result = _ios_step_once(op, text, match, timeout, on_ready, action)
    if (result.get("reason") in ("xcodebuild hung", "not started")
            or "failed to initialize for UI testing" in result.get("tail", "")):
        # The second case: "Timed out while enabling automation mode", before the step itself ran.
        log(f"  {op}: {result.get('reason')}, trying once more")
        result = _ios_step_once(op, text, match, timeout, on_ready, action)
    return result


def _ios_step_once(op, text, match, timeout, on_ready, action):
    env = {**DEV, "TEST_RUNNER_PT_OP": op, "TEST_RUNNER_PT_TEXT": text,
           "TEST_RUNNER_PT_MATCH": match, "TEST_RUNNER_PT_TIMEOUT": str(timeout),
           "TEST_RUNNER_PT_ACTION": action}
    process = subprocess.Popen(
        ["xcodebuild", "test-without-building", "-xctestrun", args.xctestrun,
         "-destination", f"id={args.device}",
         "-only-testing:PastronautUITests/SyncStepTests/testStep",
         # Without this every step leaves a new folder in ~/Library/Developer/Xcode/DerivedData.
         "-derivedDataPath", os.path.join(work, "DerivedData")],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    result = None
    output = []
    # Generous: launching the runner takes ~10 s, the step itself up to `timeout`.
    watchdog = threading.Timer(timeout + 180, process.kill)
    watchdog.start()
    for line in process.stdout:
        output.append(line)
        if "PTEST-READY" in line and on_ready:
            threading.Thread(target=on_ready, daemon=True).start()
            on_ready = None
        if line.startswith("PTEST-RESULT "):
            result = json.loads(line[len("PTEST-RESULT "):])
    process.wait()
    hung = not watchdog.is_alive() and result is None
    watchdog.cancel()
    if hung:
        return {"ok": False, "reason": "xcodebuild hung"}
    if result is None and not any("Test Case" in line and "started" in line for line in output):
        # The runner came up but the test itself never began: nothing on the iPhone was touched.
        return {"ok": False, "reason": "not started", "tail": "".join(output[-15:])[-1500:]}
    if result is None:
        tail = "".join(output[-15:])
        if "Unlock" in tail or "locked" in tail:
            raise RuntimeError("iPhone is locked; unlock it and run again")
        return {"ok": False, "reason": "no result", "tail": tail[-1500:]}
    return result


def ios_install():
    """`xcodebuild test-without-building` does not always reinstall a changed app, so install it here."""
    app = os.path.join(os.path.dirname(args.xctestrun), "Debug-iphoneos", "Pastronaut.app")
    subprocess.run(["xcrun", "devicectl", "device", "install", "app", "--device", args.device, app, "-q"],
                   env=DEV, check=True, capture_output=True)


def ios_open():
    """Starts the app and leaves it open, so changes arrive by push while the script reads its files (1.3).
    A UI test step ends with the app closed; this keeps it running between steps. Same switches as the steps."""
    subprocess.run(["xcrun", "devicectl", "device", "process", "launch", "--device", args.device,
                    "--terminate-existing", "--environment-variables", json.dumps({"PT_E2E": "1", "PT_AUTO_SAVE": "0"}),
                    BUNDLE_ID, "-q"], env=DEV, capture_output=True)
    time.sleep(3)


def ios_terminate_app():
    """Ends the app process so only the keyboard can bring in new data."""
    out = subprocess.run(["xcrun", "devicectl", "device", "info", "processes", "--device", args.device],
                         env=DEV, capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.rstrip().endswith("/Pastronaut.app/Pastronaut"):
            subprocess.run(["xcrun", "devicectl", "device", "process", "terminate", "--device", args.device,
                            "--pid", line.split()[0], "-q"], env=DEV, capture_output=True)


def ios_file(name):
    destination = os.path.join(work, name)
    if os.path.exists(destination):
        os.remove(destination)
    subprocess.run(["xcrun", "devicectl", "device", "copy", "from", "--device", args.device,
                    "--domain-type", "appGroupDataContainer", "--domain-identifier", APP_GROUP,
                    "--source", f"Library/Pastronaut/{name}", "--destination", destination, "-q"],
                   env=DEV, capture_output=True)
    if not os.path.exists(destination):
        return None
    with open(destination, encoding="utf-8") as file:
        return json.load(file)


def ios_mirror():
    """Clips the iPhone app holds in its sync mirror (its view of iCloud)."""
    state = ios_file("clip-sync.json") or {}
    return [entry["clip"] for entry in state.get("entries", {}).values()]


def ios_collections():
    """Collection names in the iPhone's mirror, and clip text → its collection names."""
    state = ios_file("clip-sync.json") or {}
    names = {key: entry["collection"]["name"] for key, entry in state.get("collections", {}).items()}
    members = {entry["clip"]["text"]: [names.get(i, "?") for i in entry["clip"].get("collectionIDs", [])]
               for entry in state.get("entries", {}).values()}
    return set(names.values()), members, state


def ios_key_fingerprint():
    key = (ios_file("sync-key.json") or {}).get("data")
    return hashlib.sha256(base64.b64decode(key)).hexdigest()[:16] if key else None


def ios_snapshot():
    """Clips the keyboard sees."""
    return ios_file("clips.json")


def media_text(clip):
    """What a media clip is found by: the text read from it and its file names (1.3)."""
    media = clip.get("media") or {}
    return " ".join([media.get("recognizedText") or ""] + [f["name"] for f in media.get("files", [])])


def find_media(clips, *needles):
    return next((clip for clip in clips or [] if clip.get("media")
                 and all(n.lower() in media_text(clip).lower() for n in needles)), None)


def ios_entry(clip_id):
    return (ios_file("clip-sync.json") or {}).get("entries", {}).get(clip_id)


def ios_raw(path):
    """A file from the App Group's Pastronaut folder, as bytes."""
    destination = os.path.join(work, "raw-" + path.replace("/", "_"))
    if os.path.exists(destination):
        os.remove(destination)
    subprocess.run(["xcrun", "devicectl", "device", "copy", "from", "--device", args.device,
                    "--domain-type", "appGroupDataContainer", "--domain-identifier", APP_GROUP,
                    "--source", f"Library/Pastronaut/{path}", "--destination", destination, "-q"],
                   env=DEV, capture_output=True)
    if not os.path.exists(destination):
        return None
    with open(destination, "rb") as file:
        return file.read()


def ios_media_arrived(clip):
    """The clip is mirrored with its files downloaded, and its first file is in the store."""
    entry = ios_entry(clip["id"]) or {}
    name = clip["media"]["files"][0]["name"]
    return not entry.get("filesPending") and ios_raw(f"media/{clip['id']}/files/0/{name}")


def ios_wait_media(timeout, *needles):
    start = time.time()
    while time.time() - start < timeout:
        clip = find_media(ios_mirror(), *needles)
        if clip:
            data = ios_media_arrived(clip)
            if data:
                return clip, data, round(time.time() - start)
        time.sleep(4)
    return find_media(ios_mirror(), *needles), None, round(time.time() - start)


def mac_media(state, *needles, mirror=False):
    items = state.get("mediaMirror" if mirror else "media", [])
    def text(item):
        return " ".join([item.get("title") or "", item.get("text") or ""] + item.get("files", []))
    return next((i for i in items if all(n.lower() in text(i).lower() for n in needles)), None)


def characters(text):
    """The text split as Swift counts characters (close enough for test texts): CR LF, combining marks,
    variation selectors, skin tones, joined emoji and flag pairs each stay with the character before them."""
    out = []
    for char in text:
        code = ord(char)
        joins = out and (
            (char == "\n" and out[-1] == "\r") or unicodedata.combining(char) or char in "\u200d\ufe0e\ufe0f"
            or 0x1F3FB <= code <= 0x1F3FF or out[-1].endswith("\u200d")
            or (0x1F1E6 <= code <= 0x1F1FF and len(out[-1]) == 1 and 0x1F1E6 <= ord(out[-1]) <= 0x1F1FF))
        if joins:
            out[-1] += char
        else:
            out.append(char)
    return out


def summary(text):
    """Same shortening as E2EControl.dump, so Mac and iPhone texts compare. In NFC, as decomposed letters
    ("O" + "¨") are one character to Swift."""
    chars = characters(unicodedata.normalize("NFC", text))
    return "".join(chars) if len(chars) <= 80 else f"{''.join(chars[:80])}…({len(chars)})"


def find(clips, match):
    return next((clip for clip in clips or [] if match in clip["text"]), None)


# MARK: - Extended checks (1.3, 4th run): catch-up, limits, privacy, conflicts, order, health

REFERENCE_EPOCH = 978307200  # 2001-01-01, as Swift's timeIntervalSinceReferenceDate


def mac_now():
    return time.time() - REFERENCE_EPOCH


def mac_copy_files(paths):
    """Several files on the clipboard the way Finder copies a selection, one pasteboard item each (1.3). JXA
    wrote only the first of them, so a small Swift script does it."""
    helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), "copy_files.swift")
    env = {k: v for k, v in DEV.items() if k != "SDKROOT"}
    subprocess.run(["swift", helper, *paths], check=True, capture_output=True, env=env)


def ios_state():
    return ios_file("clip-sync.json") or {}


def ios_entry_for(text):
    return next((e for e in ios_state().get("entries", {}).values() if e["clip"]["text"] == text), None)


def ios_wait(predicate, timeout, interval=4):
    """Polls the iPhone's sync state until `predicate(state)` holds."""
    start = time.time()
    while time.time() - start < timeout:
        state = ios_state()
        if predicate(state):
            return True, round(time.time() - start), state
        time.sleep(interval)
    return False, round(time.time() - start), ios_state()


def ios_media(state, *needles):
    return find_media([e["clip"] for e in state.get("entries", {}).values()], *needles)


def nfc(text):
    return unicodedata.normalize("NFC", text)


def mac_sync_log(since):
    """ClipSync lines this Mac logged since `since` (a time.time())."""
    start = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(since))
    return subprocess.run(
        ["/usr/bin/log", "show", "--start", start, "--style", "compact", "--predicate",
         'process == "Pastronaut" AND category == "ClipSync"'], capture_output=True, text=True).stdout.splitlines()


def sent_counts(line):
    """(saves, failed saves) of a "Sent …" line, or None."""
    words = line.split()
    if "Sent" not in words:
        return None
    i = words.index("Sent")
    try:
        return int(words[i + 1]), int(words[words.index("failed") - 1])
    except (ValueError, IndexError):
        return None


def extended_tests(run, prefix, tag, run_started):
    """Checks added before the 1.3 release (4th run): what the first three runs did not cover."""
    big_size = 11_000_000  # over the default Largest Item (10 MB)

    # 46. Mac image while the iPhone app isn't running: it arrives when the app opens (catch-up path, files
    #     fetched after the records), and the keyboard's data has it with a thumbnail.
    ios_terminate_app()
    mac_copy_image(f"CATCHUP {tag}")
    mac_wait("catch-up image", lambda s: mac_media(s, "catchup", tag, mirror=True) is not None, 60, prefix=tag)
    time.sleep(5)
    ios_open()
    clip, data, secs = ios_wait_media(150, "catchup", tag)
    check("T46", "Mac image made while the iPhone app was closed arrives when it opens (files too)",
          clip is not None and bool(data), f"{secs}s, kind={clip and clip['kind']}, bytes={len(data) if data else 0}")
    snapshot = ios_snapshot() or []
    in_keyboard = clip is not None and any(c.get("id") == clip["id"] for c in snapshot)
    thumbnail = clip is not None and ios_raw(f"media/{clip['id']}/thumbnail.jpg") is not None
    check("T46b", "Keyboard data lists that image with its thumbnail", in_keyboard and thumbnail,
          f"in keyboard snapshot={in_keyboard}, thumbnail={thumbnail}")
    catchup_id = clip and clip["id"]

    # 47. Several Finder files at once, names with Turkish letters, spaces and an emoji: all arrive, in order,
    #     byte for byte, with their names.
    names = [f"PTEST-{tag} rapor çğış.txt", f"PTEST-{tag}-🚀 notlar.md", f"PTEST-{tag}-üçüncü,veri.csv"]
    bodies = [f"rapor {tag}\nikinci satır".encode(), f"# notlar {tag} 🚀".encode(), f"a,b\n1,{tag}".encode()]
    paths = []
    for name, body in zip(names, bodies):
        path = os.path.join(work, name)
        with open(path, "wb") as handle:
            handle.write(body)
        paths.append(path)
    mac_copy_files(paths)
    ok, secs, state = ios_wait(lambda s: (lambda c: c is not None and not (s["entries"][c["id"]].get("filesPending")))(
        ios_media(s, tag, "rapor")), 150)
    clip = ios_media(state, tag, "rapor")
    files = (clip or {}).get("media", {}).get("files", [])
    got_names = [nfc(f["name"]) for f in files]
    expected = dict(zip((nfc(n) for n in names), bodies))
    same = clip is not None and sorted(got_names) == sorted(expected) and all(
        ios_raw(f"media/{clip['id']}/files/{i}/{f['name']}") == expected.get(nfc(f["name"]))
        for i, f in enumerate(files))
    check("T47", "Three Finder files at once (Turkish letters, emoji, comma in names) → iPhone, same names and bytes",
          ok and same, f"{secs}s, names={got_names}, same={same}")
    if clip:
        mac_state(op="deleteMedia", text=names[0], prefix=tag)

    # 48. A file over Largest Item stays on the Mac: not in iCloud, not on the iPhone.
    big_path = os.path.join(work, f"PTEST-{tag}-big.bin")
    with open(big_path, "wb") as handle:
        handle.write(os.urandom(big_size))
    big_from = mac_now() - 1
    mac_copy_files([big_path])
    time.sleep(20)
    in_mirror = mac_media(mac_state(prefix=tag), "big.bin", mirror=True) is not None
    on_iphone = ios_media(ios_state(), "big.bin") is not None
    mac_state(op="deleteUnsyncedMedia", text=f"{big_from},{mac_now() + 1}")
    check("T48", "Mac file over Largest Item (11 MB) stays on the Mac", not in_mirror and not on_iphone,
          f"in iCloud={in_mirror}, on iPhone={on_iphone}")

    # 49. The same on the iPhone: an 11 MB file saved there stays there (kept on this iPhone only).
    big_phone = f"PTEST-{tag}-bigphone.bin"
    r = ios_step("saveFile", f"{big_phone}|@bytes:{big_size}", match=big_phone, timeout=40)
    time.sleep(15)
    clip = ios_media(ios_state(), big_phone)
    local_only = bool(clip and ios_state()["entries"][clip["id"]].get("isLocalOnly"))
    on_mac = mac_media(mac_state(prefix=tag), big_phone, mirror=True) is not None
    check("T49", "iPhone file over Largest Item stays on the iPhone (marked local-only), not on the Mac",
          r.get("ok") and local_only and not on_mac, f"step={r.get('ok')}, local-only={local_only}, on Mac={on_mac}")
    ios_step("delete", big_phone, match=big_phone)

    # 50. The same file saved on both devices is one clip on each (its ID follows the content).
    same_name = f"PTEST-{tag}-same.txt"
    same_body = f"same content {tag}"
    with open(os.path.join(work, same_name), "wb") as handle:
        handle.write(same_body.encode())
    mac_copy_files([os.path.join(work, same_name)])
    ios_open()
    ios_wait(lambda s: ios_media(s, same_name) is not None, 120)
    r = ios_step("saveFile", f"PTEST-{tag}-same-again.txt|{same_body}", match=tag, timeout=30)
    ios_open()
    time.sleep(25)
    on_phone = [e for e in ios_state().get("entries", {}).values()
                if e["clip"].get("media") and same_body.encode() == (ios_raw(
                    f"media/{e['clip']['id']}/files/0/{e['clip']['media']['files'][0]['name']}") or b"")]
    mac_mirror = [m for m in mac_state(prefix=tag).get("mediaMirror", []) if "same" in " ".join(m["files"])]
    check("T50", "Same file saved on both devices stays one clip on each", len(on_phone) == 1 and len(mac_mirror) == 1,
          f"iPhone {len(on_phone)}, Mac {len(mac_mirror)}, step={r.get('ok')}")
    for m in mac_mirror:
        mac_state(op="deleteMedia", text=m["files"][0], prefix=tag)

    # 51. Privacy inside images: with "Don't sync one-time codes" on, a screenshot of a code stays on the Mac.
    code = str(int(run) * 7 % 900000 + 100000)  # six digits, not the run's own
    mac_state(op="privacy", text="otp:on")
    shot_from = mac_now() - 1
    ios_open()
    mac_copy_image(f"Kod: {code}")
    time.sleep(25)
    in_mirror = any(code in (m.get("text") or "") for m in mac_state(prefix=code).get("mediaMirror", []))
    on_iphone = ios_media(ios_state(), code) is not None
    mac_state(op="privacy", text="otp:off")
    mac_state(op="deleteUnsyncedMedia", text=f"{shot_from},{mac_now() + 1}")
    check("T51", "Image showing a one-time code stays on the Mac (codes switch on)", not in_mirror and not on_iphone,
          f"in iCloud={in_mirror}, on iPhone={on_iphone}")

    # 52. A title on a media clip, both ways.
    mac_title, phone_title = f"MacTitle {tag}", f"PhoneTitle {tag}"
    if catchup_id:
        mac_state(op="titleMedia", text=f"CATCHUP {tag}", name=mac_title, prefix=tag)
        ok1, secs1, _ = ios_wait(lambda s: s.get("entries", {}).get(catchup_id, {}).get("clip", {}).get("title") == mac_title, 90)
        r = ios_step("title", mac_title, match=mac_title, action=phone_title)
        ok2, secs2, _ = mac_wait("phone title", lambda s: any(phone_title in (m.get("title") or "") for m in s.get("media", [])),
                                 90, prefix=tag)
        check("T52", "Media title: Mac → iPhone and iPhone → Mac", ok1 and r.get("ok") and ok2,
              f"Mac→iPhone {ok1} {secs1}s, iPhone→Mac {ok2} {secs2}s, step={r}")
        # Found by the clip's ID from here on, whichever title it ended up with.
        any_title = f"Title {tag}"

        # 53. A media clip put in a collection on the Mac is in it on the iPhone.
        collection = f"PTEST {run} Media"
        mac_state(op="collectMedia", text=f"CATCHUP {tag}", name=collection, prefix=tag)
        ios_open()
        ok, secs, _ = ios_wait(lambda s: any(c["collection"]["name"] == collection for c in s.get("collections", {}).values())
                               and bool(s.get("entries", {}).get(catchup_id, {}).get("clip", {}).get("collectionIDs")), 90)
        check("T53", "Media clip added to a collection on the Mac → iPhone", ok, f"{secs}s")
        mac_state(op="deleteCollection", name=collection)

        # 54. Pinning the Mac's image on the iPhone reaches the Mac.
        r = ios_step("pin", any_title, match=any_title)
        ok, secs, _ = mac_wait("phone pin", lambda s: any(m.get("id") == catchup_id and m.get("pinned")
                                                          for m in s.get("media", [])), 90, prefix=tag)
        check("T54", "iPhone pin of a Mac image → Mac", r.get("ok") and ok, f"{secs}s step={r.get('ok')}")

        # 55. Deleting it on the iPhone removes it from the Mac.
        r = ios_step("delete", any_title, match=any_title)
        ok, secs, _ = mac_wait("phone delete", lambda s: not any(m.get("id") == catchup_id for m in s.get("media", []))
                               and not any(m.get("id") == catchup_id for m in s.get("mediaMirror", [])), 90, prefix=tag)
        check("T55", "iPhone delete of a Mac image → gone from the Mac", r.get("ok") and ok, f"{secs}s step={r.get('ok')}")

    # 56. A clip the Mac's history limit hid comes back on the Mac when the iPhone copies it again.
    hide = f"PTEST-{tag}-hide.txt"
    ios_step("saveFile", f"{hide}|hide me {tag}", match=hide, timeout=30)
    mac_wait("hide arrives", lambda s: (mac_media(s, hide) or {}).get("hasFiles") is True, 120, prefix=tag)
    mac_state(op="pruneMedia", text=hide, prefix=tag)
    time.sleep(5)
    hidden = mac_media(mac_state(prefix=tag), hide) is None
    ios_step("saveFile", f"{hide}|hide me {tag}", match=hide, timeout=30)
    ok, secs, _ = mac_wait("shown again", lambda s: mac_media(s, hide) is not None, 120, prefix=tag)
    check("T56", "Hidden by the Mac's history limit, shown again after the iPhone copies it again", hidden and ok,
          f"hidden={hidden}, back after {secs}s={ok}")
    ios_step("delete", hide, match=hide)

    # 57. "Sync pinned items only" with an image on the Mac: it stays until pinned, then goes up with its file.
    mac_state(op="privacy", text="pinned:on")
    pin_from = mac_now() - 1
    ios_open()
    mac_copy_image(f"PINONLY {tag}")
    time.sleep(15)
    # Kept for sync but on this Mac only until pinned; nothing on the iPhone.
    held = mac_media(mac_state(prefix=tag), "pinonly", tag, mirror=True) or {}
    early = (bool(held) and not held.get("localOnly")) or ios_media(ios_state(), "pinonly", tag) is not None
    mac_state(op="pinNewest")
    clip, data, secs = ios_wait_media(90, "pinonly", tag)
    mac_state(op="privacy", text="pinned:off")
    check("T57", "Pinned-only on the Mac: an image goes up once it is pinned (with its file)",
          not early and clip is not None and bool(data), f"before pin in iCloud={early}, after pin on iPhone={bool(data)} {secs}s")
    mac_state(op="deleteMedia", text=f"PINONLY {tag}", prefix=tag)
    mac_state(op="deleteUnsyncedMedia", text=f"{pin_from},{mac_now() + 1}")

    # 58. "Sync pinned items only" on the iPhone: an unpinned save stays there; pinning it sends it.
    t58 = f"{prefix} T58 pinned-only on iPhone"
    mac_state(op="privacy", text="pinned:on")
    ios_open()
    ios_wait(lambda s: s.get("sharedSettings", {}).get("pinnedOnly") is True, 90)
    r1 = ios_step("save", t58)
    time.sleep(15)
    entry = ios_entry_for(t58)
    kept = bool(entry and entry.get("isLocalOnly")) and mac_item(mac_state(), t58) is None
    r2 = ios_step("pin", t58)
    ok, secs, _ = mac_wait("T58 on Mac", lambda s: mac_item(s, t58) is not None, 90)
    mac_state(op="privacy", text="pinned:off")
    check("T58", "Pinned-only on the iPhone: unpinned save stays, pinning it sends it to the Mac",
          r1.get("ok") and r2.get("ok") and kept and ok, f"kept before pin={kept}, on Mac after pin={ok} {secs}s")
    ios_step("delete", t58)
    mac_state(op="delete", text=t58)

    # 59. A shared setting changed on the iPhone reaches the Mac, and back.
    r = ios_step("shared", "maxItemBytes=25000000")
    ok1, secs1, _ = mac_wait("limit on Mac", lambda s: s.get("defaults", {}).get("maxItemBytes") == 25_000_000, 90)
    mac_state(op="mediaLimit", text="10000000")
    ios_open()
    ok2, secs2, _ = ios_wait(lambda s: (s.get("sharedSettings", {}).get("media") or {}).get("maxItemBytes") == 10_000_000, 90)
    check("T59", "Largest Item changed on the iPhone → Mac settings, and back from the Mac", r.get("ok") and ok1 and ok2,
          f"iPhone→Mac {ok1} {secs1}s, Mac→iPhone {ok2} {secs2}s")

    # 60. Two devices change different shared switches at the same moment: they end up agreeing, and both
    #     changes stay (each setting has its own change time since the 4th run).
    worker = threading.Thread(target=lambda: ios_step("shared", "codes=1"))
    worker.start()
    time.sleep(16)  # the runner starts (~10 s), the app waits 4 s before changing the setting
    mac_state(op="privacy", text="cards:on")
    worker.join()
    ios_open()
    # A save that met the other device's change is merged and sent again; CKSyncEngine may wait ~30 s before that.
    start = time.time()
    while True:
        mac_shared = mac_state().get("shared", {})
        phone_shared = ios_state().get("sharedSettings", {})
        agree = (mac_shared.get("codes"), mac_shared.get("cards")) == (
            phone_shared.get("skipOneTimeCodes"), phone_shared.get("skipCardNumbers"))
        if (agree and mac_shared.get("codes") and mac_shared.get("cards")) or time.time() - start > 120:
            break
        time.sleep(5)
    agreed_after = round(time.time() - start)
    both = mac_shared.get("codes") is True and mac_shared.get("cards") is True
    check("T60", "Shared switches changed on both devices at once: devices agree", agree,
          f"{agreed_after}s, Mac codes={mac_shared.get('codes')} cards={mac_shared.get('cards')}, iPhone codes="
          f"{phone_shared.get('skipOneTimeCodes')} cards={phone_shared.get('skipCardNumbers')}")
    check("T60b", "…and both changes are kept (each setting merges with its own time)", both,
          f"codes={mac_shared.get('codes')} cards={mac_shared.get('cards')}")
    mac_state(op="privacy", text="otp:off")
    mac_state(op="privacy", text="cards:off")

    # 61. A burst of 15 Mac copies (one a second) all reach the iPhone in the order they were copied.
    burst = [f"{prefix} burst {i:02d}" for i in range(15)]
    ios_open()
    for text in burst:
        mac_copy(text)
        time.sleep(1.0)
    ok, secs, state = ios_wait(lambda s: all(any(e["clip"]["text"] == t for e in s.get("entries", {}).values())
                                             for t in burst), 120)
    times = [next((e["clip"]["lastCopiedAt"] for e in state.get("entries", {}).values() if e["clip"]["text"] == t), 0)
             for t in burst]
    in_order = times == sorted(times) and len(set(times)) == len(times)
    check("T61", "15 quick Mac copies all reach the iPhone, in copy order", ok and in_order,
          f"{secs}s, all there={ok}, in order={in_order}")

    # 62. Copying an older one again on the Mac makes it the newest on the iPhone.
    mac_copy(burst[3])
    ok, secs, _ = ios_wait(lambda s: (lambda m: m.get(burst[3], 0) > m.get(burst[14], 0))(
        {e["clip"]["text"]: e["clip"]["lastCopiedAt"] for e in s.get("entries", {}).values()}), 90)
    check("T62", "Mac copies an older clip again → newest on the iPhone", ok, f"{secs}s")

    # 63. Saving a Mac clip again on the iPhone makes it the newest on the Mac.
    r = ios_step("save", burst[5])
    ok, secs, _ = mac_wait("T63 order", lambda s: (lambda m: m.get(burst[5], 0) > m.get(burst[3], 0))(
        {i["text"]: i.get("lastCopiedAt", 0) for i in s["history"]}), 90)
    check("T63", "iPhone saves a Mac clip again → newest in Mac history", r.get("ok") and ok, f"{secs}s")

    # 64. Delete on the Mac, then copy the same text again right away: it is back on both devices.
    mac_state(op="delete", text=burst[7])
    time.sleep(1)
    mac_copy(burst[7])
    ios_open()
    time.sleep(45)
    on_mac = mac_item(mac_state(), burst[7]) is not None
    on_phone = ios_entry_for(burst[7]) is not None
    check("T64", "Mac delete then immediate re-copy: the clip is on both devices", on_mac and on_phone,
          f"Mac {on_mac}, iPhone {on_phone}")

    # 65. iPhone deletes a clip while the Mac copies it again: both devices end up the same.
    worker = threading.Thread(target=lambda: ios_step("delete", burst[9]))
    worker.start()
    time.sleep(12)
    mac_copy(burst[9])
    worker.join()
    ios_open()
    time.sleep(45)
    on_mac = mac_item(mac_state(), burst[9]) is not None
    on_phone = ios_entry_for(burst[9]) is not None
    check("T65", "iPhone delete racing a Mac re-copy: devices agree", on_mac == on_phone,
          f"Mac {on_mac}, iPhone {on_phone}")

    # 66. A title on the iPhone and a pin on the Mac for the same clip, both in flight at once (the Mac pins as the
    #     iPhone saves the title, before either has the other's change): both changes stay. Pinning while the
    #     iPhone's menu opens would only close the menu (the row moves to Pinned), so the pin waits for the save.
    t66_title = f"{prefix} T66 title"
    t66_step = ios_step("title", burst[11], action=t66_title)
    mac_state(op="pin", text=burst[11])
    ios_open()
    time.sleep(45)
    phone = ios_entry_for(burst[11]) or {}
    mac = find(mac_state()["mirror"], burst[11]) or {}
    both = (phone.get("clip", {}).get("pinned") is True and phone.get("clip", {}).get("title") == t66_title
            and mac.get("pinned") is True and mac.get("title") == t66_title)
    check("T66", "Mac pin and iPhone title on the same clip at once: both kept on both devices", both,
          f"iPhone pinned={phone.get('clip', {}).get('pinned')} title={phone.get('clip', {}).get('title')!r}, "
          f"Mac pinned={mac.get('pinned')} title={mac.get('title')!r}, step={t66_step}")
    for text in burst:
        mac_state(op="delete", text=text)

    # 67. When nothing happens, nothing is sent: catches save loops like the app-icon one found in the 2nd run.
    ios_open()
    time.sleep(20)
    quiet_from = time.time()
    time.sleep(150)
    sends = [c for c in (sent_counts(l) for l in mac_sync_log(quiet_from)) if c and (c[0] or c[1])]
    check("T67", "Idle for 2.5 minutes: the Mac sends nothing", not sends, f"send batches while idle: {sends[:5]}")

    # 68. Both mirrors agree on every clip in iCloud: IDs, pins, titles, collections and copy times.
    ios_open()
    time.sleep(15)
    mac_full = {c["id"]: c for c in mac_state(op="fullDump", prefix="").get("full", [])}
    phone_full = {}
    for key, entry in ios_state().get("entries", {}).items():
        if entry.get("isLocalOnly"):
            continue
        clip = entry["clip"]
        title = clip.get("title")
        phone_full[clip["id"]] = {
            "pinned": clip.get("pinned", False), "lastCopiedAt": clip.get("lastCopiedAt", 0),
            "title": hashlib.sha256(title.encode()).hexdigest()[:12] if title else None,
            "collections": sorted(clip.get("collectionIDs", [])),
        }
    only_mac = sorted(set(mac_full) - set(phone_full))
    only_phone = sorted(set(phone_full) - set(mac_full))
    differ = []
    for key in set(mac_full) & set(phone_full):
        m, p = mac_full[key], phone_full[key]
        fields = [f for f in ("pinned", "title", "collections") if m.get(f) != p.get(f)]
        if abs(m.get("lastCopiedAt", 0) - p.get("lastCopiedAt", 0)) > 1:
            fields.append("lastCopiedAt")
        if fields:
            differ.append((key[:14], fields))
    check("T68", "Mac and iPhone hold the same clips with the same pins, titles, collections and times",
          not only_mac and not only_phone and not differ,
          f"{len(mac_full)} vs {len(phone_full)}; only Mac {[k[:14] for k in only_mac[:3]]}, "
          f"only iPhone {[k[:14] for k in only_phone[:3]]}, differ {differ[:3]}")

    # 69. Over the whole run: no save errors, and failed sends only from the first launch.
    lines = mac_sync_log(run_started)
    errors = [l for l in lines if "Cannot save" in l or "Cannot delete" in l]
    failed = [l for l in lines if (sent_counts(l) or (0, 0))[1]]
    check("T69", "Whole run: no save errors on the Mac", not errors, f"{len(errors)} errors {[e[-80:] for e in errors[:2]]}")
    check("T69b", "Whole run: failed sends only around the first launch", len(failed) <= 2,
          f"{len(failed)} batches with failed saves", soft=True)


# MARK: - Reporting

def check(test_id, title, ok, detail="", soft=False):
    status = "PASS" if ok else ("WARN" if soft else "FAIL")
    results.append((test_id, title, status, detail))
    log(f"{status} {test_id} {title} {detail}")
    return ok


def write_report(run):
    lines = [f"# Pastronaut sync E2E — run {run}", "",
             "| # | Test | Result | Detail |", "|---|---|---|---|"]
    for test_id, title, status, detail in results:
        lines.append(f"| {test_id} | {title} | {status} | {str(detail).replace('|', '/')[:300]} |")
    path = args.report or os.path.join(work, "report.md")
    with open(path, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    log(f"Report: {path}")


# MARK: - Scenario

def main():
    global args
    parser = argparse.ArgumentParser()
    parser.add_argument("--mac-app", required=True)
    parser.add_argument("--xctestrun", required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--report")
    parser.add_argument("--skip-keyboard", action="store_true")
    args = parser.parse_args()

    run = time.strftime("%H%M%S")
    run_started = time.time()
    prefix = f"PTEST-{run}"
    a = f"{prefix} A from Mac"
    b = f"{prefix} B from iPhone"
    c = f"{prefix} C while iPhone app is in background"
    d_match = f"{prefix} D"
    d = f"{d_match} Türkçe çğıöşü İŞ 🚀\nikinci satır\ttab"
    e = f"{prefix} E concealed secret"
    f_match = f"{prefix} F"
    f = f"{f_match} large " + "x" * 110_000
    g = f"{prefix} G saved on iPhone while Mac app was closed"
    k = f"{prefix} K fetched by the keyboard itself"
    y = f"{prefix} Y saved by the keyboard directly"
    log(f"Run {run}, scratch files in {work}")

    # 0. Both apps up, sync on.
    ios_install()
    state = mac_launch()
    mac_state(op="purge", prefix="PTEST-")
    if not check("T00", "Mac sync enabled and running", state["enabled"] and state["running"], state["lastError"] or ""):
        return
    launch = ios_step("launch")
    check("T00b", "iPhone app launches", launch.get("ok"), launch)

    # 1. Fresh install pulls the existing cloud history.
    every = mac_state(prefix="")
    mac_texts = sorted(unicodedata.normalize("NFC", item["text"]) for item in every["mirror"])
    # Compared through the iPhone's sync mirror: a long list doesn't put every row on screen for the UI test.
    # The app stays open meanwhile, so a copy made on the Mac during the wait still arrives.
    ios_open()
    start = time.time()
    ios_texts = []
    while time.time() - start < 90:
        ios_texts = sorted(summary(clip["text"]) for clip in ios_mirror())
        if ios_texts == mac_texts:
            break
        time.sleep(3)
    missing = sorted(set(mac_texts) - set(ios_texts))[:3]
    check("T01", "Fresh iPhone install has the Mac's synced clips", ios_texts == mac_texts,
          f"Mac {len(mac_texts)}, iPhone {len(ios_texts)}, {round(time.time() - start)}s, missing {missing}")

    # 2. Mac copy shows up on the open iPhone app by push.
    r = ios_step("waitVisible", a, timeout=120, on_ready=lambda: (time.sleep(2), mac_copy(a)))
    check("T02", "Mac copy → iPhone (app open, push)", r.get("ok"), f"{r.get('seconds')}s")

    # 3. iPhone save reaches the Mac.
    r = ios_step("save", b)
    check("T03a", "iPhone save (app save path; Paste button itself is manual)", r.get("ok"), r.get("reason", ""))
    ok, secs, state = mac_wait("B", lambda s: mac_item(s, b) is not None, 120)
    mirror = find(state["mirror"], b) if state else None
    have_b = check("T03", "iPhone save → Mac", ok, f"{secs}s, device={mirror and mirror.get('device')}")

    # 4–5. iPhone pin/unpin reach the Mac. Meaningless unless the Mac has B.
    if not have_b:
        for test_id, title in (("T04", "iPhone pin → Mac"), ("T05", "iPhone unpin → Mac"), ("T11", "iPhone delete → Mac")):
            check(test_id, title, False, "not run: Mac never got B (T03)")
    r = ios_step("pin", b) if have_b else {}
    if have_b:
        ok, secs, _ = mac_wait("B pinned", lambda s: (mac_item(s, b) or {}).get("pinned") is True, 120)
        check("T04", "iPhone pin → Mac", r.get("ok") and ok, f"{secs}s")
        r = ios_step("unpin", b)
        ok, secs, _ = mac_wait("B unpinned", lambda s: (mac_item(s, b) or {}).get("pinned") is False, 120)
        check("T05", "iPhone unpin → Mac", r.get("ok") and ok, f"{secs}s")

    # 6–7. Mac pin/unpin reach the open iPhone app.
    r = ios_step("waitPinned", a, timeout=120, on_ready=lambda: (time.sleep(2), mac_state(op="pin", text=a)))
    check("T06", "Mac pin → iPhone (app open)", r.get("ok"), f"{r.get('seconds')}s")
    r = ios_step("waitUnpinned", a, timeout=120, on_ready=lambda: (time.sleep(2), mac_state(op="unpin", text=a)))
    check("T07", "Mac unpin → iPhone (app open)", r.get("ok"), f"{r.get('seconds')}s")

    # 8. Unicode and multi-line text survive the round trip byte for byte.
    r = ios_step("waitVisible", d, match=d_match, timeout=120, on_ready=lambda: (time.sleep(2), mac_copy(d)))
    remote = find(ios_mirror(), d_match)
    check("T08", "Unicode / multi-line text is identical on iPhone", r.get("ok") and remote and remote["text"] == d,
          f"{r.get('seconds')}s")

    # 9. Concealed (password manager) copies never sync.
    mac_copy(e, concealed=True)
    time.sleep(8)
    state = mac_state()
    in_mac = mac_item(state, e) is not None or find(state["mirror"], e) is not None
    time.sleep(10)
    check("T09", "Concealed copy is ignored (not in Mac history, not on iPhone)",
          not in_mac and find(ios_mirror(), e) is None)

    # 10. Texts over the 100 KB limit stay on the Mac.
    mac_copy(f)
    ok, _, state = mac_wait("F", lambda s: mac_item(s, f_match) is not None, 20)
    time.sleep(15)
    check("T10", "Over-limit text stays on Mac only",
          ok and find(state["mirror"], f_match) is None and find(ios_mirror(), f_match) is None,
          f"in Mac history: {ok}")

    # 11. iPhone delete reaches the Mac (only meaningful if the Mac has B).
    if have_b and mac_item(mac_state(), b) is not None:
        r = ios_step("delete", b)
        ok, secs, _ = mac_wait("B gone", lambda s: mac_item(s, b) is None, 120)
        check("T11", "iPhone delete → Mac", r.get("ok") and ok, f"{secs}s")
    elif have_b:
        check("T11", "iPhone delete → Mac", False, "not run: B vanished from the Mac before the delete")

    # 12. Mac delete reaches the open iPhone app.
    r = ios_step("waitGone", d, match=d_match, timeout=120,
                 on_ready=lambda: (time.sleep(2), mac_state(op="delete", text=d)))
    check("T12", "Mac delete → iPhone (app open)", r.get("ok"), f"{r.get('seconds')}s")

    # 13. With the app in the background, a silent push refreshes the keyboard snapshot.
    r = ios_step("background")
    mac_copy(c)
    time.sleep(3)
    mac_state(op="pin", text=c)
    start, clip = time.time(), None
    while time.time() - start < 180:
        clip = find(ios_snapshot(), c)
        if clip and clip["pinned"]:
            break
        time.sleep(10)
    check("T13", "Background: silent push updates keyboard data without opening the app",
          bool(clip and clip["pinned"]), f"{round(time.time() - start)}s, found={bool(clip)}", soft=True)

    # 14. The keyboard shows that clip and types it (Safari address bar, app not opened).
    if not args.skip_keyboard:
        r = ios_step("keyboard", c, timeout=20)
        check("T14", "Keyboard lists the clip and types it", r.get("ok"),
              r.get("reason", "") + f" pinIcons={r.get('pinIcons')}", soft=True)
        if not r.get("ok"):
            log(f"keyboard: {json.dumps(r, ensure_ascii=False)[:1500]}")

    # 18. Faz 3: with Full Access the keyboard fetches by itself, even with the app not running.
    if not args.skip_keyboard:
        ios_terminate_app()
        mac_copy(k)
        time.sleep(5)
        in_snapshot = find(ios_snapshot(), k) is not None
        r = ios_step("keyboard", k, timeout=20)
        check("T18", "Keyboard fetches new Mac clips itself (app not running, Full Access)",
              r.get("ok") and not in_snapshot, f"app snapshot already had it: {in_snapshot}")
        if not r.get("ok"):
            log(f"keyboard: {json.dumps(r, ensure_ascii=False)[:1500]}")

    # 19. Faz 3: the keyboard's direct upload reaches the Mac.
    r = ios_step("keyboardSave", y)
    ok, secs, _ = mac_wait("Y", lambda s: mac_item(s, y) is not None, 60)
    check("T19", "Keyboard's direct upload reaches the Mac", ok, f"{secs}s")

    # 20. Copying a pinned text again on the iPhone keeps it pinned (direct and app paths).
    if ok:
        mac_state(op="pin", text=y)
        time.sleep(8)
        ios_step("keyboardSave", y)
        ios_step("save", y)
        time.sleep(15)
        state = mac_state()
        remote = find(ios_mirror(), y)
        check("T20", "Copying a pinned text again keeps the pin",
              (mac_item(state, y) or {}).get("pinned") is True and bool(remote and remote["pinned"]),
              f"Mac {mac_item(state, y)}, iPhone pinned={remote and remote['pinned']}")

    # 22–23. Faz 4: pin changes and deletions made in the keyboard reach the Mac without the app.
    if not args.skip_keyboard and ok:
        r = ios_step("keyboardAction", y, action="pin")
        ok22, secs, _ = mac_wait("Y unpinned", lambda s: (mac_item(s, y) or {}).get("pinned") is False, 60)
        check("T22", "Keyboard unpin → Mac", r.get("ok") and ok22, f"{secs}s {r.get('cloudStatus', r.get('reason', ''))}")
        r = ios_step("keyboardAction", y, action="delete")
        ok23, secs, _ = mac_wait("Y gone", lambda s: mac_item(s, y) is None, 60)
        check("T23", "Keyboard delete → Mac", r.get("ok") and ok23, f"{secs}s {r.get('cloudStatus', r.get('reason', ''))}")

    # 24. Privacy: with "Don't sync one-time codes" on, a code stays on the Mac. The iPhone app is kept in the
    # foreground (it refreshes every minute and gets pushes) so "not there" really means not synced.
    code = run[-6:]  # six digits, unique per run
    mac_state(op="privacy", text="otp:on")
    marker = f"{prefix} marker after the number"  # no code word: the switch must not catch it
    r = ios_step("waitVisible", marker, timeout=90,
                 on_ready=lambda: (time.sleep(2), mac_copy(code), time.sleep(3), mac_copy(marker)))
    ok_mac = any(item["text"] == code for item in mac_state(prefix=code)["history"])
    leaked = any(clip["text"] == code for clip in ios_mirror())
    mac_state(op="privacy", text="otp:off")
    for text in (code, marker):
        mac_state(op="delete", text=text)
    check("T24", "One-time code stays on the Mac (privacy switch on)",
          r.get("ok") and ok_mac and not leaked,
          f"later copy reached iPhone: {r.get('ok')}, code in Mac history: {ok_mac}, code on iPhone: {leaked}")

    # 25. Privacy: with "Sync pinned items only" on, only pinned copies reach the iPhone.
    p = f"{prefix} P pinned-only"
    q = f"{prefix} Q pinned marker"
    mac_state(op="privacy", text="pinned:on")
    r1 = ios_step("waitVisible", q, timeout=90,
                  on_ready=lambda: (time.sleep(2), mac_copy(p), time.sleep(3), mac_copy(q),
                                    time.sleep(2), mac_state(op="pin", text=q)))
    early = find(ios_mirror(), p) is not None
    r2 = ios_step("waitVisible", p, timeout=90, on_ready=lambda: (time.sleep(2), mac_state(op="pin", text=p)))
    mac_state(op="privacy", text="pinned:off")
    for text in (p, q):
        mac_state(op="delete", text=text)
    check("T25", "Pinned-only: unpinned copy stays, pinned copy syncs",
          r1.get("ok") and not early and r2.get("ok"),
          f"pinned marker reached: {r1.get('ok')}, unpinned on iPhone: {early}, after pin: {r2.get('ok')} {r2.get('seconds')}s")

    # 26. "+" makes a clip on the iPhone without copying anything; the Mac gets it.
    n = f"{prefix} N typed on iPhone"
    r = ios_step("newClip", n)
    ok, secs, _ = mac_wait("new clip", lambda s: mac_item(s, n) is not None, 60)
    check("T26", "New clip typed on iPhone → Mac", r.get("ok") and ok, f"{secs}s")

    # 27. Select mode deletes two clips at once; both leave the Mac.
    s1, s2 = f"{prefix} S1 bulk", f"{prefix} S2 bulk"
    mac_copy(s1)
    time.sleep(2)
    mac_copy(s2)
    r = ios_step("bulkDelete", f"{s1}|{s2}", timeout=60)
    ok, secs, _ = mac_wait("bulk delete", lambda s: mac_item(s, s1) is None and mac_item(s, s2) is None, 60)
    check("T27", "Select mode: two clips deleted on iPhone → gone on Mac", r.get("ok") and ok, f"{secs}s {r}")

    # 28. "Save Clipboard on Opening": the app saves the iPhone's clipboard when it opens. The test runner's
    # copy is local only, so the only way to the Mac is this save.
    auto = f"{prefix} V saved when the app opened"
    ios_terminate_app()
    r = ios_step("autoSave", auto, timeout=20)
    ok, secs, _ = mac_wait("auto-save", lambda s: mac_item(s, auto) is not None, 60)
    check("T28", "Clipboard saved on opening → Mac", r.get("ok") and ok, f"{secs}s {r}")

    # 29. ...but a one-time code on the clipboard is left out.
    otp = f"Doğrulama kodunuz: {run}"
    ios_terminate_app()
    r = ios_step("autoSave", otp, timeout=8)
    time.sleep(3)
    on_iphone = find(ios_mirror(), otp) is not None
    on_mac = mac_item(mac_state(prefix="Doğrulama"), otp) is not None
    check("T29", "Opening skips a one-time code on the clipboard",
          not r.get("visible") and not on_iphone and not on_mac,
          f"row {r.get('visible')}, iPhone {on_iphone}, Mac {on_mac}")

    # 30. Record names are private: keyed on both devices with the same key, and the original zone is gone.
    state = mac_state()
    _, _, ios_state = ios_collections()
    mac_fp, ios_fp = state.get("keyFingerprint"), ios_key_fingerprint()
    keyed = all(item.get("keyedName") for item in state["mirror"])
    check("T30", "Record names keyed with one shared key; original zone removed",
          state.get("hasKey") and mac_fp and mac_fp == ios_fp and keyed
          and state.get("oldZoneCleared") and ios_state.get("needsLegacyCleanup") is False,
          f"mac={mac_fp} iphone={ios_fp} keyed={keyed} macOldZoneCleared={state.get('oldZoneCleared')} "
          f"iphoneNeedsCleanup={ios_state.get('needsLegacyCleanup')}")

    # 31. A collection made on the Mac reaches the iPhone with its clip.
    col_mac = f"PTEST {run} Mac"
    m1 = f"{prefix} M1 in a Mac collection"
    mac_copy(m1)
    time.sleep(2)
    mac_state(op="collect", text=m1, name=col_mac)
    r = ios_step("openCollection", m1, action=col_mac, timeout=90)
    names, members, _ = ios_collections()
    check("T31", "Collection made on Mac → iPhone (chip and membership)",
          r.get("ok") and col_mac in names and col_mac in members.get(m1, []), f"{r} names={names}")

    # 32. A collection made on the iPhone reaches the Mac.
    col_ios = f"PTEST {run} iPhone"
    m2 = f"{prefix} M2 in an iPhone collection"
    mac_copy(m2)
    ios_step("waitVisible", m2, timeout=90)
    r = ios_step("collect", m2, action=col_ios, timeout=30)

    def mac_has_membership(s):
        clip = next((item for item in s["mirror"] if m2 in item["text"]), None)
        return col_ios in s.get("collections", []) and clip is not None and col_ios in clip.get("collections", [])
    ok, secs, s = mac_wait("iPhone collection", mac_has_membership, 90)
    kept = (mac_item(s, m2) or {}).get("kept") if s else None
    check("T32", "Collection made on iPhone → Mac, clip is kept there",
          r.get("ok") and ok and kept is True, f"{secs}s step={r} kept={kept}")

    # 33. Deleting a collection keeps its clips everywhere.
    mac_state(op="deleteCollection", name=col_mac)
    r = ios_step("waitVisible", m1, timeout=60)
    deadline = time.time() + 60
    while time.time() < deadline:
        names, members, _ = ios_collections()
        if col_mac not in names:
            break
        time.sleep(3)
    check("T33", "Deleted collection leaves its clips (iPhone keeps the clip, drops the collection)",
          r.get("ok") and col_mac not in names and m1 in members, f"names={names} clipThere={m1 in members}")
    mac_state(op="deleteCollection", name=col_ios)

    # 34. A title given on the iPhone reaches iCloud (1.2). Saving it also creates the title fields in the
    #     Development schema, which must exist before they can be deployed to Production.
    title = f"{prefix} title"
    r = ios_step("title", n, action=title)
    start = time.time()
    entry = None
    while time.time() - start < 60:
        state = ios_file("clip-sync.json") or {}
        entry = next((e for e in state.get("entries", {}).values() if n in e["clip"]["text"]), None)
        if entry and entry["clip"].get("title") == title and entry.get("systemFields") and not entry.get("hasUnsentCopy"):
            break
        time.sleep(3)
    status = ios_step("status")
    check("T34", "Title given on iPhone is saved to iCloud",
          r.get("ok") and entry is not None and entry["clip"].get("title") == title and not status.get("error"),
          f"step={r}, title={entry and entry['clip'].get('title')}, sent={bool(entry and entry.get('systemFields'))}, "
          f"error={status.get('error')!r}")

    # MARK: 1.3 — images, PDFs and files
    # Letters, not the run's digits: six digits in an image read as a one-time code, which the iPhone never saves
    # by itself.
    tag = "".join(chr(ord("B") + int(digit)) for digit in run)

    # 35. A screenshot copied on the Mac reaches the iPhone, files and text in it included.
    ios_open()
    mac_copy_image(f"MAC {tag}")
    ok_mac, secs_mac, state = mac_wait("Mac image", lambda s: mac_media(s, "mac", tag, mirror=True) is not None, 60,
                                       prefix=tag)
    clip, data, secs = ios_wait_media(150, "mac", tag)
    check("T35", "Mac image → iPhone (with its file and the text read from it)",
          ok_mac and clip is not None and clip["kind"] == "image" and bool(data),
          f"Mac {secs_mac}s, iPhone {secs}s, kind={clip and clip['kind']}, text={clip and clip['media'].get('recognizedText')!r}, "
          f"bytes={len(data) if data else 0}")

    # 36. PDF data copied on the Mac (as from Preview) arrives byte for byte, with its text read.
    pdf_text = f"PDF {tag} invoice"
    pdf = make_pdf(pdf_text, os.path.join(work, f"PTEST-{tag}.pdf"))
    mac_copy_pdf(os.path.join(work, f"PTEST-{tag}.pdf"))
    clip, data, secs = ios_wait_media(150, "pdf", tag)
    check("T36", "Mac PDF → iPhone (same bytes, text searchable)",
          clip is not None and clip["kind"] == "pdf" and data == pdf
          and pdf_text in (clip["media"].get("recognizedText") or ""),
          f"{secs}s, same bytes={data == pdf}, text={clip and clip['media'].get('recognizedText')!r}")

    # 37. A file copied in Finder (a file URL; the Mac reads it at once) arrives byte for byte, with its name.
    file_name = f"PTEST-{tag}-notes.txt"
    file_body = f"Notes for tag {tag}\nsecond line".encode()
    with open(os.path.join(work, file_name), "wb") as handle:
        handle.write(file_body)
    mac_copy_file(os.path.join(work, file_name))
    clip, data, secs = ios_wait_media(150, file_name)
    check("T37", "Finder file on the Mac → iPhone (same name and bytes)",
          clip is not None and data == file_body, f"{secs}s, kind={clip and clip['kind']}, same={data == file_body}")

    # 38. An image the iPhone saves from its clipboard reaches the Mac as an image it can paste.
    r = ios_step("autoSaveImage", f"PHONE {tag}", match=tag, timeout=40)
    ok, secs, state = mac_wait("iPhone image", lambda s: (mac_media(s, "phone", tag) or {}).get("hasFiles") is True,
                               150, prefix=tag)
    item = mac_media(state, "phone", tag) if state else None
    check("T38", "iPhone image → Mac history (as an image)",
          r.get("ok") and ok and (item or {}).get("kind") == "image" and (item or {}).get("device") == "iphone",
          f"{secs}s step={r.get('ok')} item={item}")

    # 39. A file the iPhone saves (as Share would) reaches the Mac with its name.
    phone_file = f"PTEST-{tag}-phone.txt"
    r = ios_step("saveFile", f"{phone_file}|hello from the iPhone {tag}", match=phone_file, timeout=40)
    ok, secs, state = mac_wait("iPhone file", lambda s: (mac_media(s, phone_file) or {}).get("hasFiles") is True,
                               150, prefix=tag)
    check("T39", "iPhone file → Mac history (as a file)", r.get("ok") and ok, f"{secs}s step={r}")

    # 40. Pinning a PDF on the Mac reaches the iPhone.
    ios_open()
    mac_state(op="pinMedia", text=pdf_text, prefix=tag)
    start = time.time()
    pinned = False
    while time.time() - start < 90 and not pinned:
        clip = find_media(ios_mirror(), "pdf", tag)
        pinned = bool(clip and clip["pinned"])
        if not pinned:
            time.sleep(4)
    check("T40", "Mac pin of a PDF → iPhone", pinned, f"{round(time.time() - start)}s")

    # 41. The Mac's history limit takes another device's clip out of the Mac only (decision 3).
    mac_state(op="pruneMedia", text=phone_file, prefix=tag)
    time.sleep(20)
    state = mac_state(prefix=tag)
    on_mac = mac_media(state, phone_file) is not None
    still_mirrored = mac_media(state, phone_file, mirror=True) is not None
    on_iphone = find_media(ios_mirror(), phone_file) is not None
    check("T41", "Mac history limit hides the iPhone's file on the Mac, keeps it in iCloud and on the iPhone",
          not on_mac and still_mirrored and on_iphone,
          f"in Mac history={on_mac}, in Mac mirror={still_mirrored}, on iPhone={on_iphone}")

    # 42. The privacy switches are shared: one changed on the Mac is on the iPhone too.
    def ios_shared():
        return (ios_file("clip-sync.json") or {}).get("sharedSettings", {})
    mac_state(op="privacy", text="cards:on")
    start, on = time.time(), False
    while time.time() - start < 90 and not on:
        on = ios_shared().get("skipCardNumbers") is True
        if not on:
            time.sleep(4)
    mac_state(op="privacy", text="cards:off")
    start, off = time.time(), False
    while time.time() - start < 90 and not off:
        off = ios_shared().get("skipCardNumbers") is False
        if not off:
            time.sleep(4)
    check("T42", "Shared privacy switch: Mac change reaches the iPhone (on, then off)", on and off,
          f"on={on} off={off} {round(time.time() - start)}s")

    # 43. Images & Files off (shared): a new image stays on the Mac and nothing reaches the iPhone.
    mac_state(op="mediaSync", text="off")
    start = time.time()
    while time.time() - start < 90 and (ios_shared().get("media") or {}).get("syncEnabled") is not False:
        time.sleep(4)
    synced_off = (ios_shared().get("media") or {}).get("syncEnabled") is False
    off_from = mac_now() - 1
    mac_copy_image(f"OFF {tag}")
    time.sleep(25)
    leaked = find_media(ios_mirror(), "off", tag) is not None
    in_mirror = mac_media(mac_state(prefix=tag), "off", tag, mirror=True) is not None
    mac_state(op="mediaSync", text="on")
    # It stays in this Mac's history only: take it out so no test image is left there.
    mac_state(op="deleteUnsyncedMedia", text=f"{off_from},{mac_now() + 1}")
    check("T43", "Images & Files off: a new image doesn't leave the Mac; the switch reached the iPhone",
          synced_off and not leaked and not in_mirror,
          f"iPhone sees off={synced_off}, sent={in_mirror}, on iPhone={leaked}")

    # 44. The Mac sends app icons; the iPhone keeps them for its cards.
    icons = (ios_file("clip-sync.json") or {}).get("appIcons", {})
    check("T44", "Mac app icons reached the iPhone", len(icons) > 0, f"{len(icons)} icons", soft=True)

    # Media cleanup: the Mac deletes what it has; the iPhone deletes its file the Mac only hid.
    for needle in (f"MAC {tag}", pdf_text, file_name, f"PHONE {tag}"):
        mac_state(op="deleteMedia", text=needle, prefix=tag)
    ios_step("delete", phone_file, match=phone_file)
    ios_open()
    start = time.time()
    while time.time() - start < 120:
        left = [media_text(c)[:40] for c in ios_mirror() if c.get("media") and tag in media_text(c)]
        left_mac = mac_state(prefix=tag).get("mediaMirror", [])
        if not left and not left_mac:
            break
        time.sleep(5)
    check("T45", "Media cleanup: deletes reach both devices",
          not left and not left_mac, f"iPhone {left} Mac {[i.get('files') for i in left_mac]}")

    try:
        extended_tests(run, prefix, tag, run_started)
    except Exception as error:  # noqa: BLE001 — a script error must not skip the cleanup below
        check("T4X", "Extended checks ran to the end", False, f"stopped: {error!r}")

    # 15. Changes made while the Mac app is closed arrive when it starts (70: an image too, with its file).
    mac_quit()
    r1 = ios_step("save", g)
    r2 = ios_step("pin", a)
    r3 = ios_step("autoSaveImage", f"CLOSED {tag}", match=f"CLOSED {tag}", timeout=40)
    mac_launch()
    ok, secs, _ = mac_wait("catch-up", lambda s: mac_item(s, g) is not None
                           and (mac_item(s, a) or {}).get("pinned") is True, 90)
    check("T15", "Mac catches up on launch (save + pin made while it was closed)",
          r1.get("ok") and r2.get("ok") and ok, f"{secs}s save={r1} pin={r2}")
    ok, secs, _ = mac_wait("closed image", lambda s: (mac_media(s, "closed", tag) or {}).get("hasFiles") is True,
                           120, prefix=tag)
    check("T70", "iPhone image saved while the Mac app was closed arrives (as an image, with its file) on launch",
          r3.get("ok") and ok, f"{secs}s step={r3.get('ok')}")
    mac_state(op="deleteMedia", text=f"CLOSED {tag}", prefix=tag)

    # 16. Clean up through the Mac; the iPhone must follow.
    for text in (a, c, g, f, k, y, n, auto, m1, m2):
        mac_state(op="delete", text=text)
    r = ios_step("waitGone", a, timeout=120)
    time.sleep(5)
    leftovers_ios = [clip["text"][:40] for clip in ios_mirror() if clip["text"].startswith(prefix)]
    state = mac_state()
    leftovers_mac = [item["text"][:40] for item in state["history"] if item["text"].startswith(prefix)]
    check("T16", "Cleanup: Mac deletes reach iPhone, nothing left over",
          r.get("ok") and not leftovers_ios and not leftovers_mac, f"iPhone {leftovers_ios} Mac {leftovers_mac}")

    # 17. Both sides agree and report no errors.
    every = mac_state(prefix="")
    time.sleep(5)
    status = ios_step("status")
    check("T21", "App runs in the device language (Turkish device shows Ayarlar)",
          "Ayarlar" in status.get("titles", []) or "Settings" in status.get("titles", []),
          f"navigation titles={status.get('titles')}")
    check("T17", "Final counts match, no sync errors",
          every["synced"] == len(ios_mirror()) and not every["lastError"] and not status.get("error"),
          f"Mac {every['synced']} iPhone {len(ios_mirror())} macError={every['lastError']} "
          f"iPhoneError={status.get('error')!r}")

    write_report(run)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # noqa: BLE001 — print and still write what ran
        log(f"ABORTED: {error}")
        write_report("aborted")
        sys.exit(2)
    sys.exit(0 if all(status != "FAIL" for _, _, status, _ in results) else 1)
