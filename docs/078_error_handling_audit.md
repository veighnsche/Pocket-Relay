# 078 Error Handling Audit

## Scope

- Audit target: current `master` at the time of branch cut for `feat/error-handling-audit`
- Audit date: `2026-03-27`
- Scope: `lib/src/**` and supporting tests under `test/**`
- Goal: evaluate how Pocket Relay currently handles errors, where the shared error system is used, where it is bypassed, and what order a normalization effort should follow

## Audit Method

This revision treats the audit as two layers:

1. Mechanical repo-wide inventory
- Source model and formatter scan:
  - `rg -n "PocketUserFacingError|PocketErrorCatalog|runtimeMessage|inlineMessage|bodyWithCode" lib/src`
- Source user-visible emission scan:
  - `rg -n "showSnackBar|SnackBar\\(|_emitSnackBar\\(|runtimeErrorMessage" lib/src`
- Source catch scan:
  - `rg -n "catch\\s*\\(|catch\\s*\\{" lib/src`
- Source throw/rethrow scan:
  - `rg -n "\\bthrow\\b|rethrow" lib/src`
- Test coverage scan:
  - `rg -n "PocketErrorCatalog|PocketUserFacingError|inlineMessage|bodyWithCode|runtimeMessage|showSnackBar|SnackBar\\(|_emitSnackBar\\(" test`

2. Manual classification
- I used the inventories above to build the full source-file universe, then manually inspected the user-visible and mixed files to separate coded handling, uncoded handling, internal-only exception flow, and silent/collapsed behavior.

Exact mechanical results:

- `129` coded-model and formatter matches across `13` source files
- `57` user-visible emission matches across `15` source files
- `66` catch matches across `34` source files
- `90` throw/rethrow matches across `29` source files
- union audited source universe: `59` files
- relevant test universe: `15` test files with `46` direct matches

## Overall Grade

Current grade: `C+`

Why:

- The repo has a real first-class error model in [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart), with stable codes, domains, and meanings.
- Two major feature areas already map failures into that model well: workspace lifecycle errors and chat session send/restore failures.
- Adoption is incomplete. Large areas still use raw snackbar strings, generic fallback messages, feature-local catch-and-collapse patterns, and duplicated error-detail normalization.
- There are too many places where the app either swallows the underlying error entirely or turns it into a boolean/UI flag instead of a typed user-facing error with a stable code.

Measured counts from the current tree:

- `2` core error domains in [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1): `connectionLifecycle` and `chatSession`
- `45` catalog definitions in [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart)
- `30` `PocketUserFacingError(...)` constructors in `lib/src/**`
- `27` direct snackbar/display call sites across chat, workspace, and connection settings surfaces
- `14` raw `_emitSnackBar('...')` string call sites in `lib/src/features/chat/lane/application`
- `66` generic catch blocks in `lib/src/**`
- `90` `throw` / `rethrow` sites in `lib/src/**`

## Pass 1: User-Visible Error Surface Inventory

### What already uses the shared error model

The shared model is well-defined in [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1).

- `PocketErrorDefinition` owns the stable code, domain, and meaning.
- `PocketUserFacingError` owns the user-facing title and message.
- The main display format is `inlineMessage`, which prefixes the stable code.
- `bodyWithCode` exists for longer error bodies and dialogs.

The two strongest adopters are:

