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
6. **Flagship motion + professional tutorial feel** — cold-launch skip/shared-ring handoff,
   traveling spotlight, blur/exposure transitions, blank-account gesture showcase, caption safe
   areas, and Back/Continue/Skip need real iPhone timing/visual confirmation. Automatic first-run
   launch and Settings replay passed browser QA, but a desktop browser cannot establish 60fps or
   exact safe-area feel on the phone.
7. **Today daily-ritual shell + Cairn Close** — verify hero density, internal scrolling,
   floating-tab safe-area placement/auto-hide, one-shot seal motion, and Close-sheet feel in both
   Light and OLED on the iPhone 17.
8. **Two-phone Proud nudge** — the live server link/send-once/unlink rules passed with isolated
   disposable accounts. When her phone is available, confirm quiet hours, lock-screen copy,
   received state, and reciprocal unlink in both real PWAs.
If a gesture fails, the likely culprit is touch-scroll stealing the gesture — see the
non-passive `touchmove` blocker in `bindRowGestures` (app.js) and `touch-action` on `.rowwrap`.

## Blocked / waiting on a phone
- **Paxton's phone:** after this deployment, open Cairn → Settings → Reminders, turn reminders
  off, then back on and allow notifications. This replaces the old push subscription with one
  signed by the rotated public VAPID key.
- **Her phone, whenever available:** do the same reminders off/on cycle, then complete the
  in-app six-digit pairing flow and real two-phone Proud nudge/quiet-hours/lock-screen test above.
  The owner is currently unlinked and her account ID is not documented, so do not guess among
  approved members. The reciprocal link, once-daily nudge, and unlink authorization already
  passed server-side with isolated disposable accounts.

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
