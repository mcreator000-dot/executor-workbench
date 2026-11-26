import json, subprocess, sys, time

LAUNCH = ["cmd.exe", "/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]

class Studio:
    def __init__(self):
        self.p = subprocess.Popen(LAUNCH, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)
        self.id = 0
        self.raw("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                "clientInfo": {"name": "dsh", "version": "0.1"}})
        self.p.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}) + "\n")
        self.p.stdin.flush()

    def raw(self, method, params=None, timeout=120):
        self.id += 1
        msg = {"jsonrpc": "2.0", "id": self.id, "method": method}
        if params is not None:
            msg["params"] = params
        self.p.stdin.write(json.dumps(msg) + "\n"); self.p.stdin.flush()
        end = time.time() + timeout
        while time.time() < end:
            line = self.p.stdout.readline()
            if not line:
                return None
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if obj.get("id") == self.id:
                return obj
        return None

    def tool_count(self):
        r = self.raw("tools/list", {}, timeout=20)
        if r and "result" in r:
            return len(r["result"].get("tools", []))
        return 0

    def wait_connected(self, timeout=45):
        end = time.time() + timeout
        last = 0
        while time.time() < end:
            last = self.tool_count()
            if last > 0:
                return last
            time.sleep(1.0)
        return last

    def call(self, tool, args):
        r = self.raw("tools/call", {"name": tool, "arguments": args})
        if not r or "result" not in r:
            return ("ERROR", json.dumps(r)[:800])
        res = r["result"]
        parts = [c.get("text", "") for c in res.get("content", []) if c.get("type") == "text"]
        return ("ERR" if res.get("isError") else "OK", "\n".join(parts))

    def close(self):
        try: self.p.terminate()
        except Exception: pass


def main():
    s = Studio()
    try:
        n = s.wait_connected()
        print("studio tools visible:", n, flush=True)
        if n == 0:
            print("Studio did not register with the proxy within the wait window"); return
        cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
        if cmd == "tools":
            r = s.raw("tools/list", {})
            print(", ".join(t["name"] for t in r["result"]["tools"]))
        elif cmd == "state":
            print(s.call("get_studio_state", {})[1])
        elif cmd == "luau":
            code = sys.argv[2]
            dm = sys.argv[3] if len(sys.argv) > 3 else "Edit"
            st, tx = s.call("execute_luau", {"code": code, "datamodel_type": dm})
            print("[" + st + "]", flush=True); print(tx)
        elif cmd == "file":
            code = open(sys.argv[2], encoding="utf-8").read()
            dm = sys.argv[3] if len(sys.argv) > 3 else "Edit"
            st, tx = s.call("execute_luau", {"code": code, "datamodel_type": dm})
            print("[" + st + "]", flush=True); print(tx)
        elif cmd == "read":
            print(s.call("script_read", {"path": sys.argv[2]})[1])
        else:
            print("usage: mc.py tools|state|luau <code> [dm]|file <path> [dm]|read <path>")
    finally:
        s.close()

if __name__ == "__main__":
    main()
