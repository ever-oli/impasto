"""ask_extras — what ask.py adds around a question: modes, the profile,
reference files, the browser page, and pictures rendered from the answer."""
import glob, tempfile, hashlib, json, os, re, sqlite3, subprocess, urllib.request

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", f"{HOME}/.config") + "/notch"
CACHE = os.environ.get("XDG_CACHE_HOME", f"{HOME}/.cache") + "/notch/ask"
PROFILE_CAP, FILES_BUDGET = 8000, 20000

VISUAL_RULES = """<visual_rules>
When a diagram or chart makes the answer clearer, include ONE fenced block:
```mermaid  for flows, sequences, ER and state diagrams (valid mermaid syntax), or
```chart    for data, JSON: {"type":"bar|line|scatter|pie","title":"…","labels":[…],
            "series":[{"name":"…","values":[…]}],"x":"axis label","y":"axis label"}
The shell renders it as a picture. Only when it helps; never for trivia.
</visual_rules>"""

# ── MODES ──────────────────────────────────────────────────────────────────
def modes():
    out = []
    for path in sorted(glob.glob(f"{CONF}/modes/*.md")):
        mode_id = os.path.basename(path)[:-3]
        if mode_id.startswith("_"):
            continue
        text = open(path).read()
        meta, body = {}, text
        m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
        if m:
            body = m.group(2)
            for line in m.group(1).splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip()
        out.append({"id": mode_id, "name": meta.get("name", mode_id), "icon": meta.get("icon", "󰚩"),
                    "sources": meta.get("sources", "").split(), "rules": meta.get("rules", "none"), "act": meta.get("act", "off"),
                    "body": body.strip()})
    order = {"general": 0}
    return sorted(out, key=lambda m: (order.get(m["id"], 1), m["name"]))

def mode_of(mode_id):
    all_ = modes()
    return next((m for m in all_ if m["id"] == mode_id), all_[0] if all_ else None)

def rules():
    path = f"{CONF}/modes/_rules.md"
    return "\n".join(l for l in open(path).read().splitlines() if not l.startswith("# ")) if os.path.exists(path) else ""

def profile():
    path = f"{CONF}/profile.md"
    if not os.path.exists(path):
        return ""
    text = re.sub(r"<!--.*?-->", "", open(path).read(), flags=re.S).strip()
    return text[:PROFILE_CAP]

# ── REFERENCE FILES ────────────────────────────────────────────────────────
def extract(path):
    """Text of a file, cached by content hash."""
    os.makedirs(f"{CACHE}/text", exist_ok=True)
    digest = hashlib.sha1(open(path, "rb").read()).hexdigest()
    cached = f"{CACHE}/text/{digest}.txt"
    if os.path.exists(cached):
        return open(cached).read()
    ext = path.lower().rsplit(".", 1)[-1]
    try:
        if ext == "pdf":
            text = subprocess.run(["pdftotext", "-layout", path, "-"], capture_output=True, timeout=60).stdout.decode(errors="replace")
        elif ext in ("docx", "odt", "rtf", "html", "epub"):
            text = subprocess.run(["pandoc", "-t", "plain", path], capture_output=True, timeout=60).stdout.decode(errors="replace")
        else:
            text = open(path, errors="replace").read()
    except (subprocess.TimeoutExpired, OSError):
        text = ""
    open(cached, "w").write(text)
    return text

def files_block(mode_id, question):
    paths = sorted(p for p in glob.glob(f"{CONF}/files/{mode_id}/*") if os.path.isfile(p))
    docs = [(os.path.basename(p), extract(p)) for p in paths]
    docs = [(n, t) for n, t in docs if t.strip()]
    if not docs:
        return ""
    if sum(len(t) for _, t in docs) <= FILES_BUDGET:
        return "\n".join(f'<reference_file name="{n}">\n{t.strip()}\n</reference_file>' for n, t in docs)
    # Too big to send whole: the best chunks by BM25 (SQLite FTS5).
    db = sqlite3.connect(":memory:")
    db.execute("CREATE VIRTUAL TABLE c USING fts5(name UNINDEXED, body)")
    for n, t in docs:
        words = t.split()
        for i in range(0, len(words), 220):
            db.execute("INSERT INTO c VALUES (?, ?)", (n, " ".join(words[i:i + 260])))
    terms = " OR ".join(f'"{w}"' for w in re.findall(r"\w{3,}", question.lower())[:24]) or '""'
    try:
        rows = db.execute("SELECT name, body FROM c WHERE c MATCH ? ORDER BY bm25(c) LIMIT 8", (terms,)).fetchall()
    except sqlite3.OperationalError:
        rows = []
    return "\n".join(f'<reference_file name="{n}" excerpt="true">\n{b}\n</reference_file>' for n, b in rows)

# ── BROWSER (Helium over CDP, loopback only) ───────────────────────────────
GRAB = """(() => { const s = String(getSelection() || '').trim();
  return JSON.stringify({ title: document.title, url: location.href, selection: s,
    text: s ? '' : (document.querySelector('article, main') || document.body).innerText.slice(0, 12000) }); })()"""

def browser_page():
    import websocket
    tabs = json.load(urllib.request.urlopen("http://127.0.0.1:9222/json", timeout=2))
    page = next(t for t in tabs if t.get("type") == "page" and not t["url"].startswith(("chrome", "devtools")))
    ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=5, suppress_origin=True)
    ws.send(json.dumps({"id": 1, "method": "Runtime.evaluate", "params": {"expression": GRAB, "returnByValue": True}}))
    while True:
        msg = json.loads(ws.recv())
        if msg.get("id") == 1:
            break
    ws.close()
    return json.loads(msg["result"]["result"]["value"])

