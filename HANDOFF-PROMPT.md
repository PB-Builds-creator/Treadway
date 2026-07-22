# Cairn — Animation & Polish Handoff Prompt

_Copy everything below the line into a fresh session with your new model._

---

You are taking over a finished, live, personally-used app called **Cairn** and doing one job:
**making it feel like a flagship-tier native app through motion.** The logic is done and correct.
Do not redesign it. Make it *move* beautifully.

## Read these first, in this order

```
/Users/paxton/Cairn/PROJECT_CONTEXT.md   — architecture, how app.js works, deploy commands
/Users/paxton/Cairn/TODO.md              — open items + a testing trap that costs 30min if ignored
/Users/paxton/Cairn/DECISIONS.md         — why things are the way they are
/Users/paxton/Cairn/CHANGELOG.md         — what shipped, newest first
```

Then read `Web/app.js` (1338 lines) and `Web/styles.css` (459 lines) **in full** before writing
anything. This is a single-file vanilla-JS app with no framework and no build step; you cannot
understand a part of it without the whole.

## What Cairn is

A private daily-discipline app for two people (the owner + his girlfriend), plus an owner-gated
hub for friends. Live at **https://cairn.surge.sh**, installed to iPhone home screens as a PWA.
Tabs: Today / Week / History / Settings. Tasks grouped into categories, checked off daily, with
streaks, rest days, hydration tracking, and web-push reminders.

**A cairn is a stack of balanced stones that marks a path.** That is the entire design language.
Deliberate, weighted, quiet, permanent. Every animation you write should feel like *stone
settling into place* — never bouncy, never playful, never cartoonish. Think Things 3, Oak,
Apple Fitness rings. Weight and inevitability, not springiness and fun.

## Hard constraints — violating any of these breaks the app

1. **No dependencies, no framework, no build step.** Plain `<script src>` static files served by
   Surge. Do not add npm packages, bundlers, GSAP, Lottie, Framer, Tailwind, or anything else.
   Hand-written CSS + Web Animations API only.
2. **`prefers-reduced-motion` must disable everything you add.** There is already a guard in
   `styles.css` and one in `app.js` — extend them; never bypass them. Non-negotiable.
3. **Transform and opacity only.** No animating `width`, `height`, `top`, `left`, `margin`, or
   anything that triggers layout. This runs on a phone. Sixty frames per second is the bar; if an
   effect can't hold it, cut the effect.
4. **`render()` rebuilds the entire DOM via innerHTML on every state change.** Any animation
   state living in a DOM node is destroyed on re-render. Persist what must survive in JS
   variables (see how `lastRenderedTab` and `captureRows`/`playFlip` already handle this). This is
   the single biggest trap in the codebase — study `playFlip` before you animate anything that
   crosses a re-render.
5. **Order of tasks comes from `sort_index` and nothing else.** `bySort` is the only sort for
   Today. Never sort by `time` — `time` is purely a reminder. Reintroducing a time-sort silently
   resurrects a bug that took a full session to find.
6. **Never add a `lostpointercapture` handler to rows.** It ends drags prematurely. It was added
   once, broke gestures, and was removed. Do not rediscover this.
7. **Do not touch `vapid-private-KEEP-SECRET.txt`, and never put a secret in `Web/`** — that
   folder is deployed publicly to the open internet.
8. **Match the existing code style.** Terse, dense, no comments except where non-obvious, same
   naming conventions. Your code should be indistinguishable from what's there.

## What is ALREADY animated — do not rebuild these, only refine them

Existing `@keyframes`: `shake up sp pgin tcpop checkpop checkdraw checkripple donetext rowin
ringpulse burst fadein`

Existing motion functions: `animateRing`, `captureRows`/`playFlip` (FLIP), `celebrateBurst`,
`showToast`, `openSheet` (drag-to-dismiss with a real notch handle), `bindRowGestures`
(swipe-to-edit/delete + press-and-hold-to-reorder), `runTour` (12-step spotlight tour).

Already working: tab-change fade/rise, press states on buttons/rows/chips/tabs, checkbox pop +
checkmark draw + ripple, FLIP glide from list into Completed, drag-reorder with neighbours
opening a gap, sheet spring-back, blurred tour backdrop.

## Your mission, in priority order

### 1. The launch animation — this does not exist yet, and it matters most

There is currently **no splash, no boot sequence, nothing**. The app just appears. This is the
biggest missed opportunity in the product and the first thing the owner sees every single morning.

Build a cold-boot sequence where **stones stack into a cairn**, then the stack resolves into the
app. Requirements:

- **Under 900ms.** This is a daily-use app; a slow splash becomes hated by week two.
- **Cold boot only.** Not on every `render()`, not on tab switches, not on returning from
  background within a session. Gate it properly.
- **Skippable** — any tap during it jumps straight to the app.
- Stones should **land with weight**: fast in, decelerating hard, a micro-settle at the end. Each
  stone slightly overlapping the last. No bounce.
