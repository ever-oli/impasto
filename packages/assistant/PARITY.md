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
