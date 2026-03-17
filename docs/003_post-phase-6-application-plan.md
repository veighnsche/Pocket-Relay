# Post-Phase-6 Application Refactor Plan

This is a follow-on cleanup plan for the remaining app-layer hotspots after the
main chat refactor completed.

Scope is intentionally limited to:

- `lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart`
- `lib/src/features/chat/application/runtime_event_mapper_support.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`

It does not reopen the transcript, transport, or settings refactors unless a
required seam forces a small callsite adjustment.

## Why These Files Are Next

### `runtime_event_mapper_notification_mapper.dart`

This file still concentrates several unrelated responsibilities:

- notification dispatch
- session/thread/turn mapping
- item lifecycle/update mapping
- content-delta mapping
- warning/error/status mapping
- request-resolution cleanup against pending request state

The core problem is not only size. The main issue is that one switch owns
multiple protocol domains, so small protocol changes still land in one dense
place.

### `runtime_event_mapper_support.dart`

This file is now an unstructured bag of:

- raw value readers
- whitespace-sensitive string extraction
- item/request/thread/turn normalization
- request token decoding
- plan/question/answer decoding
- token-usage message formatting

The risk here is hidden coupling. Notification mapping and request mapping both
depend on helpers from this file, but the helpers do not have clear ownership
groups yet.

### `chat_session_controller.dart`

This file still mixes:

- persisted profile loading
- connection settings application
- prompt send flow
- thread/session ensure logic
- stop/approval/input actions
- app-server event subscription and runtime-event application
- unsupported host request rejection
- transport failure reporting and snackbar feedback

It is smaller than the old screen/controller god object, but it is still the
main orchestration hotspot in the application layer.

## Refactor Goals

1. Remove hidden coupling created by the runtime mapper `part` layout.
2. Split notification mapping by protocol domain, not by arbitrary LOC slices.
3. Reduce `ChatSessionController` to a `ChangeNotifier` facade over explicit
   flow helpers.
4. Preserve the public surfaces of `CodexRuntimeEventMapper` and
   `ChatSessionController` while the cuts happen.
5. Expand focused tests where today only integration coverage exists.

## Non-Goals

Do not do these as part of this plan:

- UI redesign
- transport or SSH bootstrap changes
- runtime model/schema redesign
- settings-sheet refactor
- moving every application file into subdirectories just for aesthetics

## Guard Rails

- Keep `CodexRuntimeEventMapper.mapEvent()` stable until the runtime mapper
  split is complete.
- Keep `ChatSessionController` public methods and getters stable during the
  controller split.
- Prefer small imported collaborators over more `part` files.
- Do not mix behavioral bug fixes with structural moves unless a seam cut
  exposes an existing bug that blocks the build or tests.
- End each subphase with `dart analyze` and green tests.

## Current Test Situation

### Runtime mapper

Coverage is broad but mostly concentrated in:

- `test/codex_runtime_event_mapper_test.dart`

This is good protection for behavior, but it is not grouped by protocol domain
yet, so refactoring will still be somewhat clumsy.

### Controller

Dedicated controller coverage is thin:

- `test/chat_session_controller_test.dart`

There is additional behavior coverage through:

- `test/chat_screen_app_server_test.dart`

That means the controller can be refactored safely, but only if dedicated
controller tests are expanded before or alongside each structural cut.

## Proposed Target Tree

Keep the current flat `application/` tree, but give the remaining hotspots real
ownership boundaries:

```text
lib/src/features/chat/application/
  runtime_event_mapper.dart
  runtime_event_mapper_request_mapper.dart
  runtime_event_mapper_notification_mapper.dart
  runtime_event_mapper_notification_session_mapper.dart
  runtime_event_mapper_notification_item_mapper.dart
  runtime_event_mapper_notification_misc_mapper.dart
  runtime_event_mapper_protocol_normalizer.dart
  runtime_event_mapper_payload_decoders.dart
  runtime_event_mapper_value_reader.dart

  chat_session_controller.dart
  chat_session_connection_flow.dart
  chat_session_request_actions.dart
  chat_session_event_bridge.dart
  chat_session_feedback.dart

  transcript_*.dart
```

Notes:

- `runtime_event_mapper_notification_misc_mapper.dart` is the bucket for warning, error,
  status, and request-resolution notifications. Only split it further if it
  stays too large after the first cut.
- `chat_session_controller.dart` remains the public `ChangeNotifier` facade.
- Existing transcript files stay as they are.

## Ownership Boundaries

### Runtime value reader

Own only raw decoding primitives:

- `asObject`
- `asList`
- `asString`
- `asInt`
- `asDouble`
- string candidate helpers

This file must not know anything about Codex protocol semantics.

### Runtime protocol normalizer

Own protocol meaning and canonical mapping:

- canonical item type normalization
- type-string normalization
- item title/detail extraction
- request type mapping
- thread/turn/item status normalization
- content stream-kind normalization

This file may know protocol semantics, but it should not build runtime events.

### Runtime payload decoders

Own structured payload decoding:

- turn usage decoding
- plan step decoding
- user-input question decoding
- user-input answer decoding
- request token decoding
- thread token usage formatting

This file should return typed values, not runtime events.

### Runtime notification mappers

Own event construction only:

- session/thread notifications
- turn notifications
- item/update/delta notifications
- misc notifications like warnings, errors, status, and request resolution

These files should depend on value readers, normalizers, and decoders, but not
reimplement them.

