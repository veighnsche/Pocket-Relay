# File Tree Refactor Execution Plan

## Purpose

This document turns the proposed target file tree into an execution plan for a
large, meaningful refactor.

The goal is not another small cleanup.

The goal is to move the codebase onto the proposed ownership tree in a way
that:

- preserves behavior
- minimizes repeated import churn
- avoids temporary shadow structures
- gives each migration slice a clear verification gate

This plan assumes the target structure described in:

- `docs/050_codebase_audit_and_file_tree_proposal.md`

## Refactor Strategy

This refactor should be done as a staged large migration, not as unrelated
micro-moves.

Rules for the migration:

- move files in large domain slices, not one file at a time across random areas
- keep each slice primarily move-only
- avoid behavior changes unless a move reveals a broken ownership seam
- retarget imports as part of each slice
- run broad verification after each slice
- do not create temporary duplicate wrappers unless absolutely required

## Target Tree

```text
lib/src/
  app/
  core/
  storage/
  features/
    workspace/
      domain/
      application/
      infrastructure/
      presentation/
    connection_settings/
      domain/
      application/
      presentation/
    chat/
      lane/
        application/
        presentation/
      transcript/
        domain/
        application/
        presentation/
      runtime/
        application/
      requests/
        domain/
        presentation/
      composer/
        presentation/
      transcript_follow/
        presentation/
      lane_header/
        presentation/
      worklog/
        domain/
        application/
        presentation/
      transport/
        app_server/
          testing/
```

## Migration Order

### Phase A: Create destination directories only

Create the final destination directories before moving files.

Do not move anything yet.

Why first:

- keeps later slices mechanical
- avoids repeated “mkdir + move + import” churn

## Phase B: `chat/transcript`

This is the highest-value move-only slice.

### Move map

From `lib/src/features/chat/models/`:

- `codex_ui_block.dart`
  -> `lib/src/features/chat/transcript/domain/codex_ui_block.dart`
- `codex_session_state.dart`
  -> `lib/src/features/chat/transcript/domain/codex_session_state.dart`
- `codex_runtime_event.dart`
  -> `lib/src/features/chat/transcript/domain/codex_runtime_event.dart`
- `chat_conversation_recovery_state.dart`
  -> `lib/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart`
- `chat_historical_conversation_restore_state.dart`
  -> `lib/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart`

From `lib/src/features/chat/application/`:

- `transcript_reducer.dart`
  -> `lib/src/features/chat/transcript/application/transcript_reducer.dart`
- `transcript_policy.dart`
  -> `lib/src/features/chat/transcript/application/transcript_policy.dart`
- `transcript_policy_support.dart`
  -> `lib/src/features/chat/transcript/application/transcript_policy_support.dart`
- `transcript_item_policy.dart`
  -> `lib/src/features/chat/transcript/application/transcript_item_policy.dart`
- `transcript_item_support.dart`
  -> `lib/src/features/chat/transcript/application/transcript_item_support.dart`
- `transcript_item_block_factory.dart`
  -> `lib/src/features/chat/transcript/application/transcript_item_block_factory.dart`
- `transcript_request_policy.dart`
  -> `lib/src/features/chat/transcript/application/transcript_request_policy.dart`
- `transcript_turn_segmenter.dart`
  -> `lib/src/features/chat/transcript/application/transcript_turn_segmenter.dart`
- `transcript_changed_files_parser.dart`
  -> `lib/src/features/chat/transcript/application/transcript_changed_files_parser.dart`
- `codex_historical_conversation.dart`
  -> `lib/src/features/chat/transcript/application/codex_historical_conversation.dart`
- `codex_historical_conversation_normalizer.dart`
  -> `lib/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart`
- `chat_historical_conversation_restorer.dart`
  -> `lib/src/features/chat/transcript/application/chat_historical_conversation_restorer.dart`

From `lib/src/features/chat/presentation/`:

- `chat_transcript_item_contract.dart`
  -> `lib/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart`
