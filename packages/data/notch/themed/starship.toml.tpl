# written by notch-theme from themed/starship.toml.tpl
add_newline = false
format = "$directory$git_branch$git_status$cmd_duration$line_break$character"
palette = "notch"

[palettes.notch]
accent = "{{ accent }}"
muted = "{{ muted }}"
fg = "{{ foreground }}"
ok = "{{ green }}"
err = "{{ red }}"
warn = "{{ yellow }}"

[directory]
style = "bold accent"
truncation_length = 3

[git_branch]
symbol = " "
style = "muted"
format = "[$symbol$branch]($style) "

[git_status]
style = "warn"

[cmd_duration]
style = "muted"

[character]
success_symbol = "[❯](accent)"
error_symbol = "[❯](err)"
