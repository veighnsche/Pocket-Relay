# 079 Error Handling Centralization Plan

## Goal

Turn Pocket Relay's existing error seed into the single app-wide error pipeline so that user-visible failures are:

- defined once
- mapped in feature application code
- formatted consistently
- rendered consistently
- reportable by stable code

This plan intentionally does not create a second parallel error system. It completes the system that already exists in [pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart).

## Why This Is The Right Upgrade

The repo already has the right base abstraction:

- `PocketErrorDefinition`
- `PocketUserFacingError`
- `PocketErrorCatalog`

The audit in [078_error_handling_audit.md](/home/vince/Projects/codex_pocket/docs/078_error_handling_audit.md) showed that the main problem is not missing infrastructure. The main problem is partial adoption and duplicated formatting.

So the right direction is:

1. strengthen the core contract
2. centralize shared formatting and rendering helpers
3. expand feature-owned mappers
4. remove widget-owned fallback strings
5. enforce the new structure

## Target Architecture

The target pipeline should be:

1. infrastructure and transport throw internal exceptions
2. feature application code maps failures into `PocketUserFacingError`
3. presentation only renders typed errors
4. core owns code definitions, detail formatting, and UI emission helpers

That means the target ownership model is:

- `lib/src/core/errors/`
  - stable domains and codes
  - normalized underlying-detail formatting
  - shared typed-error rendering helpers
- `lib/src/features/**/application/`
  - feature-specific mapping from raw failures or guardrails into `PocketUserFacingError`
- `lib/src/features/**/presentation/`
  - no ad hoc final user-facing error strings
  - no local `Could not ...` assembly when a typed error should exist

## Core Abstractions To Add Or Complete

### 1. Complete `PocketUserFacingError`

Keep [pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart) as the root type, but upgrade it so feature mappers stop hand-assembling detail strings.

Target additions:

- optional normalized underlying detail field
- helper or factory for attaching underlying errors
- one consistent rule for `inlineMessage`
- one consistent rule for long-body formatting

The important rule is: feature code should not need to manually decide how to append `Underlying error: ...`.

### 2. Add One Shared Detail Formatter

Add a single core helper under `lib/src/core/errors/`, for example:

- `pocket_error_detail_formatter.dart`

Responsibilities:

- normalize `Exception: ...`
- normalize `Bad state: ...`
- normalize app-server exception wrappers
- deduplicate repeated detail text
- produce the final optional detail payload used by `PocketUserFacingError`

This replaces the duplicated normalization currently living in:

