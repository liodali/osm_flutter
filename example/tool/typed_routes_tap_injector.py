#!/usr/bin/env python3
"""External touch injector for the typed-routes tap checks.

Apple maps take their touches from UIKit/AppKit, and `flutter test` cannot
deliver native touches to the map platform view on iOS/macOS, so tap events
are validated by a plain app (`lib/typed_routes_tap_probe.dart`) plus this
injector. It watches a run log for armed points and taps each one with AXe
(iOS simulator, coordinates in points) or `adb shell input` (Android,
coordinates in pixels: pass the device pixel ratio as --scale):

    PROBE armed: <phase> at (x, y)[ long-press]
    TYPED_ROUTES: taps armed: <phase> at (x, y)[ long-press]

    cd example
    flutter run -d <udid> -t lib/typed_routes_tap_probe.dart > /tmp/probe.log 2>&1 &
    python3 tool/typed_routes_tap_injector.py --udid <udid> --log /tmp/probe.log

    flutter run -d <serial> -t lib/typed_routes_tap_probe.dart > /tmp/probe.log 2>&1 &
    python3 tool/typed_routes_tap_injector.py --adb <serial> --scale 2.625 --log /tmp/probe.log

Exits when the log reports `PROBE done` or a finished `flutter test` run.
Requires https://github.com/cameroncooke/AXe (`brew install cameroncooke/tap/axe`)
for the simulator. On macOS the clicks are posted as CGEvents at the app
window's position (the window must be frontmost and unobstructed); the
posting process needs Accessibility trust.
"""
import argparse
import ctypes
import os
import re
import subprocess
import sys
import time

LINE = re.compile(
    r"(?:PROBE armed|TYPED_ROUTES: taps armed): ([\w()-]+) at "
    r"\(([\d.]+), ([\d.]+)\)( long-press)?"
)
END = ("PROBE done", "EXIT=")
SHOT = re.compile(r"PROBE screenshot: ([\w()\-]+)")
# The probe reports the Flutter view's center (view-local points) when a
# pass becomes ready; on macOS it locates the view inside the window.
CENTER = re.compile(r"center=Offset\(([\d.]+), ([\d.]+)\)")


def activate(process: str) -> None:
    subprocess.run(
        ["osascript", "-e", 'tell application "System Events" to set frontmost '
         f'of process "{process}" to true'],
        capture_output=True,
    )


def mac_window(process: str) -> tuple[int, int, int, int]:
    """Window position and size in screen points (top-left origin).

    System Events can lag the app's launch, so the lookup retries for a
    few seconds before it gives up.
    """
    script = (
        'tell application "System Events" to tell process '
        f'"{process}" to get {{position, size}} of window 1'
    )
    last = ""
    for _ in range(20):
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
        tokens = result.stdout.strip().split(", ")
        if not result.returncode and len(tokens) == 4 and all(t.lstrip("-").isdigit() for t in tokens):
            return tuple(int(v) for v in tokens)  # x, y, width, height
        last = result.stderr.strip() or result.stdout.strip()
        time.sleep(0.5)
    raise SystemExit(f"window of {process!r} not found (is the app running?): {last}")


def mac_point(args, x: float, y: float) -> tuple[int, int, int, int]:
    """Screen point of a view-local point, and the view's screen origin.

    The Flutter view sits below the title bar: its height is twice the
    reported center, so the title bar is the remainder of the window.
    """
    wx, wy, ww, wh = mac_window(args.macos)
    if not args.view_size:
        raise SystemExit("no `center=Offset(...)` seen in the log yet")
    vw, vh = args.view_size
    left, top = wx + (ww - vw) // 2, wy + (wh - vh)
    return round(left + x), round(top + y), left, top


def mac_click(x: int, y: int, hold_seconds: float) -> str:
    cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")

    class CGPoint(ctypes.Structure):
        _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

    cg.CGEventCreateMouseEvent.restype = ctypes.c_void_p
    cg.CGEventCreateMouseEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint32, CGPoint, ctypes.c_uint32]
    cg.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]
    moved, down, up, button, hid = 5, 1, 2, 0, 0
    point = CGPoint(x, y)
    for kind in (moved, down):
        cg.CGEventPost(hid, cg.CGEventCreateMouseEvent(None, kind, point, button))
        time.sleep(0.05)
    time.sleep(hold_seconds)
    cg.CGEventPost(hid, cg.CGEventCreateMouseEvent(None, up, point, button))
    return "CGEvent posted"


