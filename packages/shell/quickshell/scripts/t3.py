#!/usr/bin/env python3
"""T3 Code Nightly: status (JSON on stdout) and update.

  t3.py status [--refresh]   service state, installed and latest versions
  t3.py update               fetch the newest x86_64 AppImage and swap it in

The latest release is cached in ~/.cache/notch/t3.json for 30 minutes,
so the bar never hits the GitHub API more than twice an hour.
"""
import json, os, shutil, struct, subprocess, sys, tempfile, time, urllib.request

HOME = os.path.expanduser("~")
APPS = os.path.join(HOME, "Applications")
APPIMAGE = os.path.join(APPS, "T3-Code-Nightly.AppImage")
DIR = os.path.join(APPS, "t3code-nightly")
ASAR = os.path.join(DIR, "resources", "app.asar")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "notch", "t3.json")
REPO = "pingdotgg/t3code"
SERVICE = "t3code-web"
TTL = 30 * 60


def installed_version():
    """Read package.json straight out of app.asar: no Electron start-up."""
    try:
        with open(ASAR, "rb") as f:
            _, header_size, _, json_size = struct.unpack("<4I", f.read(16))
            header = json.loads(f.read(json_size).decode())
            base = 8 + header_size
            for path in (["package.json"], ["apps", "desktop", "package.json"]):
                node = header
                for part in path:
                    node = (node or {}).get("files", {}).get(part)
                if node and "offset" in node:
                    f.seek(base + int(node["offset"]))
                    version = json.loads(f.read(node["size"]).decode()).get("version", "")
                    if version:
                        return version
    except Exception:
        pass
    return ""


def service_state():
    out = subprocess.run(["systemctl", "--user", "is-active", SERVICE],
                         capture_output=True, text=True).stdout.strip()
    out = out or "unknown"
    # The desktop app runs its own server on the same port, so the web
    # service stepping aside for it is a pause, not a failure.
    if out != "active" and (desktop_running() or already_running()):
        return "paused"
    return out


def desktop_running():
    # The desktop app's main process is the bare binary; its helpers carry
    # --type=..., and the CLI server runs through /usr/local/bin/t3.
    found = subprocess.run(["pgrep", "-u", str(os.getuid()), "-fx", r".*/t3code(-nightly)?/t3code"],
                           capture_output=True, text=True)
    return found.returncode == 0


def already_running():
    for cmd in (["journalctl", "--user", "-u", SERVICE, "-n", "40", "--no-pager", "-o", "cat"],
                ["systemctl", "--user", "status", SERVICE, "-n", "40", "--no-pager"]):
        try:
            text = subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
        except (OSError, subprocess.TimeoutExpired):
            continue
        if "ServerAlreadyRunning" in text:
            return True
    return False


def latest(refresh=False):
    try:
        with open(CACHE) as f:
            cached = json.load(f)
        if not refresh and time.time() - cached.get("checked", 0) < TTL:
            return cached
    except Exception:
        cached = {}
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases?per_page=5",
                                     headers={"Accept": "application/vnd.github+json",
                                              "User-Agent": "notch-lean"})
        with urllib.request.urlopen(req, timeout=10) as r:
            releases = json.load(r)
        release = next(r for r in releases if "nightly" in r.get("tag_name", ""))
        asset = next((a["browser_download_url"] for a in release["assets"]
                      if a["name"].endswith("x86_64.AppImage")), "")
        cached = {"tag": release["tag_name"], "version": release["tag_name"].lstrip("v"),
                  "published": release.get("published_at", ""), "url": asset,
                  "checked": time.time()}
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w") as f:
            json.dump(cached, f)
    except Exception as error:
        cached = dict(cached, error=str(error))
    return cached


def status(refresh=False):
    have = installed_version()
    new = latest(refresh)
    print(json.dumps({
        "service": service_state(),
        "installed": have,
        "latest": new.get("version", ""),
        "published": new.get("published", ""),
        "checked": new.get("checked", 0),
        "error": new.get("error", ""),
        "update": bool(have and new.get("version") and new["version"] != have),
    }))


def wake_pill():
    """Best effort: a notch shell running means its Update pill is live; make it
    re-sync now so an update finished in a terminal clears instantly."""
    if shutil.which("qs"):
        subprocess.run(["qs", "ipc", "call", "t3", "refresh"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)


def update():
    new = latest(refresh=True)
    if not new.get("url"):
        sys.exit("no AppImage in the latest release")
    if new.get("version") == installed_version():
        print("already up to date"); wake_pill(); return
    work = tempfile.mkdtemp(prefix="t3-", dir=APPS)
    image = os.path.join(work, "T3.AppImage")
    print(f"downloading {new['version']}", flush=True)
    urllib.request.urlretrieve(new["url"], image)
    os.chmod(image, 0o755)
    subprocess.run([image, "--appimage-extract"], cwd=work, check=True,
                   stdout=subprocess.DEVNULL)
    fresh = os.path.join(work, "squashfs-root")
    # chrome-sandbox has to stay setuid root: move the old one across rather
    # than keep the unprivileged copy (same filesystem, so no root needed).
    old_sandbox = os.path.join(DIR, "chrome-sandbox")
    if os.path.exists(old_sandbox):
        os.replace(old_sandbox, os.path.join(fresh, "chrome-sandbox"))
    was = service_state() == "active"
    subprocess.run(["systemctl", "--user", "stop", SERVICE])
    retired = DIR + ".old"
    shutil.rmtree(retired, ignore_errors=True)
    if os.path.exists(DIR):
        os.rename(DIR, retired)
    os.rename(fresh, DIR)
    os.replace(image, APPIMAGE)
    shutil.rmtree(work, ignore_errors=True)
    shutil.rmtree(retired, ignore_errors=True)
    if was:
        subprocess.run(["systemctl", "--user", "start", SERVICE])
    print(f"updated to {installed_version()}")
    wake_pill()


if __name__ == "__main__":
    verb = sys.argv[1] if len(sys.argv) > 1 else "status"
    if verb == "update":
        update()
    else:
        status("--refresh" in sys.argv)
