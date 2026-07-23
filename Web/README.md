# Trailhead — synced web app

A private daily-discipline checklist for **you and your girlfriend**. Each person
signs in with their own email/password and gets their **own** list, synced across
all their devices. Data lives in *your* Supabase project (free tier); no one else
can read it (row-level security). Works offline and installs to the home screen.

## Files
```
Web/
├── index.html      app shell (loads Supabase, config, styles, app)
├── app.js          the app: auth, live sync, offline cache, all screens
├── styles.css      design system (light + dark)
├── config.js       your Supabase URL + public key  ← already filled in
├── schema.sql      database tables + security (already run in Supabase)
├── manifest.webmanifest · sw.js · icon-*.png   PWA / offline / home-screen icon
```

## Status
- ✅ Supabase project created, `schema.sql` run, security verified.
- ✅ `config.js` filled with your project URL + publishable key.
- ⬜ Deploy to the web (below) → get your live URL.

## Deploy it (free, ~2 minutes) — Netlify Drop
1. Go to **https://app.netlify.com/drop**.
2. Drag the **entire `Web` folder** onto the page.
3. It uploads and gives you a live URL like `https://random-name.netlify.app`.
4. (Optional) Make a free Netlify account to keep the URL and rename it
   (Site settings → Change site name → e.g. `paxton-trailhead` →
   `https://paxton-trailhead.netlify.app`).

That URL is the app. Open it on any device.

### Alternative hosts (any static host works)
- **Cloudflare Pages**: create a project → upload the `Web` folder.
- **Vercel**: `npx vercel` inside `Web/`.
- **GitHub Pages**: push `Web/` to a repo → enable Pages.

## Create your two logins
On the live URL:
1. **You:** open it → *New here? Create an account* → your email + a password →
   choose **Paxton's routine**.
2. **Her:** she opens the same URL on her phone → *Create an account* → her email +
   password → choose **Her routine**.

Each account only ever sees its own data. Sign in once per device and it stays
signed in.

> Sign-up is instant only if email confirmation is **off** in Supabase
> (Authentication → Sign In / Providers → Email → "Confirm email" = off). If it's
> on, you'll each get a confirmation email to click first.

## Add to home screen (feels like a native app)
- **iPhone (Safari):** open the URL → Share → **Add to Home Screen**. Launches
  full-screen with the Trailhead icon.
- **Mac (Safari):** File → **Add to Dock**. **Chrome:** install icon in the address bar.

## What works
Today / Week / History / Settings · one-tap complete · hydration ring + quick-add ·
recurrence (daily / specific days / weekly) · Mountain-Time daily reset · current &
longest streaks · 30-day history · add/edit/delete tasks · accent + light/dark ·
**live sync across your devices** · **offline** (changes queue and sync on reconnect).

## Not included on web (native-only, by platform)
Home-screen widgets, background push reminders, and Face ID — see the native Mac/iOS
app in the parent folder for those.

## Changing things later
- Edit tasks/goals in the app (Settings → Manage tasks) — syncs automatically.
- Change code/design → re-drag the folder to Netlify (or your host redeploys).
- The `0930` / `0307` quick-PIN lock from the preview can be added on request.
