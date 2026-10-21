#!/usr/bin/env python3
"""ask_lessons — the shell's memory of its own mistakes.

Harness2's lesson: an agent's harness (prompts, tools, memory, skills)
can be edited by the agent itself, and the edit is kept when it earns
its place. The notch's harness is files — the modes, the skills, the
visual rules, and lessons.md, which holds what the shell has learned.

A lesson written straight into lessons.md is a lesson nobody tested.
So the cycle has three steps:

  propose  a failed turn asks a free model for one lesson, and the
           lesson waits in proposals.json rather than in lessons.md
  probe    the next attempt of the same question carries that lesson
  keep     if the attempt works the lesson moves into lessons.md; if it
           fails again the lesson is dropped

lessons.md is Ever's file, so it is pruned too: the oldest lessons go
when it grows past what a person will read.
"""
import json
import os
import re
import time

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", f"{HOME}/.config") + "/notch"
LESSONS = os.path.join(CONF, "lessons.md")
PROPOSALS = os.path.join(
    os.environ.get("XDG_STATE_HOME", f"{HOME}/.local/state"), "notch",
    "proposals.json")
LESSON_CAP = 16000      # bytes of lessons.md a person will still read
LESSON_ENTRIES = 40     # and this many lessons at most
APPLIED = {}            # the proposal the turn on the desk is trying


def key(question):
    """The same question, however Ever typed it."""
    text = re.sub(r"[^a-z0-9 ]+", " ", (question or "").lower())
    return " ".join(text.split())[:160]


def proposals():
    try:
        with open(PROPOSALS) as handle:
            data = json.load(handle)
        return data if isinstance(data, list) else []
    except (OSError, ValueError):
        return []


def save(items):
    try:
        os.makedirs(os.path.dirname(PROPOSALS), exist_ok=True)
        with open(PROPOSALS, "w") as handle:
            json.dump(items, handle, indent=1)
    except OSError:
        pass


def propose(question, lesson):
    """Keep a candidate lesson until it has proved itself."""
    lesson = (lesson or "").strip()
    if not lesson:
        return ""
    ident = key(question)
    items = [item for item in proposals() if item.get("key") != ident]
    items.append({"id": f"{int(time.time() * 1000)}-{len(items)}",
                  "key": ident, "question": (question or "")[:300],
                  "lesson": lesson[:1200], "t": time.time(), "tries": 0})
    save(items)
    return lesson


def candidate(question):
    """The lesson this attempt should try, if there is one."""
    for item in proposals():
        if item.get("key") == key(question):
            item["tries"] = int(item.get("tries", 0)) + 1
            save(proposals())
            APPLIED["id"] = item.get("id")
            return item.get("lesson", "")
    return ""


def settle(worked):
    """Keep the lesson when the attempt worked; drop it when it did not."""
    ident = APPLIED.pop("id", None)
    if not ident:
        return ""
    kept, lesson = [], ""
    for item in proposals():
        if item.get("id") == ident:
            lesson = item.get("lesson", "")
        else:
            kept.append(item)
    save(kept)
    if worked and lesson:
        keep(lesson)
    return lesson


def keep(lesson):
    """Put a lesson that worked into lessons.md, and keep that file short."""
    stamp = time.strftime("%Y-%m-%d")
    entry = ("\n## A lesson from a failed turn\n"
             f"<!-- Ever: {stamp} — kept because it worked -->\n\n"
             f"{lesson.strip()}\n")
    try:
        with open(LESSONS, "a") as handle:
            handle.write(entry)
    except OSError:
        return ""
    prune()
    return lesson


def prune():
    """Drop the oldest lessons until lessons.md is short enough to read."""
    try:
        with open(LESSONS) as handle:
            text = handle.read()
    except OSError:
        return
    parts = text.split("\n## ")
    if len(parts) <= 1:
        return
    head, entries = parts[0], parts[1:]
    while entries and (len(entries) > LESSON_ENTRIES or
                       len(head) + len("\n## ".join(entries)) > LESSON_CAP):
        entries.pop(0)
    try:
        with open(LESSONS, "w") as handle:
            handle.write(head + "".join("\n## " + entry for entry in entries))
    except OSError:
        pass
