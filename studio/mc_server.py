import json, os, subprocess, time, datetime, traceback

LAUNCH = ["cmd.exe", "/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]
BASE = r"D:\RobloxRE\studio"
REQ = os.path.join(BASE, "req.json")
RESP = os.path.join(BASE, "resp.json")
LOG = os.path.join(BASE, "server.log")

def log(m):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write("[%s] %s\n" % (datetime.datetime.now().strftime("%H:%M:%S"), m))
    print(m, flush=True)

open(LOG, "w", encoding="utf-8").close()
p = subprocess.Popen(LAUNCH, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)
nid = [0]

def raw(method, params=None, timeout=90):
    nid[0] += 1
    msg = {"jsonrpc": "2.0", "id": nid[0], "method": method}
    if params is not None: msg["params"] = params
    p.stdin.write(json.dumps(msg) + "\n"); p.stdin.flush()
    end = time.time() + timeout
    while time.time() < end:
        line = p.stdout.readline()
        if not line: return None
        line = line.strip()
        if not line: continue
        try: obj = json.loads(line)
        except Exception: continue
        if obj.get("id") == nid[0]: return obj
    return None

def call(tool, args, timeout=90):
    r = raw("tools/call", {"name": tool, "arguments": args}, timeout)
    if not r or "result" not in r: return {"error": json.dumps(r)[:400]}
    res = r["result"]
    return {"isError": bool(res.get("isError")),
            "text": "\n".join(c.get("text","") for c in res.get("content",[]) if c.get("type")=="text")}

log("init")
raw("initialize", {"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"dsh","version":"0.1"}})
p.stdin.write(json.dumps({"jsonrpc":"2.0","method":"notifications/initialized","params":{}})+"\n"); p.stdin.flush()

for i in range(60):
    st = call("get_studio_state", {}, timeout=20)
    if not st.get("isError") and "Studio Mode" in st.get("text",""):
        log("connected: " + st["text"].splitlines()[0]); break
    time.sleep(2)
else:
    log("never connected"); p.terminate(); raise SystemExit(0)

log("serving requests from " + REQ)
while True:
    try:
        if os.path.exists(REQ):
            try:
                with open(REQ, encoding="utf-8") as f: req = json.load(f)
            except Exception:
                time.sleep(0.3); continue
            os.remove(REQ)
            tool = req.get("tool"); args = req.get("args", {})
            log("call " + str(tool))
            try:
                out = call(tool, args)
            except Exception:
                out = {"error": traceback.format_exc()[:600]}
            with open(RESP, "w", encoding="utf-8") as f:
                json.dump(out, f)
            log("done " + str(tool))
        time.sleep(0.25)
    except KeyboardInterrupt:
        break
