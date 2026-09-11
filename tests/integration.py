"""Real Notify/CloseNotification calls on the private bus created by run.sh."""
import json
import contextlib
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
if os.environ.get("EMILIA_TEST_SESSION") != "1":
    raise SystemExit("Run bash tests/run.sh to create an isolated D-Bus session first.")
ENV = dict(os.environ, QT_QPA_PLATFORM="xcb", QT_QUICK_BACKEND="software",
           QT_QPA_PLATFORMTHEME="basic", QT_NO_XDG_DESKTOP_PORTAL="1")
ENV.pop("WAYLAND_DISPLAY", None)
DEST = ["org.freedesktop.Notifications", "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications"]


def command(*args):
    return subprocess.check_output(args, env=ENV, text=True, stderr=subprocess.STDOUT).strip()


def notify(title, body="Body text", replacement=0, timeout=0, urgency=1, actions=(), resident=False, icon="", image=""):
    hints = ["urgency", "y", str(urgency), "resident", "b", str(resident).lower()]
    if image:
        hints += ["image-path", "s", image]
    output = command("busctl", "--user", "call", "--", *DEST, "Notify", "susssasa{sv}i",
        "Emilia test", str(replacement), icon, title, body, str(len(actions)), *actions,
        str(3 if image else 2), *hints, str(timeout))
    return int(output.split()[1])


def close(notification_id):
    command("busctl", "--user", "call", *DEST, "CloseNotification", "u", str(notification_id))


def ipc(method, *args):
    return command("qs", "ipc", "-p", str(ROOT / "test-shell.qml"), "call", "test", method, *args)


def state():
    value = ipc("state")
    return json.loads(value)


