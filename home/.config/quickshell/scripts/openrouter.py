#!/usr/bin/env python3
"""OpenRouter credit and usage for the bar, as one JSON line.

The key is the one Pi already holds (~/.pi/agent/auth.json, or
$OPENROUTER_API_KEY). It is read here at run time and sent only to
openrouter.ai; it is never printed, logged or written anywhere.
Idea from k4ditano/k4 (MIT): an AI usage meter in the bar.
"""
import json, os, urllib.request


def key():
    k = os.environ.get("OPENROUTER_API_KEY")
    if k:
        return k
    try:
        d = json.load(open(os.path.expanduser("~/.pi/agent/auth.json"))).get("openrouter") or {}
        return d.get("access") or d.get("key") or ""
    except (OSError, ValueError):
        return ""


def get(path, k):
    req = urllib.request.Request("https://openrouter.ai/api/v1/" + path, headers={"Authorization": "Bearer " + k})
    return json.loads(urllib.request.urlopen(req, timeout=20).read()).get("data") or {}


k = key()
if not k:
    print(json.dumps({"ok": False, "error": "no OpenRouter key in Pi"}))
    raise SystemExit
try:
    info = get("key", k)
    out = {"ok": True, "today": info.get("usage_daily") or 0, "month": info.get("usage_monthly") or 0,
           "keyLimitLeft": info.get("limit_remaining")}
    try:
        c = get("credits", k)
        out["credits"] = c.get("total_credits") or 0
        out["remaining"] = (c.get("total_credits") or 0) - (c.get("total_usage") or 0)
    except Exception:
        out["remaining"] = info.get("limit_remaining")
    print(json.dumps(out))
except Exception as e:
    print(json.dumps({"ok": False, "error": type(e).__name__}))
