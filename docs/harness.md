# The harness, hourly

The agent that works on this repo reflects on its own turns once an hour,
writes down what would have made the answers better, and puts each
lesson where it will be read. It is a scheduled task in the app, and this
is its playbook, so the steps are in the repository and not only in the
scheduler.

## The loop

1. **Read the ground rules** first: `~/.config/opencode/skill/notch/modes/_rules.md`.
   They decide what an answer may claim.
2. **Read the recent turns**: the questions asked in this project and the
   answers that came back. The shell's own history is
   `~/.local/state/notch/ask-history.jsonl`; the agent's is the app's
   thread.
3. **Propose at most three lessons.** A lesson is one line of plain
   instruction, not a story: what to do, or what to avoid, that would
   have changed an answer.
4. **Test each one against the turns.** Would it have changed an answer
   that went wrong? If not, drop it. If a lesson was proposed before and
   the answers since are better, keep it; if they are not, drop it.
5. **Route each survivor** to where it will be read:
   - generalises beyond this project → a skill, in `~/.agents/skills/`
   - specific to the notch → `~/.config/opencode/skill/notch/SKILL.md`
   - about the work in progress → `~/.config/notch/lessons.md`
6. **Keep the file small**: under 16 KB, no more than 40 lessons. If
   nothing survives, change nothing.

## Why the routing matters

A lesson in a file nobody opens until they are stuck is a note, not a
correction. The mise shim bit me three times in one session with the
lesson written down the whole time, because the lesson was in a file
that was read at the start of a turn and not during one. The lessons
live in the skills now, and the skills are read before the work.

## What it has produced

Nine lessons so far, all routed: the flag the command line never sets,
the pkill that killed the session doing the killing, the removed thing
that left its name behind, the check written from a remembered fact, the
copy that guessed a name, the partial answer presented as complete, the
command that failed only in some directories, the promise with no
check-back, and the mise shim.

Three of them became structure rather than text: `tests/correct.sh`
holds the ones that are about the repo, `tests/regressions.sh` holds the
bugs that were found, and the two pstack skills carry the ones that
generalise.

## The task itself

It is a scheduled task in the app, hourly, bound to this project. Its
prompt is the loop above. When it changes, this file changes with it:
the prompt is the only copy that lives in the repository, and the
scheduler is the only copy that runs.
