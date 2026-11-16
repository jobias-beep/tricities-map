// Home-screen app helper. Keeps a copy of the map page and its libraries so the app
// opens fast and still opens with a weak signal. Customer data (Supabase), map tiles
// and property-line lookups always go to the network and are never stored here.
const VERSION = "prestige-map-v2";
const SHELL = ["./", "manifest.webmanifest", "icons/icon-192.png", "icons/apple-touch-icon.png"];
const LIB_HOSTS = ["unpkg.com", "cdn.jsdelivr.net", "cdnjs.cloudflare.com", "fonts.googleapis.com", "fonts.gstatic.com"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // The map page itself: always try for the newest version first, fall back to the saved copy.
  if (req.mode === "navigate" && url.origin === location.origin) {
    e.respondWith(
      fetch(req)
        .then(res => { const copy = res.clone(); caches.open(VERSION).then(c => c.put("./", copy)); return res; })
        .catch(() => caches.match("./"))
    );
    return;
  }

  // Version-pinned libraries and fonts: never change, so serve the saved copy.
  if (LIB_HOSTS.includes(url.hostname)) {
    e.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        if (res.ok || res.type === "opaque") { const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); }
        return res;
      }))
    );
    return;
  }

  // App icons and manifest from this site.
  if (url.origin === location.origin) {
    e.respondWith(caches.match(req).then(hit => hit || fetch(req)));
  }
  // Everything else (Supabase, tiles, county parcels, Google) goes straight to the network.
});
