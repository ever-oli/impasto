// notch-resolve.mjs — the stream behind videasy's player, without a browser.
//
// The page at player.videasy.to is a player that fetches its stream at
// runtime, so the stream is not in the HTML. Its JavaScript asks an API
// for the sources and then decrypts the answer with a seed that the same
// API hands out.
//
// This talks to that API directly, which is both lighter and steadier
// than a browser: the page sits behind a filter that turns headless
// browsers away, while the API answers.
//
//   node notch-resolve.mjs --tmdb 550 --title "Fight Club" --year 1999 --type movie
//   node notch-resolve.mjs --tmdb 1396 --title "Breaking Bad" --year 2008 \
//       --type tv --season 1 --episode 1
//
// It prints the playlist address on stdout and what it saw on stderr.

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
           "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
const API = "https://api.speedracelight.com";
const HEADERS = {
  "User-Agent": UA,
  "Accept": "application/json, text/plain, */*",
  "Origin": "https://player.videasy.to",
  "Referer": "https://player.videasy.to/",
};

// The keys and the arithmetic below are the site's own, transcribed.
// The site's page is minified, but this is the same code, spelled out.
const CONSTANTS = [
  1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993,
  2453635748, 2870763221, 3624381080, 310598401, 607225278, 1426881987,
  1925078388, 2162078206, 2614888103, 3248222580,
];
const MAGIC = [109, 118, 109, 49];   // "mnm1"

const even = (n) => (n * (n + 1) & 1) === 0;
const odd = (n) => (n * (n + 1) & 1) === 1;

function mix(value) {                // the 32-bit finaliser
  let e = value >>> 0;
  e ^= e >>> 16;
  e = Math.imul(e, 2246822507) >>> 0;
  e ^= e >>> 13;
  e = Math.imul(e, 3266489909) >>> 0;
  e ^= e >>> 16;
  return e >>> 0;
}

function rotate(value, bits) {       // a rotate to the left
  const t = bits & 31;
  const e = value >>> 0;
  return t === 0 ? e : ((e << t) | (e >>> (32 - t))) >>> 0;
}

function table(seed) {               // the site's first key schedule
  const t = Array(256);
  for (let i = 0; i < 256; i++) t[i] = i;
  let s = 0;
  for (let i = 0; i < 256; i++) {
    s = (s + t[i] + seed.charCodeAt(i % seed.length)) & 255;
    const other = t[i];
    t[i] = t[s];
    t[s] = other;
  }
  return t;
}

function checksum(text) {            // the site's running sum
  let t = 1732584193;
  for (let i = 0; i < text.length; i++) {
    t = rotate((t ^ Math.imul(text.charCodeAt(i), CONSTANTS[15 & i])) >>> 0, 5);
  }
  return mix(t);
}

function digest(text) {              // the site's other hash
  let t = 2166136261;
  for (let i = 0; i < text.length; i++) {
    t = Math.imul(t ^ text.charCodeAt(i), 16777619) >>> 0;
  }
  return mix(t);
}

function keystream(seed, mediaId, length) {
  let schedule, acc;
  if (odd(seed.length)) {
    schedule = table(seed);
    acc = checksum(seed);
  } else {
    schedule = Array(61);
    let state = mix(digest(seed) ^ mix((Number(mediaId) >>> 0) ^ 2654435769)) >>> 0;
    for (let i = 0; i < 8; i++) {
      if (even(i)) {
        const slot = state % 61;
        state = rotate((state + 2654435769) >>> 0, 7 + (7 & i));
        schedule[slot] = (state ^ mix(state)) >>> 0;
        state = mix((state + slot) >>> 0);
      } else {
        schedule[i] = CONSTANTS[15 & i];
      }
    }
    acc = mix((2779096485 ^ state) >>> 0);
  }

  const out = new Uint8Array(length);
  let counter = 0;
  let written = 0;
  while (written < length) {
    const index = acc % 61;
    const held = schedule[index] >>> 0;
    const mixed = (held ^ Math.imul(2654435769, counter + 1)) >>> 0;
    let value = ((acc ^ mixed) >>> 0 | (acc & mixed & -1) >>> 0) >>> 0;
    value = (rotate((value + acc) >>> 0, 31 & index) ^
             rotate(acc, 31 & Math.imul(index, 7))) >>> 0;
    acc = mix((value + 2654435769) >>> 0);
    schedule[index] = acc >>> 0;
    const word = acc >>> 0;
    out[written++] = 255 & word;
    if (written < length) out[written++] = (word >>> 8) & 255;
    if (written < length) out[written++] = (word >>> 16) & 255;
    if (written < length) out[written++] = (word >>> 24) & 255;
    counter++;
  }
  return out;
}

