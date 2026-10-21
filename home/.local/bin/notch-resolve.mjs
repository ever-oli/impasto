// notch-resolve.mjs — find the stream behind a source's page.
//
// A source's page (videasy, vidsrc, …) is a player that fetches its
// stream at runtime, so the stream is not in the HTML: it appears in the
// network. This opens the page in a browser and watches for the m3u8,
// which is what the player is about to play.
//
// It runs where the page is welcome: on a machine whose address the
// source accepts. The notch's own address is a cloud one, and these pages
// answer it with a 403, so the resolver belongs on the instabox box.
//
//   node notch-resolve.mjs <page-url> [browser]

import puppeteer from "puppeteer-core";

const url = process.argv[2];
if (!url) {
  console.error("usage: notch-resolve.mjs <page-url>");
  process.exit(2);
}

const browser = await puppeteer.launch({
  executablePath: process.argv[3] || "/usr/bin/chromium",
  headless: "new",
  args: [
    "--no-sandbox",
    "--disable-gpu",
    "--autoplay-policy=no-user-gesture-required",
    "--window-size=1280,720",
  ],
});

try {
  const page = await browser.newPage();
  const found = new Promise((resolve) => {
    page.on("response", (response) => {
      const target = response.url();
      if (target.includes(".m3u8")) resolve(target);
    });
  });

  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });

  const stream = await Promise.race([
    found,
    new Promise((resolve) => setTimeout(() => resolve(null), 45000)),
  ]);

  if (!stream) {
    console.error("notch-resolve: no stream in the page's network");
    process.exit(1);
  }
  console.log(stream);
} finally {
  await browser.close();
}
