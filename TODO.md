# Treadway (formerly Trailhead, formerly Cairn) — TODO

_Last updated: 2026-07-23. Keep prioritized; delete done items (they go to CHANGELOG)._

## ⏳ ACTIVE — Impeccable full polish pass (in progress, user wants "the most polished app ever")
Driven by `/impeccable critique` (score 33/40). Refinement of the incumbent world, NOT a redesign.
CSS-led; verify each with browser + `detect.mjs` + `node --check`; commit after each. Progress:
- [x] **P1 contrast** — `--faint` failed AA in all 3 themes; now dark #8e908a, oled #828480,
      light #71736d (all clear 4.5:1 on real backgrounds; computed + browser-verified). commit 461891c
- [x] **P2 hierarchy** — dissolved the nested `.daystats` card into a borderless band; ring is hero.
- [x] **P2 reveal gestures** — one-time swipe `peekhint` (maybeSwipeHint); gated post-tour, max 2,
      reduced-motion-safe, canceled on pointerdown. Verified: pencil reveals.
- [x] **P3 detector** — side-tab callout, tutorial dots off `width`, blockquote 1px. Detector CLEAN (0).
- [ ] `/impeccable polish` pass → verify-fix
- [ ] `/impeccable audit` (a11y/perf) → verify-fix  (NOTE: accessibility roadmap #10 — rows are
      clickable divs likely missing role/aria/focus; expect audit to flag. Fix there.)
- [ ] `/impeccable critique` re-run → confirm score rises; final deploy; update CHANGELOG/DECISIONS.
Deployed through sw.js **v15**. Detector: `node /Users/paxton/.claude/skills/impeccable/scripts/detect.mjs --json <files>`.
Deploy = bump sw.js + `npx surge . cairn.surge.sh`. Live QA gotchas: launch overlay + rAF + CSS
transitions are PAUSED while the preview isn't painting — remove `#launch`/read post-transition
values or neutralize transitions when verifying; always resize to 375×812 first.


**Current release state:** the product is renamed **Treadway** with a redesigned stepping-stone
mark (live, no SQL). The earned meal-plan Cheat Day UI and reminder handling remain current.
Treadway assets are live at the original `cairn.surge.sh` origin (origin deliberately unchanged).
The list below is real-device confirmation, per-phone reinstall/resubscription, one
unavailable-phone partner test, one optional gesture enhancement, plus the sellability roadmap.

## ⚠️ Needs confirmation on a REAL iPhone (dev env has no touch device)
Everything below is verified with synthetic pointer events in a desktop browser only.
1. **Hold-to-drag reorder** — press ~0.4s, row lifts, drag, release. Should stay put.
2. **Drag between categories** — drop on another group's card; it should adopt that category.
3. **Swipe** right = blue pencil (edit), left = red trash (delete + undo toast). The rAF-batched,
   transform-only path passes at 375×812 in browser QA; confirm actual iPhone frame pacing.
4. **Undo toast** on delete ("Deleted — Undo") — visually confirmed in mobile browser QA and
   restored the exact row; still confirm real touch timing.
5. **Sheet notch** drag-down-to-dismiss + no background scrolling behind sheets.
6. **Flagship motion + professional tutorial feel** — the launch animation is now the branded
   FIRST paint (pre-rendered in index.html, no spinner); confirm on the phone that there's no
   spinner flash, the mark lays in, and it hands off/fades cleanly. Also: richer page-transition
   slide+scale, active-tab pop, cold-launch skip/shared-logo handoff, traveling spotlight,
   blur/exposure transitions, blank-account gesture showcase, caption safe areas, Back/Continue/
   Skip. Browser QA passed, but a desktop browser cannot establish 60fps or exact safe-area feel.
   **Haptics are wired app-wide but iOS Safari ignores the Vibration API — they will NOT fire on
   the iPhone.** They work on Android; true iPhone haptics require the native app. Don't "fix" the
   haptics thinking they're broken — the web platform simply doesn't expose them on iOS.
7. **Today daily-ritual shell + Trailhead Close** — verify hero density, internal scrolling,
   floating-tab safe-area placement/auto-hide, one-shot seal motion, and Close-sheet feel in both
   Light and OLED on the iPhone 17.
8. **Two-phone Proud nudge** — the live server link/send-once/unlink rules passed with isolated
   disposable accounts. When her phone is available, confirm quiet hours, lock-screen copy,
   received state, and reciprocal unlink in both real PWAs.
9. **Meal-plan Cheat Day feel** — configure a meal task under Edit → More options, confirm the
   progress card is readable in Light and OLED, and eventually verify Use/End Cheat Day on the
   real iPhone. Earned/active/toggle-back logic, 7- and 30-day settings, minimum validation,
   reminder suppression code, and 375×812 containment already passed local browser QA.
If a gesture fails, the likely culprit is touch-scroll stealing the gesture — see the
non-passive `touchmove` blocker in `bindRowGestures` (app.js) and `touch-action` on `.rowwrap`.

## Blocked / waiting on a phone
- **Paxton's phone:** open `https://cairn.surge.sh` once so the new shell loads. Delete the old
  Cairn Home Screen icon, then in Safari use Share → Add to Home Screen, confirm the name is
  **Trailhead**, and add it. Open Trailhead, sign in if asked, then go to Settings → Reminders and
  turn reminders off/back on. Removing the shortcut does not delete synced account data.
