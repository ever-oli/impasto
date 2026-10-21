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

import json
import os
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
        # The browser is the player: the embed brings its own player, and
        # the notch-player class is what drops it under the notch.
        browser = os.environ.get("NOTCH_BROWSER", "helium-browser")
        try:
            subprocess.Popen([browser, "--new-window", "--class=notch-player", url],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass
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