1. Workspace lifecycle
- Mapper: [lib/src/features/workspace/application/connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart)
- Presentation use: [lib/src/features/workspace/presentation/workspace_saved_connections_content.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_saved_connections_content.dart#L151), [lib/src/features/workspace/presentation/workspace_desktop_shell.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_desktop_shell.dart#L154), [lib/src/features/workspace/presentation/workspace_live_lane_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface.dart#L542)

2. Chat session send and transcript restore failures
- Mapper: [lib/src/features/chat/lane/application/chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart#L3)
- Runtime use: [lib/src/features/chat/lane/application/chat_session_controller_history.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_history.dart#L355)

The biggest structural gap is domain coverage. The core catalog only defines `connectionLifecycle` and `chatSession` in [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1), so there is no first-class domain coverage yet for connection settings, composer attachments, bootstrap, device hosts, or storage-facing user-visible failures.

### Where user-visible errors are still uncoded

The biggest uncoded surface is chat lane controller guardrails. These are product-visible failures, but they are emitted as raw strings instead of stable coded errors.

Examples:

- [lib/src/features/chat/lane/application/chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart#L4)
- [lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart#L4)
- [lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart#L57)

Representative raw messages:

- `Stop the active turn before starting a new thread.`
- `Wait for transcript restore before continuing from here.`
- `This host fingerprint prompt is no longer available.`
- `This profile needs an SSH password.`
- `This model does not support image inputs. Remove images or switch models.`

Connection settings also has uncoded user-visible error state:

- [lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart#L21) collapses all refresh failures into `_didModelCatalogRefreshFail = true`
- [lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart#L81) stores raw thrown text as runtime detail rather than mapping to a typed user-facing error

There are also presentation-owned generic fallbacks:

- [lib/src/features/chat/composer/presentation/chat_composer_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/composer/presentation/chat_composer_surface.dart#L300) falls back to `Could not attach image.`
- [lib/src/features/workspace/presentation/workspace_live_lane_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface.dart#L467) builds a direct `Could not disconnect lane.` message from caught text

### User-visible surface summary

- Strong: workspace lifecycle dialogs, notices, and lane reconnect failures
- Medium: chat session send/restore failures
- Weak: chat controller guardrails, connection settings refresh/probe UX, composer attachment fallback handling

## Pass 2: Thrown and Swallowed Failure Inventory

### Catch inventory

Measured catch-block file buckets:

- `15` files under `features/chat`
- `12` files under `features/workspace`
- `3` files under `core/device`
- `2` files under `features/connection_settings`
- `1` file under `core/storage`
- `1` file under `app`

Representative categories:

1. Catch and map to user-facing error
- [lib/src/features/chat/lane/application/chat_session_controller_history.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_history.dart#L158)
- [lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart#L39)
- [lib/src/features/workspace/presentation/workspace_saved_connections_content.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_saved_connections_content.dart#L128)

2. Catch and collapse into UI state only
- [lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart#L45)

3. Catch and keep raw detail text
- [lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart#L81)

4. Catch and silently ignore
- [lib/src/core/device/foreground_service_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/foreground_service_host.dart#L216)
- [lib/src/core/device/background_grace_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/background_grace_host.dart#L133)
- [lib/src/core/device/display_wake_lock_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/display_wake_lock_host.dart#L121)
- [lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart#L185)

5. Catch and rethrow
- [lib/src/features/workspace/application/connection_workspace_controller_lane.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_workspace_controller_lane.dart#L36)
- [lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart#L83)
- [lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart#L62)

### Throw inventory

Measured throw/rethrow file buckets:

- `21` files under `features/chat`
- `4` files under `features/workspace`
- `4` files under `core/storage`

Representative categories:

1. Internal guard/argument errors
- [lib/src/features/chat/lane/application/chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart#L60)
- [lib/src/core/storage/connection_scoped_stores.dart](/home/vince/Projects/codex_pocket/lib/src/core/storage/connection_scoped_stores.dart#L41)

2. Transport/protocol exceptions
- [lib/src/features/chat/transport/app_server/codex_app_server_connection.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/transport/app_server/codex_app_server_connection.dart#L85)
- [lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart#L16)
- [lib/src/features/chat/transport/app_server/codex_json_rpc_codec_models.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/transport/app_server/codex_json_rpc_codec_models.dart#L27)

3. Recovery-preserving rethrows with stack traces
- [lib/src/features/chat/lane/application/chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart#L150)
- [lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart#L150)

### Pass 2 conclusion

The codebase does not lack error handling. It lacks consistency in how errors are surfaced and normalized after they are caught.

## Pass 3: Ownership Audit

### Correct current ownership

1. Core
- [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1) is the correct owner for stable codes and cross-feature user-facing error definitions.

2. Feature application mapping
- [lib/src/features/workspace/application/connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart) is the correct owner for lifecycle-specific error mapping.
- [lib/src/features/chat/lane/application/chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart) is the correct owner for live chat-session failure mapping.

3. Transport and infrastructure
- Transport layers mostly throw domain-specific exceptions and let application layers map them later. That is structurally fine.

### Incorrect or weak ownership

1. Presentation-owned fallback messaging
- [lib/src/features/chat/composer/presentation/chat_composer_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/composer/presentation/chat_composer_surface.dart#L300)
- [lib/src/features/workspace/presentation/workspace_live_lane_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface.dart#L467)

These surfaces should not be inventing final user-visible failure text when there is already a core error model.

2. Controller-owned raw guardrail strings
- [lib/src/features/chat/lane/application/chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart#L4)
- [lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart#L4)

These are application-owned errors, but they are not modeled as application-owned error definitions.

3. Connection settings refresh/probe errors owned by local state flags
- [lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart#L3)
- [lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart#L12)

These errors are effectively product-visible, but they currently belong to widget-local booleans and raw detail strings rather than a feature-level mapper.

4. Duplicated error-detail normalization
- [lib/src/features/chat/lane/application/chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart#L105)
- [lib/src/features/workspace/application/connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart#L347)

The normalization logic should be owned once in core, not copied by feature.

## Pass 4: Classification Matrix

### Bucket A: Coded user-facing errors

Definition:
- stable `PR-...` code
- typed `PocketUserFacingError`
- user-visible via snackbar, dialog, notice, or body text

Current examples:

- Workspace open/connect/server/history failures in [lib/src/features/workspace/application/connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart)
- Chat send/restore/turn-control/request failures in [lib/src/features/chat/lane/application/chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart)

Assessment:
- strongest bucket in the repo
- good semantics
- codes are tested and stable
- not yet broad enough

### Bucket B: Uncoded user-facing errors

Definition:
- user sees a message
- no stable code
- not modeled through `PocketUserFacingError`

Current examples:

- Raw chat guardrails in [lib/src/features/chat/lane/application/chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart#L4)
- Validation strings in [lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart#L168)
- Generic disconnect message in [lib/src/features/workspace/presentation/workspace_live_lane_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface.dart#L471)
- Generic composer attach fallback in [lib/src/features/chat/composer/presentation/chat_composer_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/composer/presentation/chat_composer_surface.dart#L300)

Assessment:
- this is the main gap preventing a higher grade
- the app already has the right abstraction, but these cases bypass it

### Bucket C: Internal exceptions only

Definition:
- thrown for protocol, programming, or invariant reasons
- not directly user-facing
- should usually be caught and mapped later

Current examples:

- Transport/API argument errors under `lib/src/features/chat/transport/app_server/**`
- Storage lookup and argument errors under `lib/src/core/storage/**`
- Runtime mapper guard in [lib/src/features/chat/runtime/application/runtime_event_mapper.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/runtime/application/runtime_event_mapper.dart#L43)

Assessment:
- structurally acceptable
- some `StateError` use is blunt, but the ownership layer is usually reasonable

### Bucket D: Silently swallowed or non-observable failures

Definition:
- failures are caught
- no code, no surfaced detail, sometimes no telemetry
- user may see only degraded behavior or nothing at all

Current examples:

- device capability fallbacks in [lib/src/core/device/foreground_service_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/foreground_service_host.dart#L216)
- device hosts in [lib/src/core/device/background_grace_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/background_grace_host.dart#L133) and [lib/src/core/device/display_wake_lock_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/display_wake_lock_host.dart#L121)
- connection settings model refresh in [lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart#L45)
- several workspace settings catches in [lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart#L185)

Assessment:
- some of these are acceptable resilience tradeoffs
- many still need at least debug observability and explicit product decisions

## Pass 5: Test Audit

### What is already tested well

1. Core catalog integrity
- [test/core/errors/error_catalog_test.dart](/home/vince/Projects/codex_pocket/test/core/errors/error_catalog_test.dart)
- verifies code uniqueness and lookup

2. Workspace lifecycle error mapping
- [test/features/workspace/application/lifecycle_errors_test.dart](/home/vince/Projects/codex_pocket/test/features/workspace/application/lifecycle_errors_test.dart)
- verifies stable mapping and `bodyWithCode` / `inlineMessage`

3. Chat session error mapping
- [test/features/chat/lane/application/session_errors_test.dart](/home/vince/Projects/codex_pocket/test/features/chat/lane/application/session_errors_test.dart)
- verifies coded chat-session mapping and runtime detail formatting

4. Presentation tests that prove codes reach UI
- [test/features/workspace/presentation/conversation_history_sheet_test.dart](/home/vince/Projects/codex_pocket/test/features/workspace/presentation/conversation_history_sheet_test.dart)
- [test/features/workspace/presentation/shell/mobile/conversation_history_test.dart](/home/vince/Projects/codex_pocket/test/features/workspace/presentation/shell/mobile/conversation_history_test.dart)
- [test/features/workspace/presentation/shell/desktop/conversation_history_dialog_test.dart](/home/vince/Projects/codex_pocket/test/features/workspace/presentation/shell/desktop/conversation_history_dialog_test.dart)
- [test/features/workspace/presentation/live_lane/remote_runtime_notices_test.dart](/home/vince/Projects/codex_pocket/test/features/workspace/presentation/live_lane/remote_runtime_notices_test.dart)
- [test/features/workspace/presentation/live_lane/connection_actions_test.dart](/home/vince/Projects/codex_pocket/test/features/workspace/presentation/live_lane/connection_actions_test.dart)

### What is weak or missing

1. No audit-level test prevents new uncoded user-facing errors

There is no test or lint that fails when a feature introduces another raw `_emitSnackBar('...')` product error.

2. Connection settings refresh and probe failure behavior is under-tested as an error model

The behavior is tested as state, but not as a stable user-facing error contract.

3. Chat controller guardrail messages are not modeled or tested as first-class errors

The current raw strings in recovery and prompt flow are easy to drift and hard to report.

4. Silent failure paths are mostly untested as observability decisions

Core device hosts intentionally ignore failures, but the codebase does not clearly lock which ones are acceptable to ignore and which should become surfaced failures.

### Pass 5 recommendation order

If this becomes implementation work, the test rollout should happen in this order:

1. Lock the core formatting contract once
- Add tests for shared error-detail normalization so feature mappers stop owning their own string cleanup behavior.

2. Lock chat guardrails before rewriting them
- Add tests around the current recovery, prompt-flow, and model-capability guardrails so raw strings can be replaced with coded errors without behavior drift.

3. Lock connection settings host error behavior
- Add tests that prove model refresh and remote probe failures produce stable, reportable user-facing outcomes instead of booleans or raw thrown text.

4. Lock presentation fallback removal
- Add tests for composer attachment failure and lane disconnect failure so widgets stop inventing generic `Could not ...` text locally.

5. Add repo-level regression enforcement
- Add a static or test-time check that blocks new raw product-facing snackbar strings in feature application code unless they intentionally route through the shared error model.

## Ordered Findings

### Strongest current areas

1. Core error catalog structure
- [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1)

2. Workspace lifecycle mapping
- [lib/src/features/workspace/application/connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart)

3. Chat session send/restore failure mapping
- [lib/src/features/chat/lane/application/chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart)

### Highest-risk weaknesses

1. Raw user-visible chat guardrail strings
- [lib/src/features/chat/lane/application/chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart#L4)
- [lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart#L4)

2. Widget-local error collapse in connection settings
- [lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart#L45)
- [lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart#L81)

3. Presentation-owned generic fallback errors
- [lib/src/features/chat/composer/presentation/chat_composer_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/composer/presentation/chat_composer_surface.dart#L300)
- [lib/src/features/workspace/presentation/workspace_live_lane_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface.dart#L471)

4. Duplicated error-detail normalization
- [lib/src/features/chat/lane/application/chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart#L105)
- [lib/src/features/workspace/application/connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart#L347)

5. Core catalog domain coverage is too narrow
- [lib/src/core/errors/pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1)

The existing coded system is good, but it only names two domains. That makes it easy for adjacent features to bypass the system instead of extending it.

## Ordering Recommendation

If this turns into implementation work, the safest order is:

1. Move detail normalization into `core/errors`
- delete feature-local duplicate formatters

2. Normalize uncoded chat guardrails
- recoveries
- prompt-flow validation
- image capability rejection

3. Normalize connection settings refresh/probe failures
- model catalog refresh
- remote runtime probe

4. Normalize presentation-owned generic fallback errors
- composer attach
- lane disconnect
- any remaining generic `Could not ...` snackbar assembly in widgets

5. Add audit enforcement
- tests for code uniqueness already exist
- add tests or static checks that block new raw product-facing snackbar strings in feature application layers

## Final Assessment

Pocket Relay already has enough infrastructure to reach a high-quality error-handling model. The main problem is not absence of abstraction. The main problem is partial adoption.

The repo is closest to a `B` in architecture and a `C` in execution consistency, which averages out to the `C+` grade above.

The next meaningful improvement is not inventing a new error system. It is expanding the existing `PocketErrorCatalog` and `PocketUserFacingError` system into the uncoded chat, connection-settings, and presentation fallback paths until user-visible failures are consistently reportable by stable code.

## Appendix A: Full Ownership Map

The audited source-file universe contains `59` files. Grouped by ownership:

### App Bootstrap

- `lib/src/app/pocket_relay_bootstrap.dart`

### Core Error Infrastructure

- `lib/src/core/errors/pocket_error.dart`

### Core Device Hosts

- `lib/src/core/device/background_grace_host.dart`
- `lib/src/core/device/display_wake_lock_host.dart`
- `lib/src/core/device/foreground_service_host.dart`

### Core Storage

- `lib/src/core/storage/codex_connection_repository_memory.dart`
- `lib/src/core/storage/codex_connection_repository_secure.dart`
- `lib/src/core/storage/connection_model_catalog_store.dart`
- `lib/src/core/storage/connection_scoped_stores.dart`

### Chat Composer

- `lib/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart`
- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`

### Chat Lane Application

- `lib/src/features/chat/lane/application/chat_conversation_recovery_policy.dart`
- `lib/src/features/chat/lane/application/chat_session_controller.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_events.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_recovery.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_support.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_thread_metadata.dart`
- `lib/src/features/chat/lane/application/chat_session_errors.dart`

### Chat Lane Presentation

- `lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart`

### Chat Runtime Application

- `lib/src/features/chat/runtime/application/runtime_event_mapper.dart`

### Chat Transcript Presentation Support

- `lib/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart`

### Chat Transport App-Server Layer

- `lib/src/features/chat/transport/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_process_launcher.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_models.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_support.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_fixture_sanitizer.dart`
- `lib/src/features/chat/transport/app_server/codex_json_rpc_codec.dart`
- `lib/src/features/chat/transport/app_server/codex_json_rpc_codec_models.dart`
- `lib/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart`

### Connection Settings Host Presentation

- `lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart`
- `lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart`

### Workspace Application

- `lib/src/features/workspace/application/connection_lifecycle_errors.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_lane.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart`
- `lib/src/features/workspace/application/controller/bootstrap.dart`
- `lib/src/features/workspace/application/controller/catalog_connections.dart`
- `lib/src/features/workspace/application/controller/reconnect.dart`
- `lib/src/features/workspace/application/controller/recovery_persistence.dart`
- `lib/src/features/workspace/application/controller/remote_runtime.dart`

### Workspace Infrastructure

- `lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`
- `lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart`

### Workspace Presentation

- `lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart`
- `lib/src/features/workspace/presentation/workspace_desktop_shell.dart`
- `lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`
- `lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart`
- `lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`

## Appendix B: Full Classification Map

Files can appear in more than one bucket when they both use the shared error model and bypass it elsewhere.

### Bucket A: Coded Infrastructure and Typed Mapper Files

- `lib/src/core/errors/pocket_error.dart`
- `lib/src/features/chat/lane/application/chat_conversation_recovery_policy.dart`
- `lib/src/features/chat/lane/application/chat_session_controller.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_events.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/chat/lane/application/chat_session_errors.dart`
- `lib/src/features/workspace/application/connection_lifecycle_errors.dart`
- `lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart`
- `lib/src/features/workspace/presentation/workspace_desktop_shell.dart`
- `lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`
- `lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`

### Bucket B: Mixed Coded and Uncoded User-Facing Handling

- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart`
- `lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`

### Bucket C: Uncoded User-Visible or Raw-State Handling

- `lib/src/app/pocket_relay_bootstrap.dart`
- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_recovery.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_support.dart`
- `lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart`
- `lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart`
- `lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart`
- `lib/src/features/workspace/application/controller/remote_runtime.dart`
- `lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`

### Bucket D: Silent, Collapsed, or Non-Observable Handling

- `lib/src/core/device/background_grace_host.dart`
- `lib/src/core/device/display_wake_lock_host.dart`
- `lib/src/core/device/foreground_service_host.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_thread_metadata.dart`
- `lib/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart`
- `lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart`
- `lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart`
- `lib/src/features/workspace/application/controller/recovery_persistence.dart`
- `lib/src/features/workspace/application/controller/remote_runtime.dart`
- `lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart`
- `lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart`

### Bucket E: Internal-Only Exception Flow or Non-UI Recovery Orchestration

- `lib/src/core/storage/codex_connection_repository_memory.dart`
- `lib/src/core/storage/codex_connection_repository_secure.dart`
- `lib/src/core/storage/connection_model_catalog_store.dart`
- `lib/src/core/storage/connection_scoped_stores.dart`
- `lib/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart`
- `lib/src/features/chat/runtime/application/runtime_event_mapper.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_process_launcher.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_models.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_support.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_fixture_sanitizer.dart`
- `lib/src/features/chat/transport/app_server/codex_json_rpc_codec.dart`
- `lib/src/features/chat/transport/app_server/codex_json_rpc_codec_models.dart`
- `lib/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_lane.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart`
- `lib/src/features/workspace/application/controller/bootstrap.dart`
- `lib/src/features/workspace/application/controller/catalog_connections.dart`
- `lib/src/features/workspace/application/controller/reconnect.dart`
- `lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`

## Appendix C: Pass 1 Per-File Counts for Coded Model and Formatter Touchpoints

```text
      5 lib/src/core/errors/pocket_error.dart
      4 lib/src/features/chat/lane/application/chat_conversation_recovery_policy.dart
      1 lib/src/features/chat/lane/application/chat_session_controller.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_events.dart
      7 lib/src/features/chat/lane/application/chat_session_controller_history.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart
      2 lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart
     41 lib/src/features/chat/lane/application/chat_session_errors.dart
     57 lib/src/features/workspace/application/connection_lifecycle_errors.dart
      1 lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart
      1 lib/src/features/workspace/presentation/workspace_desktop_shell.dart
      7 lib/src/features/workspace/presentation/workspace_live_lane_surface.dart
      1 lib/src/features/workspace/presentation/workspace_saved_connections_content.dart
```

## Appendix D: Pass 1 Per-File Counts for User-Visible Emission Touchpoints

```text
      2 lib/src/core/errors/pocket_error.dart
      2 lib/src/features/chat/composer/presentation/chat_composer_surface.dart
      4 lib/src/features/chat/lane/application/chat_conversation_recovery_policy.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_events.dart
      8 lib/src/features/chat/lane/application/chat_session_controller_history.dart
      2 lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart
      9 lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart
     10 lib/src/features/chat/lane/application/chat_session_controller_recovery.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_support.dart
      3 lib/src/features/chat/lane/application/chat_session_errors.dart
      1 lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart
      1 lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart
      2 lib/src/features/workspace/presentation/workspace_desktop_shell.dart
      9 lib/src/features/workspace/presentation/workspace_live_lane_surface.dart
      2 lib/src/features/workspace/presentation/workspace_saved_connections_content.dart
```

## Appendix E: Pass 2 Per-File Catch Counts

```text
      1 lib/src/app/pocket_relay_bootstrap.dart
      1 lib/src/core/device/background_grace_host.dart
      1 lib/src/core/device/display_wake_lock_host.dart
      3 lib/src/core/device/foreground_service_host.dart
      1 lib/src/core/storage/codex_connection_repository_secure.dart
      1 lib/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart
      2 lib/src/features/chat/composer/presentation/chat_composer_surface.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_events.dart
      5 lib/src/features/chat/lane/application/chat_session_controller_history.dart
      2 lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart
      2 lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_recovery.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_thread_metadata.dart
      1 lib/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart
      2 lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart
      2 lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart
      4 lib/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart
      3 lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart
      3 lib/src/features/chat/transport/app_server/codex_json_rpc_codec.dart
      1 lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart
      1 lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart
      1 lib/src/features/workspace/application/connection_workspace_controller_lane.dart
      1 lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart
      2 lib/src/features/workspace/application/controller/bootstrap.dart
      5 lib/src/features/workspace/application/controller/reconnect.dart
      1 lib/src/features/workspace/application/controller/recovery_persistence.dart
      1 lib/src/features/workspace/application/controller/remote_runtime.dart
      1 lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart
      1 lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart
      2 lib/src/features/workspace/presentation/workspace_desktop_shell.dart
      4 lib/src/features/workspace/presentation/workspace_live_lane_surface.dart
      5 lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart
      2 lib/src/features/workspace/presentation/workspace_saved_connections_content.dart
```

## Appendix F: Pass 2 Per-File Throw and Rethrow Counts

```text
      1 lib/src/core/storage/codex_connection_repository_memory.dart
      2 lib/src/core/storage/codex_connection_repository_secure.dart
      1 lib/src/core/storage/connection_model_catalog_store.dart
      1 lib/src/core/storage/connection_scoped_stores.dart
      6 lib/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart
      1 lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart
      2 lib/src/features/chat/lane/application/chat_session_controller_recovery.dart
      1 lib/src/features/chat/runtime/application/runtime_event_mapper.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_client.dart
      9 lib/src/features/chat/transport/app_server/codex_app_server_connection.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_process_launcher.dart
      9 lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_request_api_models.dart
      3 lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart
      4 lib/src/features/chat/transport/app_server/codex_app_server_request_api_support.dart
     10 lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart
      4 lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart
      4 lib/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart
      1 lib/src/features/chat/transport/app_server/codex_app_server_thread_read_fixture_sanitizer.dart
      1 lib/src/features/chat/transport/app_server/codex_json_rpc_codec_models.dart
     12 lib/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart
      2 lib/src/features/workspace/application/connection_workspace_controller_lane.dart
      1 lib/src/features/workspace/application/connection_workspace_controller_remote_owner.dart
      5 lib/src/features/workspace/application/controller/catalog_connections.dart
      3 lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart
```

## Appendix G: Pass 5 Per-File Test Coverage Counts

```text
      3 test/core/errors/error_catalog_test.dart
      4 test/features/chat/lane/application/conversation_recovery_policy_test.dart
      1 test/features/chat/lane/application/session_controller_branch_conversation_test.dart
      1 test/features/chat/lane/application/session_controller_fresh_lane_and_continue_test.dart
      2 test/features/chat/lane/application/session_controller_history_restore_transitions_test.dart
      1 test/features/chat/lane/application/session_controller_host_and_changed_files_test.dart
      2 test/features/chat/lane/application/session_controller_recovery_state_test.dart
      2 test/features/chat/lane/application/session_controller_submission_failures_test.dart
     11 test/features/chat/lane/application/session_errors_test.dart
     10 test/features/workspace/application/lifecycle_errors_test.dart
      2 test/features/workspace/presentation/conversation_history_sheet_test.dart
      1 test/features/workspace/presentation/live_lane/connection_actions_test.dart
      2 test/features/workspace/presentation/live_lane/remote_runtime_notices_test.dart
      3 test/features/workspace/presentation/shell/desktop/conversation_history_dialog_test.dart
      1 test/features/workspace/presentation/shell/mobile/conversation_history_test.dart
```
