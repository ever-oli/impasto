"""ask_box — the notch assistant's cloud engine: an instabox machine.

A box is a Linux VM in the cloud (instabox.sh, Apache-2.0). The question
goes there over the instabox CLI, the box's own agent answers, and the
answer comes back the same way — so a heavy job runs off the laptop
while the bar keeps answering.

The prompt travels on the command's standard input (the CLI allows a
megabyte), and the answer is what the agent printed. The agent inside
the box is whatever ASK_BOX_AGENT names; `claude -p` and `codex` are
already installed on the agent-browser template, and each needs to be
logged in once, inside the box.

  ask_box.py "the question"          print the answer
  ask_box.py --stream "the question"  print it as it arrives
"""

import os
import subprocess
import sys

BOX = os.environ.get("ASK_BOX", "notch")
# The agent inside the box. `claude -p` and `codex` are installed on the
# agent-browser template; each needs a login in the box once (the box's
# own opencode works too, but wants a terminal for its first run).
AGENT = os.environ.get("ASK_BOX_AGENT", "claude -p")
CWD = os.environ.get("ASK_BOX_CWD", "/data/workspace")
TIMEOUT = int(os.environ.get("ASK_BOX_TIMEOUT", "600"))
CLI = os.environ.get("INSTABOX_CLI", "instabox")


def command(prompt):
    """The CLI call: the prompt on stdin, the agent's words on stdout."""
    return [CLI, "exec", BOX, "-stdin", "-cwd", CWD, "-timeout", str(TIMEOUT),
            "--"] + AGENT.split()


def ask(prompt, on_line=None):
    """Ask the box. on_line, if given, hears the answer as it arrives."""
    try:
        proc = subprocess.Popen(command(prompt), stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, bufsize=1)
    except FileNotFoundError:
        raise RuntimeError("the instabox CLI is not on the path")
    try:
        proc.stdin.write(prompt)
        proc.stdin.close()
    except BrokenPipeError:
        pass
    said = []
    for line in proc.stdout:
        line = line.rstrip("\n")
        if line:
            said.append(line)
        if on_line:
            on_line(line)
    code = proc.wait()
    if code:
        # The box's agent says why (it may not be logged in yet); say that.
        why = said[-1] if said else f"the agent exited {code}"
        raise RuntimeError(f"the box's agent: {why}")


if __name__ == "__main__":
    stream = "--stream" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--stream"]
    question = args[0] if args else "Say hi."
    if stream:
        ask(question, lambda line: print(line, flush=True))
    else:
        ask(question, lambda line: print(line))
