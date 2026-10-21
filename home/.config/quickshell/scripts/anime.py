"""anime — the catalogue behind the notch's anime panel.

AniList's GraphQL, no key and no account: what is trending, what is
popular, what a genre holds, and the episodes of a show. One JSON line
out, so the shell can read it.

  anime.py rows             the rows of the panel, and its hero
  anime.py search <text>    the titles that match
  anime.py episodes <id>    the episodes of one show
"""

import json
import os
import sys
import urllib.request

API = "https://graphql.anilist.co"
UA = "notch/1.0 (the notch shell)"

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

# The rows, in the order the panel shows them.
SHELVES = [
    ("Trending now", "TRENDING_DESC", None),
    ("Popular this season", "POPULARITY_DESC", None),
    ("Action", "POPULARITY_DESC", "Action"),
    ("Fantasy", "POPULARITY_DESC", "Fantasy"),
    ("Romance", "POPULARITY_DESC", "Romance"),
    ("Sci-Fi", "POPULARITY_DESC", "Sci-Fi"),
]


def ask(query, variables=None):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    request = urllib.request.Request(API, data=body, headers={
        "Content-Type": "application/json", "User-Agent": UA})
    return json.load(urllib.request.urlopen(request, timeout=25))


def items(media):
    """One JSON-friendly row per title."""
    out = []
    for entry in media or []:
        title = entry.get("title") or {}
        cover = entry.get("coverImage") or {}
        out.append({
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


def shelf(sort, genre, per_page=14):
    """One row of titles: the most of something, optionally of a genre."""
    if genre:
        query = ("query($g:String){Page(perPage:" + str(per_page)
                 + "){media(type:ANIME,sort:" + sort + ",genre:$g){"
                 + FIELDS + "}}}")
        media = ask(query, {"g": genre})["data"]["Page"]["media"]
    else:
        query = ("query($p:Int){Page(page:$p,perPage:" + str(per_page)
                 + "){media(type:ANIME,sort:" + sort + "){"
                 + FIELDS + "}}}")
        media = ask(query, {"p": 1})["data"]["Page"]["media"]
    return items(media)


def rows():
    """The panel's rows, and the one to show big at the top."""
    out = []
    for label, sort, genre in SHELVES:
        try:
            found = shelf(sort, genre)
        except Exception:
            found = []
        if found:
            out.append({"title": label, "items": found})
    hero = None
    for row in out:
        if row["items"]:
            hero = row["items"][0]
            break
    print(json.dumps({"hero": hero, "rows": out}))


def search(text):
    query = ("query($s:String){Page(perPage:20){media(type:ANIME,search:$s){"
             + FIELDS + "}}}")
    media = ask(query, {"s": text})["data"]["Page"]["media"]
    print(json.dumps({"items": items(media)}))


def episodes(media_id):
    query = """query($id:Int){Media(id:$id){episodes(sort:ASC){number title
             description image coverImage{large extraLarge}}}}"""
    try:
        media = ask(query, {"id": media_id})["data"]["Media"] or {}
    except Exception:
        media = {}
    out = []
    for episode in media.get("episodes") or []:
        cover = episode.get("coverImage") or {}
        out.append({
            "number": episode.get("number"),
            "title": episode.get("title") or "",
            "description": (episode.get("description") or "").strip(),
            "cover": cover.get("extraLarge") or cover.get("large") or "",
        })
    print(json.dumps({"episodes": out}))


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if args[0] == "rows":
        rows()
    elif args[0] == "search" and len(args) > 1:
        search(" ".join(args[1:]))
    elif args[0] == "episodes" and len(args) > 1:
        episodes(int(args[1]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
