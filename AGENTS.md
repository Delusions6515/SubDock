# AGENTS.md

<!-- agents-md-generator: v1; doc-type: single_repo -->

## 1. Overview

SubDock is a native shell that runs a packaged Sub-Store backend and embeds its local management UI.

## 2. Ownership Map

### Stable Ownership Boundaries

- **Runtime lifecycle**: Start in `lib/runtime/desktop_backend_runtime.dart`; keep `BackendRuntime`
  platform-neutral and preserve process identity, serialized mutation, failure publication, and cleanup.
- **Configuration**: Start in `lib/settings/backend_env.dart` for policy, `backend_env_store.dart` for
  persistence, and `AppCoordinator` for activation. Preserve raw ENV text and SubDock-reserved paths.
- **WebUI boundary**: Start in `lib/app/app.dart`, but keep endpoint selection in `AppCoordinator`.
  Preserve same-origin containment, external-browser handoff, download interception, and recovery UI.
- **Packaged resources**: Treat `data/runtime`, `data/backend`, and `data/frontend` as the runtime
  contract. Linux packaging owns this layout today; verify other platforms rather than assuming parity.

## 3. Core Behaviors & Patterns

- `AppCoordinator` serializes app actions and `DesktopBackendRuntime` serializes process mutations.
  Keep both layers; `restart` must never call `start` after `stop` fails.
- Lifecycle failures publish the actionable runtime state before rethrowing. Cleanup must cover only
  resources owned by that runtime instance and must still run when shutdown fails.
- Backend environment precedence is system `<` user `<` SubDock-reserved values. The packaged binary
  directory is prepended to `PATH`; users may not override data or frontend resource paths.
- Saving ENV does not restart the backend. Persistence occurs before runtime activation, so activation
  failure can leave disk newer than in-memory state; do not hide or reverse this ordering accidentally.
- Create the WebView only for a running backend with a valid reachable configuration. Keep same-origin
  routes embedded, open external HTTP(S) outside, deny other schemes, and cap Blob exports at 16 MiB.
- Tray initialization failure deliberately changes window close from hide-to-tray to full exit with a
  visible warning. Explicit exit must await backend disposal before destroying host resources.
- Writable runtime state is private to the current user. Preserve atomic file replacement and POSIX
  `0700` directory / `0600` file permissions or the corresponding Windows current-user ACL.

## 4. Conventions

- Shared app/coordinator code depends on `BackendRuntime`; construct `DesktopBackendRuntime` only in
  the desktop entrypoint. Keep process, tray, window, and single-instance APIs out of the mobile seam.
- `lib/mobile_main.dart` is intentionally a no-op seam, not an implemented mobile runtime. Do not add
  speculative platform abstractions until a real mobile implementation requires them.
- Edit localization inputs in `lib/l10n/app_zh.arb` and `l10n.yaml`, not `lib/l10n/generated/`. Treat
  platform plugin registrants as generated from dependency configuration, never as hand-edited source.
- Resource preparation stages before replacement. Keep version selection centralized and preserve
  checksum verification for Node and released Shoutrrr assets; `.subdock/` remains untracked output.

## 5. Working Agreements

- Build context by reviewing related usages, flows, patterns, and likely impact before editing.
- Fix the underlying cause, not only the visible symptom; prefer the narrowest complete change.
- Check side effects across callers, shared abstractions, and behavior/API boundaries.
- Ask only when a decision materially affects user-visible behavior, task scope, or an irreversible tradeoff.
- Do not introduce a new testing, linting, or formatting framework without explicit approval.
- Add or update tests within the existing test infrastructure when behavior changes.
- Run `fvm flutter analyze` after code changes.
- Run relevant tests for changed behavior; run the full suite for substantial or cross-cutting changes.
- Keep new functions single-purpose and colocated with related code.
- Add external dependencies only when necessary, and explain why.
