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

### Group 2: Medium Cleanups

Status: completed on 2026-03-15

Completed items:

- replaced permanent legacy-key fallback with a converging migration that
  copies legacy profile and secret keys forward, then removes the legacy keys
- removed the dead `skipGitRepoCheck` setting from the profile model and
  settings UI
- removed unused `CodexAppServerClient` facade methods
  `resolvePermissionsRequest(...)` and `sendServerResult(...)`
- removed unused `latestUsageSummary` from `CodexActiveTurnState`
- removed the write-only active-turn fields `turnDiffSnapshot`, `hasWork`,
  and `hasReasoning`
- removed the dead auth-refresh response API from the app-server client and
  request layer
- removed legacy file-read approval resolution support so transport behavior
  matches the controller's rejection-only handling
- updated `README.md` to reflect the current app-server-only architecture
- updated `docs/pre-phase-5-infrastructure-plan.md` so its frozen public
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

## Verification

- `dart analyze` reports no errors after the current cleanup pass.
- The full test suite passed after the current cleanup pass.
- All other findings were confirmed by direct call-site tracing with `rg`.

## Remaining Findings

No confirmed remaining findings from this audit as of 2026-03-15.