function unbase64(text) {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/")
                     .padEnd(4 * Math.ceil(text.length / 4), "=");
  const raw = Buffer.from(padded, "base64");
  return new Uint8Array(raw);
}

function decrypt(text, seed, mediaId) {
  const payload = unbase64(text);
  const key = keystream(seed, Number(mediaId), payload.length);
  for (let i = 0; i < payload.length; i++) payload[i] ^= key[i];
  for (let i = 0; i < MAGIC.length; i++) {
    if (payload[i] !== MAGIC[i]) throw new Error("the answer did not open");
  }
  return Buffer.from(payload.subarray(MAGIC.length)).toString("utf8");
}

function argument(name, fallback) {
  const at = process.argv.indexOf("--" + name);
  if (at === -1 || at + 1 >= process.argv.length) return fallback;
  return process.argv[at + 1];
}

async function get(path, params) {
  const url = new URL(API + path);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, String(value));
    }
  }
  const response = await fetch(url, { headers: HEADERS });
  const text = await response.text();
  if (!response.ok) throw new Error(`${response.status} from ${path}: ${text.slice(0, 160)}`);
  return text;
}

export { keystream, decrypt, unbase64 };

async function main() {
const tmdb = argument("tmdb", "");
const title = argument("title", "");
const year = argument("year", "");
const type = argument("type", "movie");
const season = argument("season", "");
const episode = argument("episode", "");
const mediaType = type === "tv" ? "tv" : "movie";

if (!tmdb || !title) {
  console.error("usage: notch-resolve.mjs --tmdb <id> --title <name> [--year Y] " +
                "[--type movie|tv] [--season N] [--episode N]");
  process.exit(2);
}

try {
  const seedReply = JSON.parse(await get("/seed", { mediaId: tmdb }));
  const seed = seedReply.seed;
  const params = {
    title: encodeURIComponent(title),
    mediaType,
    year,
    totalSeasons: "",
    episodeId: episode,
    seasonId: season,
    tmdbId: tmdb,
    imdbId: "",
    enc: "2",
    seed,
  };
  const answer = await get("/vsrc/sources-with-title", params);
  const opened = JSON.parse(decrypt(answer, seed, tmdb));
  const sources = opened.sources || [];
  const usable = sources.find((s) => /\.m3u8/i.test(s.url || "")) ||
                 sources.find((s) => s.url);
  if (!usable) {
    console.error(JSON.stringify({ found: null, sources: sources.length }));
    process.exit(1);
  }
  const subtitles = (opened.subtitles || []).map((s) => s.url || s.src).filter(Boolean);
  console.error(JSON.stringify({
    found: usable.url,
    quality: usable.quality || "",
    type: usable.type || "",
    sources: sources.length,
    subtitles: subtitles.length,
  }));
  console.log(usable.url);
  if (subtitles.length) console.error("subtitle: " + subtitles[0]);
} catch (error) {
  console.error("notch-resolve: " + error.message);
  process.exit(1);
}
}

if (process.argv[1] && process.argv[1].endsWith("notch-resolve.mjs")) {
  await main();
}
