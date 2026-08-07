# Contributing

Treadway is in active private-beta development. Focused bug reports and small, well-scoped pull requests are welcome.

## Before changing code

1. Read `PROJECT_CONTEXT.md`, `TODO.md`, and `DECISIONS.md` for current constraints.
2. Keep the deployed web client dependency-light and build-step-free.
3. Preserve the `cairn.surge.sh` origin, `cairn_*` storage keys, and `CAIRN_CONFIG` unless the change includes a deliberate migration plan.
4. Never add secrets, production user data, or real account fixtures.

## Quality bar

- Run `npm test` from the repository root.
- Run `swift test` and `swift run cairncore-verify` from `CairnCore/` when changing shared domain logic.
- Test light, dark, OLED, and reduced-motion modes for visual changes.
- Treat real-device touch performance, safe areas, and web-push delivery as separate manual verification items.
- Preserve accessibility names, keyboard behavior, and minimum touch-target sizing.

## Pull requests

Explain the problem, the chosen behavior, verification performed, remaining unverified boundaries, and any migration or privacy impact. Keep unrelated changes separate.
