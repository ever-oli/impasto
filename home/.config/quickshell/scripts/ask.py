#!/usr/bin/env python3
"""ask.py — the notch assistant's bridge to an ACP agent (`opencode acp`).

Reads one JSON command per line on stdin:
  {"op":"ask","text":..,"screen":"none|screen|region","context":bool,"act":bool}
  {"op":"cancel"}  {"op":"reset"}  {"op":"answer","id":..,"allow":bool}
Prints one JSON event per line on stdout:
  {"type":"ready"} {"type":"chunk","text":..} {"type":"thought","text":..}
  {"type":"tool","title":..,"status":..} {"type":"permission","id":..,"title":..,"detail":..}
  {"type":"done","stop":..} {"type":"error","text":..}
One session is kept, so follow-ups share it; `reset` starts a new one.
Reads (read/search/fetch/think) are allowed; anything else is denied unless
the question was asked in act mode, where the shell asks Ever first.
"""
import base64, json, os, subprocess, sys, threading, time

HOME = os.path.expanduser("~")
STATE = os.environ.get("XDG_STATE_HOME", f"{HOME}/.local/state") + "/impasto"
HISTORY = f"{STATE}/ask-history.jsonl"
AGENT = os.environ.get("ASK_AGENT", f"{HOME}/.local/share/mise/installs/opencode/latest/node_modules/.bin/opencode")
SAFE = {"read", "search", "fetch", "think"}
ACT = f"""You can operate Ever's Linux desktop (niri, Wayland) with shell commands:
`impasto-act` (run with no arguments for usage) types, presses keys, clicks and moves the
mouse, focuses windows and takes a screenshot to observe. Work in small steps: observe,
act, observe again. To see a screenshot, read the PNG file `impasto-act look` prints. Screen
pixels are logical (scale 1). Every command is shown to Ever for approval, so explain each one briefly."""

# `ask.py history` lists past questions (newest first, "question<TAB>n");
# `ask.py answer n` prints that answer. The palette's Ask history uses both.
if sys.argv[1:2] in (["history"], ["answer"]):
    rows = [json.loads(l) for l in open(HISTORY)] if os.path.exists(HISTORY) else []
    if sys.argv[1] == "history":
        for n in range(len(rows) - 1, -1, -1):
            print(f"{rows[n]['q'][:120]}\t{n}")
    else:
        print(rows[int(sys.argv[2])]["a"])
    sys.exit()

out_lock = threading.Lock()
def emit(**event):
    with out_lock:
        sys.stdout.write(json.dumps(event) + "\n"); sys.stdout.flush()

env = dict(os.environ, OPENCODE_CONFIG_CONTENT=json.dumps(
    {"permission": {"edit": "ask", "bash": "ask", "webfetch": "allow"}}))
