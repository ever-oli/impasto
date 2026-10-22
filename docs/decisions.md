# Why the notch is shaped like this

The decisions that took an argument, and what settled them. A decision
that only lives in a chat is a decision the next reader has to make
again.

## The shell has no assistant in it

**The decision.** The notch used to have its own assistant: an ask panel,
a bridge to an engine, four engines to choose from, a memory of its own
mistakes, modes, and a harness that learned from them. All of that is
gone. The thinking happens next door, in T3 Code or any opencode agent,
and the notch hands over what it knows.

**Why.** The shell was becoming two things at once: a shell for Ever, and
a place to run a model. The second half cost the first. Every bug in the
bridge was a shell bug, and the shell is where the screen, the panels and
the media live. The agent is better at being an agent: it has delegation,
worktrees, scheduling, browser and MCP tools, and it is the thing that is
already running.

**The counter-argument, and why it does not win.** A shell with an
assistant in it is the Cluely shape: one keystroke, the screen as
context, the answer in the notch. That capability survives, but the place
changed. What is lost is the *place*, not the *capability*, and what is
gained is a shell that stays a shell.

**What settles it.** The parity bench. It measures the stack against
Natively's own tasks and rubric, and the numbers are in `PARITY.md`.

## The seam is the clipboard, and T3 in front

**The decision.** `notch context get` returns what the shell knows as
JSON. `notch context hand` puts that on the clipboard and opens T3 Code.
There is no API call into the agent, and no protocol.

**Why.** The notch should not depend on a particular agent being
installed, on a particular port, or on an API that moves. The clipboard
and a raised window are the oldest and most portable handoff there is,
and they work over RustDesk from an iPad, which is how Ever actually
reaches this machine.

**The cost, stated plainly.** It is a gesture, not an API. The agent has
to be *told* to read the clipboard, and nothing tells it. The skill says
the notch is a device it stands on, which is the honest version: the
notch can be driven, and it can hand over, but the loop between them is
the agent's judgement, not the shell's wiring.

**What would settle it.** A caller that does not need a human in the
loop: the agent starting a task, and the notch showing its result. Until
that exists, the seam is a handoff and not a pipe.

## The AI training platforms are a table

**The decision.** Outlier, Mercor, Handshake, Mindrift, Appen and TELUS
are a static list in `packages/media/scripts/jobs.py`, with their rates
and what they want before a sign-up. They are not fetched.

**Why.** None of them publishes a feed. Each wants an account, and the
useful thing about them is the same for all: the requirements. A table
cannot go stale in the way a scraper goes stale, and it does not pretend
to be a source of work when it is a source of *where to look*.

**The cost.** The rates and the requirements are as true as the day
somebody wrote them down. There is no date on the table, so a reader
cannot tell how old it is. That is the next thing to fix, and it is a
small thing: a date per row, and the bench will show whether anything
has moved.

## The media is the reason the repo exists

**The decision.** The catalogue plays in the island terminal, through
`mpv --vo=tct`. There is no window and no GPU.

**Why.** It is the one thing in the repo that no agent can do for itself.
An agent with a terminal can fetch a JSON feed. It cannot put a film on
the screen of a machine on the other side of a RustDesk session, in a
notch, with the shelf and the episode row and the resume point. The
device layer is not a role the shell plays; it is the thing the shell is.

**The counter-argument.** The media is also the part that depends on
third parties: the film's own api was down for part of one session, and
the upstream film source answered 523 more than once. A device layer that
depends on a source being up is a device layer with a hole in it.

**What settles it.** Both, and the answer is that the work band and the
platforms table do not depend on anything: four boards that publish
plain JSON, and a table of six platforms. The media is the best thing
here and the least reliable; the work band is the least impressive and
the most reliable. A device layer wants both.

## The tests check the shell's answers, not its behaviour

**The decision.** `bar.sh` opens every panel, calls every target and
checks each answer carries data. `sweep.sh` does the same and adds the
media. `setup.sh` installs into a home of its own. `correct.sh` holds
the mistakes that actually happened.

**Why.** The notch's whole surface is IPC and files. A check that calls
the surface is a check of the contract Ever and the agent depend on.

**What it does not check, said plainly.** Nobody has watched the notch
*be* the notch. A panel can open with the right data and the wrong
picture, a shelf can be laid out over the text, the terminal can play
without a frame. The checks prove the answers are right, not that the
thing is good. That is the gap a human eye closes, and it is the reason
there are three pictures in this repository.

**What settles it.** A verification skill that drives the shell the way
Ever does and looks at the result, which is what pstack's
`create-verification-skill` is for.
