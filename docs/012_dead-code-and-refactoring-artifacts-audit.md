# Dead Code And Refactoring Artifacts Audit

Date: 2026-03-15

## Purpose

This document records confirmed dead code, compatibility residue, facade-only
APIs, duplicated ownership, and parallel code paths that now overlap in the
current Pocket Relay codebase.

This is an audit document, not a cleanup plan. The goal is to describe what is
actually present today and why it looks like refactoring residue.

## Cleanup Buckets

### Group 1: Safe Quick Deletions

Status: completed on 2026-03-15

Completed items:

- removed `CodexRuntimeEventMapper.bind()`
- removed `ChatSessionController.hasVisibleConversation`
- removed `lib/src/core/utils/thread_utils.dart`
- removed the unused `TranscriptChangedFilesParser` dependency injection seam
- removed the dead conditional branch in
  `_mergeResolvedRequestBlocks()`
- removed the dead `ChatScreen` compatibility wrapper
- removed the standalone fallback mode from `FlutterChatScreenRenderer`

### Group 2: Medium Cleanups

Status: completed on 2026-03-15

Completed items:

- replaced permanent legacy-key fallback with a converging migration that
  copies legacy profile and secret keys forward, then removes the legacy keys
- removed the dead `skipGitRepoCheck` setting from the profile model and
  settings UI
- removed unused `CodexAppServerClient` facade methods
  `resolvePermissionsRequest(...)` and `sendServerResult(...)`
- removed the write-only active-turn fields `turnDiffSnapshot`, `hasWork`,
  and `hasReasoning`
- removed the dead auth-refresh response API from the app-server client and
  request layer
- removed legacy file-read approval resolution support so transport behavior
  matches the controller's rejection-only handling
- updated `README.md` to reflect the current app-server-only architecture
- updated `docs/002_pre-phase-5-infrastructure-plan.md` so its frozen public
  surface matches the current client API

Scope:
- keep medium cleanup converged as adjacent transport work changes

### Group 3: Structural Refactors

Status: completed on 2026-03-15

Completed items:

- removed the dead pre-artifact `TranscriptItemBlockFactory.blockFromActiveItem(...)`
  path and its test-only coverage
- removed the leftover `CodexCommandExecutionBlock`,
  `CodexWorkLogEntryBlock`, and `CommandCard` shim path
- collapsed active-turn bootstrap into shared `TranscriptPolicySupport`
  helpers so reducer, item policy, request policy, and transcript policy no
  longer each build turn state separately
- moved thread and turn start ownership to runtime notifications instead of
  synthesizing duplicate start events from controller responses
- centralized request titles and question/answer summaries so pending overlays
  and resolved transcript entries share one string owner

Scope:
- keep the structural ownership model converged as follow-up cleanup lands

### Group 4: Runtime Surface Cleanup

Status: completed on 2026-03-15

Completed items:

- removed the no-op runtime surfaces for `transport/connected` session-start
  events, `session/started`, and `turn/diff/updated`
- removed the unused session-level `latestUsageSummary` field
- removed the dead `CodexCanonicalRequestType.dynamicToolCall` request variant
- removed the dead `CodexUiBlockKind.fileChange` and
  `CodexWorkLogEntryKind.fileChange` variants
- centralized default item titles under one shared helper so runtime mapping
  and transcript projection use the same labels
- updated stale architecture and chronology docs to match the current code

Scope:
- keep runtime model surface aligned with the transcript and controller owners

## Verification

- `dart analyze` reports no errors after the current cleanup pass.
- The full test suite passed after the current cleanup pass.
- All other findings were confirmed by direct call-site tracing with `rg`.

## Remaining Findings

Status: open as of 2026-03-15

The following findings are still confirmed in the current tree.

### 1. No-op transcript renderer fork in root policy

Files:

- `lib/src/features/chat/presentation/chat_root_region_policy.dart`
- `lib/src/features/chat/presentation/chat_root_renderer_delegate.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `test/chat_root_adapter_test.dart`

Why it is residue:

- `ChatRootRegionPolicy` and `ChatRootRegionRenderer` model both `flutter` and
  `cupertino` transcript renderers
- `ChatRootRendererDelegate.buildTranscriptRegion(...)` routes both enum values
  to the same `FlutterChatTranscriptRegion`
- `ChatRootAdapter.regionPolicy` exists largely to let tests override selection
  around this seam

Why it matters:

- it presents a second transcript renderer path that does not exist
- it adds policy surface and test scaffolding without adding real runtime
  behavior

### 2. Large duplicated settings renderer fork

Files:

- `lib/src/features/settings/presentation/connection_sheet.dart`
- `lib/src/features/settings/presentation/cupertino_connection_sheet.dart`

Why it is residue:

- the Material and Cupertino settings renderers duplicate the same section
  order, field iteration, auth-field loops, toggle iteration, footer actions,
  keyboard-type mapping, auth icon mapping, and local `_Section` widget role
- only control primitives and styling differ materially
- recent drift already caused a real bug: the Cupertino path lacked its own
  text-style host and inherited `MaterialApp`'s fallback error
  `DefaultTextStyle`

Why it matters:

- behavior can diverge between renderers even when the shared
  `ConnectionSettingsHost` contract is stable
- the duplication obscures which parts are renderer-specific and which are
  shared form structure

### 3. Facade-only renderer and overlay vocabulary

Files:

- `lib/src/features/chat/presentation/chat_root_overlay_delegate.dart`
- `lib/src/features/chat/presentation/chat_root_renderer_delegate.dart`
- `lib/src/features/settings/presentation/connection_settings_renderer.dart`
- `lib/src/features/chat/presentation/chat_root_region_policy.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`

Why it is residue:

- there is one production `ChatRootOverlayDelegate` implementation and one
  production `ChatRootRendererDelegate` implementation
- `ConnectionSettingsRenderer` and `ChatTransientFeedbackRenderer` are thin
  translation enums layered on top of `ChatRootRegionRenderer`
- the adapter maps region policy into these extra enums before calling the
  delegates

Why it matters:

- there are multiple renderer vocabularies for the same two runtime variants
- this adds translation seams that are mostly facades today rather than true
  independently-owned abstractions

### 4. Real backwards-compat storage migration still in hot path

File:

- `lib/src/core/storage/codex_profile_store.dart`

Why it is compatibility code:

- profile load/save still carries legacy preference keys, legacy secure-storage
  keys, and `SharedPreferences` to `SharedPreferencesAsync` migration logic
- the implementation is converging rather than permanently dual-writing, but
  the compatibility path still executes in the runtime storage layer

Why it matters:

- if the migration window is closed, this is now permanent compatibility
  residue
- if the migration window is still open, it should stay documented as active
  backwards-compat code rather than being treated as “cleaned up”

### 5. Legacy app-server request rejection branch

File:

- `lib/src/features/chat/application/chat_session_controller.dart`

Why it is compatibility code:

- `_handleUnsupportedHostRequest(...)` still carries a dedicated branch for the
  legacy `item/fileRead/requestApproval` method

Why it matters:

- if the transport contract is fully cut over, this is leftover compatibility
  behavior
- if the transport still emits that method in the field, it is active
  backwards-compat code and should stay categorized as such