agent = subprocess.Popen([AGENT, "acp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, bufsize=1, env=env, cwd=HOME)
next_id, waiting, pending = [0], {}, {}
session, act_mode, turn = [None], [False], {"q": "", "a": ""}

def send(msg):
    agent.stdin.write(json.dumps(msg) + "\n"); agent.stdin.flush()

def request(method, params):
    next_id[0] += 1
    box = {"event": threading.Event()}
    waiting[next_id[0]] = box
    send({"jsonrpc": "2.0", "id": next_id[0], "method": method, "params": params})
    box["event"].wait()
    if "error" in box:
        raise RuntimeError(box["error"].get("message", str(box["error"])))
    return box["result"]

def on_update(u):
    kind = u.get("sessionUpdate")
    content = u.get("content") or {}
    if kind == "agent_message_chunk" and content.get("type") == "text":
        turn["a"] += content["text"]; emit(type="chunk", text=content["text"])
    elif kind == "agent_thought_chunk" and content.get("type") == "text":
        emit(type="thought", text=content["text"])
    elif kind in ("tool_call", "tool_call_update"):
        emit(type="tool", title=u.get("title") or "", status=u.get("status") or "")

def on_permission(rid, params):
    call = params.get("toolCall") or {}
    options = params.get("options") or []
    def pick(allow):
        want = ("allow_once", "allow_always") if allow else ("reject_once", "reject_always")
        opt = next((o for o in options if o.get("kind") in want), None)
        send({"jsonrpc": "2.0", "id": rid, "result": {"outcome": {"outcome": "selected", "optionId": opt["optionId"]}
              if opt else {"outcome": "cancelled"}}})
    if call.get("kind") in SAFE:
        return pick(True)
    if not act_mode[0]:
        emit(type="tool", title=f"Denied: {call.get('title', 'action')}", status="failed")
        return pick(False)
    raw = call.get("rawInput") or {}
    pending[str(rid)] = pick
    emit(type="permission", id=str(rid), title=call.get("title") or "Action",
         detail=raw.get("command") or raw.get("description") or json.dumps(raw)[:300])

def reader():
    for line in agent.stdout:
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if "method" in msg and "id" in msg:
            if msg["method"] == "session/request_permission":
                on_permission(msg["id"], msg["params"])
            else:
                send({"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32601, "message": "unsupported"}})
        elif "method" in msg:
            if msg["method"] == "session/update":
                on_update(msg["params"].get("update") or {})
        elif msg.get("id") in waiting:
            box = waiting.pop(msg["id"])
            box.update({k: msg[k] for k in ("result", "error") if k in msg}); box["event"].set()
    emit(type="error", text="The agent stopped.")

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, timeout=30).stdout
    except subprocess.TimeoutExpired:
        return b""

def context():
    win = sh("niri msg -j focused-window")
    try:
        w = json.loads(win or b"null") or {}
        parts = [f"Focused window: {w.get('title')} ({w.get('app_id')})"]
    except ValueError:
        parts = []
    for label, cmd in (("Clipboard", "wl-paste -n -t text"), ("Selected text", "wl-paste -p -n -t text")):
        text = sh(cmd).decode(errors="replace").strip()
        if text:
            parts.append(f"{label}:\n{text[:2000]}")
    return "\n\n".join(parts)

def ask(cmd):
    if session[0] is None:
        session[0] = request("session/new", {"cwd": HOME, "mcpServers": []})["sessionId"]
    act_mode[0] = bool(cmd.get("act"))
    text = cmd.get("text", "").strip()
    blocks = []
    if cmd.get("context"):
        ctx = context()
        if ctx:
            text = f"{text}\n\n<context>\n{ctx}\n</context>"
    if act_mode[0]:
        text = f"{ACT}\n\n{text}"
    shot = {"screen": "grim -o Virtual-1 -", "region": 'g=$(slurp) && grim -g "$g" -'}.get(cmd.get("screen"))
    if shot:
        png = sh(shot)
        if png:
            blocks.append({"type": "image", "mimeType": "image/png", "data": base64.b64encode(png).decode()})
            # The text on it too, so a model without vision still sees the screen.
            seen = subprocess.run(["tesseract", "stdin", "-"], input=png, capture_output=True).stdout.decode(errors="replace").strip()
            if seen:
                text += f"\n\n<screen_text source=\"OCR of the attached screenshot\">\n{seen[:6000]}\n</screen_text>"
    turn.update(q=cmd.get("text", ""), a="")
    try:
        result = request("session/prompt", {"sessionId": session[0], "prompt": [{"type": "text", "text": text}] + blocks})
        emit(type="done", stop=result.get("stopReason", "end_turn"))
    except RuntimeError as error:
        emit(type="error", text=str(error))
    os.makedirs(STATE, exist_ok=True)
    with open(HISTORY, "a") as f:
        f.write(json.dumps({"t": time.time(), "q": turn["q"], "a": turn["a"]}) + "\n")

threading.Thread(target=reader, daemon=True).start()
try:
    request("initialize", {"protocolVersion": 1, "clientCapabilities":
            {"fs": {"readTextFile": False, "writeTextFile": False}, "terminal": False}})
    emit(type="ready")
except RuntimeError as error:
    emit(type="error", text=str(error))

for line in sys.stdin:
    try:
        cmd = json.loads(line)
    except ValueError:
        continue
    op = cmd.get("op")
    if op == "ask":
        threading.Thread(target=ask, args=(cmd,), daemon=True).start()
    elif op == "cancel" and session[0]:
        send({"jsonrpc": "2.0", "method": "session/cancel", "params": {"sessionId": session[0]}})
        for pick in pending.values():
            pick(False)
        pending.clear()
    elif op == "answer" and cmd.get("id") in pending:
        pending.pop(cmd["id"])(bool(cmd.get("allow")))
    elif op == "reset":
        session[0] = None
agent.terminate()
