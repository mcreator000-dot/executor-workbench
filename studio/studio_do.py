"""Small Studio MCP helper with retries.

Usage:
  python -u studio_do.py state
  python -u studio_do.py stop
  python -u studio_do.py start [wait_s]
  python -u studio_do.py console [substr ...]
  python -u studio_do.py script <path> [Edit|Client|Server]

An empty discovery response may mean Studio is transitioning. Exit 3 means
Studio or the command outcome could not be confirmed. Exit 1 means a command
reported an error; exit 2 means invalid usage.
"""
import json
import sys
import time

from mc import Studio

UNCONFIRMED = 3


def list_studios(s):
    status, text = s.call("list_roblox_studios", {})
    if status != "OK":
        raise RuntimeError(text)
    studios = json.loads(text)["studios"]
    if not isinstance(studios, list) or any(
        not isinstance(entry, dict) or not entry.get("id") for entry in studios
    ):
        raise ValueError("unexpected Studio discovery response")
    return studios


def with_studio(fn, tries=12, delay=4.0):
    last = "discovery has not started"
    for i in range(tries):
        s = None
        try:
            s = Studio()
            if not s.wait_connected():
                raise RuntimeError("MCP tools unavailable")
            studios = list_studios(s)
        except Exception as e:
            last = str(e)
        else:
            if studios:
                # Do not retry a command that may already have taken effect.
                return run_and_close(s, fn, studios[0])
            last = "Studio list is temporarily empty"
        if s is not None:
            s.close()
        if i + 1 < tries:
            time.sleep(delay)
    print("Studio discovery unconfirmed:", last[:200], flush=True)
    return UNCONFIRMED


def run_and_close(s, fn, studio):
    try:
        return fn(s, studio)
    finally:
        s.close()


def cmd_state(s, d):
    print("id:", d["id"], flush=True)
    print("mode:", d["mode"], "placeId:", d.get("placeId"), flush=True)
    print(d["state"], flush=True)
    return 0


def in_edit(studio):
    return str(studio.get("mode", "")).casefold() == "edit"


def cmd_stop(s, d, tries=12, delay=4.0):
    studio_id = d["id"]
    if in_edit(d):
        print("stop: confirmed Edit mode (already stopped)", flush=True)
        return 0

    try:
        status, text = s.call("start_stop_play", {"is_start": False, "studio_id": studio_id})
    except Exception as e:
        status, text = "ERROR", str(e)

    if status == "ERR" and "timeout" not in text.casefold() and "timed out" not in text.casefold():
        print("stop: rejected:", text[:200], flush=True)
        return 1

    last = "no discovery response yet"
    for i in range(tries):
        try:
            target = next((entry for entry in list_studios(s) if entry["id"] == studio_id), None)
            if target is not None and in_edit(target):
                print(f"stop: confirmed Edit mode for {studio_id}", flush=True)
                return 0
            last = "target not listed" if target is None else f"mode={target.get('mode')!r}"
        except Exception as e:
            last = str(e)
        if i + 1 < tries:
            time.sleep(delay)

    print(f"stop: outcome unconfirmed for {studio_id} ({status}: {text[:120]}; {last[:120]})", flush=True)
    return UNCONFIRMED


def cmd_start(s, d, wait=20):
    st, tx = s.call("start_stop_play", {"is_start": True, "studio_id": d["id"]})
    print("start:", st, tx[:200], flush=True)
    time.sleep(float(wait))
    return 0 if st == "OK" else 1


def cmd_console(s, d, needles):
    st, tx = s.call("get_console_output", {"studio_id": d["id"]})
    lines = tx.splitlines()
    if needles:
        lines = [l for l in lines if any(n in l for n in needles)]
    print("console:", st, "lines:", len(lines), flush=True)
    for l in lines[-40:]:
        print("  ", l.rstrip(), flush=True)
    return 0 if st == "OK" else 1


def cmd_script(s, d, path, dm="Edit"):
    code = open(path, encoding="utf-8").read()
    st, tx = s.call("execute_luau", {"code": code, "datamodel_type": dm, "studio_id": d["id"]})
    print("[", st, "]", flush=True)
    print(tx[:2000], flush=True)
    return 0 if st == "OK" else 1


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "state":
        return with_studio(cmd_state)
    if cmd == "stop":
        return with_studio(cmd_stop)
    if cmd == "start":
        w = sys.argv[2] if len(sys.argv) > 2 else "20"
        return with_studio(lambda s, d: cmd_start(s, d, w))
    if cmd == "console":
        return with_studio(lambda s, d: cmd_console(s, d, sys.argv[2:]))
    if cmd == "script":
        dm = sys.argv[3] if len(sys.argv) > 3 else "Edit"
        return with_studio(lambda s, d: cmd_script(s, d, sys.argv[2], dm))
    print("unknown command", cmd)
    return 2


if __name__ == "__main__":
    sys.exit(main())
