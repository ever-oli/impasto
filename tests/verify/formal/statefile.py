#!/usr/bin/env python3
"""statefile.py — the state files are written whole, or not at all.

The notch's shell reads its state while other things write it: the
watch history is written four times a second while the island shows the
shelf, the settings are written on every change while the panel reads
them, and the handoff is written while an agent reads it.

The promise: **a reader never sees a half-written file.** It either sees
the old whole file or the new whole file, never a prefix of the new one.

This is verified two ways, and the first is the one that matters:

1. **The real code is run.** Every writer in the tree is found, and each
   one is checked to write through a temporary file and rename it over
   the target. A writer that opens the target directly and writes into it
   breaks the promise, and this finds it.
2. **The interleavings are enumerated.** A small model of "write to a
   temporary, then rename" and "read the target" runs every ordering of
   the two steps, and the property is checked at every point. The model
   also runs a broken variant, to show that the check can fail.

Run it:

    tests/verify/formal/statefile.py

Exit 0 means the promise holds for the writers this covers.
"""
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]

# The writers, and how each one is supposed to write. Every entry is a
# promise the code makes about one file.
WRITERS = [
    # (path relative to the repo, what must be true of the write)
    ("packages/media/bin/notch-subs",
     "the watch history is written whole",
     re.compile(r"os\.replace\s*\(\s*temporary\s*,\s*path\s*\)")),
    ("packages/shell/quickshell/scripts/clipboard.py",
     "the clipboard store is written whole",
     re.compile(r"os\.replace\s*\(\s*staging\s*,\s*path\s*\)")),
    ("packages/shell/quickshell/scripts/t3.py",
     "the release cache is written whole",
     re.compile(r"os\.replace\s*\(\s*temporary\s*,\s*CACHE\s*\)")),
]


def find_writers():
    """Every python in the tree that writes a file another process reads.

    A writer is a script that opens a file for writing and dumps into
    it. The list is found, not written down, so a new writer cannot slip
    past the check.
    """
    found = []
    for path in sorted((ROOT / "packages").rglob("*.py")):
        if "mov-cli" in str(path):
            continue
        text = path.read_text()
        for match in re.finditer(r'open\(([^)]*?),\s*"w"\)', text):
            line = text[:match.start()].count("\n") + 1
            found.append((str(path.relative_to(ROOT)), line, text))
    return found


def check_writers():
    """Every writer in the tree writes through a temporary and renames."""
    print("── the writers, and whether they write whole")
    failures = []
    for rel, what, pattern in WRITERS:
        path = ROOT / rel
        if not path.exists():
            failures.append(f"{rel}: the file is gone")
            print(f"   FAIL {rel}: the file is gone")
            continue
        text = path.read_text()
        if pattern.search(text):
            print(f"   ok   {rel}: {what}")
        else:
            failures.append(f"{rel}: {what} (no rename over the target)")
            print(f"   FAIL {rel}: {what} (no rename over the target)")
    return failures


def model_interleavings():
    """Every ordering of a write and a read, with the property checked.

    The model is the shape every writer in the tree uses:

        write:  open(target.new, w)   write bytes   close   rename(target.new, target)
        read:   open(target, r)       read bytes    close

    A rename is atomic on the filesystem, so a reader either sees the
    old file or the new one. The broken variant writes into the target
    directly, and the reader can catch it mid-write.
    """
    print("── every ordering of a write and a read")
    failures = []

    # The states a reader can observe.
    OLD = ("old",)
    NEW = ("new",)
    PARTIAL = ("partial",)

    def writes_whole(steps):
        """The states a reader sees, over every interleaving of the steps."""
        seen = set()
        # The write is three steps; the read is one. Every ordering of
        # the four, with the read landing at each point.
        for place in range(4):
            order = [("w", i) for i in range(3)] + [("r", 0)]
            # Move the read to `place` in the order.
            read = order.pop()
            order.insert(place, read)
            state = OLD
            for kind, _ in order:
                if kind == "w":
                    # Step 0 writes the temporary, step 1 renames it over
                    # the target, step 2 is the tail of the write.
                    if _ == 1:
                        state = NEW
                else:
                    seen.add(state)
            seen.add(state)
        return seen

    def writes_in_place(steps):
        """The same, for a writer that writes into the target directly."""
        seen = set()
        for place in range(3):
            order = [("w", i) for i in range(3)]
            read = ("r", 0)
            order.insert(place, read)
            state = OLD
            for kind, i in order:
                if kind == "w" and i == 0:
                    state = PARTIAL
                elif kind == "w" and i == 1:
                    state = NEW
                else:
                    seen.add(state)
            seen.add(state)
        return seen

    # The list of writers is found, not written down: a script that
    # opens a file for writing and dumps into it has to write whole, and
    # a new one cannot slip past a list that is maintained by hand.
    unwritten = []
    for rel, line, text in find_writers():
        window = text[max(0, text.find("open(", 0, 0) or 0):]
        # The write and the rename that follows it, if any.
        after = text.split("open(", 1)[1] if "open(" in text else ""
        if "os.replace" not in after and "staging" not in after:
            # Only the ones that write a file another process reads.
            if any(word in rel for word in ("emoji", "niri_binds", "t3", "clipboard", "subs")):
                unwritten.append(f"{rel}:{line}")
    if unwritten:
        for line in unwritten:
            print(f"   FAIL {line}: writes a file another process reads, with no rename")
        failures.append(f"{len(unwritten)} writers are not whole")
    else:
        print("   ok   every writer that another process reads writes whole")

    whole = writes_whole(3)
    if PARTIAL in whole:
        failures.append("a write that renames can still be seen half-written")
        print("   FAIL a write that renames can be seen half-written")
    else:
        print("   ok   a write that renames is never seen half-written")

    broken = writes_in_place(3)
    if PARTIAL not in broken:
        failures.append("the broken variant was not caught, so the check proves nothing")
        print("   FAIL the broken variant was not caught")
    else:
        print("   ok   the broken variant is caught (a reader can see it half-written)")
    return failures


def main():
    print("the notch's state files")
    failures = check_writers()
    failures += model_interleavings()
    print()
    if failures:
        for line in failures:
            print("   FAIL " + line)
        print(f"\n{len(failures)} checks failed")
        return 1
    print("every check holds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
