# mov-cli, vendored

`mov-cli` (MIT) is unmaintained upstream: the author stepped away in
October 2025 and the v4.5 rewrite never landed. The notch keeps its own
copy so the tool can be kept alive here, where it is useful.

- Upstream: https://github.com/mov-cli/mov-cli, branch `v4`
- Pinned at: `13399f9` ("fix: remove ruff test for python 3.8", 2025-10-05)
- License: MIT (see `LICENSE`)

## How it is used

`notch-mov` makes a venv out of mise's Python 3.12 (the newest the code
supports) and installs this copy into it, then opens the island terminal
with `mov-cli` in it. The venv lives at `~/.local/share/notch/mov-cli/.venv`
and is not in the repository.

## Keeping it alive

This is the copy that runs, so fixes land here:

1. Patch `mov_cli/` in this directory.
2. Reinstall: `~/.local/share/notch/mov-cli/.venv/bin/pip install -e .`
   from this directory, or `notch-mov install`.
3. Keep a note of what changed, so the next upstream pull is a merge and
   not a mystery.

To pull upstream again: fetch `v4`, diff `mov_cli/` against this copy,
and take what still applies.
