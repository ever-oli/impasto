---
name: verify-state-files
description: "Check that the notch's state files are written whole, so a reader never sees half a file. Use when touching anything that writes a state file - the watch history, the clipboard store, the release cache, the handoff - and before declaring a write safe."
---

# Verify the state files

The notch's shell reads its state while other things write it: the watch
history is written four times a second while the island shows the shelf,
the settings are written on every change while the panel reads them, and
the handoff is written while an agent reads it.

**The promise:** a reader never sees a half-written file. It sees the old
whole file or the new whole file, never a prefix of the new one. A
half-written JSON file is a broken file, and a broken file in the shell's
own state is a shell that shows nothing.

**How to check it:**

```sh
python3 tests/verify/formal/statefile.py
```

Exit 0 means the promise holds for the writers it covers.

**What it does.** It finds the writers itself, rather than trusting a
list, so a script that starts writing a state file cannot slip past.
For each one it checks that the write goes through a temporary file and
is renamed over the target. Then it enumerates every ordering of a write
and a read, checking the property at each point, and runs a broken
variant of the same model to show the check can fail.

**When it fails**, the failure names the file and the line. A writer
that opens the target directly and dumps into it breaks the promise.
The fix is the idiom the other writers use:

```python
temporary = path + ".new"
with open(temporary, "w") as handle:
    json.dump(state, handle)
os.replace(temporary, path)
```

**What it does not cover.** The shell's own `FileView` writes (the
settings, the playing state, the emoji history) are Quickshell's, and
Quickshell does not write them through a temporary. The check says so
rather than pretending. If a reader of one of those files breaks, the
fix belongs upstream or in a shell-side reader that tolerates a bad
parse.

**Coverage.** `packages/media/bin/notch-subs`,
`packages/shell/quickshell/scripts/clipboard.py`,
`packages/shell/quickshell/scripts/t3.py`. Last confirmed in step with
the code at commit `f710da8`. When the code those files change after
that commit, run the check again and move the commit forward only once
it says the check still describes them.
