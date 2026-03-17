# Local Codex Connection Migration Plan

## Status

This document is a proposal for adding a desktop-local `codex app-server`
connection mode to Pocket Relay.

It does not describe a partial shortcut.

The target behavior is:

1. SSH remains a supported first-class connection mode.
2. desktop builds can also run `codex app-server --listen stdio://` locally.
3. both modes share the same app-server JSON-RPC stack after process launch.
4. mobile builds do not expose or accept local mode.

## Why This Needs Its Own Plan

The current app is not merely "missing a local launcher".

It is SSH-shaped across:

- connection profile modeling
- settings validation and form copy
- controller validation
- empty-state and header copy
- default launcher selection

If local support is added only as a branch inside the launcher, the app will
still be structurally wrong:

- the saved profile will still claim every connection is SSH
- the settings sheet will still require SSH concepts for local mode
- the controller will still validate local mode as if it needed SSH auth
- UI copy will continue describing every session as a remote box

The migration therefore has to start with ownership, then add the adapter.

## Current State

Today the app-server stack already has one strong transport boundary:

- `codex_app_server_connection.dart` owns JSON-RPC/stdin/stdout session wiring
- `codex_app_server_request_api.dart` owns app-server request methods
- `codex_app_server_ssh_process.dart` owns SSH bootstrap and remote launch
- `codex_app_server_client.dart` uses SSH as the default process launcher

That means the downstream protocol layers are already transport-agnostic.

The upstream problem is that the profile and UI model still assume one mode:
SSH.

## Design Rules

These rules should govern the migration.

1. `ssh` and `local` must be explicit connection modes.
2. SSH stays first-class; local is added beside it, not on top of it.
3. The mode switch belongs in the connection profile and settings model.
4. The launcher adapter belongs at the process-launch boundary, not in widgets
   or transcript logic.
5. `codex_app_server_connection.dart` and
   `codex_app_server_request_api.dart` should stay mode-agnostic.
6. Local mode must be desktop-only in both product behavior and validation.
7. Switching modes must not silently erase the user's SSH fields or secrets.

## Target Architecture

The target shape is:

`ConnectionProfile -> process launcher resolver -> CodexAppServerProcess -> CodexAppServerConnection`

More concretely:

1. `ConnectionProfile` declares the mode.
2. a launcher resolver chooses the correct process-launch strategy.
3. both strategies return the same `CodexAppServerProcess` abstraction.
4. the existing connection and request layers remain shared.

## Ownership Plan

### 1. Connection model

The connection profile should own transport mode explicitly.

Recommended addition in `lib/src/core/models/connection_models.dart`:

- `enum ConnectionMode { ssh, local }`

Recommended `ConnectionProfile` rules:

- `ssh` requires:
  - `host`
  - `port`
  - `username`
  - `workspaceDir`
  - `codexPath`
- `local` requires:
  - `workspaceDir`
  - `codexPath`

Important rule:

- SSH-only fields and secrets should remain stored when the user switches to
  local mode.
- Hiding a field is not the same as deleting its value.

That preserves user intent and avoids destructive mode toggling.

### 2. Settings model and presenter

The settings stack must become mode-aware before transport branching is added.

Files that need mode ownership:

- `lib/src/features/settings/presentation/connection_settings_contract.dart`
- `lib/src/features/settings/presentation/connection_settings_draft.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`
- `lib/src/features/settings/presentation/connection_settings_host.dart`
- `lib/src/features/settings/presentation/connection_settings_sheet_surface.dart`

Required behavior:

1. add a mode picker: `SSH` vs `Local`
2. in `ssh` mode, show SSH identity/auth fields
3. in `local` mode, hide SSH-only fields and auth controls
4. in both modes, keep:
   - profile label
   - workspace directory
   - codex launch command
   - run-mode toggles that still apply

Validation must come from the presenter, not widget-local heuristics.

### 3. Transport-root adapter

The adapter belongs in the app-server infrastructure layer, at the default
process-launch selection point.

Recommended new seam:

- add a new resolver file under
  `lib/src/features/chat/infrastructure/app_server/`

Recommended shape:

- `ssh -> openSshCodexAppServerProcess(...)`
- `local -> openLocalCodexAppServerProcess(...)`

The likely file set is:

- keep `codex_app_server_ssh_process.dart`
- add `codex_app_server_local_process.dart`
- add `codex_app_server_process_launcher.dart`

`codex_app_server_client.dart` should use the resolver as its default launcher.

It should not contain widget/platform policy.

### 4. Shared protocol layers

