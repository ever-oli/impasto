#!/bin/sh
# A random title, end to end: a film or a series, its seasons and
# episodes when it is a series, and the stream for one of them. The
# catalogue must work for any title, not for the one that happens to be
# in the screenshot.
#
#   tests/series-random.sh            one random title
#   tests/series-random.sh 6          six, one after another
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
STREAM="$root/packages/media/scripts/stream.py"
RESOLVE="$root/packages/media/bin/notch-resolve.mjs"
TOKEN=$(cat "$HOME/.config/notch/tmdb.key" 2>/dev/null || echo "")
[ -n "$TOKEN" ] || { echo "no TMDB token in ~/.config/notch/tmdb.key"; exit 1; }
COUNT=${1:-1}
i=0
while [ "$i" -lt "$COUNT" ]; do
    i=$((i + 1))
    # A film or a series, at random: a page of each, and one of them.
    picked=$(python3 - "$TOKEN" <<'PY'
import json, random, sys, urllib.request
key = sys.argv[1]


def page(kind, number):
    url = "https://api.themoviedb.org/3/%s/popular?page=%d" % (kind, number)
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + key})
    return json.load(urllib.request.urlopen(request, timeout=30))["results"]


kind = random.choice(["movie", "tv"])
results = page(kind, random.randint(1, 5))
item = random.choice([r for r in results if r.get("id") and r.get("title" if kind == "movie" else "name")])
name = item["title"] if kind == "movie" else item["name"]
date = item.get("release_date") if kind == "movie" else item.get("first_air_date")
year = (date or "")[:4]
print(kind, item["id"], name.replace(" ", "_"), year)
PY
)
    kind=$(echo "$picked" | cut -d' ' -f1)
    id=$(echo "$picked" | cut -d' ' -f2)
    name=$(echo "$picked" | cut -d' ' -f3)
    year=$(echo "$picked" | cut -d' ' -f4)
    echo "· $name ($year, $kind, id $id)"

    if [ "$kind" = "tv" ]; then
        seasons=$(python3 "$STREAM" seasons "$id")
        count=$(echo "$seasons" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
        if [ "$count" -lt 1 ]; then
            echo "  FAIL no seasons for $name"
            continue
        fi
        echo "  ok   $count season(s): $(echo "$seasons" | python3 -c "
import json,sys
print(' '.join('S%d' % s['season'] for s in json.load(sys.stdin)))")"
        season=$(echo "$seasons" | python3 -c "
import json, random, sys
print(random.choice(json.load(sys.stdin))['season'])")
        episodes=$(python3 "$STREAM" episodes "$id" --season "$season")
        episode=$(echo "$episodes" | python3 -c "
import json, random, sys
eps = json.load(sys.stdin)
print(random.choice(eps)['episode'] if eps else 0)")
        if [ "$episode" -lt 1 ]; then
            echo "  FAIL no episodes for $name season $season"
            continue
        fi
        echo "  ok   S$season E$episode: $(echo "$episodes" | python3 -c "
import json,sys
eps = json.load(sys.stdin)
names = [e['name'] for e in eps if e['episode'] == $episode]
print(names[0] if names else '')")"
        args="--season $season --episode $episode"
    else
        args=""
    fi

    answer=$(node "$RESOLVE" --tmdb "$id" --type "$kind" --title "$name" --year "$year" \
             $args --json 2>&1 >/dev/null | tail -1)
    found=$(node "$RESOLVE" --tmdb "$id" --type "$kind" --title "$name" --year "$year" \
            $args --json 2>/dev/null \
            | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('found','')[:64])
except Exception:
    print('')" 2>/dev/null)
    if [ -n "$found" ]; then
        echo "  ok   a stream for it"
    else
        echo "  no   no stream for it: ${answer:-the source does not carry this title}"
    fi
done