- `chat_transcript_item_projector.dart`
  -> `lib/src/features/chat/transcript/presentation/chat_transcript_item_projector.dart`
- `chat_transcript_surface_projector.dart`
  -> `lib/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart`
- `chat_pending_request_placement_contract.dart`
  -> `lib/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart`
- `chat_pending_request_placement_projector.dart`
  -> `lib/src/features/chat/transcript/presentation/chat_pending_request_placement_projector.dart`

From `lib/src/features/chat/presentation/widgets/transcript/`
and descendants:

- move the entire transcript widget subtree under:
  `lib/src/features/chat/transcript/presentation/widgets/transcript/`

### Verification gate

Run:

- `flutter test test/codex_session_reducer_test.dart`
- `flutter test test/chat_screen_presentation_test.dart`
- `flutter test test/codex_ui_block_card_test.dart`
- `flutter test test/chat_screen_app_server_test.dart`

### Risk

High import churn, low semantic risk if this stays move-only.

## Phase C: `chat/lane`

This slice isolates live lane/session orchestration from transcript semantics.

### Move map

From `lib/src/features/chat/application/`:

- `chat_session_controller.dart`
  -> `lib/src/features/chat/lane/application/chat_session_controller.dart`
- `chat_conversation_selection_coordinator.dart`
  -> `lib/src/features/chat/lane/application/chat_conversation_selection_coordinator.dart`
- `chat_conversation_recovery_policy.dart`
  -> `lib/src/features/chat/lane/application/chat_conversation_recovery_policy.dart`

From `lib/src/features/chat/presentation/`:

- `connection_lane_binding.dart`
  -> `lib/src/features/chat/lane/presentation/connection_lane_binding.dart`
- `chat_root_adapter.dart`
  -> `lib/src/features/chat/lane/presentation/chat_root_adapter.dart`
- `chat_root_overlay_delegate.dart`
  -> `lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart`
- `chat_screen_contract.dart`
  -> `lib/src/features/chat/lane/presentation/chat_screen_contract.dart`
- `chat_screen_effect.dart`
  -> `lib/src/features/chat/lane/presentation/chat_screen_effect.dart`
- `chat_screen_effect_mapper.dart`
  -> `lib/src/features/chat/lane/presentation/chat_screen_effect_mapper.dart`
- `chat_screen_presenter.dart`
  -> `lib/src/features/chat/lane/presentation/chat_screen_presenter.dart`
- `chat_chrome_menu_action.dart`
  -> `lib/src/features/chat/lane/presentation/chat_chrome_menu_action.dart`

From `lib/src/features/chat/presentation/widgets/`:

- `chat_app_chrome.dart`
  -> `lib/src/features/chat/lane/presentation/widgets/chat_app_chrome.dart`
- `chat_screen_shell.dart`
  -> `lib/src/features/chat/lane/presentation/widgets/chat_screen_shell.dart`
- `flutter_chat_screen_renderer.dart`
  -> `lib/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart`
- `chat_empty_state_body.dart`
  -> `lib/src/features/chat/lane/presentation/widgets/chat_empty_state_body.dart`
- `empty_state.dart`
  -> `lib/src/features/chat/lane/presentation/widgets/empty_state.dart`

### Verification gate

Run:

- `flutter test test/chat_session_controller_test.dart`
- `flutter test test/chat_root_adapter_test.dart`
- `flutter test test/chat_screen_renderer_test.dart`
- `flutter test test/chat_screen_presentation_test.dart`

### Risk

High import churn and moderate wiring risk because many app and workspace files
touch lane seams.

## Phase D: `chat/runtime`

This slice isolates runtime event ingestion and payload support.

### Move map

From `lib/src/features/chat/application/`:

- `runtime_event_mapper.dart`
  -> `lib/src/features/chat/runtime/application/runtime_event_mapper.dart`
- `runtime_event_mapper_support.dart`
  -> `lib/src/features/chat/runtime/application/runtime_event_mapper_support.dart`
