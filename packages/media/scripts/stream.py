"""stream — the notch's catalogue and its streams.

One catalogue, two sources, the way streambert does it: anime comes from
AniList (no key, no account) and films and series from TMDB, which wants
a free read token — put it in ~/.config/notch/tmdb.key, or set TMDB_TOKEN,
and the shelves fill up. The playing is a source's own page: for a film
or a series that is a VidSrc embed keyed by the TMDB id, opened in the
browser under the notch; for anime it is hianime, through ani-cli.

  stream.py rows                  the shelves, and the hero
  stream.py search <text>         anime, films and series that match
  stream.py play <kind> <id>      the page to play: <kind> is movie, tv
                                  or anime; id is the TMDB id, or the
                                  AniList id for anime
  stream.py token                 where the TMDB token goes
"""

import base64
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HOME = os.environ.get("HOME", os.path.expanduser("~"))
ANILIST = "https://graphql.anilist.co"
TMDB = "https://api.themoviedb.org/3"
UA = "notch/1.0 (the notch shell)"
TOKEN_FILE = Path(HOME) / ".config/notch/tmdb.key"

FIELDS = """
id
title { romaji english }
coverImage { large extraLarge }
bannerImage
startDate { year }
genres
averageScore
description(asHtml:false)
"""

# The shelves, in the order the panel shows them.
SHELVES = [
    ("Trending now", "TRENDING_DESC", None),
    ("Popular this season", "POPULARITY_DESC", None),
    ("Action", "POPULARITY_DESC", "Action"),
    ("Fantasy", "POPULARITY_DESC", "Fantasy"),
    ("Romance", "POPULARITY_DESC", "Romance"),
    ("Sci-Fi", "POPULARITY_DESC", "Sci-Fi"),
]

# The film and series shelves, from TMDB.
FILM_SHELVES = [
    ("Films", "movie", "trending"),
    ("Popular films", "movie", "popular"),
    ("Series", "tv", "trending"),
    ("Top rated", "tv", "top"),
]


# Where a title comes from. The registry is small on purpose: a source
# that breaks should be one line to remove, and the self-check says which
# ones answer today.
SOURCES = {
    "anime": ["hianime"],
    "film": ["vidsrc"],
    "tv": ["vidsrc"],
}


def source_state():
    """How the sources are doing, as the last check left it."""
    path = os.path.join(os.environ.get("XDG_STATE_HOME",
                                       os.path.expanduser("~/.local/state")),
                         "notch", "sources.json")
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def token():
    """The TMDB read token, if the user has given the notch one."""
    if os.environ.get("TMDB_TOKEN"):
        return os.environ["TMDB_TOKEN"].strip()
    try:
        return TOKEN_FILE.read_text().strip()
    except OSError:
        return ""


def get(url, headers=None):
    request = urllib.request.Request(url, headers={"User-Agent": UA,
                                                   **(headers or {})})
    return urllib.request.urlopen(request, timeout=25)


def get_json(url, headers=None):
    return json.load(get(url, headers))


# ── ANILIST ──────────────────────────────────────────────────────────────────

def anilist(query, variables=None):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    request = urllib.request.Request(ANILIST, data=body, headers={
        "Content-Type": "application/json", "User-Agent": UA})
    return json.load(urllib.request.urlopen(request, timeout=25))


def anime_items(media):
    out = []
    for entry in media or []:
        title = entry.get("title") or {}
        cover = entry.get("coverImage") or {}
        out.append({
            "kind": "anime",
            "id": entry.get("id"),
            "title": title.get("english") or title.get("romaji") or "—",
            "romaji": title.get("romaji") or "",
            "cover": cover.get("extraLarge") or cover.get("large") or "",
            "banner": entry.get("bannerImage") or "",
            "year": (entry.get("startDate") or {}).get("year") or 0,
            "genres": entry.get("genres") or [],
            "score": entry.get("averageScore") or 0,
            "description": (entry.get("description") or "").strip(),
        })
    return out


def anime_shelf(sort, genre, per_page=14):
    if genre:
        query = ("query($g:String){Page(perPage:" + str(per_page)
                 + "){media(type:ANIME,sort:" + sort + ",genre:$g){"
                 + FIELDS + "}}}")
        media = anilist(query, {"g": genre})["data"]["Page"]["media"]
    else:
        query = ("query($p:Int){Page(page:$p,perPage:" + str(per_page)
                 + "){media(type:ANIME,sort:" + sort + "){"
                 + FIELDS + "}}}")
        media = anilist(query, {"p": 1})["data"]["Page"]["media"]
    return anime_items(media)


