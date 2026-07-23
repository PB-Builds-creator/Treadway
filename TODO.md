# Trailhead (formerly Cairn) — TODO

_Last updated: 2026-07-22. Keep prioritized; delete done items (they go to CHANGELOG)._

**Current release state:** the earned meal-plan Cheat Day web UI and reminder handling are the
current release; they require no SQL. Trailhead identity assets remain live at the original
`cairn.surge.sh` origin. The list below is intentionally limited to real-device confirmation,
per-phone reinstall/resubscription, one unavailable-phone partner test, and one optional future
gesture enhancement.

## ⚠️ Needs confirmation on a REAL iPhone (dev env has no touch device)
Everything below is verified with synthetic pointer events in a desktop browser only.
1. **Hold-to-drag reorder** — press ~0.4s, row lifts, drag, release. Should stay put.
2. **Drag between categories** — drop on another group's card; it should adopt that category.
3. **Swipe** right = blue pencil (edit), left = red trash (delete + undo toast). The rAF-batched,
   transform-only path passes at 375×812 in browser QA; confirm actual iPhone frame pacing.
4. **Undo toast** on delete ("Deleted — Undo") — visually confirmed in mobile browser QA and
   restored the exact row; still confirm real touch timing.
5. **Sheet notch** drag-down-to-dismiss + no background scrolling behind sheets.
6. **Flagship motion + professional tutorial feel** — cold-launch skip/shared-logo handoff,
   traveling spotlight, blur/exposure transitions, blank-account gesture showcase, caption safe
   areas, and Back/Continue/Skip need real iPhone timing/visual confirmation. Automatic first-run
   launch and Settings replay passed browser QA, but a desktop browser cannot establish 60fps or
   exact safe-area feel on the phone.
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

## Known caveats
- Access checks fail closed on unknown server errors. A cached previously-approved user can still
  open their cached offline view, while server RLS remains authoritative for all remote data.
- Weekly Trail replays the current active task definitions across seven days; adding or archiving
  tasks intentionally reshapes the rolling view and the UI states this.
- App-URL scheme presets (mfp://, youversion://, instagram://) are best guesses.
- Web push needs the PWA added to the Home Screen on iOS.
- Reorder pushes an upsert for every active task (fine at personal scale).
- **Trailhead is a user-directed working/private brand, not a cleared public trademark.**
  Salesforce actively uses Trailhead/Trailhead GO. Do not charge the general public under this
  name until professional clearance is obtained or the product is renamed.
- `trailhead.surge.sh` is occupied by an unrelated site and is not this app. The correct live link
  remains `https://cairn.surge.sh`. Do not change origins casually: a future branded address needs
  a verified available hostname plus Supabase Auth redirect, PWA reinstall, and push-subscription
  migration work.

## Testing gotcha (cost ~30 min once — don't repeat it)
The in-app browser pane can collapse to a **0×0 viewport**, which makes every
`getBoundingClientRect()` ~2px and `elementFromPoint` return null — tests then "fail" for no
reason. Always `resize_window` to the mobile preset (375×812) first and sanity-check
`window.innerWidth` before trusting a geometry/gesture test.
