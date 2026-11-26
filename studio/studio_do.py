"""Small Studio MCP helper with retries.

Usage:
  python -u studio_do.py state
  python -u studio_do.py stop
  python -u studio_do.py start [wait_s]
  python -u studio_do.py console [substr ...]
  python -u studio_do.py script <path> [Edit|Client|Server]

The MCP bridge returns an empty studio list for several seconds after a restart or a
play/stop transition, so every call retries instead of concluding Studio is gone.
"""
import sys, json, time

sys.path.insert(0, r'D:\RobloxRE\studio')
from mc import Studio


def with_studio(fn, tries=12, delay=4.0):
    last = None
    for i in range(tries):
        s = Studio()
        try:
            s.wait_connected()
            st, tx = s.call("list_roblox_studios", {})
            try:
                studios = json.loads(tx).get("studios", [])
            except Exception:
                studios = []
            if studios:
                return fn(s, studios[0])
            last = tx
        except Exception as e:
            last = repr(e)
        finally:
            s.close()
        time.sleep(delay)
    print("no studio after retries:", str(last)[:200], flush=True)
    return 1


def cmd_state(s, d):
    print("id:", d["id"], flush=True)
    print("mode:", d["mode"], "placeId:", d.get("placeId"), flush=True)
    print(d["state"], flush=True)
    return 0


def cmd_stop(s, d):
    st, tx = s.call("start_stop_play", {"is_start": False, "studio_id": d["id"]})
    print("stop:", st, tx[:200], flush=True)
    return 0 if st == "OK" else 1


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
    return 0


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
