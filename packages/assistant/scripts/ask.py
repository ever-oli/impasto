#!/usr/bin/env python3
"""ask.py — the notch assistant's bridge to its engine, chosen in
~/.config/notch/ask-backend: "cua" (opencode with the Cua Driver's computer,
the default), "box" (an instabox machine), "pi" (Pi with OptChat memory) or
"opencode" (ACP).

Reads one JSON command per line on stdin:
  {"op":"ask","text":..,"screen":"none|screen|region","context":bool,"act":bool}
  {"op":"capture"} (the active Helium tab, for the next question)
  {"op":"cancel"}  {"op":"reset"}  {"op":"answer","id":..,"allow":bool}
Prints one JSON event per line on stdout:
  {"type":"ready"} {"type":"chunk","text":..} {"type":"thought","text":..}
  {"type":"tool","title":..,"status":..} {"type":"permission","id":..,"title":..,"detail":..}
  {"type":"captured","title":..} {"type":"visual","kind":..,"path":..,"source":..}
  {"type":"rolled","summary":..} {"type":"done","stop":..} {"type":"error","text":..}
One session is kept, so follow-ups share it; `reset` starts a new one.
Reads (read/search/fetch/think) are allowed; anything else is denied unless
the question was asked in act mode, where the shell asks Ever first.
"""
import base64, json, os, subprocess, sys, threading, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ask_box as box
import ask_extras as extras
import ask_pi as pi

HOME = os.path.expanduser("~")
STATE = os.environ.get("XDG_STATE_HOME", f"{HOME}/.local/state") + "/notch"
HISTORY = f"{STATE}/ask-history.jsonl"
CONF = f"{HOME}/.config/notch"
def _backend():
    if "--backend" in sys.argv:
        return sys.argv[sys.argv.index("--backend") + 1]
    try:
        return open(f"{CONF}/ask-backend").read().strip() or "cua"
    except OSError:
        return os.environ.get("ASK_BACKEND", "cua")
BACKEND = _backend()
PI = os.environ.get("ASK_PI", f"{HOME}/.local/share/mise/installs/node/latest/bin/pi")
# ASK_PI_STATE / ASK_PI_SESSION: tests use their own chat.
PI_STATE = os.environ.get("ASK_PI_STATE", f"{STATE}/pi")
PI_SESSION = os.environ.get("ASK_PI_SESSION", "notch")
AGENT = os.environ.get("ASK_AGENT", f"{HOME}/.local/share/mise/installs/opencode/latest/node_modules/.bin/opencode")
SAFE = {"read", "search", "fetch", "think"}

# `ask.py history` lists past questions (newest first, "question<TAB>n");
# `ask.py answer n` prints that answer. The palette's Ask history uses both.
if sys.argv[1:2] == ["backend"]:
    if sys.argv[2:3]:
        os.makedirs(CONF, exist_ok=True); open(f"{CONF}/ask-backend", "w").write(sys.argv[2] + "\n")
    print(_backend()); sys.exit()
if sys.argv[1:2] == ["modes"]:
    print(json.dumps([{k: m[k] for k in ("id", "name", "icon", "sources")} for m in extras.modes()]))
    sys.exit()
