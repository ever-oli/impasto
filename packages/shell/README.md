# The shell

The quickshell app: the bar, the island, the panels, the theme.

It is one package because the panels and the services are one thing: they
import each other by name, so they live in one tree.

    quickshell/  →  ~/.config/quickshell/

The `install` file says where each of its files lands; `./setup files`
follows it.
