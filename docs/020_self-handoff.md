# Self Handoff

Generated: 2026-03-18

## Purpose

This document is a restart point for future work after refreshing the app or
losing chat context. It captures the current mental model of the codebase, the
important repo rules, the current worktree state, and the last change completed
in this session.

## Product Summary

Pocket Relay is a Flutter client for Codex sessions.

- It is app-server-only.
- Remote transport is SSH-backed `codex app-server --listen stdio://`.
- There is also a desktop-local transport path for running Codex on the same
  machine as the app.
- The core pipeline is:
  - transport / JSON-RPC
  - canonical runtime events
  - session + timeline state
  - presentation contracts / projectors
  - widgets

`README.md` is accurate at a high level and is still the best short product
summary.

## Repo Rules That Matter

From `AGENTS.md`, the important operating rules are:

- Requirements are contracts. Do not fake a semantic requirement with a visual
  approximation.
- Prefer correct ownership over small diffs.
- Do not silently ship shortcuts or heuristics as if they fully solve the
  problem.
- Generic requests should land as generic solutions, not screen-specific hacks.
- Verify behavior, ownership, lifecycle, and placement, not just text.
- New docs under `docs/` must use the next three-digit prefix.

Implication: if a task sounds like "make platform behavior different", the
correct solution is to put that behavior at a real seam, not scattered widget
conditionals.

## High-Level Architecture

### 1. App bootstrap

`lib/main.dart` just runs the app.

`lib/src/app.dart` is the top-level bootstrap:

- binds injected or owned dependencies
- loads saved connection profile
- loads saved conversation handoff state
- creates the app-server client
- selects a platform policy
- hands off to `ChatRootAdapter`

This file is the correct place for app-level dependency ownership, not feature
logic.

### 2. Core models and storage

`lib/src/core/models/connection_models.dart`

- defines `ConnectionProfile`
- supports `remote` and `local` connection modes
- stores auth mode, workspace dir, Codex path, host fingerprint, sandbox mode,
  and ephemeral session mode

`lib/src/core/storage/codex_profile_store.dart`

- persists connection profile in `SharedPreferencesAsync`
- persists secrets in `flutter_secure_storage`
- migrates legacy keys forward

`lib/src/core/storage/codex_conversation_handoff_store.dart`

- persists only the resume thread id
- intentionally keeps this separate from the full profile

### 3. Chat root and orchestration

`lib/src/features/chat/presentation/chat_root_adapter.dart`

- is the feature composition root
- owns `ChatSessionController`
- owns local UI draft helpers like `ChatComposerDraftHost`
- wires overlay effects, transcript follow behavior, screen actions, settings,
  changed-file diff sheets, approvals, and user input

`lib/src/features/chat/application/chat_session_controller.dart`

- is the main orchestration layer
- owns connection state, session state, recovery state, and snack bar effects
- starts and resumes app-server sessions
- applies connection setting changes
- handles approvals and user-input responses
- handles conversation recovery rules
- persists continuation thread handoff state

This is one of the main complexity hotspots in the repo.

### 4. App-server transport

`lib/src/features/chat/infrastructure/app_server/`

Important files:

- `codex_app_server_client.dart`
- `codex_app_server_connection.dart`
- `codex_app_server_request_api.dart`
- `codex_app_server_ssh_process.dart`
- `codex_app_server_local_process.dart`
- `codex_json_rpc_codec.dart`

Ownership split:

- `client`: public API used by the controller
- `connection`: JSON-RPC connection and tracked request lifecycle
- `request_api`: app-server request shapes and response validation
- `ssh_process`: remote launch / SSH auth / host key handling
- `local_process`: desktop-local process launch

The transport layer is reasonably clean. Most future bugs are more likely to be
in mapping, reducer logic, or presentation ownership than in raw process setup.

### 5. Runtime mapping and reducer

`lib/src/features/chat/application/runtime_event_mapper.dart`

- converts app-server events into canonical runtime events
- delegates to request, notification, transport, and support mappers

`lib/src/features/chat/application/transcript_reducer.dart`

- reduces canonical runtime events into `CodexSessionState`
- handles both legacy single-thread state and current workspace / multi-timeline
  state

`lib/src/features/chat/application/transcript_policy.dart`

- contains a lot of the actual transcript mutation rules

Important model files:

- `lib/src/features/chat/models/codex_runtime_event.dart`
- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/models/codex_ui_block.dart`

These files are the biggest state/behavior hotspots in the repo.

### 6. Presentation

`lib/src/features/chat/presentation/chat_screen_presenter.dart`

- builds the top-level screen contract
- produces header, actions, timeline summaries, composer state, and recovery
  notices

`lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

- projects session state into transcript contracts
- handles pinned vs main request placement

`lib/src/features/chat/presentation/chat_root_region_policy.dart`

- controls which renderers are used for app chrome, transcript, composer,
  feedback, settings, and empty state
- current policy supports a Cupertino foundation on iOS/macOS and a Flutter
  fallback elsewhere