def tap(args, x: float, y: float, long_press: bool) -> str:
    if args.macos:
        # Bring the window forward right before each click so no other
        # window can receive it.
        activate(args.macos)
        started = time.time()
        sx, sy, _, _ = mac_point(args, x, y)
        hold = args.long_press_seconds if long_press else 0.05
        return f"screen ({sx}, {sy}) {mac_click(sx, sy, hold)} " \
               f"in {time.time() - started:.1f}s"
    if args.udid:
        command = [
            "axe", "touch", "-x", f"{x:.1f}", "-y", f"{y:.1f}",
            "--down", "--up",
            "--delay", str(args.long_press_seconds if long_press else 0.05),
            "--udid", args.udid,
        ]
    else:
        kind = "swipe" if long_press else "tap"
        command = [
            "adb", "-s", args.adb, "shell", "input", kind,
            f"{x:.0f}", f"{y:.0f}",
        ]
        if long_press:
            # A swipe that returns to its start point with a long duration is
            # a long press.
            command += [f"{x:.0f}", f"{y:.0f}", str(int(args.long_press_seconds * 1000))]
    started = time.time()
    result = subprocess.run(command, capture_output=True, text=True)
    note = (result.stderr or result.stdout).strip().splitlines()
    return (
        f"exit {result.returncode} in {time.time() - started:.1f}s"
        f"{': ' + note[-1][:120] if note and result.returncode else ''}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--udid", help="iOS simulator UDID (AXe, points)")
    target.add_argument("--adb", help="Android device serial (pixels)")
    target.add_argument("--macos", metavar="PROCESS",
                        help="macOS app process name (view points)")
    parser.add_argument("--log", required=True, help="run log to watch")
    parser.add_argument("--scale", type=float, default=1.0,
                        help="multiply points by this before tapping "
                             "(Android device pixel ratio)")
    parser.add_argument("--max-minutes", type=float, default=15)
    parser.add_argument("--long-press-seconds", type=float, default=1.2)
    parser.add_argument("--shots", default="/tmp/typed_routes_shots",
                        help="directory for the probe's screenshots")
    args = parser.parse_args()

    os.makedirs(args.shots, exist_ok=True)
    args.view_size = None
    if args.macos:
        activate(args.macos)
    deadline = time.time() + args.max_minutes * 60
    offset = 0
    while time.time() < deadline:
        try:
            with open(args.log, "rb") as log:
                log.seek(offset)
                chunk = log.read()
                offset = log.tell()
        except FileNotFoundError:
            time.sleep(0.3)
            continue
        for line in chunk.decode("utf-8", "replace").replace("\r", "\n").split("\n"):
            center = CENTER.search(line)
            if center:
                args.view_size = (round(2 * float(center.group(1))), round(2 * float(center.group(2))))
            if any(marker in line for marker in END):
                print(f"{time.strftime('%H:%M:%S')} run ended", flush=True)
                return 0
            shot = SHOT.search(line)
            if shot:
                path = f"{args.shots}/probe_{shot.group(1)}.png"
                if args.udid:
                    capture = ["xcrun", "simctl", "io", args.udid, "screenshot", path]
                elif args.macos:
                    activate(args.macos)  # keep other windows out of the capture
                    time.sleep(0.3)
                    _, _, left, top = mac_point(args, 0, 0)
                    vw, vh = args.view_size or (0, 0)
                    capture = ["screencapture", "-x", "-R", f"{left},{top},{vw},{vh}", path]
                else:
                    capture = ["bash", "-c",
                               f"adb -s {args.adb} exec-out screencap -p > {path}"]
                try:
                    result = subprocess.run(capture, capture_output=True, text=True)
                    print(f"{time.strftime('%H:%M:%S')} screenshot {path} -> exit {result.returncode}", flush=True)
                except SystemExit as error:
                    print(f"{time.strftime('%H:%M:%S')} screenshot skipped: {error}", flush=True)
                continue
            match = LINE.search(line)
            if not match:
                continue
            phase, x, y, long_press = match.groups()
            px, py = float(x) * args.scale, float(y) * args.scale
            print(
                f"{time.strftime('%H:%M:%S')} {phase}: tap ({px:.1f}, {py:.1f})"
                f"{' long-press' if long_press else ''} -> "
                f"{tap(args, px, py, bool(long_press))}",
                flush=True,
            )
        time.sleep(0.2)
    print("injector timed out", flush=True)
    return 1


if __name__ == "__main__":
    sys.exit(main())
