# Large File Bug Triage And Refactor Plan

This note tracks the current tracked files over 500 LOC and classifies them for bug-fix work.

The goal is not "refactor everything now." The goal is to know which large files are likely bug magnets and which ones are mostly noise while we focus on fixing behavior first.

Counts below are from the current workspace snapshot and will drift over time.

## Fix Bugs First In These Files

| LOC | File | Why it matters |
| ---: | --- | --- |
| 2109 | `lib/src/features/chat/presentation/widgets/conversation_entry_card.dart` | Huge rendering surface with many card variants, theme branches, parsing helpers, and conditional UI paths. High regression risk. |
| 1321 | `lib/src/features/chat/services/codex_session_reducer.dart` | Central transcript state machine. Small logic bugs here usually show up everywhere. |
| 1169 | `lib/src/features/chat/services/codex_runtime_event_mapper.dart` | Protocol mapping layer. Missing cases or bad normalization here turn into silent UI bugs. |
| 929 | `lib/src/features/chat/services/codex_app_server_client.dart` | Transport and request/response plumbing. Breakage here causes session, approval, and runtime failures. |
| 805 | `lib/src/features/chat/presentation/chat_screen.dart` | Top-level screen orchestration, event routing, connection flow, scroll behavior, and action handling. |
| 508 | `lib/src/features/settings/presentation/connection_sheet.dart` | Large form with persistence and validation behavior. Worth touching when a settings bug lands here. |
| 507 | `lib/src/features/chat/models/codex_runtime_event.dart` | Large protocol model surface. Not a direct bug hotspot by itself, but it is growing enough that mistakes become easier. |

## Usually Ignore During Bug Triage

| LOC | File | Why it is lower priority |
| ---: | --- | --- |
| 935 | `test/codex_app_server_client_test.dart` | Big, but test-only. Important for coverage, not a production bug source. |
| 705 | `macos/Runner.xcodeproj/project.pbxproj` | Generated Xcode project metadata. Only touch when fixing platform build/config issues. |
| 620 | `ios/Runner.xcodeproj/project.pbxproj` | Same as macOS project metadata. |
| 578 | `pubspec.lock` | Dependency lockfile. Not a refactor target. |

## Practical Rule

When a bug report comes in:

1. Check `codex_runtime_event_mapper.dart`, `codex_session_reducer.dart`, and `chat_screen.dart` first for transcript/runtime issues.
2. Check `codex_app_server_client.dart` first for connection, approval, request, or session bugs.
3. Check `conversation_entry_card.dart` first for rendering, spacing, theming, or card-specific UI bugs.
4. Only touch `project.pbxproj` files or `pubspec.lock` if the bug is explicitly platform/build/dependency related.

## Refactor Later, Not Now

When the bug backlog is calmer, the best split candidates are:

- `codex_runtime_event_mapper.dart`: split by transport type, item mapping, request mapping, and notification helpers.
- `codex_session_reducer.dart`: split reducer logic from block-construction helpers.
- `conversation_entry_card.dart`: split by card family instead of keeping every visual variant in one file.
- `codex_app_server_client.dart`: split JSON-RPC transport, request helpers, and SSH process bootstrap.

## Refactor Goals

This refactor is meant to stop bug whack-a-mole in the chat feature.

The desired outcome is:

1. Protocol parsing is separate from product decisions.
2. Transcript state changes are separate from widget construction.
3. `ChatScreen` only orchestrates UI and delegates session logic.
4. Each transcript card family lives in its own file.
5. Thread/turn/runtime behavior can be tested without pumping the full app.

## Non-Goals

Do not do these during the refactor:

- Rewrite the app-server protocol model.
- Redesign every card visually at the same time.
- Delete the legacy SSH path before the normalized interfaces exist.
- Change persisted profile/settings behavior unless required by a bug fix.

## Current Tree

Current chat feature shape:

```text
lib/src/features/chat/
  models/
    codex_remote_event.dart
    codex_runtime_event.dart
    codex_session_state.dart
    codex_ui_block.dart
    conversation_entry.dart
  presentation/
    chat_screen.dart
    widgets/
      chat_composer.dart
      conversation_entry_card.dart
      empty_state.dart
  services/
    codex_app_server_client.dart
    codex_event_parser.dart
    codex_json_rpc_codec.dart
    codex_runtime_event_mapper.dart
    codex_session_reducer.dart
    ssh_codex_service.dart
```

