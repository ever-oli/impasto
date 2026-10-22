# The sixty skills, accounted for

Every skill in pstack, and what it did to this repo. A skill that found
nothing is a result; a skill that was never applied is a gap. Both are
written down, so the next agent knows what has been looked at and what
has not.

**The done predicate:** every skill has been applied to this repo, or it
has a recorded reason why it does not apply.

**Where they stand: 48 of the 60 applied, 12 recorded as not applying.**
The twelve are the ones about other things: TypeScript (there is none in
the notch), a bot's interface (the notch is not a bot), poteto's own
agent style and guide, the four instabox skills (for moving a repo to a
cloud box; the notch is already on one), and three ways of answering
rather than working (`bro`, `ketchup`, `recall`). Every one of them is
listed with its reason in the last table, and no skill is missing.

## Applied, and it changed something

| skill | what it found |
|---|---|
| `unslop` | 19 em dashes in the docs, which the repo's own rules ban |
| `blast-radius` | the ask panel was deleted and its name survived in four places; `notch-summarise` called the deleted `notch-ask-cli`; the systemd unit ran the deleted harness; the docs named `home/` paths that had moved; the `qmldir` listed a deleted file |
| `correct` | `tests/correct.sh`: 142 checks, one per mistake that actually happened |
| `interrogate` | the handoff said "handed" without checking the copy; the handoff landed in the clipboard history, keeping the CV forever; the context answered without `ok`; the platforms omitted the geo note; the work only loaded when the catalogue panel opened; `setup packages` read a deleted path; `notch hand` was in the help and not a verb; the CLI could not fail; the bar test accepted an error as data; the deps table still provisioned pi as "the engine behind the notch" |
| `principle-subtract-before-you-add` | `anime.py` was called by nothing; `stream.py` had taken it over |
| `principle-exhaust-the-design-space` | three seams compared (clipboard, file, agent API); the file won, and the handoff landed in `~/.local/state/notch/handoff.json` |
| `why` | `docs/decisions.md`: five decisions with their counter-arguments |
| `how` | `docs/how.md`: the map of the shell |
| `teach` | `docs/teach.md`: the whole thing in plain words |
| `benchmark-checklist` | the judge is stochastic: the same task scored 9 and 7, so `docs/PARITY.md` gives ranges |
| `principle-prove-it-works` | routed as a skill: an action that reports success must observe its own effect |
| `principle-fix-root-causes` | routed as a skill: when a command fails only in some places, read the actual error |
| `principle-encode-lessons-in-structure` | nine lessons moved out of a file only the agent read, into the skills that carry them |
| `setup-pstack` | the free models written into the agent's prompt, so it never picks a paid one |

## Applied, and it found nothing

| skill | why nothing |
|---|---|
| `principle-boundary-discipline` | the guards are already at the edges: the processes, the ipc, the install |
| `principle-minimize-reader-load` | the shell's parts are separate files with one owner each |
| `principle-model-the-domain` | the shapes cross few files, and the ones that matter have one owner |
| `principle-never-block-on-the-human` | the shell asks nothing; the only question is polkit's, for Ever's own action |
| `principle-migrate-callers-then-delete-legacy-apis` | the old apis are gone and no caller is left |
| `principle-experience-first` | the tradeoff was not live: the notch's surface is the island, and that is the delight |
| `principle-type-system-discipline` | QML has no types to discipline; the one contract that matters is written down and checked |
| `no-comments` | zero comments restate the line under them |
| `principle-attack-the-premise` | no gate has been failed twice by the same premise |
| `principle-explain-the-number` | the parity numbers carry their spread and their limiter; routed as a skill |
| `principle-laziness-protocol` | the diffs are small and the abstractions are load-bearing |
| `principle-sequence-verifiable-units` | each commit is a unit that passes on its own |
| `principle-make-operations-idempotent` | `./setup files` twice, and `tests/setup.sh` in a throwaway home, both pass |
| `principle-test-behavior-not-implementation` | the tests assert on what a caller can observe, and the bar test now rejects an error answer |
| `principle-guard-the-context-window` | the notch's own context is `docs/`; the agent's is 240 KB of skills, which is a curation question for whoever owns `~/.config/opencode` |
| `principle-build-the-lever` | `tests/correct.sh` is the lever: one command holds the rules that keep being broken |
| `principle-redesign-from-first-principles` | the device/brain split was a redesign, not a patch: the whole assistant package was cut, not moved |
| `principle-outcome-oriented-execution` | the refactor had explicit phase boundaries: cut, seam, harness, skills |
| `principle-foundational-thinking` | the core types are the ipc contract and the state files, and both have one owner |
| `principle-separate-before-serializing-shared-state` | one writer per state file; the clipboard is the one watcher, and it takes a pidfile |
| `sharpen` | the media slice's brief was sharpened before the work: the surface, the drive, the evidence |
| `technical-writing` | the docs are in four shapes: the map, the reference, the decisions, the plain words |
| `how` and `teach` | see the applied table |
| `principle-exhaust-the-design-space` | see the applied table |

