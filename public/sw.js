// Offline support. Install caches the app shell — index.html plus the hashed JS/CSS bundle it links,
// which the very first page load fetched before this worker existed — and the library + dictionary.
// Stories and pictures are cached as they are opened, so every story read once keeps working offline.
const CACHE = "readle-v2";
const CORE = ["./", "./content/stories.json", "./content/dict.json", "./manifest.webmanifest", "./icon.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      await cache.addAll(CORE);
      const html = await (await cache.match("./")).text();
      const bundle = [...html.matchAll(/(?:src|href)="((?:\.\/)?assets\/[^"]+)"/g)].map((m) => m[1]);
      await cache.addAll(bundle);
    })(),
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))),
  );
  self.clients.claim();
});

// Word clips: an audio element asks for byte ranges and gets 206 partial responses, which the Cache
// API can't store, so a clip heard online would never play offline. Fetch the whole clip (no Range
// header, so 200), keep it, and answer the element with the full file, online or off.
async function clip(event) {
  const url = event.request.url;
  try {
    const response = await fetch(url);
    if (response.status === 200) {
      const copy = response.clone();
      event.waitUntil(caches.open(CACHE).then((c) => c.put(url, copy)));
    }
    return response;
  } catch {
    return (await caches.match(url, { ignoreVary: true })) ?? Response.error();
  }
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;
  if (url.pathname.includes("/content/audio/")) {
    event.respondWith(clip(event));
    return;
  }
  // Network first so content updates arrive; the cache is the fallback.
  event.respondWith(
    fetch(request)
      .then((response) => {
        // 200 only: audio elements may get 206 partial responses, which the Cache API rejects.
        if (response.status === 200) {
          const copy = response.clone();
          event.waitUntil(caches.open(CACHE).then((c) => c.put(request, copy)));
        }
        return response;
      })
      .catch(async () => {
        // ignoreVary: module scripts are requested with an Origin header, and a server that answers
        // with "Vary: Origin" (vite preview, some CDNs) would otherwise never match the precache.
        const hit = await caches.match(request, { ignoreVary: true });
        if (hit) return hit;
        // Only a page load falls back to the app shell; a missing script, story or image must fail
        // as itself, not come back as index.html (which broke module loading and JSON parsing).
        if (request.mode === "navigate") return (await caches.match("./")) ?? Response.error();
        return Response.error();
      }),
  );
});
