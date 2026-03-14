# App-Server Chat Refactor Plan

## Status

The app-server migration is complete enough to treat as the default architecture:

- the legacy SSH parser path is removed from the app
- the chat feature is now app-server-only
- the remaining problem is structural concentration, not transport ambiguity

This document is the active refactor plan for the post-migration codebase.

Detailed Phase 5 preflight planning and the rationale behind the infra cut live in `docs/pre-phase-5-infrastructure-plan.md`.

## Refactor Goals

This refactor is meant to stop chat-layer bug whack-a-mole.

The desired outcome is:

1. Runtime mapping is separate from transcript state changes.
2. Transcript state changes are separate from widget rendering.
3. `ChatScreen` becomes composition and binding code, not session logic.
4. Transcript cards are split by card family instead of one giant renderer.
5. Bug fixes usually land in one layer instead of three or four files.

## Non-Goals

Do not do these during the refactor:

- reintroduce the legacy SSH/event-parser path
- rewrite the app-server protocol model
- redesign the full chat UI while moving code around
- create extra micro-files unless they remove real coupling
- add compatibility shims just to preserve old imports

## Refactor Strategy

This refactor follows a hard-cut strategy:

1. Make a structural cut.
2. Let the compiler fail.
3. Repair imports, callsites, and tests immediately.
4. End the phase with `dart analyze` and passing tests.

Rules for every phase:

- no dual-path transport logic
- no legacy wrappers
- no opportunistic UI redesign in the same commit series
- size targets are secondary; ownership boundaries matter more

## Current Chat Tree

```text
lib/src/features/chat/
  application/
    chat_session_controller.dart
    runtime_event_mapper.dart
    runtime_event_mapper_notification_mapper.dart
    runtime_event_mapper_request_mapper.dart
    runtime_event_mapper_support.dart
    transcript_policy.dart
    transcript_reducer.dart
  infrastructure/
    app_server/
      codex_app_server_client.dart
      codex_app_server_connection.dart
      codex_app_server_models.dart
      codex_app_server_request_api.dart
      codex_app_server_ssh_process.dart
      codex_json_rpc_codec.dart
  models/
    codex_runtime_event.dart
    codex_session_state.dart
    codex_ui_block.dart
  presentation/
    chat_screen.dart
    widgets/
      chat_composer.dart
      empty_state.dart
      transcript/
        conversation_entry_card.dart
        transcript_list.dart
        cards/
        support/
```

## Proposed Target Tree

This is the lean target tree.

```text
lib/src/features/chat/
  models/
    codex_runtime_event.dart
    codex_session_state.dart
    codex_ui_block.dart

  application/
    chat_session_controller.dart
    transcript_reducer.dart
    transcript_policy.dart
    runtime_event_mapper.dart
    runtime_event_mapper_notification_mapper.dart
    runtime_event_mapper_request_mapper.dart
    runtime_event_mapper_support.dart

  infrastructure/
    app_server/
      codex_app_server_client.dart
      codex_app_server_connection.dart
      codex_app_server_models.dart
      codex_app_server_request_api.dart
      codex_app_server_ssh_process.dart
      codex_json_rpc_codec.dart

  presentation/
    screens/
      chat_screen.dart
    widgets/
      chat_composer.dart
      empty_state.dart
      transcript/
        conversation_entry_card.dart
        transcript_list.dart
        cards/
          assistant_message_card.dart
          user_message_card.dart
          reasoning_card.dart
          plan_update_card.dart
          proposed_plan_card.dart
          command_card.dart
          work_log_group_card.dart
          changed_files_card.dart
          approval_request_card.dart
          user_input_request_card.dart
          status_card.dart
          error_card.dart
          usage_card.dart
        support/
          conversation_card_palette.dart
          markdown_style_factory.dart
          meta_card.dart
          transcript_chips.dart
```

## Explicitly Not In The First-Wave Tree

These were in earlier proposals and are intentionally out for now:

- `scroll_follow_controller.dart`
- `codex_item_policy.dart`
- `codex_request_policy.dart`
- `codex_usage_policy.dart`
- `request_event_mapper.dart`
- `notification_event_mapper.dart`
- `item_event_mapper.dart`
- `content_delta_mapper.dart`
- `runtime_value_normalizer.dart`
- `codex_app_server_process.dart`
- `codex_app_server_requests.dart`

If we still need them later, that should be because a real boundary appears during the cut, not because the plan said so up front.

## Proposed Test Tree

The tests should mirror the real seams, not every implementation detail:

