# Parity with omastorm

The radar is upstream's engine, kept as it is: the pinned release is
`engine-0.1.13`, sha256 `9391de72…` — the same tag and the same hash
upstream pins in `engine/release.pin`. So the wire is theirs and the
engine is theirs; the notch is the client and the face.

## What the notch speaks

| Command | Upstream | Notch |
|---|---|---|
| `view_center` | yes | yes (`notchstorm center`) |
| `search_places` | yes | yes (`notchstorm place`) |
| `select_site` | yes | yes (`notchstorm site`) |
| `select_source` | yes | yes (`notchstorm source`) |
| `follow` / `lock` | yes | no |
| `metar_query` | yes | no |
| `play` / `pause` / `step` / `seek` | yes | no |
| `set_product` | yes | no |
| `tiles_needed` | yes | no |

Everything upstream's client can do, the engine can still do: the gaps
are in our client, not in the engine. Each missing command is a feature
the notch could grow.

## What the notch shows

- the sweep, in the shell's own colours, in the island — no separate
  window, no bar popover of its own
- the station, the product, and how old the frame is
- a place to point the map at, and a home turf to come back to
- the frames the engine draws, straight from its texture

## What upstream shows that the notch does not

- **a basemap**: the geography under the echo (OSM, Natural Earth),
  which the engine already serves as tiles — `tiles_needed`
- **the timeline**: the last hour of sweeps, played and stepped through
  — `play`, `pause`, `step`, `seek`
- **the product and the elevation**: reflectivity or velocity, and which
  tilt — `set_product`
- **the METAR chips**: the flight category of the stations near the
  radar — `metar_query`
- **follow and lock**: whether the camera follows the radar or stays
  where it was put
- **one-click location**: a guess from the public address, where a place
  is not set yet

## Where the notch differs on purpose

- the config is one small file of the notch's own
  (`~/.config/notch/notchstorm.json`), not upstream's pair of a
  preferences file and a state file
- the engine runs under the notch's own runtime directory, so nothing
  of upstream's tree is touched
- the colours are the notch's theme, not upstream's
