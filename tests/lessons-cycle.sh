#!/bin/sh
# The harness's memory: a lesson is proposed, the next attempt of the
# same question carries it, a lesson that works is kept, a lesson that
# fails again is dropped, and lessons.md is pruned when it grows.
#
# Runs against the repo's script, in a throwaway directory.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$root" "$work" <<'PY'
import importlib.util
import os
import sys

root, work = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location(
    "ask_lessons", os.path.join(root, "packages/assistant/scripts/ask_lessons.py"))
lessons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lessons)

checks = []


def check(name, condition):
    checks.append((name, bool(condition)))


# The paths are Ever's own.
check("the lessons live in the config",
      lessons.LESSONS.endswith("/.config/notch/lessons.md"))
check("the proposals live in the state",
      lessons.PROPOSALS.endswith("/notch/proposals.json"))

# Work in a throwaway place.
lessons.LESSONS = os.path.join(work, "lessons.md")
lessons.PROPOSALS = os.path.join(work, "proposals.json")

# A failed turn proposes a lesson; it waits in proposals.json.
lessons.propose("How do I open a file?", "Ask for the path before reading it.")
check("the proposal waits", len(lessons.proposals()) == 1)
check("it is not in lessons.md yet", not os.path.exists(lessons.LESSONS))

# The next attempt of the same question carries it; another one does not.
check("the same question gets it",
      lessons.candidate("how do I OPEN a file!") ==
      "Ask for the path before reading it.")
check("a general lesson rides every question",
      lessons.candidate("what is the weather") == "Ask for the path before reading it.")

# The attempt works: the lesson moves into lessons.md.
lessons.settle(True)
check("the lesson was kept", "Ask for the path" in open(lessons.LESSONS).read())
check("the proposal is gone", lessons.proposals() == [])

# A lesson for one question only stays with that question.
lessons.propose("One question only", "A specific lesson", scope="specific")
check("a specific lesson rides its own question",
      lessons.candidate("one question only") == "A specific lesson")
check("a specific lesson stays off the others",
      lessons.candidate("what is the weather") == "")
lessons.settle(True)
check("the specific lesson was kept",
      "A specific lesson" in open(lessons.LESSONS).read())

# The attempt fails again: the lesson is dropped, not kept.
lessons.propose("Second question", "This lesson is wrong.")
lessons.candidate("Second question")
lessons.settle(False)
check("the bad lesson was dropped",
      "This lesson is wrong" not in open(lessons.LESSONS).read())

# lessons.md is Ever's file: it is pruned.
for number in range(60):
    lessons.keep(f"Lesson number {number} " + "x" * 300)
text = open(lessons.LESSONS).read()
check("the file stays short", len(text) <= lessons.LESSON_CAP)
check("the newest lessons are kept", "Lesson number 59" in text)
check("the oldest are dropped", "Lesson number 0 " not in text)
check("the shape holds", text.count("## A lesson") == text.count("<!-- Ever:"))

failed = [name for name, good in checks if not good]
for name, good in checks:
    print(f"{'ok  ' if good else 'FAIL'} {name}")
if failed:
    sys.exit(f"{len(failed)} of {len(checks)} checks failed")
print(f"{len(checks)} checks passed")
PY
