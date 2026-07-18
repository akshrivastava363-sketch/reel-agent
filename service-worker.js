const CACHE_NAME = 'reel-agent-v3';
const APP_SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  // App shell: network-first so updates always reach installed devices.
  // Falls back to cache only when offline. Gemini API calls / remote media
  // are cross-origin and untouched by this handler (network-only).
  const url = new URL(event.request.url);
  if(url.origin === self.location.origin){
    event.respondWith(
      fetch(event.request)
        .then(res => {
          const resClone = res.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, resClone));
          return res;
        })
        .catch(() => caches.match(event.request))
    );
  }
});