- **Her phone, whenever available:** do the same Cairn-icon removal, Trailhead re-add, and
  reminders off/on cycle, then complete the
  in-app six-digit pairing flow and real two-phone Proud nudge/quiet-hours/lock-screen test above.
  The owner is currently unlinked and her account ID is not documented, so do not guess among
  approved members. The reciprocal link, once-daily nudge, and unlink authorization already
  passed server-side with isolated disposable accounts.
- **No manual Supabase or SQL work is pending for either the Trailhead rebrand or Cheat Day
  rewards.** Do not rerun product migrations or rotate credentials for either change.

## Next features (not yet built)
1. Dropping into an **empty/absent category** isn't possible (groups only render when they have
   tasks). Workaround: change group in Edit. Could render placeholder drop zones during a drag.

## Sellability roadmap (if this ever becomes a paid product)
Staged by what blocks charging money. Ordered; do top-down. "DONE" items shipped this session.
**Tier 0 — hard blockers on charging anyone**
1. ~~Name collided with Salesforce (Trailhead)~~ — DONE: renamed **Treadway**. Still NOT legal
   clearance; get a professional trademark search before public paid launch (Treadway is a surname).
2. **Commercial domain.** `cairn.surge.sh` is a free subdomain and can't be a paid product's home.
   Needs a purchased domain + a planned origin migration (Supabase Auth redirect, PWA reinstall,
   push-subscription migration all move together). Do it at the same time as any future re-brand.
3. **Self-serve signup.** Today every signup needs owner approval (a guest list, not a business).
   Selling needs sign-up → pay → use without a human in the loop. Approval hub becomes anti-abuse.
4. **Billing.** No Stripe/checkout/plan/trial anywhere. Needs a payment integration + plan gating.
**Tier 1 — breaks quietly once strangers use it**
5. ~~No error tracking~~ — DONE: global handler + local buffer + optional `error-log.sql`.
6. **Backups.** Free Supabase has no point-in-time recovery + pauses after inactivity (verify
   current terms). Paid tier or a scheduled `pg_dump`. Needs owner action (credentials/billing).
7. **Email deliverability.** Supabase built-in SMTP is rate-limited and not for production; resets/
   confirmations will silently drop past a few/hour. Needs Resend/Postmark on the real domain
   (SPF/DKIM). Owner action.
8. **Terms of Service.** Privacy policy exists; no ToS (liability, refunds, subscription terms).
   Can be drafted in-repo (matches privacy.html), owner gets it reviewed before charging.
9. **Analytics.** None. Privacy-respecting (Plausible/Umami) fits the brand; needs an account.
**Tier 2 — hobby vs product**
10. **Accessibility.** ~13 aria-*, but zero `role=` and zero `alt=`. Clearest "built by pros"
    signal and low-risk pure-code work — good next autonomous item.
11. **Landing page.** `index.html` IS the app; a stranger hits a login form with no explanation.
12. **Automated tests.** All QA is manual. A small headless suite over streak/date/cheat-day logic
    would catch the most expensive class of regression.
13. **`app.js` is one ~1650-line / 130KB file.** No-build-step was right for personal scale; it's
    the ceiling on safe change velocity. Don't split yet, but know it's the limit.
**Tier 3 — strategic**
14. **$99 Apple Developer** buys distribution + payment rails + the two things habit apps get paid
    for (widgets, HealthKit) that a PWA can't do. Deferred "a few months".
15. **Positioning** is the real asset: the ritual framing (day stone, Close, Weekly Trail) + the
    couple/accountability layer. Won't win on task-checking; build any pitch around those.

## Known caveats
- Access checks fail closed on unknown server errors. A cached previously-approved user can still
  open their cached offline view, while server RLS remains authoritative for all remote data.
- Weekly Trail replays the current active task definitions across seven days; adding or archiving
  tasks intentionally reshapes the rolling view and the UI states this.
- App-URL scheme presets (mfp://, youversion://, instagram://) are best guesses.
- Web push needs the PWA added to the Home Screen on iOS.
- Reorder pushes an upsert for every active task (fine at personal scale).
- **Treadway is a user-directed working/private brand, not a cleared public trademark.** It was
  renamed from Trailhead (which collided with Salesforce). Web search found no software/app
  "Treadway", but that is NOT legal clearance and "Treadway" is also a surname — obtain a
  professional trademark search before charging the general public.
- **The live origin is still `https://cairn.surge.sh`** even though the product is named Treadway.
  The origin is deliberately unchanged (Supabase auth redirects + push subscriptions are bound to
  it). Every shared link must use `cairn.surge.sh`. A future branded address needs a verified-
  available hostname plus Supabase Auth redirect, PWA reinstall, and push-subscription migration —
  do not change origins casually. Note `trailhead.surge.sh` is occupied by an unrelated site; a
  `treadway.surge.sh` was NOT checked or claimed.
- ~~Redeploy `send-reminders` for the Treadway push title~~ — DONE 2026-07-23; live reminders
  now title "Treadway".

## Testing gotcha (cost ~30 min once — don't repeat it)
The in-app browser pane can collapse to a **0×0 viewport**, which makes every
`getBoundingClientRect()` ~2px and `elementFromPoint` return null — tests then "fail" for no
reason. Always `resize_window` to the mobile preset (375×812) first and sanity-check
`window.innerWidth` before trusting a geometry/gesture test.
