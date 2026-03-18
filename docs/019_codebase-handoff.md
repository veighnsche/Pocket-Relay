# Pocket Relay Codebase Handoff

Date: 2026-03-18

This document is a self-handoff for the next Codex session. It summarizes the
repo shape, the current architectural seams, the most important working
assumptions, and the latest validated state of the app.

## 1. What This App Is

Pocket Relay is a Flutter client for running Codex from a phone or desktop UI.

Current shipped architecture:

- transport is `codex app-server`
- remote mode uses SSH and starts `codex app-server --listen stdio://`
- local mode exists for desktop and starts `codex app-server --listen stdio://`
  directly on the host
- the app maps app-server JSON-RPC into canonical runtime events, reduces those
  events into session state, and renders transcript cards from that state

The project is app-server-only now. The legacy SSH parser path is gone.

## 2. Repo Rules That Matter

The repo-level rules in `AGENTS.md` are strong and should be followed as design
constraints, not style suggestions.

Important ones:

- requirements are contracts
- prefer correct ownership over the smallest diff
- do not silently ship compromises
- build generic solutions when the problem is generic
- verify lifecycle and ownership behavior, not just text
- use the smallest test scope that proves the behavior, then broader validation
  when shared infrastructure changed
- new docs under `docs/` should use the next chronological three-digit prefix

Note: there are already two unprefixed docs in `docs/`, but do not continue
that pattern for new files.

## 3. Current Codebase Map

The high-level boot and ownership path is:

1. `lib/main.dart`
2. `lib/src/app.dart`
3. `lib/src/features/chat/presentation/chat_root_adapter.dart`
4. `lib/src/features/chat/application/chat_session_controller.dart`
5. app-server client / connection / request API
6. runtime event mapper
7. transcript reducer + session state
8. presenter / projector layer
9. widgets

Put differently:

bootstrap stores -> root adapter -> session controller -> app-server transport
-> canonical runtime events -> reducer -> session/timeline state -> presenter
contracts -> widgets

## 4. Ownership By Layer

### App bootstrap

`lib/src/app.dart`

- creates or accepts stores and the app-server client
- loads saved profile and saved conversation handoff
- resolves the app-level platform policy once at the root
- renders `ChatRootAdapter` once bootstrap state is ready

### Chat root binding layer

`lib/src/features/chat/presentation/chat_root_adapter.dart`

- owns draft host, transcript follow host, effect mapping, and screen binding
- binds `ChatSessionController` to presenter output and overlay actions
- is the main composition seam for screen-level behavior

### Session orchestration

`lib/src/features/chat/application/chat_session_controller.dart`

- the core application controller
- owns current profile/secrets/session state
- persists connection settings and resume thread handoff
- manages send / stop / approval / user-input flows
- handles conversation recovery rules
- listens to app-server events and applies mapped runtime events

This is one of the biggest complexity hotspots in the repo.

### Transport

`lib/src/features/chat/infrastructure/app_server/`

Important files:

- `codex_app_server_client.dart`
- `codex_app_server_connection.dart`
- `codex_app_server_request_api.dart`
- `codex_app_server_ssh_process.dart`
- `codex_app_server_local_process.dart`
- `codex_json_rpc_codec.dart`

Responsibilities:

- connect and initialize app-server
- manage JSON-RPC request/response tracking
- launch either SSH-backed or local app-server processes
- translate app-server request methods into client replies for approvals,
  elicitation, user input, abort, etc

### Runtime mapping and reduction

Important files:

- `lib/src/features/chat/application/runtime_event_mapper.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/application/transcript_request_policy.dart`

Responsibilities:

- map raw transport events to canonical runtime events
- reduce those events into state
- preserve transcript chronology and request ownership

### Models

Important files:

- `lib/src/features/chat/models/codex_runtime_event.dart`
- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/models/codex_ui_block.dart`

`codex_session_state.dart` is the biggest state hotspot in the project.

### Presentation contracts and widgets

Important files:

- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`
- `lib/src/features/chat/presentation/chat_transcript_item_projector.dart`
- `lib/src/features/chat/presentation/widgets/`

The current presentation split is good:

- presenter/projector files derive display contracts from state
- widgets mostly render those contracts instead of re-owning session logic

### Settings and persistence

Important files:

- `lib/src/core/models/connection_models.dart`
- `lib/src/core/storage/codex_profile_store.dart`
- `lib/src/core/storage/codex_conversation_handoff_store.dart`
- `lib/src/features/settings/presentation/connection_settings_host.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`

Responsibilities:

- persisted connection profile + secrets
- persisted resume thread handoff
- settings validation and payload assembly
- remote vs local connection configuration

## 5. Platform And UI Conditioning

The repo now has a real app-level platform seam.

### App-level platform policy

`lib/src/core/platform/pocket_platform_policy.dart`

This is the first-class root policy. It resolves, from one place:

- product behavior policy
- region renderer policy

### Platform behavior

`lib/src/core/platform/pocket_platform_behavior.dart`

This is the app-wide product-behavior model. It currently owns:

- `mobile` vs `desktop` experience
- whether local connection mode is available
- whether display wake lock is available
- whether desktop keyboard submit behavior should be enabled

### Region policy

`lib/src/features/chat/presentation/chat_root_region_policy.dart`

This remains the visual/foundation policy and chooses:

- screen shell renderer
- app chrome renderer
- transcript renderer
- composer renderer
- settings overlay renderer
- feedback renderer
- empty-state renderer

Current policy behavior:

- iOS and macOS use a Cupertino foundation policy
- fallback platforms use Flutter/Material renderers
- transcript rendering still stays on the Flutter path even in the Cupertino
  foundation policy

### Platform capabilities

`lib/src/core/utils/platform_capabilities.dart`

This now acts as a compatibility wrapper over `PocketPlatformBehavior.resolve()`
for places that still want a narrow helper.

### Current ownership model

`lib/src/app.dart` resolves `PocketPlatformPolicy` once, and
`lib/src/features/chat/presentation/chat_root_adapter.dart` passes its
behavior/region decisions down into the shared renderers and widgets.

Important consequence:

- mobile vs desktop behavior should now flow through `PocketPlatformBehavior`
- Cupertino vs Material region selection should now flow through
  `ChatRootRegionPolicy`
- future platform-specific product splits should start from
  `PocketPlatformPolicy`, not widget-local platform checks

## 6. Latest Change In This Session

Implemented a first-class app-wide platform policy and routed the main desktop
vs mobile behaviors through it.

Files changed by this session:

- `lib/src/core/platform/pocket_platform_policy.dart`
- `lib/src/core/platform/pocket_platform_behavior.dart`
- `lib/src/app.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/chat/presentation/widgets/chat_composer_surface.dart`
- `lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart`
- `lib/src/features/settings/presentation/connection_settings_host.dart`
- `test/chat_composer_test.dart`
- `test/cupertino_chat_composer_test.dart`
- `test/pocket_platform_behavior_test.dart`
- `test/pocket_platform_policy_test.dart`

Behavior now:

- the root resolves one `PocketPlatformPolicy`
- desktop/mobile product behavior is modeled explicitly via
  `PocketPlatformBehavior`
- desktop composer `Enter` send behavior still lives in the shared composer
  surface, but now depends on the shared behavior policy
- empty-state desktop/mobile structure now depends on explicit experience
  ownership instead of treating local-mode capability as a proxy for desktop
- settings local/remote availability now depends on injected platform behavior
- wake-lock enablement now comes from the same root policy

Implementation note:

- visual foundation policy and product behavior policy are now resolved together
  at the root
- low-level OS launch details for local processes still stay in the
  infrastructure layer and are intentionally separate from the app UI policy

## 7. What The App Already Does Well

