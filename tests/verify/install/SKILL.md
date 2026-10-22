---
name: verify-install
description: "Check that ./setup install and uninstall keep the properties they promise: a crash at any step recovers, the manifest never names a path that is not there, the uninstall removes the notch and nothing else, and two installs land on the same tree."
---

# Verify the install

`./setup files` copies the packages into `$HOME` per their `install`
manifests, and `./setup uninstall` takes them back out. Both are
promised to be safe, and this checks the promises against the real
script rather than against a description of it.

```sh
tests/verify/install/verify-install.sh ~/src/notch
```

**What it proves.** It runs the real installer into a throwaway `$HOME`,
crash-injecting at each of the filesystem operations in turn, and checks
four properties:

- **P1 convergence**: a crash at any of the points recovers to a clean
  tree, so a half-finished install is never left behind.
- **P2 honesty**: the manifest never names a path that is not there.
- **P3 uninstall**: it removes the shell and the cli, exits 0, and
  leaves everything else in `$HOME` alone. The user's own programs in
  `~/.local/bin` are not the notch's to delete.
- **P4 idempotence**: two installs land on the same tree as one, and
  the manifest is the same after both.

**It can fail.** A variant that writes the manifest before copying it
flips P2; one that skips existing files flips P1. A check that cannot
fail is not a check.

Every `$HOME` here is a throwaway. Nothing touches the real one.
