# Treadway web app

This folder is the deployed, installable Treadway PWA. It is a static client backed by Supabase Auth, Postgres/Row Level Security, and Edge Functions.

## Current status

- Live at [cairn.surge.sh](https://cairn.surge.sh).
- Working access-gated private beta with cross-device sync and offline continuity.
- Customer-facing product name: **Treadway**.
- Live origin and compatibility identifiers intentionally remain `cairn.surge.sh`, `cairn_*`, and `window.CAIRN_CONFIG`.

## Files

```text
index.html             application shell and first paint
app.js                 state, auth, data, views, gestures, and offline behavior
styles.css             responsive design system and motion
config.js              public browser configuration only
manifest.webmanifest   installed-PWA metadata
sw.js                  versioned application-shell cache
privacy.html           public privacy policy
setup.html             phone installation guide
schema.sql             base database schema and RLS
icon-* / icon.svg      installed identity assets
```

## Run locally

```bash
python3 -m http.server 8080
```

Open `http://localhost:8080`. The checked-in Supabase URL and publishable browser key are public client configuration. Never place private VAPID material, service-role keys, cron secrets, passwords, or production data in this directory.

## Deploy

The production origin currently uses Surge:

```bash
npx surge . cairn.surge.sh
```

Changing the origin is a migration, not a cosmetic rename. It must update Supabase Auth redirects, installed PWAs, and web-push subscriptions together.

## Verification

From the repository root, run `npm test`. After a meaningful deployment, compare the live assets with the local release and perform the device-specific checks listed in `Documentation/DEVELOPMENT_STATUS.md`.