```text
test/
  features/chat/
    application/
      runtime_event_mapper_test.dart
      transcript_reducer_test.dart
      transcript_policy_test.dart
    infrastructure/
      app_server/
        codex_app_server_client_test.dart
        codex_json_rpc_codec_test.dart
    presentation/
      chat_screen_test.dart
      transcript/
        conversation_entry_card_test.dart
        cards/
          usage_card_test.dart
          work_log_group_card_test.dart
          changed_files_card_test.dart
```

The current top-level test files can move toward this layout as part of the refactor. They do not need to move before the production cuts begin.

## Phase Plan

### Phase 0: Completed Cutover

Already done:

- delete `codex_remote_event.dart`
- delete `codex_event_parser.dart`
- delete `ssh_codex_service.dart`
- remove legacy branches from the app shell and chat screen
- make the app compile and test on the app-server path only
- delete `conversation_entry.dart`

### Phase 1: Completed Transcript Rendering Split

Done:

- move transcript rendering under `presentation/widgets/transcript/`
- replace the old 2109 LOC renderer with an 89 LOC dispatcher
- extract card-family widgets into `presentation/widgets/transcript/cards/`
- extract shared palette, markdown, chip, and meta-card helpers into `presentation/widgets/transcript/support/`
- delete `conversation_entry.dart`

Result:

- card-specific rendering code no longer lives in one file
- the dispatcher owns block selection and callback wiring only

### Phase 2: Completed Transcript State Split

Done:

- replace `services/codex_session_reducer.dart` with:
  - `application/transcript_reducer.dart`
  - `application/transcript_policy.dart`
- move reducer orchestration into the thin reducer file
- move transcript behavior and block construction into the policy file
- rewire the screen and tests onto the new application layer

Result:

- the reducer is now a small event dispatch/orchestration layer
- transcript behavior can be tested without pumping `ChatScreen`
- the next state seam is now between transcript policy and runtime mapping

### Phase 3: Completed Runtime Mapping Split

Done:

- replace `services/codex_runtime_event_mapper.dart` with:
  - `application/runtime_event_mapper.dart`
  - `application/runtime_event_mapper_request_mapper.dart`
  - `application/runtime_event_mapper_notification_mapper.dart`
  - `application/runtime_event_mapper_support.dart`
- keep `CodexRuntimeEventMapper` as the stable public facade
- move request mapping, notification mapping, and pure normalization helpers behind that facade
- rewire the screen and tests onto the new application-layer path

Result:

- runtime mapping is no longer concentrated in one 1169 LOC file
- the public mapper entrypoint is now small enough to read in one pass
- request tracking stayed local to the mapper instead of leaking into `ChatScreen`
- canonical item and request normalization still live in one shared helper library

### Phase 4: Completed ChatScreen Simplification

Done:

- create `application/chat_session_controller.dart`
- create `presentation/widgets/transcript/transcript_list.dart`
- move app-server session orchestration, request handling, and reducer binding out of `chat_screen.dart`
- move scroll-follow, transcript list rendering, and pending-request tray rendering into `transcript_list.dart`
- add controller-level coverage so session flow can be tested without pumping the full screen

Result:

- `chat_screen.dart` is down to page composition, settings-sheet presentation, composer binding, and snackbars
- `chat_session_controller.dart` now owns connect/send/stop, approvals, input submission, unsupported-request handling, and event subscription
- `transcript_list.dart` owns list rendering and auto-follow behavior

### Phase 5: Completed Infrastructure Split

Done:

- move transport files from `services/` to `infrastructure/app_server/`
- keep `CodexAppServerClient` as the stable public facade
- extract `codex_app_server_connection.dart` for process lifecycle, decode loop, request tracking, inbound-request storage, and runtime pointer updates
- extract `codex_app_server_request_api.dart` for app-server method wrappers and host-request response helpers
- extract `codex_app_server_ssh_process.dart` for SSH bootstrap and concrete remote process wiring
- extract `codex_app_server_models.dart` to hold shared transport/event/process types without creating cycles
- move `codex_json_rpc_codec.dart` under the infrastructure tree
- rewire the app layer and tests onto the new infrastructure path

Result:

- `CodexAppServerClient` is now a small facade instead of a 929 LOC god file
- transport lifecycle, request APIs, SSH bootstrap, and shared transport models have explicit ownership boundaries
- the application layer still talks to one stable client surface
- `dart analyze` and the full test suite still pass after the cut

## Definition Of Done

The refactor is done when:

1. There is no legacy transport code and no dead `conversation_entry.dart`.
2. `ChatScreen` is UI composition and callback binding only.
3. Transcript rendering lives under `presentation/widgets/transcript/`.
4. Transcript behavior lives in reducer/policy code, not in widgets.
5. Runtime mapping lives in one app-server normalization layer.
6. App-server transport stays isolated from presentation logic.
7. `dart analyze` and the full test suite pass after each major phase.