def anime_search(text):
    query = ("query($s:String){Page(perPage:20){media(type:ANIME,search:$s){"
             + FIELDS + "}}}")
    return anime_items(anilist(query, {"s": text})["data"]["Page"]["media"])


# ── TMDB ─────────────────────────────────────────────────────────────────────

def tmdb(path, query=None):
    """One TMDB call, with the read token."""
    key = token()
    if not key:
        return None
    url = TMDB + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    try:
        return get_json(url, {"Authorization": f"Bearer {key}"})
    except (urllib.error.URLError, OSError, ValueError):
        return None


def seasons(media_id):
    """The seasons of a series, so the panel can offer more than the first."""
    found = tmdb(f"/tv/{media_id}") or {}
    out = []
    for entry in found.get("seasons", []):
        number = entry.get("season_number")
        if number is None or number == 0:
            continue
        out.append({"season": number, "name": entry.get("name") or "",
                    "episodes": entry.get("episode_count") or 0})
    return out


def episodes(media_id, season=1):
    """The episodes of one season of a series.

    The panel shows them as a row of buttons, the way a streaming service
    does, so the notch can start on the episode Ever means.
    """
    found = tmdb(f"/tv/{media_id}/season/{season}") or {}
    out = []
    for entry in found.get("episodes", []):
        out.append({
            "season": entry.get("season_number", season),
            "episode": entry.get("episode_number", 0),
            "name": entry.get("name") or "",
            "air": entry.get("air_date") or "",
            "description": entry.get("overview") or "",
        })
    return out


def film_items(results, kind=None):
    """The films or series of one TMDB answer.

    A series answer has no media_type of its own, so the kind it was asked
    for is the kind it is.
    """
    out = []
    for entry in results or []:
        date = entry.get("release_date") or entry.get("first_air_date") or ""
        out.append({
            "kind": entry.get("media_type") or kind or "movie",
            "id": entry.get("id"),
            "title": entry.get("title") or entry.get("name") or "—",
            "romaji": entry.get("original_title") or entry.get("original_name") or "",
            "cover": ("https://image.tmdb.org/t/p/w500" + entry["poster_path"])
                     if entry.get("poster_path") else "",
            "banner": ("https://image.tmdb.org/t/p/w1280" + entry["backdrop_path"])
                      if entry.get("backdrop_path") else "",
            "year": int(date[:4]) if date[:4].isdigit() else 0,
            "genres": [],
            "score": round((entry.get("vote_average") or 0) * 10),
            "description": entry.get("overview") or "",
        })
    return out


def film_shelf(kind, sort):
    """A shelf of films or series, the way TMDB's own pages list them."""
    if sort == "trending":
        path = "/trending/" + kind + "/week"
    elif sort == "top":
        path = "/movie/top_rated" if kind == "movie" else "/tv/top_rated"
    else:
        path = "/movie/popular" if kind == "movie" else "/tv/popular"
    data = tmdb(path)
    if not data:
        return []
    return film_items(data.get("results"), kind)


def film_search(text):
    data = tmdb("/search/multi", {"query": text, "include_adult": "false"})
    if not data:
        return []
    out = []
    for entry in data.get("results") or []:
        if entry.get("media_type") not in ("movie", "tv"):
            continue
        out += film_items([entry])
    return out


# ── THE PANEL'S DATA ─────────────────────────────────────────────────────────

def rows():
    """Every shelf: anime first, then films and series."""
    out = []
    for label, sort, genre in SHELVES:
        try:
            found = anime_shelf(sort, genre)
        except Exception:
            found = []
        if found:
            out.append({"title": label, "items": found})
    for label, kind, sort in FILM_SHELVES:
        try:
            found = film_shelf(kind, sort)
        except Exception:
            found = []
        if found:
            out.append({"title": label, "items": found})
    hero = None
    for row in out:
        if row["items"]:
            hero = row["items"][0]
            break
    print(json.dumps({"hero": hero, "rows": out, "token": bool(token())}))


