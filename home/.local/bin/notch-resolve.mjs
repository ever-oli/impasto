// notch-resolve.mjs — the stream for a film or a series, without a browser.
//
// A site's player page asks an api for the sources and opens the answer
// with a small webassembly module the api hands out. This walks the same
// path in plain node: the player page for the id, the single-use token
// it carries, the api, and the wasm that opens the answer.
//
//   node notch-resolve.mjs --tmdb 550 --title "Fight Club" --year 1999 --type movie
//   node notch-resolve.mjs --tmdb 1396 --title "Breaking Bad" --year 2008 \
//       --type tv --season 1 --episode 1
//
// It prints the playlist address on stdout and what it saw on stderr.

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
           "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
const SITE = "https://vidsrc.sh";

// The player hands out a cookie and wants it back, so keep the jar.
const jar = new Map();

function remember(response) {
  const lines = response.headers.getSetCookie ? response.headers.getSetCookie() : [];
  for (const line of lines) {
    const pair = line.split(";")[0];
    const at = pair.indexOf("=");
    if (at > 0) jar.set(pair.slice(0, at).trim(), pair.slice(at + 1).trim());
  }
}

async function get(url, referer) {
  const headers = { "User-Agent": UA, "Accept": "*/*" };
  if (referer) headers["Referer"] = referer;
  if (jar.size) {
    headers["Cookie"] = [...jar].map(([key, value]) => `${key}=${value}`).join("; ");
  }
  const response = await fetch(url, { headers });
  remember(response);
  return response;
}

// The pages carry their settings as a plain object on the window.
function config(html, name) {
  const at = html.indexOf(`window.${name}`);
  if (at === -1) return null;
  const open = html.indexOf("{", at);
  if (open === -1) return null;
  let depth = 0;
  for (let index = open; index < html.length; index++) {
    if (html[index] === "{") depth++;
    else if (html[index] === "}") {
      depth--;
      if (!depth) {
        try { return JSON.parse(html.slice(open, index + 1)); } catch { return null; }
      }
    }
  }
  return null;
}

// The api's answer holds the streams as one encrypted string; the wasm
// the api names opens it. A plain answer needs no wasm.
async function open(answer) {
  const streams = answer && answer.data ? answer.data.stream_urls : null;
  if (Array.isArray(streams)) return streams.filter(Boolean);
  if (typeof streams !== "string") return [];
  const vs = answer.vs || {};
  const bytes = vs.wasm_url
    ? Buffer.from(await (await get(vs.wasm_url)).arrayBuffer())
    : Buffer.from(vs.wasm || "", "base64");
  const module = await WebAssembly.compile(bytes);
  const instance = await WebAssembly.instantiate(module, {});
  const exports = instance.exports;
  const raw = Buffer.from(streams, "base64");
  const pointer = exports.alloc(raw.length);
  new Uint8Array(exports.memory.buffer, pointer, raw.length).set(raw);
  const length = exports.decrypt(pointer, raw.length);
  const text = new TextDecoder().decode(
    new Uint8Array(exports.memory.buffer, pointer + 12, length));
  return text.split("\n").filter(Boolean);
}

// A host answers with a plain token, or with json holding one.
function parseToken(text) {
  const trimmed = String(text || "").trim();
  if (!trimmed) return "";
  if (trimmed[0] === "{" || trimmed[0] === "[") {
    try {
      const parsed = JSON.parse(trimmed);
      if (typeof parsed === "string") return parsed;
      if (parsed && typeof parsed === "object") {
        return parsed.token || parsed.data || parsed.string || parsed.result || "";
      }
    } catch { /* not json after all */ }
  }
  return trimmed;
}

// Each host has its own short token, fetched just before its playlist.
// The host is in a hurry and says so: a refusal must not become a token.
async function stamp(url) {
  let origin = "";
  try { origin = new URL(url).origin; } catch { return url; }
  const response = await get(`${origin}/generate.php`);
  if (!response.ok) return url;
  const token = parseToken(await response.text());
  if (!token || token.startsWith("<")) return url;
  if (url.includes("__TOKEN__")) return url.split("__TOKEN__").join(token);
  return url + (url.includes("?") ? "&" : "?") + "token=" + encodeURIComponent(token);
}

function argument(name, fallback) {
  const at = process.argv.indexOf("--" + name);
  if (at === -1 || at + 1 >= process.argv.length) return fallback;
  return process.argv[at + 1];
}

const tmdb = argument("tmdb", "");
const title = argument("title", "");
const year = argument("year", "");
const type = argument("type", "movie");
const season = argument("season", "");
const episode = argument("episode", "");

if (!tmdb) {
  console.error("usage: notch-resolve.mjs --tmdb <id> [--title <name>] [--year Y] " +
                "[--type movie|tv] [--season N] [--episode N]");
  process.exit(2);
}

try {
  // The player page for this id, and the player it points at.
  const query = new URLSearchParams({ type, id: tmdb });
  if (type === "tv") {
    query.set("season", season || "1");
    query.set("episode", episode || "1");
  }
  const reply = await get(`${SITE}/vs_src.php?${query}`);
  const src = (await reply.json()).src;
  const player = new URL(src).origin;

  const embedPage = await (await get(src, `${SITE}/embed/${type}/${tmdb}`)).text();
  const embedSettings = config(embedPage, "CFG") || config(embedPage, "CONFIG");
  if (!embedSettings || !embedSettings.playerUrl) {
    throw new Error("the player page hid its player");
  }

  // The player carries a token the api accepts once.
  const playerPage = await (await get(player + embedSettings.playerUrl, src)).text();
  const settings = config(playerPage, "CONFIG");
  if (!settings || !settings.apiToken) {
    throw new Error("the player carried no token");
  }
  // A film names its api outright; a series names the base and the
  // episode to ask for.
  const api = new URL(settings.api || settings.streamBase);
  if (!settings.api) {
    api.searchParams.set("season", settings.season || season || "1");
    api.searchParams.set("episode", settings.episode || episode || "1");
    api.searchParams.set("stream_urls", "");
  }
  api.searchParams.set("api_token", settings.apiToken);
  const answer = await (await get(api.toString(), player + "/")).json();
  if (answer && answer.status_code && String(answer.status_code) !== "200") {
    throw new Error("the api said " + answer.status_code);
  }

  const streams = await open(answer);
  if (!streams.length) throw new Error("the api named no stream");

  const playable = await stamp(streams[0]);
  const report = {
    found: playable,
    referer: player + "/",
    title: (answer.data && answer.data.title) || title,
    year,
    streams: streams.length,
  };
  console.error(JSON.stringify(report));
  if (process.argv.includes("--json")) {
    console.log(JSON.stringify(report));
  } else {
    console.log(playable);
  }
} catch (error) {
  console.error("notch-resolve: " + error.message);
  process.exit(1);
}
