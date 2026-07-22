# Cairn — TODO

_Last updated: 2026-07-22. Keep prioritized; delete done items (they go to CHANGELOG)._

## ⚠️ Needs confirmation on a REAL iPhone (dev env has no touch device)
Everything below is verified with synthetic pointer events in a desktop browser only.
1. **Hold-to-drag reorder** — press ~0.4s, row lifts, drag, release. Should stay put.
2. **Drag between categories** — drop on another group's card; it should adopt that category.
3. **Swipe** right = blue pencil (edit), left = red trash (delete + undo toast).
4. **Undo toast** on delete ("Deleted — Undo") — never visually confirmed at all.
5. **Sheet notch** drag-down-to-dismiss + no background scrolling behind sheets.
6. **Flagship motion feel** — cold-launch skip/shared-ring handoff and moving tutorial spotlight
   need real iPhone timing/visual confirmation; browser QA cannot establish touch feel or 60fps.
7. **Today daily-ritual shell** — verify hero density, internal scrolling, floating-tab safe-area
   placement/auto-hide, and reflection-sheet feel in both Light and OLED on the iPhone 17.
If a gesture fails, the likely culprit is touch-scroll stealing the gesture — see the
non-passive `touchmove` blocker in `bindRowGestures` (app.js) and `touch-action` on `.rowwrap`.

## Blocked / waiting on the user
- **Access hub not active until 2 steps are done** (code deployed):
  1. Run `access-hub.sql` in Supabase (assumes owner email `paxtonraithel@gmail.com`; has a
     fallback line to set admin by email).
  2. Re-enable Supabase Auth → "Allow new users to sign up". **Do the SQL first.**
  - Verify: owner sees Settings → "Members · admin"; a throwaway signup lands as `pending`.
- **Her phone unavailable** → couple layer (pairing + partner card) and her reminders untested.

## Next features (not yet built)
1. **"Proud of you" nudge** (couple layer) — send partner an encouragement push. Needs a
   `nudges` table + edge-fn work (extend `send-reminders`). Last real couple-layer gap.
2. Dropping into an **empty/absent category** isn't possible (groups only render when they have
   tasks). Workaround: change group in Edit. Could render placeholder drop zones during a drag.

## Known caveats
- `loadAccess` fails OPEN (errors → approved) so the owner is never locked out; a transient error
  could let a pending user slip through. Fine at friends scale.
- App-URL scheme presets (mfp://, youversion://, instagram://) are best guesses.
- Web push needs the PWA added to the Home Screen on iOS.
- Reorder pushes an upsert for every active task (fine at personal scale).

## Testing gotcha (cost ~30 min once — don't repeat it)
The in-app browser pane can collapse to a **0×0 viewport**, which makes every
`getBoundingClientRect()` ~2px and `elementFromPoint` return null — tests then "fail" for no
reason. Always `resize_window` to the mobile preset (375×812) first and sanity-check
`window.innerWidth` before trusting a geometry/gesture test.