- `runtime_event_mapper_transport_mapper.dart`
  -> `lib/src/features/chat/runtime/application/runtime_event_mapper_transport_mapper.dart`
- `runtime_event_mapper_notification_mapper.dart`
  -> `lib/src/features/chat/runtime/application/runtime_event_mapper_notification_mapper.dart`
- `runtime_event_mapper_request_mapper.dart`
  -> `lib/src/features/chat/runtime/application/runtime_event_mapper_request_mapper.dart`
- `codex_runtime_payload_support.dart`
  -> `lib/src/features/chat/runtime/application/codex_runtime_payload_support.dart`

### Verification gate

Run:

- `flutter test test/codex_runtime_event_mapper_test.dart`
- `flutter test test/codex_runtime_payload_support_test.dart`
- `flutter test test/codex_session_reducer_test.dart`

### Risk

Moderate import churn, lower product risk than lane/transcript.

## Phase E: `chat/requests`, `chat/composer`, `chat/transcript_follow`,
## `chat/lane_header`

This is a grouped presentation/state-support slice.

### Move map

Requests:

- `codex_request_display.dart`
  -> `lib/src/features/chat/requests/domain/codex_request_display.dart`
- `chat_request_contract.dart`
  -> `lib/src/features/chat/requests/presentation/chat_request_contract.dart`
- `chat_request_projector.dart`
  -> `lib/src/features/chat/requests/presentation/chat_request_projector.dart`
- `pending_user_input_contract.dart`
  -> `lib/src/features/chat/requests/presentation/pending_user_input_contract.dart`
- `pending_user_input_draft.dart`
  -> `lib/src/features/chat/requests/presentation/pending_user_input_draft.dart`
- `pending_user_input_form_scope.dart`
  -> `lib/src/features/chat/requests/presentation/pending_user_input_form_scope.dart`
- `pending_user_input_presenter.dart`
  -> `lib/src/features/chat/requests/presentation/pending_user_input_presenter.dart`

Composer:

- `chat_composer_draft.dart`
  -> `lib/src/features/chat/composer/presentation/chat_composer_draft.dart`
- `chat_composer_draft_host.dart`
  -> `lib/src/features/chat/composer/presentation/chat_composer_draft_host.dart`
- `widgets/chat_composer.dart`
  -> `lib/src/features/chat/composer/presentation/chat_composer.dart`
- `widgets/chat_composer_surface.dart`
  -> `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`

Transcript follow:

- `chat_transcript_follow_contract.dart`
  -> `lib/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart`
- `chat_transcript_follow_host.dart`
  -> `lib/src/features/chat/transcript_follow/presentation/chat_transcript_follow_host.dart`

Lane header:

- `chat_lane_header_projector.dart`
  -> `lib/src/features/chat/lane_header/presentation/chat_lane_header_projector.dart`

### Verification gate

Run:

- `flutter test test/chat_composer_test.dart`
- `flutter test test/pending_user_input_presentation_test.dart`
- `flutter test test/chat_screen_presentation_test.dart`
- `flutter test test/chat_root_adapter_test.dart`

### Risk

Moderate import churn, low semantic risk if kept move-only.

## Phase F: `chat/worklog`

This isolates work-log and changed-file shaping from the rest of transcript
presentation.

### Move map

From `lib/src/features/chat/presentation/`:

- `chat_work_log_contract.dart`
  -> `lib/src/features/chat/worklog/domain/chat_work_log_contract.dart`
- `chat_work_log_item_projector.dart`
  -> `lib/src/features/chat/worklog/application/chat_work_log_item_projector.dart`
- `chat_changed_files_contract.dart`
  -> `lib/src/features/chat/worklog/application/chat_changed_files_contract.dart`
- `chat_changed_files_item_projector.dart`
  -> `lib/src/features/chat/worklog/application/chat_changed_files_item_projector.dart`

From transcript widgets:

- `cards/work_log_group_card.dart`
  -> `lib/src/features/chat/worklog/presentation/widgets/work_log_group_card.dart`
- `cards/exec_command_card.dart`
  -> `lib/src/features/chat/worklog/presentation/widgets/exec_command_card.dart`
- `cards/tool_activity_card.dart`
  -> `lib/src/features/chat/worklog/presentation/widgets/tool_activity_card.dart`
- `cards/changed_files_card.dart`
  -> `lib/src/features/chat/worklog/presentation/widgets/changed_files_card.dart`

### Verification gate

Run:

- `flutter test test/codex_ui_block_card_test.dart`
- `flutter test test/chat_screen_app_server_test.dart`
- `flutter test test/transcript_changed_files_parser_test.dart`

### Risk

Moderate import churn, low-to-moderate specialization risk.

## Phase G: `chat/transport/app_server`

This is mostly a path correction so protocol code is visually separate from
product state.

### Move map

From `lib/src/features/chat/infrastructure/app_server/`:

- `codex_app_server_client.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_client.dart`
- `codex_app_server_connection.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`
- `codex_app_server_local_process.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart`
- `codex_app_server_models.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`
- `codex_app_server_process_launcher.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_process_launcher.dart`
- `codex_app_server_request_api.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_request_api.dart`
- `codex_app_server_ssh_process.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`
- `codex_app_server_thread_read_decoder.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart`
- `codex_app_server_thread_read_fixture_sanitizer.dart`
  -> `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_fixture_sanitizer.dart`
- `codex_json_rpc_codec.dart`
  -> `lib/src/features/chat/transport/app_server/codex_json_rpc_codec.dart`
- `testing/fake_codex_app_server_client.dart`
  -> `lib/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart`

### Verification gate

Run:

- `flutter test test/codex_app_server_client_test.dart`
- `flutter test test/codex_app_server_ssh_process_test.dart`
- `flutter test test/codex_json_rpc_codec_test.dart`
- `flutter test test/chat_screen_app_server_test.dart`

### Risk

High import churn, moderate test fallout, low behavioral risk.

## Phase H: `workspace` retargeting

This is the first non-chat feature reshaping slice.

### Move map

From `lib/src/features/workspace/models/`:

- `connection_workspace_state.dart`
  -> `lib/src/features/workspace/domain/connection_workspace_state.dart`
- `codex_workspace_conversation_summary.dart`
  -> `lib/src/features/workspace/domain/codex_workspace_conversation_summary.dart`

From `lib/src/features/workspace/presentation/`:

- `connection_workspace_controller.dart`
  -> `lib/src/features/workspace/application/connection_workspace_controller.dart`
- `connection_workspace_copy.dart`
  -> `lib/src/features/workspace/application/connection_workspace_copy.dart`

From `lib/src/features/workspace/presentation/widgets/`:

- `connection_workspace_desktop_shell.dart`
  -> `lib/src/features/workspace/presentation/workspace_desktop_shell.dart`
- `connection_workspace_mobile_shell.dart`
  -> `lib/src/features/workspace/presentation/workspace_mobile_shell.dart`
- `connection_workspace_live_lane_surface.dart`
  -> `lib/src/features/workspace/presentation/workspace_live_lane_surface.dart`
- `connection_workspace_dormant_roster_content.dart`
  -> `lib/src/features/workspace/presentation/workspace_dormant_roster_content.dart`
- `connection_workspace_conversation_history_sheet.dart`
  -> `lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart`

Infrastructure:

- `codex_workspace_conversation_history_repository.dart`
  -> `lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`

### Verification gate

Run:

- `flutter test test/connection_workspace_controller_test.dart`
- `flutter test test/connection_workspace_desktop_shell_test.dart`
- `flutter test test/connection_workspace_mobile_shell_test.dart`
- `flutter test test/connection_workspace_surface_widgets_test.dart`
- `flutter test test/codex_workspace_conversation_history_repository_test.dart`