This is the core problem: protocol, reducer policy, screen orchestration, and all transcript rendering are all too concentrated.

## Proposed Tree

Proposed target tree for the chat feature:

```text
lib/src/features/chat/
  models/
    codex_remote_event.dart
    codex_runtime_event.dart
    codex_session_state.dart
    codex_ui_block.dart
    conversation_entry.dart

  application/
    chat_session_controller.dart
    scroll_follow_controller.dart
    reducers/
      codex_session_reducer.dart
      codex_block_factory.dart
      codex_item_policy.dart
      codex_request_policy.dart
      codex_usage_policy.dart
    mapping/
      codex_runtime_event_mapper.dart
      request_event_mapper.dart
      notification_event_mapper.dart
      item_event_mapper.dart
      content_delta_mapper.dart
      runtime_value_normalizer.dart

  infrastructure/
    app_server/
      codex_app_server_client.dart
      codex_json_rpc_codec.dart
      codex_app_server_process.dart
      codex_app_server_requests.dart
    legacy/
      codex_event_parser.dart
      ssh_codex_service.dart

  presentation/
    screens/
      chat_screen.dart
    widgets/
      chat_composer.dart
      empty_state.dart
      transcript/
        conversation_entry_card.dart
        transcript_block_builder.dart
        cards/
          assistant_message_card.dart
          user_message_card.dart
          reasoning_card.dart
          plan_update_card.dart
          proposed_plan_card.dart
          changed_files_card.dart
          command_card.dart
          work_log_group_card.dart
          approval_request_card.dart
          user_input_request_card.dart
          status_card.dart
          error_card.dart
          usage_card.dart
        support/
          conversation_card_palette.dart
          markdown_style_factory.dart
          usage_presentation.dart
          work_log_presentation.dart
```

Proposed test tree to mirror that split:

```text
test/
  features/chat/
    application/
      reducers/
        codex_session_reducer_test.dart
        codex_block_factory_test.dart
        codex_item_policy_test.dart
        codex_usage_policy_test.dart
      mapping/
        codex_runtime_event_mapper_test.dart
        request_event_mapper_test.dart
        notification_event_mapper_test.dart
        item_event_mapper_test.dart
    infrastructure/
      app_server/
        codex_app_server_client_test.dart
        codex_json_rpc_codec_test.dart
      legacy/
        codex_event_parser_test.dart
    presentation/
      chat_screen_test.dart
      transcript/
        usage_card_test.dart
        assistant_message_card_test.dart
        changed_files_card_test.dart
        work_log_group_card_test.dart
```

## Phase Plan

### Phase 0: Freeze Behavior

Before moving files:

1. Stop mixing refactors with UI behavior changes.
2. Add missing regression tests for the currently failing chat behaviors.
3. Keep all refactor commits behavior-preserving unless a bug is explicitly being fixed.

Exit criteria:

- `dart analyze` passes.
- Existing chat tests pass.
- New regressions are reproducible in tests before code moves begin.

### Phase 1: Split Transcript Rendering

Primary target:

- Break up `conversation_entry_card.dart`.

Files to create first:

- `presentation/widgets/transcript/cards/assistant_message_card.dart`
- `presentation/widgets/transcript/cards/user_message_card.dart`
- `presentation/widgets/transcript/cards/usage_card.dart`
- `presentation/widgets/transcript/cards/work_log_group_card.dart`
- `presentation/widgets/transcript/cards/approval_request_card.dart`
- `presentation/widgets/transcript/support/conversation_card_palette.dart`
- `presentation/widgets/transcript/support/usage_presentation.dart`

Rules:

- Do not change reducer behavior in this phase.
- `conversation_entry_card.dart` becomes a shallow switch/builder only.
- Move helper classes and style logic out with the card that owns them.

Exit criteria:

- `conversation_entry_card.dart` is under 300 LOC.
- Each card file stays roughly under 250 LOC unless there is a strong reason.

### Phase 2: Split Reducer Policy From Block Construction

Primary target:

- Break up `codex_session_reducer.dart`.

Files to create:

