#!/usr/bin/env python3
"""ask.py — the notch assistant's bridge to its agent: Pi (the default and only visible engine) or `opencode acp` (hidden fallback,
`notch ask backend opencode`) Pi with OptChat durable memory (`--backend pi`, or "pi" in
~/.config/notch/ask-backend). Pi keeps one never-ending chat under
~/.local/state/notch/pi; its tool calls go through notch-gate.ts.

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
import base64, glob, json, os, subprocess, sys, threading, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ask_extras as extras

HOME = os.path.expanduser("~")
STATE = os.environ.get("XDG_STATE_HOME", f"{HOME}/.local/state") + "/notch"
HISTORY = f"{STATE}/ask-history.jsonl"
CONF = f"{HOME}/.config/notch"
def _backend():
    if "--backend" in sys.argv:
        return sys.argv[sys.argv.index("--backend") + 1]
    try:
        return open(f"{CONF}/ask-backend").read().strip() or "pi"
    except OSError:
        return os.environ.get("ASK_BACKEND", "pi")
BACKEND = _backend()
PI = os.environ.get("ASK_PI", f"{HOME}/.local/share/mise/installs/node/latest/bin/pi")
# ASK_PI_STATE / ASK_PI_SESSION let tests use their own chat, never the live notch one.
PI_STATE = os.environ.get("ASK_PI_STATE", f"{STATE}/pi")
PI_SESSION = os.environ.get("ASK_PI_SESSION", "notch")
# One fresh transcript per roll: the session id stamps when it began. Pi
# resumes the id it is given, so reusing the first is what let an answer
# queue wait on a day's transcript; the durable memory is not inside it.
pi_sess = [PI_SESSION + "-" + time.strftime("%m%d-%H%M%S")]
AGENT = os.environ.get("ASK_AGENT", f"{HOME}/.local/share/mise/installs/opencode/latest/node_modules/.bin/opencode")
SAFE = {"read", "search", "fetch", "think"}
ACT = f"""You can operate Ever's Linux desktop (niri, Wayland) with shell commands:
`notch-act` (run with no arguments for usage) types, presses keys, clicks and moves the
mouse, focuses windows and takes a screenshot to observe. Work in small steps: observe,
act, observe again. To see a screenshot, read the PNG file `notch-act look` prints. Screen
pixels are logical (scale 1). Every command is shown to Ever for approval, so explain each one briefly."""

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
if BACKEND == "pi":
    def spawn_pi():
        """Start (or restart, after a roll or a reset) the Pi process and its stdout reader."""
        global agent
        os.makedirs(PI_STATE, exist_ok=True)
        # One transcript per session id: rolls and resets pile these up forever.
        # The durable store keeps every original (optchat.source), so old
        # transcripts are replayable debris — keep the recent dozen, drop the rest.
        try:
            olds = sorted(glob.glob(f"{PI_STATE}/*_{PI_SESSION}*.jsonl"))
            for old in olds[:-12]:
                os.unlink(old)
        except OSError:
            pass
        env = dict(os.environ, NOTCH_PI_ACT=f"{PI_STATE}/act",
                   PATH=os.path.dirname(PI) + ":" + os.environ.get("PATH", ""))
        agent = subprocess.Popen([PI, "--mode", "rpc", "--session-dir", PI_STATE, "--session-id", pi_sess[0],
                                  "--optchat-channel", "notch", "--no-context-files",
                                  # Low thinking keeps notch answers fast; ASK_PI_THINKING=medium for more.
                                  "--thinking", os.environ.get("ASK_PI_THINKING", "low"),
                                  "-e", os.path.join(os.path.dirname(os.path.abspath(__file__)), "notch-gate.ts")]
                                 + (["--model", os.environ["ASK_PI_MODEL"]] if os.environ.get("ASK_PI_MODEL") else []),
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=open(f"{PI_STATE}/pi-stderr.log", "w"),  # one startup's worth; spawns rotate
                                 env=env, cwd=HOME)
        threading.Thread(target=pi_reader, daemon=True).start()
else:
  agent = subprocess.Popen([AGENT, "acp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, text=True, bufsize=1, env=env, cwd=HOME)
next_id, waiting, pending = [0], {}, {}
session, act_mode, turn = [None], [False], {"q": "", "a": ""}
# {"op":"answer","allow":true,"session":true} approves the rest of this session.
auto_ok = [False]
# Rolling context: after ROLL turns the session is summarised and replaced by
# a fresh one seeded with the summary and the last KEEP turns.
ROLL, KEEP = 12, 4
turns, seed, captured = [], [""], [None]
quiet = [False]
conversation = [str(int(time.time() * 1000))]

def send(msg):
    line = json.dumps(msg) + "\n"
    try:
        agent.stdin.write(line.encode() if BACKEND == "pi" else line); agent.stdin.flush()
    except (OSError, ValueError, AttributeError):
        pass  # The agent process is gone; the prompt's dead check spawns a new one.

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

# ── Pi (RPC JSONL) ─────────────────────────────────────────────────────────
pi_done, pi_box = threading.Event(), {}
# When pi last had something to say. A long quiet with no permission pending
# is the one symptom of a wedged generation, and the prompt turns it out.
pi_last = [time.time()]
restarting = [False]

def restart_pi():
    """Kill the Pi process and start a fresh one: its session's own history
    is what a long notch day grows until the model balks; OptChat durable
    memory keeps every fact, so a fresh start loses nothing that matters."""
    emit(type="tool", title="Starting a fresh answer", status="pending")
    restarting[0] = True
    try:
        agent.terminate(); agent.wait(timeout=5)
    except Exception:
        try: agent.kill()
        except Exception: pass
    restarting[0] = False
    pi_sess[0] = f"{PI_SESSION}-{time.strftime('%m%d-%H%M%S')}"
    spawn_pi()
    pi_request({"type": "get_state"})
    pi_last[0] = time.time()
    emit(type="tool", title="Fresh answer started", status="pending")

def pi_request(cmd, timeout=None):
    next_id[0] += 1
    box = {"event": threading.Event()}
    waiting[str(next_id[0])] = box
    send(dict(cmd, id=str(next_id[0])))
    if not box["event"].wait(timeout):
        # The command was never taken (a wedged generation does it). Abort
        # whatever may be live and report, so the turn ends in an error
        # instead of a prompt that waits forever.
        waiting.pop(str(next_id[0]), None)
        send({"type": "abort"})
        raise RuntimeError(cmd.get("type") == "prompt" and
            f"The model never took the prompt ({int(timeout)}s) — stopped so the notch never hangs. "
            "Say it again; a reset starts a fresh session in seconds." or
            "The agent never answered the command.")
    if not box.get("success"):
        raise RuntimeError(box.get("error") or "Pi refused the command")
    return box.get("data") or {}

def pi_reader():
    # This reader watches the process that started it; a later restart's
    # reader watches the new one, so EOF here must only touch its own wants.
    mine = agent
    for raw in mine.stdout:  # bytes, split on LF only
        try:
            msg = json.loads(raw)
        except ValueError:
            continue
        kind = msg.get("type")
        if kind in ("message_update", "tool_execution_start", "tool_execution_end", "agent_settled"):
            pi_last[0] = time.time()
        if kind == "response" and msg.get("id") in waiting:
            box = waiting.pop(msg["id"]); box.update(msg); box["event"].set()
        elif kind == "message_update":
            ev = msg.get("assistantMessageEvent") or {}
            if ev.get("type") == "text_delta":
                turn["a"] += ev["delta"]; emit(type="chunk", text=ev["delta"])
            elif ev.get("type") == "thinking_delta":
                emit(type="thought", text=ev["delta"])
            elif ev.get("type") == "error":
                pi_box["error"] = str(ev.get("error") or ev.get("reason"))
        elif kind == "message_end":
            m = msg.get("message") or {}
            if m.get("role") == "assistant" and m.get("errorMessage"):
                pi_box["error"] = m["errorMessage"]
        elif kind == "tool_execution_start":
            emit(type="tool", title=msg.get("toolName", "tool"), status="pending")
        elif kind == "tool_execution_end":
            emit(type="tool", title=msg.get("toolName", "tool"), status="failed" if msg.get("isError") else "completed")
        elif kind == "agent_settled":
            pi_box["stop"] = "cancelled" if msg.get("aborted") else "end_turn"; pi_done.set()
        elif kind == "extension_ui_request" and msg.get("method") == "confirm":
            rid = msg["id"]
            def pick(allow, rid=rid):
                send({"type": "extension_ui_response", "id": rid, "confirmed": bool(allow)})
            if auto_ok[0]:
                emit(type="tool", title=f"Auto-approved: {msg.get('title') or 'action'}", status="pending")
                pick(True); continue
            pending[rid] = pick
            emit(type="permission", id=rid, title=msg.get("title") or "Action", detail=msg.get("message") or "")
        elif kind == "extension_ui_request" and msg.get("method") in ("select", "input", "editor"):
            send({"type": "extension_ui_response", "id": msg["id"], "cancelled": True})
    # The process is gone, crash or kill: fail every wait this reader owns
    # at once, so a turn ends on a clear note instead of riding a timeout.
    if mine is agent:
        for box in waiting.values():
            box.update(success=False, error="The Pi agent died; a fresh one starts for the next ask.")
            box["event"].set()
        waiting.clear()
        if not restarting[0]:
            emit(type="error", text="The agent stopped.")

def pi_prompt(text, images):
    if agent is None or agent.poll() is not None:
        # The process died mid-day (crash, kill, memory): a long quiet turn
        # waiting on a dead pipe serves nobody; spawn fresh before asking.
        pi_done.clear(); pi_box.clear()
        pi_sess[0] = f"{PI_SESSION}-{time.strftime('%m%d-%H%M%S')}"
        spawn_pi()
    open(f"{PI_STATE}/act", "w").write("1" if act_mode[0] else "0")
    pi_done.clear(); pi_box.clear()
    # A wedged generation is silent: pi's own request timeout does not always
    # come back as an event, so the bridge watches for the word. A permission
    # pending is quiet because Ever is reading it; the clock waits on him too.
    silence = float(os.environ.get("ASK_SILENCE_TIMEOUT", "300"))
    span = float(os.environ.get("ASK_TURN_TIMEOUT", "1200"))
    pi_last[0] = started = time.time()
    data = pi_request({"type": "prompt", "message": text, "images": images}, timeout=silence)
    if data.get("disposition") != "handled":
        while not pi_done.wait(2.0):
            if pending:
                pi_last[0] = started = time.time()
                continue
            if time.time() - pi_last[0] >= silence:
                send({"type": "abort"}); pi_done.wait(10)
                raise RuntimeError(f"No word from the model for {int(silence)}s, so it was stopped. "
                                   "Say it again; if it recurs, reset starts a fresh session.")
            if time.time() - started >= span:
                send({"type": "abort"}); pi_done.wait(10)
                raise RuntimeError(f"The answer ran past {int(span)}s, so it was stopped before the notch hung.")
    if pi_box.get("error"):
        raise RuntimeError(pi_box["error"])
    return {"stopReason": pi_box.get("stop", "end_turn")}

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

def compose(cmd):
    """The question with everything the mode and toggles put around it."""
    mode = extras.mode_of(cmd.get("mode", "general")) or {"id": "general", "body": "", "sources": [], "rules": "none"}
    parts = [f"<mode name=\"{mode.get('name', 'General')}\">\n{mode['body']}\n</mode>", extras.VISUAL_RULES,
             extras.rules()]  # the shared layers: security, voice — every mode
    if mode["rules"] == "grounded":
        parts.append(extras.rules_grounded())  # interview contracts, grounded only
    if "profile" in mode["sources"] and extras.profile():
        parts.append(f"<candidate_profile>\n{extras.profile()}\n</candidate_profile>")
    if "files" in mode["sources"]:
        parts.append(extras.files_block(mode["id"], cmd.get("text", "")))
    if act_mode[0]:
        parts.append(ACT)
    lessons = f"{CONF}/lessons.md"
    if mode.get("act") == "on" and os.path.exists(lessons):
        parts.append(f"<lessons source=\"Ever's past corrections\">\n{open(lessons).read()[-6000:]}\n</lessons>")
    if seed[0]:
        parts.append(seed[0]); seed[0] = ""
    if captured[0]:
        parts.append(extras.page_block(captured[0])); captured[0] = None
    if cmd.get("context"):
        ctx = context()
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

def ask(cmd):
    # One question at a time: a follow-up sent mid-answer (or mid-compaction)
    # waits rather than sharing the turn.
    with busy:
        answer_one(cmd)

def answer_one(cmd):
    # A mode with `act: on` (Build) always works with tools, behind the gate.
    act_mode[0] = bool(cmd.get("act")) or (extras.mode_of(cmd.get("mode", "general")) or {}).get("act") == "on"
    text = compose(cmd)
    blocks = []
    # OCR reads the full-size PNG; the model gets a half-size JPEG, which vision
    # models answer fast and which keeps Pi's durable chat small.
    shot = {"screen": "grim -o Virtual-1 -", "region": 'g=$(slurp) && grim -g "$g" -'}.get(cmd.get("screen"))
    if shot:
        png = sh(shot)
        if png:
            small = sh("grim -o Virtual-1 -s 0.5 -t jpeg -q 70 -") if cmd.get("screen") == "screen" else b""
            img, mime = (small, "image/jpeg") if small else (png, "image/png")
            blocks.append({"type": "image", "mimeType": mime, "data": base64.b64encode(img).decode()})
            # The text on it too, so a model without vision still sees the screen.
            seen = subprocess.run(["tesseract", "stdin", "-"], input=png, capture_output=True).stdout.decode(errors="replace").strip()
            if seen:
                text += f"\n\n<screen_text source=\"OCR of the attached screenshot\">\n{seen[:6000]}\n</screen_text>"
    turn.update(q=cmd.get("text", ""), a="")
    try:
        if BACKEND == "pi":
            result = pi_prompt(text, [dict(b) for b in blocks])
        else:
            result = prompt([{"type": "text", "text": text}] + blocks)
        for kind, png, source in extras.visuals(turn["a"]):
            emit(type="visual", kind=kind, path=png or "", source=source)
        emit(type="done", stop=result.get("stopReason", "end_turn"))
    except RuntimeError as error:
        emit(type="error", text=str(error))
    os.makedirs(STATE, exist_ok=True)
    with open(HISTORY, "a") as f:
        f.write(json.dumps({"t": time.time(), "s": conversation[0], "mode": cmd.get("mode", "general"), "q": turn["q"], "a": turn["a"]}) + "\n")
    # The history is a log, not an archive: past what Help/Recent shows it is
    # unread detail. Rotate like UniiChat pages: keep the tail, drop the rest.
    try:
        if os.path.getsize(HISTORY) > 2_000_000:
            tail = open(HISTORY, "rb").readlines()[-500:]
            open(HISTORY, "wb").writelines(tail)
    except OSError:
        pass
    turns.append({"q": turn["q"], "a": turn["a"]})
    if len(turns) > 64:  # the roll reaps it every ASK_ROLL; this bounds runs where rolls fail
        del turns[:len(turns) - 64]
    # The ACP backend rolls its transcript into a summary. Pi keeps the facts
    # in its durable memory, so a fresh session is its roll — and a long
    # day's transcript is exactly what made answers stall before.
    if BACKEND == "pi":
        if len(turns) >= int(os.environ.get("ASK_ROLL", 10)):
            emit(type="rolled", summary="A fresh session; the memory keeps what matters")
            try:
                restart_pi()
            except Exception as error:
                emit(type="error", text=f"The agent could not restart: {error}")
    elif len(turns) >= int(os.environ.get("ASK_ROLL", ROLL)):
        roll()

def capture():
    try:
        captured[0] = extras.browser_page()
        emit(type="captured", title=captured[0].get("title") or captured[0].get("url", "page"))
    except Exception as error:
        emit(type="error", text=f"No browser page: start Helium (it listens on 127.0.0.1:9222). {error}")

if BACKEND == "pi":
    spawn_pi()
    try:
        pi_request({"type": "get_state"})
        emit(type="ready", backend="pi")
    except RuntimeError as error:
        emit(type="error", text=str(error))
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
        threading.Thread(target=ask, args=(cmd,), daemon=True).start()
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
        if BACKEND == "pi":
            try:
                restart_pi()
            except Exception as error:
                emit(type="error", text=f"The agent could not restart: {error}")
agent.terminate()
