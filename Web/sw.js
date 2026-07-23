/* Treadway service worker — network-first so updates always reach signed-in devices
   when online, with a cached fallback so the app still opens offline. Supabase
   API calls are never intercepted (they hit the network; offline writes are
   handled by the app's outbox). Bump CACHE to force a clean refresh. */
const CACHE = "treadway-shell-v8";
const SHELL = ["./", "index.html", "privacy.html", "setup.html", "styles.css", "app.js", "config.js", "manifest.webmanifest", "icon.svg", "icon-180.png", "icon-192.png", "icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) =>
    Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
  ).then(() => self.clients.claim()));
});
self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (url.origin !== location.origin) return;              // let Supabase/CDN hit network
  e.respondWith(
    fetch(e.request).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(e.request, copy)).catch(() => {});
      return res;
    }).catch(() => caches.match(e.request))                // offline fallback
  );
});

/* ---- Push reminders ---- */
self.addEventListener("push", (e) => {
  let data = { title: "Treadway", body: "You have tasks to do." };
  try { if (e.data) data = Object.assign(data, e.data.json()); }
  catch (_) { if (e.data) data.body = e.data.text(); }
  e.waitUntil(self.registration.showNotification(data.title, {
    body: data.body,
    icon: "icon-192.png",
    badge: "icon-192.png",
    tag: data.tag || "treadway",
    renotify: true,
    data: data
  }));
});
self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((cl) => {
    for (const c of cl) { if ("focus" in c) return c.focus(); }
    if (self.clients.openWindow) return self.clients.openWindow("./");
  }));
});