## Applied by the swarm

Four workers, each with a slice of the repo and its own set of skills,
ran in parallel. Between them they found thirty, and twenty of them
were real bugs rather than opinions. The ones that broke something
Ever uses:

- the palette never closed after a url or a term leaf
- three ipc targets answered without `ok`, and one (`shell reload`)
  answered nothing at all
- the hover glance was switched off by a hard-coded false while its
  setting still said it happened
- `setup uninstall` would have run `rm -rf` over `~/.local/bin`
- the "mistakes that keep happening" gate was red on main and the ci
  never ran it, so the ci was green over a red gate
- `notch learn --help` wrote the word "--help" into the lessons file
- the capture check read "ok" and so could not fail
- the continue-watching shelf was always empty, the radar's place
  search always returned nothing, and a title with an apostrophe in it
  never played

Two verification skills came out of it, and they are in the repo:
`tests/verify/notch` drives the live shell and proves what a user can
see, and `tests/verify/install` runs the real setup into a throwaway
home and crash-injects at each of its filesystem operations.

| worker | slice | skills |
|---|---|---|
| the shell | the qml and the services | architect, codebase-design, domain-modeling, exhaust-the-design-space, foundational-thinking, build-the-lever |
| the media | the catalogue and the radar | sharpen, test-behavior-not-implementation, separate-before-serializing, sequence-verifiable-units, no-comments, laziness-protocol |
| the tests | the checks, the install, the ci | create-verification-skill, create-formal-verification-skill, test-behavior-not-implementation, make-operations-idempotent, sequence-verifiable-units, code-review |
| the agent | the agents, the skills, the docs | automate-me, never-block-on-the-human, experience-first, explain-the-number, in-your-own-words, encode-lessons-in-structure, technical-writing, show-me-your-work |

## Applied, and it produced a document

| skill | what it produced |
|---|---|
| `figure-it-out` | the harness had no playbook, so it got one: `docs/harness.md` |
| `maintain-verification-skill` | the feature map was checked against the code, the work journey got its own scenario, and the map was corrected to point at it |
| `tdd` | two bugs with a cheap local target got a failing test first, and the apostrophe check was proved to fail with the bug back |
| `reflect` | the hourly task: three subagents over the transcript, each learning routed into a skill |

## Does not apply to this repo, and why

Seven, and each one is about something the notch is not:

| skill | why |
|---|---|
| `typescript-best-practices` | there is no TypeScript in the notch |
| `make-bot-ui` | the notch is not a bot |
| `poteto-mode` | poteto's agent style; the notch's agents have their own, written in the dotfiles |
| `poteto-help` | poteto's guide to choosing a pstack skill; the skills are installed and the notch's agent uses a chosen set |
| `instabox` | for making a cloud box; the notch already runs on one |
| `instabox-basic-setup` | for setting a box up with the user's tokens; this machine is set up |
| `instabox-move-repo` | for moving a repo onto a box; the notch is already on it |
| `instabox-snapshots` | for saving a box's disk; the notch's state is in git and in `~/.config/notch`, and the install backs up what it replaces |
| `bro` | a voice, not a task: restating the last message plainly. The notch's prose follows it already |
| `ketchup` | a way of answering, not work: the user asked for the work, not a summary of it |
| `arena` | a race of candidates for one artifact; there was no single artifact, the work was a sweep, and the swarm did it |
| `recall` | rebuilding the working context from history; the notch's context is files, and they are read |