def search(text):
    found = []
    try:
        found += anime_search(text)
    except Exception:
        pass
    try:
        found += film_search(text)
    except Exception:
        pass
    print(json.dumps({"items": found}))


# ── HIANIME ──────────────────────────────────────────────────────────────────
#
# The anime source: hianime, scraped the way ani-cli does it. The search
# page names the shows, the episode list numbers them, the servers answer
# with a hash, and the embed page hides its playlist in a small obfuscated
# blob. The stream host wants the embed site as its referer.

HIANIME = "https://hianime.at"
BROWSER = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
           "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
KEY = b"otaku-embed-v1"


def fetch(url, referer=None):
    headers = {"User-Agent": BROWSER}
    if referer:
        headers["Referer"] = referer
    request = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(request, timeout=25).read().decode(
        errors="replace")


def hianime_search(text):
    """[(slug, title)] for the titles that match."""
    page = fetch(f"{HIANIME}/search?keyword=" + urllib.parse.quote(text))
    if "Just a moment" in page:
        raise RuntimeError("hianime is behind its cloudflare check")
    # The sidebar repeats the markup; cut it off before flattening.
    page = page.split('id="main-sidebar"')[0]
    found = []
    for block in page.split('<div class="film-detail">')[1:]:
        name = re.search(r'<h3 class="film-name">\s*<a href="[^"]*/([^"/]+)"\s*title="([^"]*)"', block)
        if name:
            found.append((name.group(1), name.group(2)))
    return found


def hianime_episodes(slug):
    """[(id, number)] for the episodes of a show."""
    # The slug carries the id after its last dash ("cowboy-bebop-1281"),
    # and the episode list wants only that id.
    slug = slug.rsplit("-", 1)[-1]
    page = fetch(f"{HIANIME}/api/theme/episode/list/{slug}").replace("\\", "")
    found = []
    for block in page.split("ep-item")[1:]:
        number = re.search(r'data-number="([^"]*)"', block)
        ident = re.search(r'data-id="([0-9]+)"', block)
        if number and ident:
            found.append((ident.group(1), number.group(1)))
    return found


def hianime_servers(episode_id, mode="sub"):
    """The ZokoAnime embed of an episode: (embed url, referer)."""
    page = fetch(f"{HIANIME}/api/theme/episode/servers?episodeId={episode_id}")
    page = page.replace('\\"', '"')
    for block in page.split("server-item")[1:]:
        if f'data-type="{mode}"' not in block:
            continue
        name = re.search(r'data-server-name="([^"]*)"', block)
        digest = re.search(r'data-hash="([^"]*)"', block)
        if not name or not digest or name.group(1) != "ZokoAnime":
            continue
        try:
            embed = base64.b64decode(digest.group(1) + "==").decode(errors="replace")
        except Exception:
            continue
        if not embed.startswith("http"):
            continue
        # The stream host wants the embed site as its referer.
        parts = urllib.parse.urlparse(embed)
        return embed, f"{parts.scheme}://{parts.netloc}/"
    return None, None


def hianime_blob(embed):
    """The playlist inside the embed page, which is obfuscated."""
    page = fetch(embed)
    blob = re.search(r'window\.__P="([^"]*)"', page)
    if not blob:
        return None
    raw = base64.b64decode(blob.group(1) + "==")
    plain = bytes(byte ^ KEY[index % len(KEY)] for index, byte in enumerate(raw))
    return plain.decode(errors="replace")


def resolve_anime(text, episode=1, mode="sub"):
    """A playable stream for a title: {url, referer, subtitle, title}."""
    shows = hianime_search(text)
    if not shows:
        raise RuntimeError(f"nothing called {text!r} on hianime")
    slug, title = shows[0]
    episodes = hianime_episodes(slug)
    if not episodes:
        raise RuntimeError(f"no episodes for {title!r}")
    chosen = None
    for ident, number in episodes:
        if str(number) == str(episode):
            chosen = ident
            break
    if chosen is None:
        chosen = episodes[0][0]
    embed, referer = hianime_servers(chosen, mode)
    if not embed:
        raise RuntimeError("no ZokoAnime server for that episode")
    json_text = hianime_blob(embed)
    if not json_text:
        raise RuntimeError("the embed page hid its playlist")
    source = re.search(r'"src":"([^"]*\.m3u8[^"]*)"', json_text)
    if not source:
        raise RuntimeError("no playlist in the embed")
    subtitle = ""
    marks = re.findall(r'"default":true[^}]*"src":"([^"]+)"', json_text)
    if not marks:
        marks = re.findall(r'"src":"([^"]+\.vtt[^"]*)"', json_text)
    if marks:
        subtitle = marks[0]
    return {"url": source.group(1).replace("\\/", "/"), "referer": referer,
            "subtitle": subtitle, "title": title, "episode": episode,
            "source": "hianime"}


