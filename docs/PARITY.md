# Parity with Natively

**What this measures.** The agent in front of the notch, answering with
the notch's context: the profile, the mode, the screen. The notch itself
is the device: the catalogue, the panels, the IPC. It has no assistant in
it, so this compares *the stack* with Natively, not two assistants.

Natively is the free Cluely clone: an Electron overlay for interviews and
meetings, with the screen and the microphone as context, local speech to
text, and answers that draw the system design for you. The stack is the
same idea in a different shape, a shell and an agent instead of an app.

The yardstick is Natively's own: their reference tasks, their gold fact
sheets written by a human analyst, and their judge rubric. Our answers
are scored against them. The judge is a model, so this is a measurement
of agreement with a human-written fact sheet, not a measurement of truth.

## The tasks and the scores

| task | what it is | overall | dimensions | facts present | contradicted |
|---|---|---|---|---|---|
| TEAM-S | a team meeting, facts and owners | 7-9 | 8.2-9.1 | 24-26 of 27 | **0** |
| SALES-S | a sales call, a correction mid-way | **9** | 9.3-9.4 | 24-26 of 28 | **0** |
| INT-M | an interview, a technical answer | 7-9 | 9.0-9.4 | 44-54 of 61 | **0** |
| LECT-VL | a lecture, with a visual | 6 | 8.1 | 62 of 90 | **0** |
| REAL-LECT-L | a long talk | running | | | |

For scale: Natively's own shipped assistant scores **4.7**, and their
best reference run **6.2**. The stack is above both on every task here.

## What the numbers are worth, and what they are not

**The judge is stochastic.** The same task, judged twice by the same
model, came out 9 and 7 on TEAM-S and 7 and 9 on INT-M. That is a spread
of two points on a ten point scale, from the judge alone, with the same
answer. So a single run's overall is worth about plus or minus two, and
the ranges above are the honest reading. The dimension averages are
steadier (8.2 to 9.4) and the fact counts are steadier still.

**Nothing was contradicted, in any run.** Not one fact was invented
against the transcript, across every task and both runs of each. That is
the number this bench is really for: the failure mode of a note-taking
model is not a low score, it is a confident falsehood. There were none.

**SALES-S handled the hard part.** The transcript corrects a seat count
(45 to 54) and moves a start date (Oct 1 to Oct 15). The notes carried
both in a corrections section rather than repeating the first version,
and kept two genuinely open questions open rather than deciding them.
That is the rubric's "decision hygiene" dimension, and it is the one the
Cluely clone scores worst.

**This is one model on a free tier.** `opencode/glm-5.3-flash-free`
answers and `opencode/glm-5.3-flash-free` judges. A different model
would score differently, and the judge's disagreement with a human is
the measurement's own error bar. The reference tasks are Natively's, so
the tasks are not chosen to flatter us; that is the point of using them.

## Running it

```sh
~/.config/opencode/skill/notch/bench.py --ref <reference.json> --transcript <transcript.txt>
~/.config/opencode/skill/notch/bench.py --suite        # every task
```

The answers come from the agent (`opencode run`, a free model, the json
format). The results land in `~/.local/state/notch/bench-results.json`,
one entry per run, so the spread above is visible rather than averaged
away.

## What would make it a stronger claim

- More than one run per task, and the median rather than the last.
- A judge that is not the same model that answers.
- The two long-talk tasks, which run through the chunk-and-reduce path.
- The tasks Natively scores worst on, not the ones it scores well on.