def page_block(page):
    body = f"Selected text:\n{page['selection']}" if page.get("selection") else page.get("text", "")
    return f'<browser_page title="{page.get("title", "")}" url="{page.get("url", "")}">\n{body}\n</browser_page>'

# ── VISUAL ANSWERS ─────────────────────────────────────────────────────────
INK = {"e-ink": ("#f4f1ea", "#1c1b19"), "e-ink-dark": ("#1c1b19", "#e8e4da"),
       "red-ink": ("#f4f1ea", "#7a1f1a"), "red-ink-dark": ("#1c1b19", "#e07a6e")}

def theme():
    try:
        return json.load(open(f"{HOME}/.local/state/notch/theme.json")).get("id", "e-ink")
    except (OSError, ValueError):
        return "e-ink"

def chart(spec, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    paper, ink = INK.get(theme(), INK["e-ink"])
    plt.rcParams.update({"font.family": ["Tinos Nerd Font", "serif"], "text.color": ink, "axes.labelcolor": ink,
                         "axes.edgecolor": ink, "xtick.color": ink, "ytick.color": ink,
                         "axes.spines.top": False, "axes.spines.right": False})
    fig, ax = plt.subplots(figsize=(6, 3.2), dpi=110, facecolor=paper)
    ax.set_facecolor(paper)
    labels, series, kind = spec.get("labels", []), spec.get("series", []), spec.get("type", "bar")
    shades = [ink, ink + "99", ink + "55", ink + "33"]
    if kind == "pie" and series:
        ax.pie(series[0]["values"], labels=labels, colors=[ink + a for a in ("", "bb", "88", "55", "33", "22")],
               wedgeprops={"edgecolor": paper}, textprops={"color": ink})
    for i, s in enumerate(series if kind != "pie" else []):
        xs = range(len(s["values"]))
        if kind == "line":
            ax.plot(labels or list(xs), s["values"], color=shades[i % 4], marker="o", label=s.get("name"))
        elif kind == "scatter":
            ax.scatter(labels or list(xs), s["values"], color=shades[i % 4], label=s.get("name"))
        else:
            width = 0.8 / max(1, len(series))
            ax.bar([x + i * width for x in xs], s["values"], width, color=shades[i % 4], label=s.get("name"))
            ax.set_xticks([x + width * (len(series) - 1) / 2 for x in xs], labels)
    ax.set_title(spec.get("title", ""), color=ink)
    ax.set_xlabel(spec.get("x", "")); ax.set_ylabel(spec.get("y", ""))
    if len(series) > 1:
        ax.legend(frameon=False)
    fig.tight_layout(); fig.savefig(out, facecolor=paper); plt.close(fig)

def mermaid(source, out):
    paper, ink = INK.get(theme(), INK["e-ink"])
    src = out[:-4] + ".mmd"
    open(src, "w").write(source)
    puppet = f"{CACHE}/puppeteer.json"
    # chrome-headless-shell, fetched once by @puppeteer/browsers (see setup).
    shell = sorted(glob.glob(f"{HOME}/.cache/notch/chrome/chrome-headless-shell/*/*/chrome-headless-shell"))
    json.dump({"executablePath": shell[-1] if shell else "/opt/helium-browser-bin/helium",
               "headless": True,
               # A fresh profile per render: the user's Helium holds the default one, and a
               # leftover render's lock would make mmdc hang.
               "args": ["--no-sandbox", f"--user-data-dir={tempfile.mkdtemp(prefix='notch-mmdc-')}", "--ozone-platform=headless"]}, open(puppet, "w"))
    conf = f"{CACHE}/mermaid.json"
    json.dump({"theme": "base", "themeVariables": {"background": paper, "primaryColor": paper, "primaryTextColor": ink,
               "primaryBorderColor": ink, "lineColor": ink, "fontFamily": "Tinos Nerd Font, serif"}}, open(conf, "w"))
    mmdc = [p for p in [f"{HOME}/.local/share/mise/installs/node/latest/bin/mmdc"]
            + glob.glob(f"{HOME}/.local/share/mise/installs/node/*/bin/mmdc") if os.path.exists(p)]
    node = f"{HOME}/.local/share/mise/installs/node/latest/bin"
    run = subprocess.run([mmdc[0] if mmdc else "mmdc", "-q", "-i", src, "-o", out, "-b", paper, "-s", "2",
                          "-c", conf, "-p", puppet], capture_output=True, timeout=60,
                         env=dict(os.environ, PATH=f"{node}:{os.environ.get('PATH', '')}"))
    if run.returncode != 0 or not os.path.exists(out):
        raise RuntimeError(run.stderr.decode(errors="replace")[-300:])

def visuals(answer):
    """[(kind, png path or None, source)] for each closed mermaid/chart block."""
    os.makedirs(CACHE, exist_ok=True)
    found = []
    for kind, source in re.findall(r"```(mermaid|chart)\s*\n(.*?)```", answer, re.S):
        out = f"{CACHE}/{hashlib.sha1(source.encode()).hexdigest()[:12]}.png"
        try:
            chart(json.loads(source), out) if kind == "chart" else mermaid(source, out)
            found.append((kind, out, source))
        except Exception as error:  # a broken block falls back to its source
            found.append((kind, None, f"{source}\n(could not render: {error})"))
    return found