- [chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart#L105)
- [connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart#L347)

### 3. Add One Shared Presentation Helper

Add a small rendering helper for typed errors, for example:

- `pocket_error_presenter.dart`
- or `pocket_error_snackbar.dart`

Responsibilities:

- render a `PocketUserFacingError` into a snackbar
- render a `PocketUserFacingError` into a dialog body where needed
- keep widget code from rebuilding the same message formatting everywhere

This should be small. It must not become a giant "error manager".

## Domain Expansion

The current core catalog only defines two domains in [pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart#L1):

- `connectionLifecycle`
- `chatSession`

That is too narrow for the current app. The catalog should expand to cover the real ownership areas that already produce user-visible failures.

Recommended new domains:

- `connectionSettings`
- `chatComposer`
- `appBootstrap`
- `workspaceRecovery`

If later needed:

- `deviceCapability`
- `storage`

Rule:

- only add a domain when the app truly exposes user-visible failures in that area
- do not create speculative domains just to look clean

## Migration Order

The order matters. The safest path is to centralize the abstraction before rewriting feature behavior.

## Phase 0: Lock The Baseline

### Outcome

Freeze the current behavior we need to preserve before changing the plumbing.

### Work

- keep [078_error_handling_audit.md](/home/vince/Projects/codex_pocket/docs/078_error_handling_audit.md) as the baseline inventory
- add focused tests for current detail-formatting behavior
- add focused tests for the current chat guardrail wording that must remain semantically the same after conversion
- add focused tests for current connection-settings failure behavior so the migration does not accidentally hide or widen UI outcomes

### Why First

Without baseline tests, the migration will drift into wording changes and invisible regressions.

### Verification

- core error tests
- affected chat lane application tests
- affected connection settings tests

## Phase 1: Centralize Core Error Formatting

### Outcome

Move all shared error-detail formatting into `core/errors`.

### Work

- add `lib/src/core/errors/pocket_error_detail_formatter.dart`
- extend `PocketUserFacingError` so it can own optional normalized detail
- update [pocket_error.dart](/home/vince/Projects/codex_pocket/lib/src/core/errors/pocket_error.dart) to make `inlineMessage` and long-body formatting the single source of truth
- remove duplicated detail-formatting logic from:
  - [chat_session_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_errors.dart)
  - [connection_lifecycle_errors.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/connection_lifecycle_errors.dart)

### Why First

This is the first real centralization step. If feature migrations happen before this, they will just spread more formatter duplication.

### Verification

- new core formatter tests
- existing `error_catalog_test.dart`
- existing workspace lifecycle error tests
- existing chat session error tests

## Phase 2: Expand The Catalog And Feature Mapper Surface

### Outcome

Create the missing typed-error ownership boundaries before changing UI call sites.

### Work

- expand `PocketErrorDomain`
- add new catalog definitions for:
  - chat guardrails
  - connection settings refresh/probe failures
  - composer attachment failures not already covered
  - app bootstrap failures if surfaced to the user
- add feature-owned mapper files:
  - `lib/src/features/chat/lane/application/chat_session_guardrail_errors.dart`
  - `lib/src/features/connection_settings/application/connection_settings_errors.dart`
  - `lib/src/features/chat/composer/application/chat_composer_errors.dart`
  - optional bootstrap mapper if bootstrap errors remain user-visible

### Why Before Feature Rewrites

The migration should create the right ownership seams first, then move callers onto them.

### Verification

- new mapper tests for each added file
- catalog uniqueness tests
- code-range lookup tests if needed

## Phase 3: Normalize Chat Guardrails

### Outcome

Remove raw chat controller guardrail strings from application logic.

### Work

Replace raw `_emitSnackBar(...)` product errors in:

- [chat_session_controller_recovery.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart)
- [chat_session_controller_prompt_flow.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart)
- [chat_session_controller_model_capabilities.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_model_capabilities.dart)
- stale-request cases in [chat_session_controller_history.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/lane/application/chat_session_controller_history.dart)

Representative cases to convert:

- active-turn guardrails
- transcript-restore guardrails
- stale prompt/request warnings
- profile validation failures
- image capability rejection
- host fingerprint save failure

### Why Here

This is the largest uncoded user-visible gap found in the audit.

### Verification

- `test/features/chat/lane/application/session_errors_test.dart`
- add new tests for guardrail mappers
- update the controller tests that currently assert raw inline strings

## Phase 4: Normalize Connection Settings And Workspace Runtime Failures

### Outcome

Stop collapsing connection-settings and runtime-probe failures into booleans or raw thrown text.

### Work

Migrate:

- [model_catalog_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/model_catalog_refresh.dart)
- [remote_runtime_refresh.dart](/home/vince/Projects/codex_pocket/lib/src/features/connection_settings/presentation/host/remote_runtime_refresh.dart)
- [remote_runtime.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/controller/remote_runtime.dart)

Target behavior:

- model refresh failure maps to a typed `PocketUserFacingError`
- remote probe failure maps to a typed `PocketUserFacingError`
- runtime state can still carry status, but not raw ad hoc thrown text as product truth

### Why Here

This is the second largest adoption gap after chat guardrails, and it currently hides too much useful failure context.

### Verification

- new connection-settings mapper tests
- connection-settings presentation tests
- workspace runtime tests if needed

## Phase 5: Remove Presentation-Owned Fallback Strings

### Outcome

Widgets stop inventing final user-visible error messages locally.

### Work

Migrate the known fallback surfaces:

- [chat_composer_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/composer/presentation/chat_composer_surface.dart)
- [workspace_live_lane_surface.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface.dart)

Add a small shared renderer such as:

- `showPocketErrorSnackBar(context, error)`

Target rule:

- presentation may decide where to show an error
- presentation may not decide what the error means

### Why After Feature Mappers

Widgets cannot become dumb until application code can provide the typed errors they need.

### Verification

- composer presentation tests
- live lane presentation tests
- smoke tests for any shared snackbar helper

## Phase 6: Decide Which Silent Paths Stay Silent

### Outcome

Make silent and collapsed catches an explicit product decision instead of an accident.

### Work

Review and classify silent paths in:

- [foreground_service_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/foreground_service_host.dart)
- [background_grace_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/background_grace_host.dart)
- [display_wake_lock_host.dart](/home/vince/Projects/codex_pocket/lib/src/core/device/display_wake_lock_host.dart)
- [workspace_live_lane_surface_settings.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart)
- [recovery_persistence.dart](/home/vince/Projects/codex_pocket/lib/src/features/workspace/application/controller/recovery_persistence.dart)

Decision rule:

- if the failure is intentionally non-blocking and the user should not be interrupted, keep it silent but add debug observability
- if the failure changes what the user can actually do, map it to a typed error

### Why This Is Separate

Not every silent catch is a bug. This phase is policy cleanup, not blanket surfacing.

### Verification

- targeted tests for any newly surfaced failures
- debug-path assertions where practical

## Phase 7: Enforce The New Rules

### Outcome

Prevent the codebase from drifting back to ad hoc error handling.

### Work

- add a repo-level regression check that fails on new raw product-facing `_emitSnackBar('...')` strings in feature application code
- add a repo-level regression check that flags widget-owned `Could not ...` fallback assembly where typed errors should exist
- keep `PocketErrorCatalog` uniqueness tests
- optionally add a structural check that feature mappers, not widgets, own new catalog definitions for feature-visible errors

### Why Last

Enforcement only helps after the target structure exists.

### Verification

- run the new static/test-time checks
- run affected feature tests

## First Slice

If we start implementation immediately, the best first slice is:

1. add `pocket_error_detail_formatter.dart`
2. extend `PocketUserFacingError` to own normalized detail
3. migrate `ChatSessionErrors.runtimeMessage(...)` and `ConnectionLifecycleErrors` to use the shared formatter
4. add tests proving the shared detail formatting matches current behavior

This is the highest-leverage starting point because it removes duplicated logic without changing product semantics yet.

## What Not To Do

- do not create a second parallel error abstraction beside `PocketUserFacingError`
- do not let widgets keep assembling final fallback copy after mappers exist
- do not turn every silent device-host failure into a user interruption
- do not add speculative domains or codes for states the product does not actually surface

## Definition Of Done

The migration is done when:

- all user-visible product failures route through `PocketUserFacingError`
- feature application code owns feature-specific mapping
- shared formatting lives in `core/errors`
- presentation renders typed errors without inventing meaning
- silent catches are intentional and documented
- repo-level checks block regression into raw ad hoc product error strings