- `application/reducers/codex_block_factory.dart`
- `application/reducers/codex_item_policy.dart`
- `application/reducers/codex_request_policy.dart`
- `application/reducers/codex_usage_policy.dart`

Responsibilities:

- `codex_session_reducer.dart`: event-to-state orchestration only.
- `codex_block_factory.dart`: `CodexUiBlock` construction only.
- `codex_item_policy.dart`: dedupe, suppression, item-type behavior.
- `codex_usage_policy.dart`: usage card identity/update rules.

Rules:

- Remove presentation-specific heuristics from the reducer where possible.
- Keep all IDs and transcript ordering logic explicit and tested.

Exit criteria:

- `codex_session_reducer.dart` is under 400 LOC.
- Every suppression/dedupe rule has a dedicated test.

### Phase 3: Split Runtime Mapping

Primary target:

- Break up `codex_runtime_event_mapper.dart`.

Files to create:

- `application/mapping/request_event_mapper.dart`
- `application/mapping/notification_event_mapper.dart`
- `application/mapping/item_event_mapper.dart`
- `application/mapping/content_delta_mapper.dart`
- `application/mapping/runtime_value_normalizer.dart`

Rules:

- Protocol normalization must not decide UI placement.
- Unknown protocol inputs should fail predictably and be easy to test.
- Item-type canonicalization should live in one place only.

Exit criteria:

- `codex_runtime_event_mapper.dart` is mostly composition glue.
- Notification, request, and item mapping can be tested independently.

### Phase 4: Simplify ChatScreen

Primary target:

- Pull orchestration out of `chat_screen.dart`.

Files to create:

- `application/chat_session_controller.dart`
- `application/scroll_follow_controller.dart`

Responsibilities:

- `chat_session_controller.dart`: connect/send/stop/approval/input actions.
- `scroll_follow_controller.dart`: auto-follow policy and scroll thresholds.
- `chat_screen.dart`: compose widgets, bind callbacks, render screen sections.

Rules:

- No protocol switch statements in `chat_screen.dart`.
- No reducer policy in widget state.
- No transcript business rules in scroll code.

Exit criteria:

- `chat_screen.dart` is under 300 LOC.
- Chat screen widget tests no longer need to cover every reducer branch.

### Phase 5: Isolate Infrastructure

Primary target:

- Break up `codex_app_server_client.dart`.

Files to create:

- `infrastructure/app_server/codex_app_server_process.dart`
- `infrastructure/app_server/codex_app_server_requests.dart`
- `infrastructure/app_server/codex_json_rpc_codec.dart`

Rules:

- Transport I/O, request encoding, and business commands must be separate.
- SSH process launch details should not be mixed with JSON-RPC request logic.

Exit criteria:

- `codex_app_server_client.dart` becomes a coordination facade.
- JSON-RPC tests do not need to instantiate the higher-level client.

### Phase 6: Decide Legacy Path Strategy

Primary target:

- Either isolate legacy SSH mode behind the same normalized interface or delete it.

Decision rule:

- If legacy SSH mode is still required, keep it under `infrastructure/legacy/`.
- If it is not required, remove it only after the app-server path is stable and fully covered.

Rules:

- No duplicate transcript business rules between legacy and app-server code.
- Legacy path must emit the same normalized runtime events or be removed.

## Priority Order

Do the refactor in this order:

1. Transcript rendering split.
2. Reducer split.
3. Runtime mapper split.
4. Chat screen orchestration split.
5. App-server client split.
6. Legacy path decision.

This order matters because rendering and reducer coupling are the current biggest bug multipliers.

## Guard Rails

During the refactor:

- One phase per branch or commit series.
- No “while I’m here” UI tweaks in refactor commits.
- No protocol shape changes without tests first.
- If a phase causes new UI regressions, stop and restore behavior before continuing.

## Definition Of Done

The refactor is done when:

1. No chat-layer production file is over roughly 400 LOC, except model unions where justified.
2. `ChatScreen` is UI composition only.
3. Runtime mapping, reducer policy, and transcript rendering are in separate folders.
4. Thread token usage, approvals, reasoning, streaming assistant text, and scroll-follow behavior all have focused regression tests.
5. New chat bugs can usually be fixed in one layer instead of touching three or four files at once.
