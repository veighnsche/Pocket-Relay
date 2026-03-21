# Large Dart File Inventory

Generated on 2026-03-21.

This inventory lists tracked Dart files in the repository whose line count is
greater than 500.

## Method

- Input set: `git ls-files`
- Ownership filter: tracked `*.dart` files only
- Generated-file filter: excluded common generated Dart naming patterns such as
  `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `*.mocks.dart`, and
  `*.mock.dart`
- Count method: `wc -l`
- Result: no generated Dart files matched the exclusion filter

## Summary

- 30 tracked Dart files exceed 500 lines
- 18 files are under `lib/`
- 11 files are under `test/`
- 1 file is under `tool/`

## Inventory

| Lines | Path |
| ---: | --- |
| 3216 | `test/codex_session_reducer_test.dart` |
| 2831 | `test/chat_screen_app_server_test.dart` |
| 2625 | `lib/src/features/chat/presentation/chat_work_log_item_projector.dart` |
| 2139 | `test/codex_ui_block_card_test.dart` |
| 1609 | `test/chat_screen_presentation_test.dart` |
| 1232 | `test/chat_session_controller_test.dart` |
| 1225 | `test/codex_app_server_client_test.dart` |
| 1095 | `lib/src/features/chat/models/codex_session_state.dart` |
| 1057 | `lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart` |
| 1025 | `lib/src/features/chat/application/chat_session_controller.dart` |
| 945 | `test/connection_workspace_controller_test.dart` |
| 903 | `lib/src/features/chat/application/transcript_reducer.dart` |
| 880 | `test/connection_workspace_mobile_shell_test.dart` |
| 845 | `test/connection_workspace_desktop_shell_test.dart` |
| 751 | `lib/src/features/chat/application/transcript_policy.dart` |
| 729 | `lib/src/features/chat/models/codex_runtime_event.dart` |
| 674 | `lib/src/features/chat/application/transcript_request_policy.dart` |
| 668 | `test/chat_root_adapter_test.dart` |
| 633 | `lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart` |
| 632 | `lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart` |
| 617 | `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart` |
| 615 | `test/codex_runtime_event_mapper_test.dart` |
| 587 | `lib/src/features/chat/application/transcript_changed_files_parser.dart` |
| 585 | `lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart` |
| 582 | `lib/src/features/workspace/presentation/connection_workspace_controller.dart` |
| 541 | `lib/src/features/chat/models/codex_ui_block.dart` |
| 540 | `lib/widgetbook/story_catalog.dart` |
| 536 | `tool/capture_live_thread_read_fixture.dart` |
| 525 | `lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart` |
| 516 | `lib/src/features/chat/presentation/chat_work_log_contract.dart` |