These files should remain shared and mode-agnostic:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`

They already operate on `CodexAppServerProcess`, which is the correct generic
boundary.

No local-vs-SSH branching should be pushed into:

- JSON-RPC decoding
- request/response tracking
- app-server request methods
- transcript mapping

### 5. Controller validation

`lib/src/features/chat/application/chat_session_controller.dart` currently
validates the profile as if every session were SSH.

That needs to become mode-aware:

- `ssh` validates SSH credentials
- `local` validates only local-launch requirements

This controller should also enforce the product rule that local mode is not
available on mobile.

That rule should not live only in the settings UI.

### 6. Product copy

The app currently describes every session as remote SSH.

These surfaces need mode-aware copy:

- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`

Examples of copy fixes:

- "Configure a remote box" becomes mode-aware
- "SSH target" becomes mode-aware
- empty-state messaging should not describe local desktop mode as remote mobile
  SSH

## Local Launcher Requirements

The local launcher should:

1. run a local `codex app-server --listen stdio://`
2. launch from the configured `workspaceDir`
3. use the configured `codexPath`
4. return a `CodexAppServerProcess`
5. surface stderr/startup failures through existing diagnostic events

It should not:

1. open SSH
2. synthesize fake SSH lifecycle events
3. bypass the shared JSON-RPC connection layer

The local launcher is a sibling transport bootstrap, not a new client stack.

## Platform Policy

Local mode is a desktop feature.

That policy should be explicit in two places:

1. settings exposure
   - desktop can choose `Local`
   - mobile should not offer it
2. runtime enforcement
   - if a persisted local profile is loaded on mobile, the controller should
     reject it cleanly with a clear message

Do not rely on hidden UI alone to enforce this.

## Migration Phases

### Phase 1: Make mode explicit

Scope:

- add `ConnectionMode`
- update `ConnectionProfile`
- make `isReady` mode-aware
- preserve existing profile JSON with sensible defaults

Definition of done:

- the model can describe both `ssh` and `local`
- existing saved profiles continue to load as `ssh`

### Phase 2: Make settings truthful

Scope:

- add a mode picker to the settings contract and UI
- make presenter validation mode-aware
- hide SSH-only fields when local mode is selected

Definition of done:

- the settings form no longer pretends local mode is SSH
- switching modes preserves hidden field values

### Phase 3: Add the process-launch adapter

Scope:

- add the local launcher
- add the launcher resolver
- route `codex_app_server_client.dart` through the resolver

Definition of done:

- launcher selection happens exactly once at the transport root
- the connection/request stack remains shared

### Phase 4: Fix controller and runtime assumptions

Scope:

- make `chat_session_controller.dart` validate by mode
- reject local mode on unsupported platforms
- update failure copy so it does not always say "remote Codex session"

Definition of done:

- runtime behavior matches the selected mode
- persisted local profiles fail safely on mobile

### Phase 5: Fix mode-specific UX copy

Scope:

- header subtitle
- empty state
- settings description
- prompt validation messages

Definition of done:

- the app no longer describes local desktop mode as SSH remote mode

### Phase 6: Add focused verification

Scope:

- presenter tests
- settings-host widget tests
- launcher-selection tests
- local-launcher tests
- controller validation tests

Definition of done:

- the new ownership boundaries are covered directly

## Non-Goals

This migration should not:

- change app-server protocol semantics
- add a second JSON-RPC client stack
- reintroduce the removed legacy parser transport
- make local mode available on web
- redesign the full app chrome while transport ownership is moving

## Recommended Test Matrix

### Model tests

- existing profiles deserialize as `ConnectionMode.ssh`
- local mode readiness ignores SSH-only fields
- switching modes preserves stored SSH data

### Presenter tests

- local mode hides SSH auth fields
- local mode validation requires only local-launch fields
- SSH mode still validates host/auth correctly

### Widget tests

- settings mode switch updates visible fields
- saving local mode produces a local profile payload
- mobile-rendered settings do not offer local mode

### Infrastructure tests

- launcher resolver selects SSH launcher for `ssh`
- launcher resolver selects local launcher for `local`
- local launcher builds the expected process invocation
- connection handshake remains unchanged after launcher selection

### Controller tests

- local mode can send prompts on supported desktop platforms
- local mode is rejected on mobile with a clear error
- SSH mode behavior remains unchanged

## Implementation Order

The correct order is:

1. connection mode model
2. settings truthfulness
3. launcher adapter
4. controller/runtime validation
5. UX copy cleanup
6. focused verification

Do not start by adding the adapter alone.

That would create a real local code path behind a still-SSH-shaped product
model, which is exactly the kind of hidden coupling this migration is meant to
avoid.
