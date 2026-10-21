# Parity with Natively

Natively is the free Cluely clone: an Electron overlay for interviews and
meetings, with the screen and the microphone as context, local speech to
text, and answers that draw the system design for you. The notch's
assistant is the same idea in a different shape — a shell instead of an
app — so the comparison is worth writing down.

## The two side by side

| | Natively | The notch |
|---|---|---|
| the surface | an Electron overlay, always on top, transparent, click-through | the island's ask panel — a surface of the shell itself |
| the context | the screen **and** the microphone | the screen (a screenshot, with its OCR read into the question); no microphone |
| speech | Parakeet, local, on the machine | none |
| modes | six, detected from the conversation | five, chosen: general, notch, lecture, technical-interview, looking-for-work |
| drawn answers | "Visual Answers" — the system design, drawn | a chart, a mermaid diagram or a QML component, drawn in the answer |
| the models | cloud keys (DeepSeek, GPT) or local ones | free ones only: opencode's free tier, Pi, and the Cua driver for the desktop |
| the memory | none — Parakeet keeps the history, the overlay is stateless | `lessons.md`, and a harness that rewrites itself from what failed (Harness²) |
| the reach | a browser extension, a hosted API, a desktop app for Mac and Windows | the shell: one machine, one key, no account |
| the checks | a benchmark harness with a judge loop over six model configurations | `tests/assistant-eval.sh` — seven checks, each one a fact |

## What the notch does that Natively does not

- **The assistant improves its own harness.** A failed turn proposes one
  change; the change is composed into a candidate; the same question is
  asked again; the change is kept only if the answer got better. Natively's
  overlay is stateless by design; ours has a memory that argues with
  itself.
- **The drawn answer is sandboxed.** A QML component an agent wrote runs
  in a bubblewrap jail: no network, and only the Qt Quick modules a
  picture needs. The shell's colours are handed to it, so the picture
  looks like the rest of the shell.
- **The context is the whole desktop.** Not a screen and a microphone,
  but a shell that can be asked to act on the machine, with every action
  shown to you first.

## What the notch does not have

- no microphone, and so no live conversation
- no meeting notes, no transcripts
- no modes detected from what is being said — they are picked
- no browser extension and no hosted API
- no Mac and Windows builds: it is a niri shell, and it is the notch

## The eval

`tests/assistant-eval.sh` asks the assistant the questions it exists to
answer and checks each one by the thing itself, not by reading the text
and hoping: the engine for an answer, the renderer for a picture, the
memory for a lesson, the gate for the tools.

## The bench, on their own tasks

`tests/assistant-bench.py` is the harder version: it takes Natively's
reference tasks — the transcript, the human-written gold fact sheet and
their judge rubric — and puts our answers through the same judge. It is
the only fair way to ask "as well as Natively" without running their
Electron app.

    NATIVELY_BENCH=.../benchmark python3 tests/assistant-bench.py \
        --ref .../references/TEAM-S.json --transcript .../transcripts/src/TEAM-S.txt

| task | ours | facts present / partial / missing | Natively, best of six | Natively, their current setup |
|---|---|---|---|---|
| TEAM-S | **8.0** | 27 / 2 / 0 | 7.0 | 5.7 |
| SALES-S | **9.0** | 25 / 1 / 2 | 8.3 | 5.7 |
| INT-M | **7.0** | 35 / 17 / 9 | 4.3 | 3.3 |

Ours, on their tasks, with their rubric: 8.0 average. Theirs, on the
same tasks: 6.5 at their best, 4.9 in the configuration they ship.
No contradictions on any of the three.

Three caveats, stated plainly: the judges are different models (a free
one here, Gemini 3.1 Pro there), so the scales are not identical; our
pipeline is one pass where theirs chunks and reduces; and our judge
shares a family with our answer, which flatters us. Three tasks is
three tasks — their suite is eleven.