- **Best idea available to you:** the completed stone stack should *become* the progress ring —
  a shared-element transition where the stack's silhouette morphs into the Today ring. If you can
  land that, it will be the single most impressive moment in the app.
- It must not delay interactivity. Data loads behind it, not after it.

### 2. The tutorial — make the spotlight travel, not teleport

`runTour` currently jump-cuts between targets. Make it feel authored:

- The spotlight ring should **morph and travel** to its next target — animate position *and*
  size, with the caption gliding along beneath it.
- Add a **quiet pulse** on the highlighted element so the eye lands correctly.
- Add **progress dots** so the user knows how long this is.
- The **welcome card** should reveal in staggered lines rather than appearing at once.
- The **final card** should complete the cairn stack from the launch animation — bookending the
  experience. Same visual vocabulary, closing the loop.
- Keep the copy exactly as terse as it is. The owner explicitly asked that nothing sound
  AI-written: short, concise, profound. Do not add words. Do not add exclamation marks.

### 3. Completion moments — earn the dopamine

- The **progress ring** should sweep with a decelerating ease and the **percentage should count
  up** as an odometer, not snap.
- Ring animation should be **synchronized with the row's FLIP arrival** in Completed — right now
  they're independent, which reads as two unrelated events instead of one causal one.
- **Milestones at 25/50/75%** deserve a small acknowledgement. **100% deserves a real one** —
  restrained, weighted, gold. The existing `celebrateBurst` is a starting point, not the answer.
- **Streak count** should roll like an odometer when it increments.
- **Hydration** should read as liquid — a fill with a slow wave, and a ripple that travels
  through it when you add ounces. Currently it's a flat bar.

### 4. Everything else, continuously

- **Staggered row entrance** (~30ms apart) when a list renders.
- **Directional tab transitions** — slide left/right based on tab index rather than a uniform
  fade, so navigation has spatial logic. The active tab-bar indicator should **slide between
  tabs**, not cut.
- **Lifted row during drag** should cast a shadow that grows as it rises — sell the Z-axis.
- **Toast** should spring in from the bottom edge with weight.
- **Empty states** deserve a slow, subtle breath of motion so they don't read as broken.
- **Sheets** deserve real rubber-banding at the top of their scroll.
- Add **haptics** (`navigator.vibrate`) on completion, drag pickup, and drop — check support
  first; iOS Safari support is limited, so it must degrade silently.

Beyond this list: **use your own judgment aggressively.** You have the whole file in front of
you. If you see a transition that cuts when it should flow, fix it. The instruction is maximum
effort, not minimum sufficient.

## How to verify — you can actually see your work

You cannot log in (no credentials), but you can test the live site directly:

1. Open a browser tool on `https://cairn.surge.sh`.
2. **Resize the viewport to 375×812 FIRST**, and sanity-check `window.innerWidth`. The pane can
   silently collapse to 0×0, which makes every `getBoundingClientRect()` ≈2px and
   `elementFromPoint` return null — tests then "fail" for reasons that have nothing to do with
   your code. This cost the previous session ~30 minutes. Do not repeat it.
3. Inject a signed-in state: set globals `userId`, `session`, `access`, `unlocked`, `tab`,
   `state`, then call `render()`.
4. Screenshot, and read back computed styles / animation state via JS to confirm.
5. `node --check Web/app.js` after every edit.

**You cannot verify real touch gestures or true 60fps in this environment.** Say so plainly
rather than claiming a smoothness you did not measure. The owner tests on an iPhone 17.

## Ship discipline

```bash
cd /Users/paxton/Cairn/Web && npx surge . cairn.surge.sh
```

The project is under git (baseline `9f7f24b`). **Commit before each risky change** — `Web/app.js`
is a single 89KB file and a bad edit is expensive:

```bash
cd /Users/paxton/Cairn && git add -A && git commit -m "..."
```

Rollback is `git checkout -- Web/app.js`.

**Update `PROJECT_CONTEXT.md`, `TODO.md`, `DECISIONS.md`, and `CHANGELOG.md` as you go** — not at
the end. Sessions run out of context mid-task and hand off without warning; these four files are
the only continuity that exists. Record *why*, not just *what*.

## Two open items you did not cause but should know about

- `access-hub.sql` still needs to be run in Supabase, and "Allow new users to sign up" re-enabled
  (SQL first). Owner's task, not yours.
- Hold-to-drag reorder, cross-category drop, and swipe gestures were fixed but are **verified only
  with synthetic pointer events** — never on real hardware. If the owner reports a gesture
  failing, start at the non-passive `touchmove` blocker in `bindRowGestures` and the
  `touch-action` rules on `.rowwrap`.

## The bar

This app is used every morning by two people who are trying to become more disciplined. The
motion should make opening it feel like a small, deliberate ritual — not like loading a webpage.

Restraint is the hard part. Anyone can add animation; the craft is knowing that a cairn settles,
it doesn't bounce. When in doubt: slower, heavier, quieter, fewer.
