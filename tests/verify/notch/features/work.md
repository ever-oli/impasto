# The work and the platforms

## Sub-features

- `work get` answers with the postings on the shelf, the count and the first
  one.
- `work platforms` answers with the AI training platforms and their rates.
- `work platform <name>` answers with one platform's requirements.
- The platforms carry the geo note: the rule that decides who can sign up.
- The work loads without the catalogue panel being open.

## How to get to it (user POV)

The palette has a "Work" entry, and the agent reads the same data through
`notch work get`. The user does not have to open anything.

## Driving it with the helper

```sh
tests/verify/notch/notch-drive.sh context <evidence-dir>
```

The `context` scenario checks that `context get` carries the work. The
platforms need their own assertions, which are in the raw calls:

```sh
qs ipc call work get
qs ipc call work platforms
qs ipc call work platform Outlier
```

`work platform Outlier` must answer with `requirements` and the name.

## Gotchas

- The work band is fetched from boards that publish plain JSON, and the
  platforms are a static table in `packages/media/scripts/jobs.py`. The
  postings can be empty when a board is down; the platforms never are.
  A proof that needs postings has to say which board it read.
- `work platform` takes a **name**, not an index: `work hand` takes an
  index. The two are easy to swap.
- The geo note lives on the platforms answer (`platformNote`). It is the
  rule that decides who can open an account; a verification that checks
  only the names has dropped it.
- The work is loaded by the config root at startup, so `work get` answers
  even when no panel has ever been opened. A check that opens the catalogue
  first cannot prove that.