def until(predicate, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            result = state()
            if predicate(result):
                return result
        except (subprocess.CalledProcessError, ValueError):
            pass
        time.sleep(.04)
    raise AssertionError(f"Condition timed out; state={state()}")


def empty():
    until(lambda s: not s["ids"] and s["phase"] == "hidden")


def stop_process(process):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


with contextlib.ExitStack() as cleanup:
    temp = tempfile.mkdtemp(prefix="emilia-tests-")
    print("Test artifacts:", temp, flush=True)
    read_fd, write_fd = os.pipe()
    display = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0", "1280x800x24", "-nolisten", "tcp"],
        pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    cleanup.callback(stop_process, display)
    os.close(write_fd)
    with os.fdopen(read_fd) as pipe:
        ENV["DISPLAY"] = ":" + pipe.readline().strip()
    log_path = Path(temp) / "quickshell.log"
    signal_path = Path(temp) / "signals.jsonl"
    signal_log = cleanup.enter_context(signal_path.open("w"))
    monitor = subprocess.Popen(["busctl", "--user", "--json=short", "monitor", DEST[0]],
        env=ENV, stdout=signal_log, stderr=subprocess.DEVNULL)
    cleanup.callback(stop_process, monitor)

    def saw_signal(member, values):
        for line in signal_path.read_text().splitlines():
            message = json.loads(line)
            if message.get("member") == member and message.get("payload", {}).get("data") == values:
                return True
        return False

    with log_path.open("w") as log:
        process = subprocess.Popen(["qs", "-p", str(ROOT / "test-shell.qml"), "--no-color"],
            env=ENV, stdout=log, stderr=subprocess.STDOUT)
        cleanup.callback(stop_process, process)
        try:
            until(lambda s: s["phase"] == "hidden")
            first = notify("Current")
            until(lambda s: s["phase"] == "visible")
            s = state()
            assert s["compositionX"] == s["shownOffsetX"]
            assert s["compositionY"] == s["topMargin"]
            assert s["cardX"] < s["emiliaX"]
            queued = [notify(f"Queued {i}") for i in range(5)]
            assert state()["ids"] == [first, *queued]
            assert notify("Updated", replacement=first) == first
            assert state()["summary"] == "Updated"
            assert state()["phase"] == "visible"
            assert notify("Queued replacement", replacement=queued[0]) == queued[0]
            close(queued[2])
            assert queued[2] not in state()["ids"]
            close(first)
            until(lambda s: s["phase"] == "visible" and s["summary"] == "Queued replacement")
            for ident in queued:
                close(ident)
            empty()
            print("PASS queue, current/queued replacement, queued close, close during animation")

            ident = notify("Countdown before update", timeout=1500)
            until(lambda s: s["phase"] == "visible")
            time.sleep(.8)
            notify("Countdown reset by update", replacement=ident, timeout=1500)
            time.sleep(.9)
            assert state()["ids"] == [ident]
            empty()
            assert saw_signal("NotificationClosed", [ident, 1])
            print("PASS replacement refreshes lifetime and expiry sends the protocol reason")

            ident = notify("Hover", timeout=1500)
            until(lambda s: s["phase"] == "visible")
            assert ipc("hover", "true") == "true"
            until(lambda s: s["hovered"])
            time.sleep(1.8)
            assert state()["ids"] == [ident]
            ipc("hover", "false")
            until(lambda s: not s["hovered"])
            empty()
            print("PASS actual pointer hover pauses and resumes expiry")

            ident = notify("Expiry boundary", timeout=1500)
            until(lambda s: s["phase"] == "visible")
            ipc("hover", "true")
            until(lambda s: s["hovered"])
            ipc("exhaustPausedTimeout")
            ipc("hover", "false")
            empty()
            print("PASS exhausted hover countdown expires instead of becoming persistent")

            for label, urgency, delay in [("Low", 0, 5.1), ("Normal", 1, 5.9)]:
                notify(label, timeout=-1, urgency=urgency)
                time.sleep(delay)
                empty()
            ident = notify("Critical", timeout=-1, urgency=2)
            time.sleep(6)
            assert state()["ids"] == [ident]
            close(ident)
            empty()
            print("PASS low/normal default expiry and longer critical lifetime")

            actions = ("default", "Open", "one", "First action", "two", "Second action", "three", "Third action")
            ident = notify("Actions", actions=actions, resident=True)
            until(lambda s: s["phase"] == "visible")
            assert state()["actions"] == 3
            ipc("scrollActions")
            ipc("click", "actionButton2")
            assert state()["ids"] == [ident]
            assert saw_signal("ActionInvoked", [ident, "three"])
            ipc("click", "closeButton")
            empty()
            assert saw_signal("NotificationClosed", [ident, 2])
            ident = notify("Default", actions=("default", "Open"))
            until(lambda s: s["phase"] == "visible")
            ipc("click", "notificationCard")
            empty()
            assert saw_signal("ActionInvoked", [ident, "default"])
            print("PASS close/default clicks, all actions reachable, resident action stays open")

            ident = notify("File icon", icon=(ROOT / "assets/emilia.png").as_uri())
            until(lambda s: s["phase"] == "visible" and s["iconVisible"])
            close(ident)
            empty()
            print("PASS file-URL application icon")

            ident = notify("Long title " * 10, "Long body " * 100, actions=actions,
                icon="missing-emilia-test-icon", image=(ROOT / "assets/emilia.png").as_uri())
            s = until(lambda s: s["phase"] == "visible" and s["imageVisible"])
            assert not s["iconVisible"]
            assert s["cardWidth"] == 300
            assert s["cardHeight"] <= 100 and s["bodyHeight"] > 0
            assert s["closeBottom"] <= s["cardHeight"]
            assert s["actionsBottom"] <= s["cardHeight"]
            assert s["maskWidth"] == s["cardWidth"]
            ipc("capture", str(Path(temp) / "composition.png"))
            time.sleep(.3)
            assert (Path(temp) / "composition.png").is_file()
            close(ident)
            empty()
            print("PASS long layout, image, missing icon collapse, card-only input mask")

            ident = notify("Reload")
            notify("Queued before reload")
            ipc("reload")
            time.sleep(1)
            empty()
            ident = notify("After reload")
            until(lambda s: s["phase"] == "visible")
            close(ident)
            empty()
            print("PASS reload clears stale notifications and accepts new traffic")
        finally:
            stop_process(process)
            print(log_path.read_text())
    errors = [line for line in log_path.read_text().splitlines()
              if any(word in line for word in ("WARN", "ERROR", "CRITICAL"))]
    assert not errors, errors
print("PASS clean runtime log")