def open_in_browser(url):
    """Put a page in the browser, which is the player here.

    Chromium keeps its own wayland app id, so niri cannot place the window
    by rule; it opens where the browser puts it.
    """
    browser = os.environ.get("NOTCH_BROWSER", "helium-browser")
    try:
        subprocess.Popen([browser, "--new-window", "--class=notch-player", url],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def trailer(kind, media_id):
    """A trailer for one title, from TMDB's videos."""
    if kind not in ("movie", "tv"):
        sys.exit(f"stream.py: unknown kind {kind!r}")
    data = tmdb(f"/{kind}/{media_id}/videos")
    clips = [v for v in (data or {}).get("results", []) if v.get("site") == "YouTube"]
    if not clips:
        sys.exit("stream.py: no trailer for that title")
    best = None
    for wanted in ("Trailer", "Teaser"):
        for clip in clips:
            if clip.get("type") == wanted:
                best = clip
                break
        if best:
            break
    best = best or clips[0]
    url = f"https://www.youtube.com/watch?v={best.get('key')}"
    open_in_browser(url)
    print(url)


def play(kind, media_id, season=None, episode=None):
    """The page to open for one title.

    Films and series play from a VidSrc embed, keyed by the TMDB id, the
    way streambert does it. Anime is hianime's business, and ani-cli knows
    how to reach it, so the notch hands it the name.
    """
    if kind in ("movie", "tv"):
        source = os.environ.get("NOTCH_SOURCE", "videasy")
        if kind == "movie":
            url = {"videasy": f"https://player.videasy.to/movie/{media_id}",
                   "vidking": f"https://www.vidking.net/embed/movie/{media_id}",
                   "vidsrc": f"https://vsembed.su/embed/movie/{media_id}"}[source]
        else:
            url = {"videasy": f"https://player.videasy.to/tv/{media_id}/{season or 1}/{episode or 1}",
                   "vidking": f"https://www.vidking.net/embed/tv/{media_id}/{season or 1}/{episode or 1}",
                   "vidsrc": f"https://vsembed.su/embed/tv/{media_id}/{season or 1}/{episode or 1}"}[source]
        # The browser is the player: the embed brings its own player.
        open_in_browser(url)
        print(url)
        return
    if kind == "anime":
        # The name is what ani-cli's search understands.
        name = ""
        for item in anime_search(media_id):
            if str(item["id"]) == str(media_id):
                name = item["romaji"] or item["title"]
                break
        print(name)
        return
    sys.exit(f"stream.py: unknown kind {kind!r}")


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if args[0] == "rows":
        rows()
    elif args[0] == "search" and len(args) > 1:
        search(" ".join(args[1:]))
    elif args[0] == "play" and len(args) > 2:
        play(args[1], args[2], args[3] if len(args) > 3 else None,
             args[4] if len(args) > 4 else None)
    elif args[0] == "resolve" and len(args) > 1:
        episode = 1
        if "--episode" in args:
            episode = int(args[args.index("--episode") + 1])
        print(json.dumps(resolve_anime(" ".join(a for a in args[1:] if not a.isdigit()),
                                      episode)))
    elif args[0] == "sources":
        print(json.dumps({"sources": SOURCES, "state": source_state()}))
    elif args[0] == "seasons" and len(args) > 1:
        print(json.dumps(seasons(args[1])))
    elif args[0] == "episodes" and len(args) > 1:
        season = 1
        if "--season" in args:
            season = int(args[args.index("--season") + 1])
        print(json.dumps(episodes(args[1], season)))
    elif args[0] == "trailer" and len(args) > 2:
        trailer(args[1], args[2])
    elif args[0] == "token":
        TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
        if len(args) > 1:
            TOKEN_FILE.write_text(args[1].strip() + "\n")
            print(f"stream: the token is in {TOKEN_FILE}")
        else:
            print(TOKEN_FILE)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
