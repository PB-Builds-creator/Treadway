# Treadway — product engineering case study

## The problem

Habit trackers often flatten very different commitments into generic checkboxes, punish recovery, and turn accountability into surveillance. Treadway began as a personal tool for building a disciplined day while preserving privacy, reflection, and room for recovery.

## The product response

Treadway organizes the day as a path rather than a scoreboard. Users place daily “markers,” track hydration, protect a streak with explicit rest rules, close the day with a short reflection, and review a rolling weekly trail. A partner can share encouragement and high-level completion status without seeing the underlying tasks or journal.

The product is a working, access-gated private beta deployed as an installable PWA. It is intentionally labeled active development: the core experience works, while commercial onboarding, broader automation, and several real-device validation items remain open.

## Selected engineering decisions

### Deterministic calendar behavior

All product-day decisions are anchored to `America/Denver`. Calendar-day helpers avoid adding fixed 24-hour durations, so midnight resets, recurrence, and streak evaluation remain correct through daylight-saving changes.

### Privacy as a data-model boundary

Privacy is enforced by owner-scoped Postgres Row Level Security, not only by hidden interface controls. Partner features use narrow aggregate records and fixed messages; task titles, routine details, and reflections stay outside that interface.

### Offline-first interaction

The application updates local state immediately, persists an account-scoped cache, and queues writes when the network is unavailable. Reconnect replays pending work and reconciles with the server. This keeps a daily-use tool responsive without pretending the local cache is the authorization boundary.

### Motion with a performance budget

The interface uses a consistent stepping-stone visual language. Direct-manipulation gestures are frame-batched, long-lived compositor layers are avoided, and animations use transform/opacity with a reduced-motion path. Desktop browser checks validate behavior and containment; real-device touch feel and frame pacing remain separately labeled.

### Compatibility over cosmetic cleanup

The product name changed while the installed origin, auth redirects, storage keys, and push subscriptions were already in use. Customer-facing branding changed, but the `cairn.surge.sh` origin and `cairn_*` identifiers were retained to avoid a destructive migration disguised as cleanup.

## Quality and release discipline

- Git checkpoints preserve each focused change and its rationale.
- A maintained changelog, decision log, project context, and prioritized TODO make handoffs explicit.
- Repository checks cover JavaScript syntax, PWA metadata/assets, privacy links, secret boundaries, and the tested Swift domain package.
- Live deployments are compared against local assets after meaningful releases.
- Unverified device-specific behavior is listed rather than implied.

## AI-assisted development

Treadway is openly AI-assisted and owner-directed. Paxton Raithel defines the user problem, product behavior, design principles, privacy model, priorities, and acceptance criteria. AI tools are used as implementation and review accelerators. The engineering standard is evidence: a change is described as verified only when a repeatable check or an explicit manual observation supports it.

## Current outcome

The project demonstrates a complete vertical slice: product framing, interaction design, state and recurrence logic, offline behavior, authentication, authorization policies, data lifecycle controls, scheduled notifications, deployment, and operational documentation. It also demonstrates judgment about what not to claim: Treadway is not presented as commercially launch-ready, legally cleared, or fully real-device automated.

## Next milestones

1. Add browser-level regression tests for the most expensive state transitions.
2. Complete real-iPhone gesture, accessibility, safe-area, and notification validation.
3. Separate the product landing experience from the access-gated application.
4. Plan a branded-domain migration across auth, PWA installation, and push subscriptions.
5. Continue native Apple-platform work when distribution and platform integrations become priorities.
