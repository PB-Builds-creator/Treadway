# Treadway web architecture

Treadway is a static, installable PWA with a Supabase backend. Its design goal is to feel immediate and private on a phone while keeping deployment and maintenance small enough for an independent developer.

## System shape

```text
Browser / installed PWA
  ├─ app.js: state, rendering, recurrence, gestures, offline mutations
  ├─ insight-engine.js: deterministic evidence, confidence, prompt contract
  ├─ styles.css: theme, layout, materials, motion, reduced motion
  ├─ service worker: versioned application shell
  └─ localStorage: account-scoped cache, preferences, bounded error buffer
          │
          ▼
Supabase
  ├─ Auth: identity and session lifecycle
  ├─ Postgres: profiles, tasks, completions, hydration, notes, reminders
  ├─ Row Level Security: owner and deliberately narrow partner policies
  ├─ Realtime/data reload: cross-device convergence
  └─ Edge Functions
       ├─ send-reminders: scheduled web-push delivery
       └─ delete-account: authenticated complete account deletion
```

## Client state and rendering

`Web/app.js` keeps one in-memory state mirror and rebuilds the active view from that state. Mutations update the UI optimistically, write an account-scoped local cache, and then write to Supabase. Failed writes enter a local outbox for retry after connectivity returns.

Because `render()` replaces the application DOM, animation state that must cross a render lives in JavaScript rather than in transient nodes. Row completion and reordering use FLIP-style measurements; pointer movement is coalesced to one paint per animation frame. New motion is limited to transform and opacity and is disabled under `prefers-reduced-motion`.

## Explainable AI handoff

`Web/insight-engine.js` consumes a bounded seven-day contract and returns metrics, confidence, ranked observations, an evidence ledger, privacy metadata, and a versioned prompt. It is a pure deterministic layer: it performs no fetch, reads no storage, mutates no product state, and makes no model call. The same source runs in the browser and in Node evaluation.

The Week view constructs the contract from the existing state mirror. Treadway Close timestamps contribute reflection coverage, but reflective prose is omitted from the prompt unless the user checks a one-action opt-in. The complete payload can be previewed before a user-initiated clipboard copy. This separates four concerns that would otherwise be easy to blur:

1. product facts and calendar rules;
2. deterministic pattern selection;
3. model instructions and context formatting;
4. the user's choice of model/provider and send action.

The current feature therefore has no inference cost, background CPU work, provider lock-in, API credential, or new server data. A future direct model integration must retain this context contract and add an explicit provider/consent/retention/failure review rather than bypassing it.

## Time and recurrence

Daily boundaries use `America/Denver` through `Intl.DateTimeFormat`. Calendar days are represented as `YYYY-MM-DD` values and advanced with UTC calendar helpers, avoiding fixed 86,400-second assumptions across daylight-saving transitions. Task recurrence, streaks, rest days, and reminder decisions all consume the same day model.

## Privacy model

The remote boundary is Supabase Auth plus Postgres Row Level Security. Each user owns their routine, completions, hydration, and reflections. Partner access is intentionally aggregate and narrow; the journal and task content are never included in partner-readable policies or payloads.

The device PIN only hides an already authenticated local session. It is explicitly not described as encryption or as the server authorization boundary.

## Offline behavior

- The service worker caches the application shell under an explicit version.
- The last account-scoped state is cached locally for startup and temporary offline use.
- User actions update local state first and queue failed remote mutations.
- Reconnect triggers outbox replay and a silent server refresh.
- Server RLS remains authoritative even if a device retains an older local snapshot.

## Notifications

Reminder settings and subscriptions are stored per user. A scheduled Supabase Edge Function evaluates due work in Mountain Time, respects quiet hours, suppresses fulfilled tasks, sends web push, and records deliveries to prevent duplicates. Private VAPID and cron material lives only in Supabase secrets or ignored local files.

## Stable compatibility identifiers

The customer-facing product was renamed without changing its live origin or storage namespace. `cairn.surge.sh`, `cairn_*`, and `CAIRN_CONFIG` remain deliberate compatibility contracts: changing them casually would invalidate auth redirects, device sessions, local preferences, installed-PWA behavior, or push subscriptions.

## Native research track

`App/`, `Widgets/`, and `CairnCore/` form a separate Apple-platform prototype. `CairnCore` isolates Foundation-only recurrence, date, streak, hydration, notification-planning, archive, and merge logic behind repeatable Swift tests. The native UI explores SwiftUI, SwiftData, CloudKit, WidgetKit, App Intents, LocalAuthentication, and distribution constraints. It is documented separately and is not required by the deployed web app.
