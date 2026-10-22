# The notch, in plain words

Ever's shell. A bar across the top of the screen, and an island that
drops out of it when you want something. It runs on niri, which is a
Wayland compositor, so "the top of the screen" is where the notch
lives.

## What is in the notch

**A catalogue.** Anime, films and series, with a picture on the cover.
Press one and it plays, and it plays in the island: the film is drawn in
the terminal, in colour, at the size of the island. There is no window
and no GPU. It works the same over a RustDesk session from an iPad,
because the picture is characters and the connection sends characters.

**The work.** Remote postings from four boards that publish them without
an account, and a table of the AI training platforms, with what each
pays and what they want before they will let you sign up. One press
hands one over: it goes on the clipboard, and T3 Code comes to the front.

**A launcher.** Everything installed, a calculator, a file finder, a
palette of commands, and a clipboard that keeps what you copy.

**A control centre.** The sound, the screens, the network, the battery,
the text size, the theme, the wallpaper, the corners of the windows, and
the plan for what each desktop holds.

**An orb.** A round thing on the bar you can open for the things you
use most.

## The two halves

The notch is the *device*. T3 Code, or any opencode agent, is the
*brain*. They talk through a small, documented surface: `qs ipc call`.
The agent can open the panels, change the theme, take a screenshot, and
read what the notch is showing. The notch can hand over what it knows.

That split is why the notch has no model in it. It is why the shell
starts in a second and stays up, and why the agent gets to be a good
agent instead of a shell with a model bolted on.

## The rules it keeps

- The machine is the install. `./setup files` copies the packages into
  `~`, and `tests/mirror.sh` checks the machine against the repository.
- No file grows past a size cap, and the ones over it may only shrink.
- The tests are the contract: `bar.sh` for the shell, `sweep.sh` for
  everything, `setup.sh` for the install, `correct.sh` for the mistakes
  that keep happening.
- The commit message is lowercase prose saying why.

## Where to go next

- [how.md](how.md) is the map, for changing it.
- [ipc.md](ipc.md) is the surface, for driving it.
- [decisions.md](decisions.md) is why it is shaped like this.
- [quickshell.md](quickshell.md) is the framework, and its sharp edges.
- [PARITY.md](PARITY.md) is how it scores against Natively's benchmark.
