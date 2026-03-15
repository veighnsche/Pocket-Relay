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

Status: pending

Scope:

- replace permanent legacy fallback with a converging profile migration
- remove dead settings and dead facade surface
- trim write-only state that no longer affects runtime behavior
- repair stale repo documentation

### Group 3: Structural Refactors

Status: pending

Scope:

- remove the dead pre-artifact transcript path and its leftover UI shims
- collapse duplicate active-turn bootstrap ownership
- unify startup lifecycle handling so response and notification paths do not
  both own turn/thread starts
- centralize request presentation strings

## Verification

- `dart analyze` reports no errors after the Group 1 cleanup batch.
- The full test suite passed after the Group 1 cleanup batch.
- All other findings were confirmed by direct call-site tracing with `rg`.

## Remaining Findings

### High

#### 1. Permanent legacy-key fallback instead of a converging migration

The profile store still reads old `codex_pocket.*` keys on every load instead of
performing a one-time migration and retiring the old keys.

Evidence:

- [`lib/src/core/storage/codex_profile_store.dart`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L40)
- [`lib/src/core/storage/codex_profile_store.dart`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L72)
- [`test/codex_profile_store_test.dart`](/home/vince/Projects/codex_pocket/test/codex_profile_store_test.dart#L57)

Why this matters:

- this is backwards-compat code that never converges
- every load keeps the legacy path alive
- tests currently lock in the legacy-key behavior

#### 2. Dead pre-artifact transcript mapping path

`TranscriptItemBlockFactory.blockFromActiveItem()` is not used by the shipped
runtime path. Production item projection now goes through turn artifacts and
artifact projection instead.

Evidence:

- [`lib/src/features/chat/application/transcript_item_block_factory.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_block_factory.dart#L14)
- [`test/transcript_item_block_factory_test.dart`](/home/vince/Projects/codex_pocket/test/transcript_item_block_factory_test.dart#L12)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart#L428)
- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart#L19)
- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L243)

Why this matters:

- the app still carries a full alternate item-to-UI mapping path
- that path is now kept alive only by tests
- it can drift independently from runtime behavior

#### 3. Dead block types and UI shims left behind by the old transcript path

The dead `TranscriptItemBlockFactory` path is also the only place that still
produces `CodexCommandExecutionBlock` and `CodexWorkLogEntryBlock`.
`ConversationEntryCard` still contains rendering branches for those types even
though runtime projection now produces grouped work blocks.

Evidence:

- [`lib/src/features/chat/application/transcript_item_block_factory.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_block_factory.dart#L24)
- [`lib/src/features/chat/application/transcript_item_block_factory.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_block_factory.dart#L33)
- [`lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart#L51)
- [`lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart#L54)

Why this matters:

- these are compat shims for a runtime shape the app no longer emits
- the UI surface still reflects an older ownership model

#### 4. Active-turn bootstrap is duplicated in four places

The same `CodexActiveTurnState` construction and timer bootstrap logic appears
in multiple layers.

Evidence:

- [`lib/src/features/chat/application/transcript_reducer.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_reducer.dart#L66)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart#L455)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart#L374)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart#L453)

Why this matters:

- this is duplicated ownership of one lifecycle transition
- small behavior changes can now require edits in several files

### Medium

#### 5. Start lifecycle is owned by two parallel paths

The controller synthesizes `ThreadStarted` and `TurnStarted` runtime events from
request responses, while the runtime event mapper already maps the matching
server notifications.

Evidence:

- [`lib/src/features/chat/application/chat_session_controller.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L317)
- [`lib/src/features/chat/application/chat_session_controller.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L357)
- [`lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart#L70)
- [`lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart#L103)

Why this matters:

- this is a real code fork with overlapping behavior
- start-state ownership is split between transport response handling and
  notification handling

#### 6. Request presentation strings are duplicated

Pending request overlays and resolved transcript entries each define their own
request title and question-summary logic.

Evidence:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L417)
- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L434)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart#L217)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart#L234)

Why this matters:

- same product strings, two owners
- drift is easy and cleanup is harder later

#### 7. `CodexActiveTurnState` still contains write-only refactor residue

Several fields are still present in state but are not read by app code.

Fields:

- `turnDiffSnapshot`
- `hasWork`
- `hasReasoning`
- `latestUsageSummary` on `CodexActiveTurnState`

Evidence:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L721)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart#L322)
- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart#L57)

Why this matters:

- these fields still shape the model layer
- production behavior no longer depends on them
- tests currently preserve some of this state shape

#### 8. `skipGitRepoCheck` is a dead setting

The profile model and settings sheet still persist and edit
`skipGitRepoCheck`, but there is no runtime consumer in transport or SSH launch
code.

Evidence:

- [`lib/src/core/models/connection_models.dart`](/home/vince/Projects/codex_pocket/lib/src/core/models/connection_models.dart#L13)
- [`lib/src/features/settings/presentation/connection_sheet.dart`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L321)

Why this matters:

- the app exposes a setting with no actual effect
- this is dead product surface, not just dead implementation

#### 9. Auth-refresh response path is dead in the shipped app

The transport layer still implements `respondAuthTokensRefresh(...)`, but the
controller rejects auth-refresh requests as unsupported before that path can be
used.

Evidence:

- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart#L102)
- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L177)
- [`lib/src/features/chat/application/chat_session_controller.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L225)

Why this matters:

- this is facade surface with no reachable production path
- transport and controller disagree about supported behavior

#### 10. `item/fileRead/requestApproval` has split ownership

The request API still knows how to resolve file-read approvals, but the
controller treats the request as legacy and rejects it before resolution can be
used.

Evidence:

- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L201)
- [`lib/src/features/chat/application/chat_session_controller.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L249)

Why this matters:

- this is split behavior for the same protocol surface
- only the rejection path is reachable in production

#### 11. `README.md` still describes removed architecture

The README still documents the old dual-transport/services structure even
though the app-server migration document says the app is app-server-only now.

Evidence:

- [`README.md`](/home/vince/Projects/codex_pocket/README.md#L8)
- [`docs/app-server-migration-plan.md`](/home/vince/Projects/codex_pocket/docs/app-server-migration-plan.md#L5)

Why this matters:

- this is refactor residue in repo documentation
- new contributors will get the wrong architecture picture

### Low

#### 12. Unused façade APIs remain exposed

These APIs have no production callers:

- `CodexAppServerClient.resolvePermissionsRequest(...)`
- `CodexAppServerClient.sendServerResult(...)`

Evidence:

- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart#L145)
- [`lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart#L175)

Why this matters:

- these are still public-looking transport surface area without runtime use

#### 13. `TranscriptPolicySupport.hasBlockingRequest()` has no call sites

One helper remains in `TranscriptPolicySupport` with no runtime callers.

Evidence:

- [`lib/src/features/chat/application/transcript_policy_support.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy_support.dart#L53)

Why this matters:

- this is leftover helper surface that no longer carries behavior
