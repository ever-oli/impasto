#!/usr/bin/env python3
"""ask_pi — the Pi half of the notch assistant's bridge.

Pi speaks its own JSONL protocol instead of ACP, so its part of the
bridge lives here: the request, the reader that turns Pi's events into
the bridge's, and the prompt that waits for a turn to end. The bridge
passes what the two halves share — the agent, the senders, the turn
being answered, the approvals — so both still talk about one question.

    ask_pi.request(cmd, ctx)     one command, and its answer
    ask_pi.reader(ctx)           the loop that listens to Pi
    ask_pi.prompt(text, images, ctx)   one turn, waited for
"""
import json
import os
import threading

# The turn's own state: Pi answers over a couple of events, and a turn
# that ends in an error says so here.
done, box = threading.Event(), {}


def request(cmd, ctx):
    """One command to Pi, and the answer it sends back."""
    ctx["next_id"][0] += 1
    wait = {"event": threading.Event()}
    ctx["waiting"][str(ctx["next_id"][0])] = wait
    ctx["send"](dict(cmd, id=str(ctx["next_id"][0])))
    wait["event"].wait()
    if not wait.get("success"):
        raise RuntimeError(wait.get("error") or "Pi refused the command")
    return wait.get("data") or {}


def reader(ctx):
    """Pi's events, turned into the bridge's."""
    for raw in ctx["agent"].stdout:  # bytes, split on LF only
        try:
            msg = json.loads(raw)
        except ValueError:
            continue
        kind = msg.get("type")
        if kind == "response" and msg.get("id") in ctx["waiting"]:
            wait = ctx["waiting"].pop(msg["id"])
            wait.update(msg)
            wait["event"].set()
        elif kind == "message_update":
            event = msg.get("assistantMessageEvent") or {}
            if event.get("type") == "text_delta":
                ctx["turn"]["a"] += event["delta"]
                ctx["emit"](type="chunk", text=event["delta"])
            elif event.get("type") == "thinking_delta":
                ctx["emit"](type="thought", text=event["delta"])
            elif event.get("type") == "error":
                box["error"] = str(event.get("error") or event.get("reason"))
        elif kind == "message_end":
            message = msg.get("message") or {}
            if message.get("role") == "assistant" and message.get("errorMessage"):
                box["error"] = message["errorMessage"]
        elif kind == "tool_execution_start":
            ctx["emit"](type="tool", title=msg.get("toolName", "tool"), status="pending")
        elif kind == "tool_execution_end":
            ctx["emit"](type="tool", title=msg.get("toolName", "tool"),
                        status="failed" if msg.get("isError") else "completed")
        elif kind == "agent_settled":
            box["stop"] = "cancelled" if msg.get("aborted") else "end_turn"
            done.set()
        elif kind == "extension_ui_request" and msg.get("method") == "confirm":
            rid = msg["id"]

            def pick(allow, rid=rid):
                ctx["send"]({"type": "extension_ui_response", "id": rid, "confirmed": bool(allow)})

            if ctx["auto_ok"][0]:
                ctx["emit"](type="tool", title=f"Auto-approved: {msg.get('title') or 'action'}",
                            status="pending")
                pick(True)
                continue
            ctx["pending"][rid] = pick
            # Unanswered approvals are denied after ASK_APPROVE_TIMEOUT.
            def expire(rid=rid):
                if ctx["pending"].pop(rid, None):
                    ctx["emit"](type="tool", title="Approval timed out: denied", status="failed")
                    ctx["send"]({"type": "extension_ui_response", "id": rid, "confirmed": False})

            threading.Timer(float(os.environ.get("ASK_APPROVE_TIMEOUT", 180)), expire).start()
            ctx["emit"](type="permission", id=rid, title=msg.get("title") or "Action",
                        detail=msg.get("message") or "")
        elif kind == "extension_ui_request" and msg.get("method") in ("select", "input", "editor"):
            ctx["send"]({"type": "extension_ui_response", "id": msg["id"], "cancelled": True})
    ctx["emit"](type="error", text="The agent stopped.")


def prompt(text, images, ctx):
    """One turn: the question, and the wait for it to end."""
    open(f"{ctx['state']}/act", "w").write("1" if ctx["act_mode"][0] else "0")
    done.clear()
    box.clear()
    data = request({"type": "prompt", "message": text, "images": images}, ctx)
    # Timeout guard: a stuck turn is aborted.
    if data.get("disposition") != "handled" and not done.wait(float(os.environ.get("ASK_PI_TIMEOUT", 300))):
        ctx["send"]({"type": "abort"})
        for pick in list(ctx["pending"].values()):
            pick(False)
        ctx["pending"].clear()
        done.wait(15)
        raise RuntimeError("Pi took too long, so the turn was stopped (ASK_PI_TIMEOUT).")
    if box.get("error"):
        raise RuntimeError(box["error"])
    return {"stopReason": box.get("stop", "end_turn")}
