# What the skills found

A pass over the notch with pstack's sixty skills, and what each one
said. The point of the list is that the next agent does not have to run
sixty skills to know what is wrong: it reads this and knows where to
look.

## The findings that were real, and what fixed them

| skill | finding | fix |
|---|---|---|
| `blast-radius` | the ask panel was deleted and its name survived in four places, and the user found it by clicking | `tests/correct.sh` greps for it |
| `blast-radius` | `notch-summarise` called the deleted `notch-ask-cli` | it asks the agent now |
| `blast-radius` | the systemd unit ran the deleted `notch-harness` | the unit is gone |
| `blast-radius` | the docs named `home/` paths the refactor had moved | every path a doc names is checked |
| `blast-radius` | the `qmldir` listed `AskPanel`, whose file was deleted | the line is gone |
| `correct` | the rules were written down but nothing stopped them recurring | `tests/correct.sh`, 142 checks |
| `interrogate` | the handoff said "handed" whether or not the copy worked | the copy is a process with an exit code |
| `interrogate` | the handoff landed in the clipboard history, keeping the CV forever | it is marked, and the watcher skips it |
| `interrogate` | `context get` and the work answered without `ok` | every answer carries it now |
| `interrogate` | the platforms omitted the geo note, the rule that decides who can sign up | the note travels with them |
| `interrogate` | the work only loaded when the catalogue panel opened | the config root asks for it at startup |
| `interrogate` | `setup packages` read a deleted path, so a fresh machine installed nothing and said all present | it reads the table that exists |
| `interrogate` | `notch hand` was in the help and was not a verb | the help names real verbs |
| `interrogate` | `qs ipc call` exits 0 on an error, so the CLI could not fail | the CLI fails now |
| `interrogate` | the bar test accepted an error as data | the check looks for the error |
| `interrogate` | the deps table still provisioned pi as "the engine behind the notch" | the table says what the machine needs |
| `interrogate` | I claimed the media was the biggest thing; it is 4% of the code | `docs/decisions.md` says so |
| `principle-subtract-before-you-add` | `anime.py` was called by nothing: `stream.py` took it over | deleted |
| `principle-subtract-before-you-add` | the shell named the agent in its comments and its binds | it says what it does now |
| `unslop` | 19 em dashes in the docs, and the repo's own rules ban them | out of the prose, and counted |
| `benchmark-checklist` | the judge is stochastic: the same task scored 9 and 7 | `docs/PARITY.md` gives ranges, not a number |
| `why` | the decisions lived only in a chat | `docs/decisions.md` |
| `how` | nobody could find the shell's shape | `docs/how.md` |
| `teach` | the whole thing was undocumented in plain words | `docs/teach.md` |

## The skills that changed nothing, and why

- **`principle-prove-it-works`, `principle-fix-root-causes`,
  `principle-boundary-discipline`, `principle-idempotent`,
  `principle-minimize-reader-load`, `principle-model-the-domain`**:
  the shell passes them already. The guards are at the edges, the
  commands are re-runnable (`setup files` twice, `setup.sh` in a
  throwaway home), the tests assert on what a caller can see, and the
  domain shapes cross few files.
- **`principle-never-block-on-the-human`**: the shell asks nothing. The
  only question it ever asked was "may I have root", and that is
  polkit's.
- **`principle-type-system-discipline`**: QML has no types to
  discipline, and the one signature that matters (the IPC contract) is
  written down in `docs/ipc.md` and checked by the tests.
- **`no-comments`**: zero comments restate the line under them.
- **`principle-guard-the-context-window`**: the finding is real but the
  fix is the agent's, not the repo's. The notch's own context is
  `docs/`, and the agent's is 240 KB of skills, which is a curation
  question for whoever owns `~/.config/opencode/`.

## What is still open

- **The clipboard history still keeps everything Ever copies**, which is
  what it is for. The handoff is excluded, and that is all.
- **The bench's two long tasks** run through the chunk-and-reduce path
  and take a while.
- **The seam is still a handoff, not a pipe.** Nothing tells the agent
  that the notch has something for it.
- **Nobody has watched the notch be the notch.** The checks prove the
  answers are right; a human eye proves the picture is.