if sys.argv[1:2] in (["history"], ["answer"]):
    extras.history(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    sys.exit()

out_lock = threading.Lock()
def emit(**event):
    with out_lock:
        sys.stdout.write(json.dumps(event) + "\n"); sys.stdout.flush()

# The ask runs on a free model, always.
FREE_MODEL = os.environ.get("ASK_MODEL", "opencode/glm-5.3-flash-free")
OPENCODE = {"permission": {"edit": "ask", "bash": "ask", "webfetch": "allow"},
            "model": FREE_MODEL}
env = dict(os.environ, OPENCODE_CONFIG_CONTENT=json.dumps(OPENCODE))
if BACKEND == "cua":
    # The Cua Driver (MIT, cua.ai): the desktop, its windows, the browser.
    OPENCODE["mcp"] = {"servers": {"cua": {
        "type": "local",
        "command": [os.path.join(HOME, ".local/bin/cua-driver"), "mcp"],
        # niri is native Wayland: without this the driver falls back to
        # X11, where a Wayland desktop has no windows to find.
        "environment": {"CUA_DRIVER_RS_ENABLE_WAYLAND": "1"},
        "enabled": True}}}
    env = dict(env, OPENCODE_CONFIG_CONTENT=json.dumps(OPENCODE))
    env["PATH"] = os.path.join(HOME, ".local/bin") + ":" + env.get("PATH", "")
if BACKEND == "pi":
    os.makedirs(PI_STATE, exist_ok=True)
    env = dict(os.environ, NOTCH_PI_ACT=f"{PI_STATE}/act",
               PATH=os.path.dirname(PI) + ":" + os.environ.get("PATH", ""))
    agent = subprocess.Popen([PI, "--mode", "rpc", "--session-dir", PI_STATE, "--session-id", PI_SESSION,
                              "--optchat-channel", "notch", "--no-context-files",
                              "--thinking", os.environ.get("ASK_PI_THINKING", "low"),
                              "-e", os.path.join(os.path.dirname(os.path.abspath(__file__)), "notch-gate.ts"),
                              # A free model, or the one asked for.
                              "--provider", "openrouter", "--model",
                              os.environ.get("ASK_PI_MODEL", "minimax/minimax-m3.1-flash:free")],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             env=env, cwd=HOME)
else:
  agent = subprocess.Popen([AGENT, "acp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, bufsize=1, env=env, cwd=HOME)
next_id, waiting, pending = [0], {}, {}
session, act_mode, turn = [None], [False], {"q": "", "a": ""}
# {"op":"answer","allow":true,"session":true} approves the rest of this session.
auto_ok = [False]
# Rolling context: summarised every ROLL turns, then a fresh session.
ROLL, KEEP = 12, 4
turns, seed, captured = [], [""], [None]
quiet = [False]
conversation = [str(int(time.time() * 1000))]

def send(msg):
    line = json.dumps(msg) + "\n"
    agent.stdin.write(line.encode() if BACKEND == "pi" else line); agent.stdin.flush()

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
        turn["a"] += content["text"]
        if not quiet[0]:
            emit(type="chunk", text=content["text"])
    elif quiet[0]:
        pass
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

def compose(cmd):
    """The question with everything the mode and toggles put around it."""
    mode = extras.mode_of(cmd.get("mode", "general")) or {"id": "general", "body": "", "sources": [], "rules": "none"}
    parts = [f"<mode name=\"{mode.get('name', 'General')}\">\n{mode['body']}\n</mode>", extras.VISUAL_RULES]
    if mode["rules"] == "grounded":
        parts.append(extras.rules())
    if "profile" in mode["sources"] and extras.profile():
        parts.append(f"<candidate_profile>\n{extras.profile()}\n</candidate_profile>")
    if "files" in mode["sources"]:
        parts.append(extras.files_block(mode["id"], cmd.get("text", "")))
    if act_mode[0]:
        parts.append(extras.ACT)
    lessons = f"{CONF}/lessons.md"
    if mode.get("act") == "on" and os.path.exists(lessons):
        parts.append(f"<lessons source=\"Ever's past corrections\">\n{open(lessons).read()[-6000:]}\n</lessons>")
    lesson = extras.candidate(cmd.get("text", ""))
    if lesson:
        parts.append(f"<candidate_lesson source=\"a lesson from a failed attempt\">\n{lesson}\n</candidate_lesson>")
    skill = os.path.expanduser("~/.pi/agent/skills/notch/SKILL.md")  # Build mode: the map of Notch
    if mode.get("act") == "on" and os.path.exists(skill):
        parts.append(f"<skill name=\"notch\">\n{open(skill).read()}\n</skill>")
    if seed[0]:
        parts.append(seed[0]); seed[0] = ""
    if captured[0]:
        parts.append(extras.page_block(captured[0])); captured[0] = None
    if cmd.get("context"):
        ctx = extras.context()
        if ctx:
            parts.append(f"<context>\n{ctx}\n</context>")
    return "\n\n".join(p for p in parts if p) + f"\n\n<question>\n{cmd.get('text', '').strip()}\n</question>"

def prompt(blocks):
    if session[0] is None:
        session[0] = request("session/new", {"cwd": HOME, "mcpServers": []})["sessionId"]
    return request("session/prompt", {"sessionId": session[0], "prompt": blocks})

def roll():
    """Summarise the session quietly and seed the next one with it."""
    emit(type="tool", title="Compacting the conversation", status="pending")
    quiet[0] = True
    turn["a"] = ""
    try:
        prompt([{"type": "text", "text": "Summarise our conversation so far in at most 12 bullet points: "
                 "facts, decisions, open questions, anything about me. No preamble."}])
        summary = turn["a"].strip()
    except RuntimeError:
        summary = ""
    quiet[0] = False
    recent = "\n".join(f"Ever: {t['q']}\nYou: {t['a'][:1500]}" for t in turns[-KEEP:])
    seed[0] = f"<conversation_summary>\n{summary}\n</conversation_summary>\n<recent_turns>\n{recent}\n</recent_turns>"
    session[0] = None
    turns.clear()
    emit(type="rolled", summary=summary)

busy = threading.Lock()

# What Pi's half and the bridge share: the agent, the senders, the turn
# being answered, and the approvals waiting for an answer.
pi_ctx = {"agent": agent, "send": send, "emit": emit, "turn": turn,
          "auto_ok": auto_ok, "pending": pending, "waiting": waiting,
          "next_id": next_id, "state": PI_STATE, "act_mode": act_mode}

def ask(cmd):
    # One question at a time: a follow-up waits its turn.
    with busy:
        answer_one(cmd)

def answer_one(cmd):
    # `act: on` (Build) works with tools, behind the gate.
    act_mode[0] = bool(cmd.get("act")) or (extras.mode_of(cmd.get("mode", "general")) or {}).get("act") == "on"
    text = compose(cmd)
    blocks = []
    # OCR reads the full-size PNG; the model gets a half-size JPEG.
    shot = {"screen": "grim -o Virtual-1 -", "region": 'g=$(slurp) && grim -g "$g" -'}.get(cmd.get("screen"))
    if shot:
        png = sh(shot)
        if png:
            small = sh("grim -o Virtual-1 -s 0.5 -t jpeg -q 70 -") if cmd.get("screen") == "screen" else b""
            img, mime = (small, "image/jpeg") if small else (png, "image/png")
            blocks.append({"type": "image", "mimeType": mime, "data": base64.b64encode(img).decode()})
            # The text on it too, for a model without vision.
            seen = subprocess.run(["tesseract", "stdin", "-"], input=png, capture_output=True).stdout.decode(errors="replace").strip()
            if seen:
                text += f"\n\n<screen_text source=\"OCR of the attached screenshot\">\n{seen[:6000]}\n</screen_text>"
    turn.update(q=cmd.get("text", ""), a="")
    worked = True
    failure = ""
    try:
        if BACKEND == "pi":
            result = pi.prompt(text, [dict(b) for b in blocks], pi_ctx)
        elif BACKEND == "box":
            box.ask(text, lambda line: emit(type="chunk", text=line + "\n"))
            result = {"stopReason": "end_turn"}
        else:
            result = prompt([{"type": "text", "text": text}] + blocks)
        for kind, png, source in extras.visuals(turn["a"]):
            emit(type="visual", kind=kind, path=png or "", source=source)
        emit(type="done", stop=result.get("stopReason", "end_turn"))
    except RuntimeError as error:
        worked = False
        failure = str(error)
        emit(type="error", text=str(error))
        extras.settle(False)
        # Harness2's reflector: a failed turn may teach the harness a lesson.
        threading.Thread(target=extras.reflect,
                         args=(turn["q"], turn["a"], str(error)),
                         daemon=True).start()
    else:
        extras.settle(True)
    os.makedirs(STATE, exist_ok=True)
    with open(HISTORY, "a") as f:
        f.write(json.dumps({"t": time.time(), "s": conversation[0],
                            "mode": cmd.get("mode", "general"),
                            "q": turn["q"], "a": turn["a"],
                            "ok": worked, "error": failure[:400]}) + "\n")
    turns.append({"q": turn["q"], "a": turn["a"]})
    # Pi's memory never forgets, so only the other backends roll.
    if BACKEND != "pi" and len(turns) >= int(os.environ.get("ASK_ROLL", ROLL)):
        roll()

def capture():
    try:
        captured[0] = extras.browser_page()
        emit(type="captured", title=captured[0].get("title") or captured[0].get("url", "page"))
    except Exception as error:
        emit(type="error", text=f"No browser page: start Helium (it listens on 127.0.0.1:9222). {error}")

if BACKEND == "box":
    emit(type="ready", backend="box")
elif BACKEND == "pi":
    threading.Thread(target=pi.reader, args=(pi_ctx,), daemon=True).start()
    try:
        pi.request({"type": "get_state"}, pi_ctx)
        emit(type="ready", backend="pi")
    except RuntimeError as error:
        emit(type="error", text=str(error))
        # Harness2's reflector: a failed turn may teach the harness a lesson.
        threading.Thread(target=extras.reflect,
                         args=(turn["q"], turn["a"], str(error)),
                         daemon=True).start()
else:
  threading.Thread(target=reader, daemon=True).start()
  try:
    request("initialize", {"protocolVersion": 1, "clientCapabilities":
            {"fs": {"readTextFile": False, "writeTextFile": False}, "terminal": False}})
    emit(type="ready", backend="opencode")
  except RuntimeError as error:
    emit(type="error", text=str(error))

for line in sys.stdin:
    try:
        cmd = json.loads(line)
    except ValueError:
        continue
    op = cmd.get("op")
    if op == "ask" and "--once" in sys.argv:
        ask(cmd)
    elif op == "ask":
        def answer_in_the_background(cmd=cmd):
            # A question that dies must say so: a silent thread leaves the
            # island on "Thinking…" forever, with nothing coming back.
            try:
                ask(cmd)
            except Exception as error:
                emit(type="error", text=f"the bridge could not answer: {error}")
                extras.settle(False)
        threading.Thread(target=answer_in_the_background, daemon=True).start()
    elif op == "capture":
        threading.Thread(target=capture, daemon=True).start()
    elif op == "cancel" and BACKEND == "pi":
        send({"type": "abort"})
        for pick in pending.values():
            pick(False)
        pending.clear()
    elif op == "cancel" and session[0]:
        send({"jsonrpc": "2.0", "method": "session/cancel", "params": {"sessionId": session[0]}})
        for pick in pending.values():
            pick(False)
        pending.clear()
    elif op == "answer" and cmd.get("id") in pending:
        if cmd.get("allow") and cmd.get("session"):
            auto_ok[0] = True
        pending.pop(cmd["id"])(bool(cmd.get("allow")))
    elif op == "reset":
        session[0] = None; auto_ok[0] = False
        turns.clear(); seed[0] = ""; captured[0] = None
        conversation[0] = str(int(time.time() * 1000))
agent.terminate()