Current app behavior appears solid in these areas:

- connection settings storage and migration
- SSH-backed app-server sessions
- desktop-local app-server sessions
- resume-thread handoff persistence
- transcript cards for assistant output, reasoning, work logs, approvals,
  changed files, status, errors, usage, and user-input requests
- host fingerprint prompting and save flow
- conversation recovery when the local transcript can no longer safely claim it
  still matches the live remote thread
- multi-thread / timeline-oriented session state instead of a purely flat
  transcript

## 8. Complexity Hotspots

These files deserve extra care before touching them:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/models/codex_runtime_event.dart`

The codebase has no obvious `TODO` / `FIXME` / `HACK` markers at the moment,
which means intent is mostly carried by docs and by the structure itself.

## 9. Docs Worth Reading First

If a future task is non-trivial, read these before making structural changes:

- `docs/000_app-server-migration-plan.md`
- `docs/004_codex-parity-maturity-plan.md`
- `docs/014_child-agent-timeline-architecture-plan.md`
- `docs/017_ux-hardening-investigation.md`

Other useful context:

- `docs/local-codex-connection-migration-plan.md`
- `docs/codex-app-server-emission-parity.md`

There is also a local reference checkout under `.reference/` that these docs
use when comparing Pocket Relay behavior against upstream Codex or other
references.

## 10. Verification Snapshot

As of 2026-03-18 after the platform-policy refactor:

- `dart analyze` passes with no errors
- the targeted platform-focused Flutter test suite passes

This repo has broad coverage relative to its size. It is worth preserving.

## 11. Useful Commands

Common entry points:

- `flutter run`
- `just mobile`
- `just desktop`
- `just android-dev`
- `just screenshot-ios`
- `just screenshot-macos`
- `just codex-mcp`

There is also:

- `scripts/host-run.sh`
- `scripts/host-screenshot.sh`
- `scripts/codex-mcp-loop.sh`

## 12. Current Worktree Snapshot

Observed dirty/untracked files after this session:

- modified: `justfile`
- modified: `linux/CMakeLists.txt`
- untracked: `scripts/host-run.sh`
- modified by this session: the platform-policy refactor plus related widget and
  test files

Assumption:

- `justfile`, `linux/CMakeLists.txt`, and `scripts/host-run.sh` should be
  treated as user-owned unless the next task explicitly says to work there

Do not revert those opportunistically.

## 13. How To Route Future Tasks Quickly

If the next request is about:

- protocol / transport bugs: start in `infrastructure/app_server/` and the
  runtime event mapper
- transcript ownership / chronology / pending request bugs: start in
  `chat_session_controller.dart`, `transcript_reducer.dart`,
  `transcript_policy.dart`, and `codex_session_state.dart`
- card/UI rendering bugs: start in the presenter/projector layer and then the
  specific widget/card
- connection/settings behavior: start in the settings host/presenter plus the
  connection models and stores
- mobile vs desktop UX splits: start in `core/platform/` plus
  `chat_root_adapter.dart`, then push the resolved policy into shared widgets
  instead of adding widget-local platform checks

## 14. Short Resume Prompt For The Next Session

If a future Codex session needs a quick bootstrap, use this mental summary:

"Pocket Relay is a Flutter app-server client for Codex. The main ownership path
is app bootstrap -> `ChatRootAdapter` -> `ChatSessionController` -> app-server
transport -> runtime mapper -> reducer -> session/timeline state ->
presenter/projectors -> widgets. The major hotspots are `codex_session_state`,
`chat_session_controller`, and `transcript_reducer`. The repo rules strongly
prefer correct ownership over small diffs. As of 2026-03-18, `dart analyze`
and the targeted platform-focused test suite pass, and the latest change is a
first-class `PocketPlatformPolicy` / `PocketPlatformBehavior` seam that owns
desktop vs mobile app behavior while `ChatRootRegionPolicy` owns
Cupertino/Material region rendering."