### Chat session connection flow

Own:

- initialize/load profile
- apply connection settings
- ensure connected
- ensure thread/session

### Chat session request actions

Own:

- approval resolve
- user-input submission
- unsupported host request rejection
- elicitation content shaping

### Chat session event bridge

Own:

- app-server event subscription callback handling
- unsupported request interception
- runtime event mapping/application

### Chat session feedback

Own:

- profile validation for send
- transport failure reporting
- snackbar emission safety

## Phase Plan

### Phase 7A: Runtime Support Decomposition

Goal:

- eliminate the current support-file grab bag

Cut:

- extract raw readers into `runtime_event_mapper_value_reader.dart`
- extract protocol normalization into
  `runtime_event_mapper_protocol_normalizer.dart`
- extract typed decoders into `runtime_event_mapper_payload_decoders.dart`
- keep `runtime_event_mapper.dart` public API unchanged

Important detail:

- this is the phase where the runtime mapper should stop depending on file-local
  `part` globals for helper access

Validation:

- `dart analyze`
- `test/codex_runtime_event_mapper_test.dart`
- full `flutter test`

### Phase 7B: Notification Mapper Domain Split

Goal:

- replace the single giant notification switch with domain-owned mappers

Cut:

- keep `runtime_event_mapper_notification_mapper.dart` as the dispatcher
- move session/thread notifications into
  `runtime_event_mapper_notification_session_mapper.dart`
- move turn notifications into the same file unless they prove large enough to
  justify their own file
- move item lifecycle/update/delta handling into
  `runtime_event_mapper_notification_item_mapper.dart`
- move request resolution, warnings, errors, deprecations, and token-usage
  status notifications into
  `runtime_event_mapper_notification_misc_mapper.dart`

Pending-request ownership:

- `_PendingRequestInfo` remains owned by `CodexRuntimeEventMapper`
- request and notification mappers receive the pending-request map explicitly
- no hidden shared mutable state outside the facade

Validation:

- split `test/codex_runtime_event_mapper_test.dart` by domain when helpful
- keep existing high-level mapper tests green
- full `flutter test`

### Phase 7C: Runtime Mapper Cleanup

Goal:

- finish the runtime mapper cleanup without changing behavior

Cut:

- remove obsolete `part` usage if imported collaborators are now sufficient
- rename files if necessary to match their actual responsibility
- keep `runtime_event_mapper_request_mapper.dart` aligned with the new helper
  layout

Definition of done for the runtime mapper cluster:

- no domain logic trapped in `runtime_event_mapper_support.dart`
- no 500+ LOC notification mapper
- `CodexRuntimeEventMapper` is a small facade over request and notification
  mapping collaborators

### Phase 8A: Controller Coverage Expansion

Goal:

- make the controller safe to split without relying mostly on screen tests

Add focused controller tests for:

- `initialize()`
- `applyConnectionSettings()`
- prompt validation for each auth mode
- `stopActiveTurn()`
- `approveRequest()` / `denyRequest()`
- `submitUserInput()` for normal input and MCP elicitation
- unsupported host request rejection
- transport failure reporting
- disposal guards

Validation:

- `dart analyze`
- controller tests
- `test/chat_screen_app_server_test.dart`
- full `flutter test`

### Phase 8B: Controller Flow Split

Goal:

- reduce `ChatSessionController` to public API, state exposure, and notifier
  ownership

Cut:

- move connect/load/settings/thread logic to
  `chat_session_connection_flow.dart`
- move approval/input/unsupported-request handling to
  `chat_session_request_actions.dart`
- move mapper subscription and runtime-event application to
  `chat_session_event_bridge.dart`
- move validation, failure reporting, and snackbar emission to
  `chat_session_feedback.dart`

Important detail:

- `ChatSessionController` remains the only `ChangeNotifier`
- helpers return values or use injected callbacks; they do not own UI state

Validation:

- controller tests
- chat screen tests
- full `flutter test`

### Phase 8C: Controller Cleanup

Goal:

- finish the controller split cleanly

Cut:

- remove leftover duplicate helpers from the controller
- ensure helpers have explicit ownership and no cyclic dependencies
- keep the controller under roughly 200-250 LOC if the cut is coherent

Definition of done for the controller cluster:

- connection flow, request flow, runtime bridge, and feedback are isolated
- unsupported host request logic is no longer buried inside the main controller
- controller tests cover real public behavior, not helper internals

## Recommended Execution Order

1. `runtime_event_mapper_support.dart`
2. `runtime_event_mapper_notification_mapper.dart`
3. `chat_session_controller.dart`

Reason:

- the runtime mapper is the largest remaining application hotspot
- the controller depends on runtime mapping behavior being stable
- controller refactors are easier once event boundaries are cleaner

## Stop Conditions

Stop and reassess if:

- a split only moves switch arms around without creating a real boundary
- new helper files still need the same private globals via `part`
- controller helpers start owning notifier state or directly calling
  `notifyListeners`
- more than one application layer is being behavior-changed in the same cut

## Definition Of Done

This follow-on cleanup is done when:

1. `runtime_event_mapper_notification_mapper.dart` is no longer the dominant
   protocol hotspot.
2. `runtime_event_mapper_support.dart` is replaced by explicit helper files with
   clear ownership.
3. `ChatSessionController` is a notifier facade, not the place where every flow
   is implemented.
4. The current integration tests still pass.
5. Dedicated runtime-mapper and controller tests cover the new seams.
