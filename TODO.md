# Cairn — TODO

_Last updated: 2026-07-22. Keep prioritized; delete done items (they go to CHANGELOG)._

## ⚠️ Needs confirmation on a REAL iPhone (dev env has no touch device)
Everything below is verified with synthetic pointer events in a desktop browser only.
1. **Hold-to-drag reorder** — press ~0.4s, row lifts, drag, release. Should stay put.
2. **Drag between categories** — drop on another group's card; it should adopt that category.
3. **Swipe** right = blue pencil (edit), left = red trash (delete + undo toast). The rAF-batched,
   transform-only path passes at 375×812 in browser QA; confirm actual iPhone frame pacing.
4. **Undo toast** on delete ("Deleted — Undo") — visually confirmed in mobile browser QA and
   restored the exact row; still confirm real touch timing.
5. **Sheet notch** drag-down-to-dismiss + no background scrolling behind sheets.
6. **Flagship motion feel** — cold-launch skip/shared-ring handoff and moving tutorial spotlight
   need real iPhone timing/visual confirmation; browser QA cannot establish touch feel or 60fps.
7. **Today daily-ritual shell + Cairn Close** — verify hero density, internal scrolling,
   floating-tab safe-area placement/auto-hide, one-shot seal motion, and Close-sheet feel in both
   Light and OLED on the iPhone 17.
8. **Two-phone Proud nudge** — after the product SQL is active, confirm send-once behavior, quiet
   hours, lock-screen copy, received state, and reciprocal unlink using both real accounts.
If a gesture fails, the likely culprit is touch-scroll stealing the gesture — see the
non-passive `touchmove` blocker in `bindRowGestures` (app.js) and `touch-action` on `.rowwrap`.

## Blocked / waiting on the user
- Run only `cairn-product-upgrade.sql`; `access-hub.sql` is retired. Then verify the
  owner admin, a pending throwaway signup, mutual partner nudge, and reciprocal unlink.
- Rotate the historically tracked VAPID key pair and `CRON_SECRET`: update the Edge secrets,
  replace `VAPID_PUBLIC_KEY` in `Web/config.js` with the new public key and redeploy, then
  reschedule the cron invocation with the new cron value entered only in Supabase SQL Editor.
  Both phones must turn Reminders off/on afterward so their subscriptions use the new VAPID key.
  Tracked files deliberately contain no private values.
- Password recovery requires the Supabase Auth Site URL and redirect allowlist to include
  `https://cairn.surge.sh`.
- Before a public paid launch, replace the explicitly early-access privacy overview with a formal
  policy containing the operator identity, public support contact, effective terms, and notice
  process.
- **Her phone unavailable** → real two-phone nudge, couple, and push behavior remains untested.

## Next features (not yet built)
1. Dropping into an **empty/absent category** isn't possible (groups only render when they have
   tasks). Workaround: change group in Edit. Could render placeholder drop zones during a drag.

## Known caveats
- Access checks fail closed on unknown server errors. A cached previously-approved user can still
  open their cached offline view, while server RLS remains authoritative for all remote data.
- Weekly Trail replays the current active task definitions across seven days; adding or archiving
  tasks intentionally reshapes the rolling view and the UI states this.
- App-URL scheme presets (mfp://, youversion://, instagram://) are best guesses.
- Web push needs the PWA added to the Home Screen on iOS.
- Reorder pushes an upsert for every active task (fine at personal scale).

## Testing gotcha (cost ~30 min once — don't repeat it)
The in-app browser pane can collapse to a **0×0 viewport**, which makes every
`getBoundingClientRect()` ~2px and `elementFromPoint` return null — tests then "fail" for no
reason. Always `resize_window` to the mobile preset (375×812) first and sanity-check
`window.innerWidth` before trusting a geometry/gesture test.
