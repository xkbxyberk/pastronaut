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
import json
import os
import subprocess
import sys
import tempfile
import threading
import time

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


_dump_counter = 0


def mac_state(prefix="PTEST", op="dump", text=None):
    """Sends a command and returns the state the Mac logs right after it."""
    global _dump_counter
    _dump_counter += 1
    tag = f"d{_dump_counter}"
    command = {"op": op, "prefix": prefix, "tag": tag}
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
    if result.get("reason") == "xcodebuild hung":
        log(f"  {op}: xcodebuild hung, trying once more")
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


def ios_snapshot():
    """Clips the keyboard sees."""
    return ios_file("clips.json")


def summary(text):
    """Same shortening as E2EControl.dump, so Mac and iPhone texts compare."""
    return text if len(text) <= 80 else f"{text[:80]}…({len(text)})"


def find(clips, match):
    return next((clip for clip in clips or [] if match in clip["text"]), None)


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
    mac_texts = sorted(item["text"] for item in every["mirror"])
    # Compared through the iPhone's sync mirror: a long list doesn't put every row on screen for the UI test.
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

    # 15. Changes made while the Mac app is closed arrive when it starts.
    mac_quit()
    r1 = ios_step("save", g)
    r2 = ios_step("pin", a)
    mac_launch()
    ok, secs, _ = mac_wait("catch-up", lambda s: mac_item(s, g) is not None
                           and (mac_item(s, a) or {}).get("pinned") is True, 90)
    check("T15", "Mac catches up on launch (save + pin made while it was closed)",
          r1.get("ok") and r2.get("ok") and ok, f"{secs}s")

    # 16. Clean up through the Mac; the iPhone must follow.
    for text in (a, c, g, f, k, y, n, auto):
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