### Risk

High import churn, moderate shell wiring risk.

## Phase I: `settings` -> `connection_settings`

This renames the feature to match what it actually owns.

### Move map

Rename root:

- `lib/src/features/settings`
  -> `lib/src/features/connection_settings`

Move within feature:

- `connection_settings_contract.dart`
  -> `domain/connection_settings_contract.dart`
- `connection_settings_draft.dart`
  -> `domain/connection_settings_draft.dart`
- `connection_settings_presenter.dart`
  -> `application/connection_settings_presenter.dart`
- `connection_settings_host.dart`
  -> `presentation/connection_settings_host.dart`
- `connection_settings_overlay_delegate.dart`
  -> `presentation/connection_settings_overlay_delegate.dart`
- `connection_settings_sheet_surface.dart`
  -> `presentation/connection_settings_sheet_surface.dart`
- `connection_sheet.dart`
  -> `presentation/connection_sheet.dart`

### Verification gate

Run:

- `flutter test test/connection_settings_host_test.dart`
- `flutter test test/connection_settings_presentation_test.dart`
- `flutter test test/widget_test.dart`

### Risk

Moderate import churn, lower domain risk.

## Phase J: app composition extraction

This is the last slice because it touches everything.

### New files to create

- `lib/src/app/pocket_relay_app.dart`
- `lib/src/app/pocket_relay_bootstrap.dart`
- `lib/src/app/pocket_relay_dependencies.dart`
- `lib/src/app/pocket_relay_shell.dart`

### Move plan

From current `lib/src/app.dart`:

- keep the public app entry in `pocket_relay_app.dart`
- move dependency wiring into `pocket_relay_dependencies.dart`
- move workspace-controller creation/bootstrap into
  `pocket_relay_bootstrap.dart`
- move shell selection/home rendering into `pocket_relay_shell.dart`

### Verification gate

Run:

- `flutter test test/widget_test.dart`
- `flutter test test/connection_workspace_desktop_shell_test.dart`
- `flutter test test/connection_workspace_mobile_shell_test.dart`
- one full targeted smoke sweep of:
  - `test/chat_root_adapter_test.dart`
  - `test/chat_screen_app_server_test.dart`
  - `test/connection_workspace_controller_test.dart`

### Risk

Highest app composition risk. Do this after all path/domain moves are stable.

## Testing Strategy

### After every phase

Always run:

- `dart format` on touched trees
- the phase-specific test gate

### After phases B through G

Also run one broad chat confidence sweep:

- `flutter test test/chat_session_controller_test.dart`
- `flutter test test/chat_root_adapter_test.dart`
- `flutter test test/chat_screen_app_server_test.dart`
- `flutter test test/chat_screen_presentation_test.dart`

### Final sweep after Phase J

Run:

- `flutter test`

If the full suite is too slow to use after every slice, it is still required at
the end of the campaign.

## Execution Notes

### 1. Prefer move-only commits

The cleanest history is:

- one commit per major phase
- mostly path/import changes
- behavioral edits only if forced by the move

### 2. Tests may move later

Production file moves should happen first.

Tests can stay in place initially if their names/imports are still intelligible.
If the production tree is stable afterward, a second test-tree cleanup pass can
follow.

### 3. Do not redesign Widgetbook during this migration

Widgetbook should only follow the real moved paths.

This campaign is about app-owned structure first.

### 4. Do not split giant files during the move campaign unless blocked

File splitting is a second-order cleanup.

The first campaign goal is:

- correct tree
- correct ownership
- stable imports

Then the next campaign can split the remaining oversized files within their new
homes.

## Recommended First Implementation Slice

Start with:

- Phase A
- Phase B

That gives the codebase the most important new structure immediately:

- transcript domain and transcript application logic no longer live as generic
  `chat/models` and `chat/application`
- transcript rendering gets its own real presentation root

This is the best first large move because it creates the deepest ownership win
with the least app-shell risk.
