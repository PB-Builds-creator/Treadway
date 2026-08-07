# Treadway (formerly Trailhead, formerly Cairn) — TODO

_Last updated: 2026-08-03. Keep prioritized; delete done items (they go to CHANGELOG)._

## ✅ DONE — Visual + motion evolution (all 4 phases; critique 35 → 36/40 Excellent)
Shipped through sw.js **v19**, detector clean throughout, both themes verified. See CHANGELOG
(2026-08-03) + DECISIONS ("accent is theme-aware, fills split"). Optional reworks the user OK'd for
later: frosted sheet backdrop, secondary-button depth, richer empty-state motion, grouped-card pattern
in Manage/other sheets. The phase notes below are kept for the record.

## (history) Visual + motion evolution — phase log
**Scope (user-chosen):** EVOLVE the visuals (richer surfaces/materials, real depth/elevation system,
bolder-but-controlled color, redrawn components) + WEIGHTED-QUIET motion (Things/Oak/Apple — ease-out,
short, nothing bounces) + intentional motion on EVERY button/placeholder + reorganize Settings (less
clutter). PRESERVE the stones/path identity, structure, copy, function — evolve execution only.
Work in verified, committed phases; both-theme browser QA each; keep detector clean; `node --check`.
Deploy = bump sw.js + `npx surge . cairn.surge.sh`. Currently at sw.js **v16**.

- [x] **Phase 1 — Foundation (tokens/materials/depth).** DONE (commit c11d930, sw.js v17).
      Theme-aware bold `--accent` (light #43618a, dark #86a4c9, oled #8aa8cd — also fixed accent-text
      AA bug), `--accent-fill`/`--accent-2` fill split + gradient primary buttons, `--edge-hi` material
      highlight + `--shadow-2` elevation on .card/.daystone/tabs/btn, `--accent-soft` now color-mix of
      --accent. Verified OLED+light+sheet, detector clean. (Still TODO in later phases: apply edge-hi to
      the remaining cards — hyd/pathcard/trailcard/closecard/notecard/reviewcard/stat/cheatcard — and
      frosted materials on sheet backdrops.)
- [x] **Phase 2 — Material coherence + button depth.** DONE (commit 4e16c2e, sw.js v18). --edge-hi
      highlight extended to 14 more surfaces (all cards now lit material); primary button press now
      compresses its shadow (weighted). Existing press states (chips/rows/tabs/restcontrol) + directional
      transitions were already strong, so net-new = material + button depth. (Optional later reworks:
      per-control depth on secondary buttons, frosted sheet backdrop, richer empty-state motion.)
- [x] **Phase 3 — Settings reorganization.** DONE (commit 9c4ab5b, sw.js v19). Flat 13-row list →
      5 iOS grouped section cards (Your day/Appearance/Reminders/Account/Learn) via `.setsection`/
      `.setlabel`/`.setcard` + staggered entrance. All data-acts + #remVal/#themeLbl preserved.
- [x] **Phase 4 — Polish + verify + detector + re-critique.** Completed in `7069c6f`; light/OLED,
      reduced-motion, keyboard behavior, detector, cohesion review, CHANGELOG, and DECISIONS were closed out.
      Optional later refinements remain: frosted sheet backdrop, secondary-button depth, richer empty-state
      motion, and the grouped-card pattern in Manage/other sheets.
**Guardrails:** craft-floor is the quality floor (depth shadows need offset+blur; motion exp ease-out;
materials/blur/mask allowed when smooth). Reduced-motion must disable all new motion (blanket rule
exists). Don't break gestures (`bindRowGestures`), sort_index ordering, or the a11y roles just added.
Live QA gotcha: launch overlay + rAF + CSS transitions PAUSE when the preview isn't painting — remove
`#launch` / neutralize transitions when verifying; resize to 375×812 first.

## ✅ DONE — Impeccable polish pass (critique 33 → 35/40, detector 3 → 0)
Shipped through sw.js **v16**. All CSS-led refinement of the incumbent world (no redesign).
Contrast (`--faint` AA in all themes), day-stone hierarchy (nested card dissolved), swipe-peek
discoverability, task-row keyboard/screen-reader a11y (role=checkbox + focus rings + Enter/Space),
and the 3 detector nits — all fixed, both themes browser-verified, 0 console errors. See CHANGELOG.
Impeccable itself is installed in `~/.claude` (design skill + PostToolUse/Stop detector hook).
**Remaining a11y follow-ups (minor, next pass):** auth inputs use placeholder-only (no `<label>`);
the blanket `prefers-reduced-motion:*{animation:none}` kill could keep instant state feedback;
audit a few small touch targets (water chips, row trailing dot) for ≥44px on device.
Live QA gotchas: launch overlay + rAF + CSS transitions are PAUSED while the preview isn't painting
— remove `#launch` / neutralize transitions when verifying; always resize to 375×812 first.
Detector: `node /Users/paxton/.claude/skills/impeccable/scripts/detect.mjs --json <files>` (include styles.css).


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
- **Paxton's phone:** open `https://cairn.surge.sh` once so the new shell loads. Delete any old
  Cairn or Trailhead Home Screen icon, then in Safari use Share → Add to Home Screen, confirm the name is
  **Treadway**, and add it. Open Treadway, sign in if asked, then go to Settings → Reminders and
  turn reminders off/back on. Removing the shortcut does not delete synced account data.
- **Her phone, whenever available:** do the same old-icon removal, Treadway re-add, and
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
10. **Accessibility.** Task rows now have roles, names, state, keyboard activation, and focus-visible
    treatment; contrast issues found in the polish pass are fixed. A complete VoiceOver and real-device
    touch-target audit is still required before a broad public launch.
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
