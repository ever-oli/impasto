// written by notch-theme from themed/fastfetch.jsonc.tpl
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "small", "color": { "1": "{{ accent_ansi }}", "2": "{{ foreground_ansi }}" } },
  "display": { "color": { "keys": "{{ accent_ansi }}", "title": "{{ accent_ansi }}", "output": "{{ foreground_ansi }}" }, "separator": "  " },
  "modules": ["title", "separator", "os", "kernel", "uptime", "packages", "shell", "wm", "terminal", "cpu", "memory", "disk", "colors"]
}