`lib/src/features/chat/presentation/chat_root_renderer_delegate.dart`

- bridges contracts to actual Material / Cupertino renderer widgets

Widgets live under:

- `lib/src/features/chat/presentation/widgets/`
- `lib/src/features/chat/presentation/widgets/transcript/`

Important UI note:

- The repo already has a good seam for platform-conditional look and feel.
- It does not yet have a single first-class app-wide "mobile vs desktop" policy.
- Right now platform/form-factor behavior is split across:
  - `ChatRootPlatformPolicy`
  - `supportsLocalCodexConnection()`
  - some widget-level layout checks such as the empty state

If a future task requires broad desktop/mobile divergence, prefer introducing an
explicit form-factor policy rather than sprinkling `if desktop` logic across
widgets.

### 7. Settings

`lib/src/features/settings/presentation/`

- host / draft / presenter / contract split is clean
- supports remote and local connection modes
- supports password and private key auth
- validation lives in presenter/draft logic, not in ad hoc widget state

This is a good area to extend without large architectural churn.

## Current Docs Worth Reading First

These docs best explain the current direction:

- `docs/000_app-server-migration-plan.md`
- `docs/004_codex-parity-maturity-plan.md`
- `docs/014_child-agent-timeline-architecture-plan.md`
- `docs/017_ux-hardening-investigation.md`

Interpretation:

- `000` explains that the app-server migration is done and the remaining work is
  ownership cleanup, not transport ambiguity.
- `004` tracks parity with upstream Codex semantics without cloning the TUI.
- `014` explains the multi-timeline / child-agent ownership model.
- `017` captures the UX hardening rule that the app must not pretend to know
  conversation continuity when it does not.

## Codebase Size and Hotspots

Quick counts observed during this session:

- `lib/src/features/chat`: 93 files
- `lib/src/features/settings`: 8 files
- `test/`: 25 top-level test files
- `docs/`: 20 files before this handoff

Largest / hottest files observed:

- `codex_session_state.dart`
- `chat_session_controller.dart`
- `transcript_reducer.dart`
- `transcript_policy.dart`
- `codex_runtime_event.dart`

If a future bug smells like transcript chronology, request placement, multi-agent
ownership, or turn lifecycle, start in those files first.

## Verification Baseline

Baseline observed before changes in this session:

- `dart analyze`: clean
- full `flutter test`: passing

After the composer change completed in this session:

- focused composer tests: passing
- full `flutter test`: passing
- `dart analyze`: clean

This repo has strong test coverage around app-server behavior, settings,
transcript chronology, pending approvals, user input, and renderer ownership.

## Current Worktree State

At the end of this session, the worktree is dirty.

Files that were already dirty or added before the composer change and should be
treated as user-owned unless asked otherwise:

- `justfile`
- `linux/CMakeLists.txt`
- `scripts/host-run.sh`

Files changed in this session:

- `lib/src/features/chat/presentation/widgets/chat_composer_surface.dart`
- `test/chat_composer_test.dart`
- `test/cupertino_chat_composer_test.dart`

`git diff --stat` at the time of writing showed:

- `chat_composer_surface.dart` modified
- both composer test files modified
- unrelated changes still present in `justfile` and `linux/CMakeLists.txt`

Do not revert the unrelated dirty files casually.

## Last Change Completed In This Session

Task completed:

- desktop `Enter` sends from the composer
- desktop `Shift+Enter` inserts a newline
- mobile keeps newline / multiline behavior

Implementation notes:

- The change was made in the shared composer surface, not duplicated across the
  Material and Cupertino wrappers.
- Desktop behavior is implemented with explicit keyboard intents / shortcuts.
- `Shift+Enter` is also explicit; it does not rely on default text-field
  behavior.
- Mobile remains in newline mode and does not use the desktop send shortcut.

Tests added/updated:

- Material composer tests cover desktop send, desktop `Shift+Enter`, and mobile
  multiline behavior.
- Cupertino composer tests cover the same behavior.

This was the correct ownership seam for the feature.

## Recommended Resume Procedure After Refresh

1. Re-open `AGENTS.md`.
2. Re-open this file.
3. Run `git status --short` to re-confirm the dirty worktree.
4. If the next task is related to:
   - transport/protocol: start in `infrastructure/app_server/`
   - transcript/state/ownership: start in controller + reducer + models
   - UI/card behavior: start in presenter/projector/renderers
   - settings/connection flow: start in settings presenter/host and core models
5. Re-run `dart analyze` and relevant tests before making structural changes.

## Best Short Summary For Future Me

Pocket Relay already has a decent architecture. The hardest parts are not basic
Flutter UI wiring, but ownership:

- which layer owns transcript truth
- which layer owns thread / timeline identity
- which layer is allowed to infer or recover state
- which platform differences are real product rules vs visual styling only

When in doubt, keep transport, reducer, and rendering responsibilities separate,
and prefer a real policy seam over a local conditional hack.
