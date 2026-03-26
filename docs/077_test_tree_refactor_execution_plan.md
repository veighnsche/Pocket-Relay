# Test Tree Refactor Execution Plan

## Purpose

This document turns the proposed test-tree cleanup into an implementation plan.

The goal is not a cosmetic shuffle.

The goal is to move the test suite onto a stable ownership tree that:

- mirrors real app ownership under `lib/src`
- removes the flat `test/` root as the default dumping ground
- normalizes repetitive file names
- reduces future import churn
- forces every `*_test.dart` entry file under 500 lines
- keeps feature-spanning integration tests close to the feature that owns them

This plan is complementary to:

- `docs/050_codebase_audit_and_file_tree_proposal.md`
- `docs/051_file_tree_refactor_execution_plan.md`
- `docs/075_sub_500_line_refactor_plan.md`

## Hard Rules

- Mirror app ownership first. Do not introduce top-level `unit/`, `widget/`,
  or `integration/` buckets.
- Top-level test roots are limited to:
  - `test/app/`
  - `test/core/`
  - `test/features/`
  - `test/widgetbook/`
  - `test/tool/`
  - `test/e2e/`
  - `test/support/`
- Use feature-local `integration/` directories only when a test genuinely spans
  multiple layers of the same feature.
- Keep `test/e2e/` only for opt-in environment-dependent flows.
- Drop repeated feature prefixes from filenames once the parent path already
  owns that meaning.
- Prefer `<owner>_<behavior>_test.dart` naming over broad catch-all names.
- No `*_test.dart` file may exceed 500 lines after the migration completes.
- Split oversized files by behavior seam, not by numbered fragments such as
  `_part_1_test.dart`.
- Keep helpers feature-local unless they are truly shared across features.
- Do not leave temporary duplicate wrappers in the flat root.

## Current Problem

The suite currently has 22 oversized test entry files over 500 lines:

- `test/connection_workspace_controller_test.dart` 3903 lines
- `test/codex_session_reducer_test.dart` 3350 lines
- `test/chat_session_controller_test.dart` 3245 lines
- `test/chat_screen_app_server_test.dart` 3192 lines
- `test/connection_workspace_surface_widgets_test.dart` 2768 lines
- `test/codex_ui_block_surface_test.dart` 2695 lines
- `test/chat_screen_presentation_test.dart` 2302 lines
- `test/codex_app_server_client_test.dart` 1917 lines
- `test/chat_root_adapter_test.dart` 1599 lines
- `test/connection_workspace_desktop_shell_test.dart` 1480 lines
- `test/connection_workspace_mobile_shell_test.dart` 1231 lines
- `test/codex_app_server_remote_owner_loopback_test.dart` 1211 lines
- `test/connection_settings_host_test.dart` 1004 lines
- `test/codex_app_server_remote_owner_ssh_test.dart` 927 lines
- `test/real_remote_connection_app_e2e_test.dart` 794 lines
- `test/codex_connection_repository_test.dart` 716 lines
- `test/connection_settings_presentation_test.dart` 691 lines
- `test/codex_runtime_event_mapper_test.dart` 686 lines
- `test/chat_composer_test.dart` 647 lines
- `test/chat_screen_renderer_test.dart` 575 lines
- `test/widget_test.dart` 561 lines
- `test/codex_app_server_remote_owner_blep_diagnostics_test.dart` 507 lines

This is not only a file-size problem.

It is evidence that the current test tree is still organized around broad flat
prefixes instead of stable ownership seams.

## Target Tree

```text
test/
  app/

  core/
    device/
    errors/
    platform/
    storage/

  features/
    connection_settings/
      application/
      presentation/
        host/
        overlay/

    workspace/
      application/
      domain/
      infrastructure/
      presentation/
      presentation/widgets/

    chat/
      composer/
        application/
        domain/
        presentation/
      lane/
        application/
        presentation/
        presentation/widgets/
        integration/
      lane_header/
        presentation/
      requests/
        presentation/
      runtime/
        application/
      transcript/
        application/
        domain/
        presentation/
        presentation/widgets/
        presentation/regression/
      transcript_follow/
        presentation/
      transport/
        app_server/
          testing/
          fixtures/
            thread_read/
      worklog/
        application/
        presentation/

  widgetbook/
  tool/
  e2e/
    remote/

  support/
    builders/
    fakes/
```

## Naming Normalization Rules

### Remove redundant prefixes

Examples:

- `test/pocket_error_catalog_test.dart`
  -> `test/core/errors/error_catalog_test.dart`
- `test/codex_connection_repository_test.dart`
  -> `test/core/storage/connection_repository_*.dart`
- `test/chat_lane_header_projector_test.dart`
  -> `test/features/chat/lane_header/presentation/header_projector_test.dart`
- `test/connection_workspace_state_test.dart`
  -> `test/features/workspace/domain/state_test.dart`
- `test/codex_app_server_local_process_test.dart`
  -> `test/features/chat/transport/app_server/local_process_test.dart`

### Prefer behavior-focused names

Examples:

- `widget_test.dart`
  -> `app_bootstrap_loading_test.dart`
  -> `app_catalog_bootstrap_test.dart`
  -> `app_shell_selection_test.dart`
  -> `app_settings_overlay_test.dart`
  -> `app_turn_device_integration_test.dart`
- `chat_screen_renderer_test.dart`
  -> `screen_renderer_layout_test.dart`
  -> `screen_renderer_actions_test.dart`
  -> `screen_renderer_timeline_test.dart`
- `connection_workspace_controller_test.dart`
  -> `workspace_controller_initialize_test.dart`
  -> `workspace_controller_catalog_mutations_test.dart`
  -> `workspace_controller_lane_lifecycle_test.dart`
  -> `workspace_controller_recovery_test.dart`
  -> `workspace_controller_remote_runtime_test.dart`
  -> `workspace_controller_busy_lane_guards_test.dart`

### Keep support names literal

- Put shared fakes under `test/support/fakes/`.
- Put shared builders under `test/support/builders/`.
- Do not keep feature-specific helpers under `test/support/` once they are only
  used by one feature slice.

## Migration Strategy

This migration should be done as phased structural slices, not as one giant
rename and not as random per-file cleanup.

For each phase:

1. Create only the destination directories needed for that phase.
2. Move and rename already-small files first.
3. Split oversized files next.
4. Extract local shared helpers only when two or more new files need them.
5. Run the phase verification gate before starting the next phase.
6. Do not leave temporary duplicate files in the old flat root.

The highest-risk files are intentionally later in the order.

That is the correct tradeoff.

The early phases settle naming rules, helper locations, and import patterns
before the biggest chat and workspace files are split.

## Phase 0: Scaffold And Guardrails

### Goal

Create the destination tree and stabilize helper locations before moving real
test entry files.

### Work

- Create the target directories under `test/`.
- Move shared helper and fixture locations first:
  - `test/support/fake_connection_settings_overlay_delegate.dart`
    -> `test/support/fakes/connection_settings_overlay_delegate.dart`
  - `test/fixtures/app_server/thread_read/*`
    -> `test/features/chat/transport/app_server/fixtures/thread_read/*`
- Add a report-only test-size audit command.
  Suggested shape:
  - `tool/check_test_file_sizes.dart`
  - or a `just test-size-audit` wrapper
- Do not fail CI on the 500-line rule yet.

### Why First

- Later phases need stable helper imports.
- Transport and transcript tests already share the thread-read fixtures.
- App and workspace tests already share the settings overlay fake.

### Gate

- `flutter analyze test tool`

## Phase 1: App, Core, Widgetbook, And Tool Roots

### Goal

Clear the non-feature catch-all files from the flat root first.

### Work

Move and split:

- `test/widget_test.dart`
  -> `test/app/app_bootstrap_loading_test.dart`
  -> `test/app/app_catalog_bootstrap_test.dart`
  -> `test/app/app_shell_selection_test.dart`
  -> `test/app/app_settings_overlay_test.dart`
  -> `test/app/app_turn_device_integration_test.dart`
- `test/background_grace_host_test.dart`
  -> `test/core/device/background_grace_host_test.dart`
- `test/display_wake_lock_host_test.dart`
  -> `test/core/device/display_wake_lock_host_test.dart`
- `test/foreground_service_host_test.dart`
  -> `test/core/device/foreground_service_host_test.dart`
- `test/pocket_error_catalog_test.dart`
  -> `test/core/errors/error_catalog_test.dart`
- `test/pocket_platform_behavior_test.dart`
  -> `test/core/platform/platform_behavior_test.dart`
- `test/pocket_platform_policy_test.dart`
  -> `test/core/platform/platform_policy_test.dart`
- `test/codex_connection_catalog_recovery_test.dart`
  -> `test/core/storage/connection_catalog_recovery_test.dart`
- `test/codex_connection_repository_test.dart`
  -> `test/core/storage/connection_repository_load_test.dart`
  -> `test/core/storage/connection_repository_save_test.dart`
  -> `test/core/storage/connection_repository_delete_test.dart`
- `test/codex_profile_store_test.dart`
  -> `test/core/storage/profile_store_test.dart`
- `test/connection_model_catalog_store_test.dart`
  -> `test/core/storage/model_catalog_store_test.dart`
- `test/connection_scoped_stores_test.dart`
  -> `test/core/storage/scoped_stores_test.dart`
- `test/widgetbook_app_test.dart`
  -> `test/widgetbook/catalog_app_test.dart`
- `test/capture_live_thread_read_fixture_test.dart`
  -> `test/tool/capture_thread_read_fixture_test.dart`

### Why This Order

- These files have minimal dependency on the later chat/workspace test tree.
- `widget_test.dart` is the worst non-feature junk drawer and should not remain
  in place while the rest of the tree is being cleaned up.

### Gate

- Run all files under `test/app/`
- Run all files under `test/core/`
- `flutter test test/widgetbook/catalog_app_test.dart`
- `flutter test test/tool/capture_thread_read_fixture_test.dart`

## Phase 2: `connection_settings`

### Goal

Move the connection-editor feature into its own coherent test tree before the
workspace tests continue to depend on it.

### Work

Move and split:

- `test/connection_settings_presentation_test.dart`
  -> `test/features/connection_settings/application/presenter_validation_test.dart`
  -> `test/features/connection_settings/application/presenter_modes_test.dart`
  -> `test/features/connection_settings/application/presenter_remote_runtime_test.dart`
  -> `test/features/connection_settings/application/presenter_model_catalog_test.dart`
- `test/connection_settings_host_test.dart`
  -> `test/features/connection_settings/presentation/host/host_validation_test.dart`
  -> `test/features/connection_settings/presentation/host/host_actions_test.dart`
  -> `test/features/connection_settings/presentation/host/host_remote_runtime_test.dart`
  -> `test/features/connection_settings/presentation/host/host_model_catalog_test.dart`
- `test/connection_settings_overlay_delegate_test.dart`
  -> `test/features/connection_settings/presentation/overlay/overlay_delegate_test.dart`
- `test/connection_settings_remote_runtime_probe_test.dart`
  -> `test/features/connection_settings/application/remote_runtime_probe_test.dart`

### Why This Order

- Workspace and app integration tests depend on connection settings seams.
- The feature is moderately isolated and gives the naming rules a real proving
  ground before the larger workspace and chat splits.

### Gate

- Run all files under `test/features/connection_settings/`
- Run `test/app/app_settings_overlay_test.dart`

## Phase 3: `workspace/presentation`

### Goal

Settle workspace presentation seams before touching the controller mega-file.

### Work

Move and split:

- `test/connection_workspace_conversation_history_sheet_test.dart`
  -> `test/features/workspace/presentation/conversation_history_sheet_test.dart`
- `test/connection_workspace_desktop_shell_test.dart`
  -> `test/features/workspace/presentation/desktop_shell_inventory_test.dart`
  -> `test/features/workspace/presentation/desktop_shell_conversation_history_test.dart`
  -> `test/features/workspace/presentation/desktop_shell_lane_switching_test.dart`
  -> `test/features/workspace/presentation/desktop_shell_roster_mutations_test.dart`
- `test/connection_workspace_mobile_shell_test.dart`
  -> `test/features/workspace/presentation/mobile_shell_navigation_test.dart`
  -> `test/features/workspace/presentation/mobile_shell_conversation_history_test.dart`
  -> `test/features/workspace/presentation/mobile_shell_lane_lifecycle_test.dart`
  -> `test/features/workspace/presentation/mobile_shell_roster_mutations_test.dart`
- `test/connection_workspace_surface_widgets_test.dart`
  -> `test/features/workspace/presentation/live_lane_surface_status_test.dart`
  -> `test/features/workspace/presentation/live_lane_surface_runtime_actions_test.dart`
  -> `test/features/workspace/presentation/live_lane_surface_settings_test.dart`
  -> `test/features/workspace/presentation/saved_connections_content_test.dart`
  -> `test/features/workspace/presentation/saved_connections_layout_test.dart`
- `test/workspace_app_lifecycle_host_test.dart`
  -> `test/features/workspace/presentation/widgets/app_lifecycle_host_test.dart`
- `test/workspace_turn_background_grace_host_test.dart`
  -> `test/features/workspace/presentation/widgets/turn_background_grace_host_test.dart`
- `test/workspace_turn_foreground_service_host_test.dart`
  -> `test/features/workspace/presentation/widgets/turn_foreground_service_host_test.dart`
- `test/workspace_turn_wake_lock_host_test.dart`
  -> `test/features/workspace/presentation/widgets/turn_wake_lock_host_test.dart`

### Why This Order

- The presentation surface is easier to split once the connection-settings
  dependencies already have stable paths.
- The controller split should happen only after the workspace shells and live
  lane surfaces already have settled test locations.

### Gate

- Run all files under `test/features/workspace/presentation/`

## Phase 4: `workspace/application`, `workspace/domain`, `workspace/infrastructure`

### Goal

Split the controller and the remaining workspace state/storage tests after the
presentation tree is stable.

### Work

Move and split:

- `test/connection_workspace_state_test.dart`
  -> `test/features/workspace/domain/state_test.dart`
- `test/connection_workspace_recovery_store_test.dart`
  -> `test/features/workspace/infrastructure/recovery_store_test.dart`
- `test/codex_workspace_conversation_history_repository_test.dart`
  -> `test/features/workspace/infrastructure/conversation_history_repository_test.dart`
- `test/connection_lifecycle_errors_test.dart`
  -> `test/features/workspace/application/lifecycle_errors_test.dart`
- `test/connection_workspace_controller_test.dart`
  -> `test/features/workspace/application/workspace_controller_initialize_test.dart`
  -> `test/features/workspace/application/workspace_controller_selection_test.dart`
  -> `test/features/workspace/application/workspace_controller_catalog_mutations_test.dart`
  -> `test/features/workspace/application/workspace_controller_lane_lifecycle_test.dart`
  -> `test/features/workspace/application/workspace_controller_recovery_test.dart`
  -> `test/features/workspace/application/workspace_controller_remote_runtime_test.dart`
  -> `test/features/workspace/application/workspace_controller_conversation_history_test.dart`
  -> `test/features/workspace/application/workspace_controller_busy_lane_guards_test.dart`

### Why This Order

- The controller test is the single largest file in the suite.
- Splitting it before the presentation tree settles would create repeated
  import and helper churn.

### Gate

- Run all files under `test/features/workspace/application/`
- Run all files under `test/features/workspace/domain/`
- Run all files under `test/features/workspace/infrastructure/`

## Phase 5: Small `chat` Leaf Slices

### Goal

Move the smaller chat feature seams before the larger transcript, transport,
and lane orchestration files.

### Work

Move and split:

- `test/chat_composer_image_attachment_loader_test.dart`
  -> `test/features/chat/composer/application/image_attachment_loader_test.dart`
- `test/chat_composer_test.dart`
  -> `test/features/chat/composer/domain/draft_text_elements_test.dart`
  -> `test/features/chat/composer/domain/draft_image_attachment_test.dart`
  -> `test/features/chat/composer/presentation/composer_text_sync_test.dart`
  -> `test/features/chat/composer/presentation/composer_attachment_action_test.dart`
- `test/pending_user_input_presentation_test.dart`
  -> `test/features/chat/requests/presentation/pending_user_input_presenter_test.dart`
  -> `test/features/chat/requests/presentation/pending_user_input_form_store_test.dart`
- `test/chat_lane_header_projector_test.dart`
  -> `test/features/chat/lane_header/presentation/header_projector_test.dart`
- `test/codex_runtime_event_mapper_test.dart`
  -> `test/features/chat/runtime/application/event_mapper_connection_test.dart`
  -> `test/features/chat/runtime/application/event_mapper_turns_test.dart`
  -> `test/features/chat/runtime/application/event_mapper_items_test.dart`
  -> `test/features/chat/runtime/application/event_mapper_requests_test.dart`
- `test/codex_runtime_payload_support_test.dart`
  -> `test/features/chat/runtime/application/payload_support_test.dart`

### Why This Order

- These are leaf-like slices with lower import churn than transcript or lane.
- This phase establishes the normalized naming style for chat tests before the
  biggest files are split.

### Gate

- Run all files under:
  - `test/features/chat/composer/`
  - `test/features/chat/requests/`
  - `test/features/chat/lane_header/`
  - `test/features/chat/runtime/`

## Phase 6: `chat/transport/app_server`

### Goal

Move the protocol and transport tests before the lane integration files that
depend on them.

### Work

Move and split:

- `test/codex_app_server_client_test.dart`
  -> `test/features/chat/transport/app_server/client_connect_test.dart`
  -> `test/features/chat/transport/app_server/client_session_test.dart`
  -> `test/features/chat/transport/app_server/client_threads_test.dart`
  -> `test/features/chat/transport/app_server/client_models_test.dart`
  -> `test/features/chat/transport/app_server/client_requests_test.dart`
  -> `test/features/chat/transport/app_server/client_turn_state_test.dart`
- `test/codex_app_server_connection_scoped_transport_test.dart`
  -> `test/features/chat/transport/app_server/connection_scoped_transport_test.dart`
- `test/codex_app_server_local_process_test.dart`
  -> `test/features/chat/transport/app_server/local_process_test.dart`
- `test/codex_app_server_process_launcher_test.dart`
  -> `test/features/chat/transport/app_server/process_launcher_test.dart`
- `test/codex_app_server_remote_owner_blep_diagnostics_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_blep_diagnostics_parse_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_blep_diagnostics_status_test.dart`
- `test/codex_app_server_remote_owner_blep_e2e_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_blep_e2e_test.dart`
- `test/codex_app_server_remote_owner_loopback_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_loopback_probe_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_loopback_launch_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_loopback_attach_test.dart`
- `test/codex_app_server_remote_owner_ssh_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_ssh_commands_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_ssh_host_probe_test.dart`
  -> `test/features/chat/transport/app_server/remote_owner_ssh_owner_control_test.dart`
- `test/codex_app_server_ssh_forward_test.dart`
  -> `test/features/chat/transport/app_server/ssh_forward_test.dart`
- `test/codex_app_server_ssh_process_test.dart`
  -> `test/features/chat/transport/app_server/ssh_process_test.dart`
- `test/codex_app_server_thread_read_decoder_test.dart`
  -> `test/features/chat/transport/app_server/thread_read_decoder_test.dart`
- `test/codex_app_server_thread_read_fixture_sanitizer_test.dart`
  -> `test/features/chat/transport/app_server/thread_read_fixture_sanitizer_test.dart`
- `test/codex_app_server_websocket_transport_test.dart`
  -> `test/features/chat/transport/app_server/websocket_transport_test.dart`
- `test/codex_json_rpc_codec_test.dart`
  -> `test/features/chat/transport/app_server/json_rpc_codec_test.dart`
- `test/widgetbook_fake_codex_app_server_client_test.dart`
  -> `test/features/chat/transport/app_server/testing/fake_client_thread_history_test.dart`

### Why This Order

- Lane and screen integration tests lean on the app-server client and fake
  client seams.
- The transport fixture location should already be stable from Phase 0.

### Gate

- Run all files under `test/features/chat/transport/app_server/`

## Phase 7: `chat/transcript`, `chat/worklog`, And Presentation Decomposition

### Goal

Break apart the broad transcript/worklog presentation tests before tackling the
lane orchestration layer.

### Work

Move and split:

- `test/chat_historical_conversation_restorer_test.dart`
  -> `test/features/chat/transcript/application/historical_conversation_restorer_test.dart`
- `test/codex_historical_conversation_normalizer_test.dart`
  -> `test/features/chat/transcript/application/historical_conversation_normalizer_test.dart`
- `test/transcript_changed_files_parser_test.dart`
  -> `test/features/chat/transcript/application/changed_files_parser_test.dart`
- `test/transcript_item_support_test.dart`
  -> `test/features/chat/transcript/application/item_support_test.dart`
- `test/transcript_memory_budget_test.dart`
  -> `test/features/chat/transcript/application/memory_budget_test.dart`
- `test/transcript_turn_segmenter_test.dart`
  -> `test/features/chat/transcript/application/turn_segmenter_test.dart`
- `test/transcript_anti_card_regression_test.dart`
  -> `test/features/chat/transcript/presentation/regression/anti_card_regression_test.dart`
- `test/codex_session_reducer_test.dart`
  -> `test/features/chat/transcript/application/reducer_turn_lifecycle_test.dart`
  -> `test/features/chat/transcript/application/reducer_streaming_test.dart`
  -> `test/features/chat/transcript/application/reducer_requests_test.dart`
  -> `test/features/chat/transcript/application/reducer_ssh_test.dart`
  -> `test/features/chat/transcript/application/reducer_worklog_test.dart`
  -> `test/features/chat/transcript/application/reducer_changed_files_test.dart`
  -> `test/features/chat/transcript/application/reducer_timeline_test.dart`
  -> `test/features/chat/transcript/application/reducer_workspace_registry_test.dart`
- `test/codex_ui_block_surface_test.dart`
  -> `test/features/chat/transcript/presentation/widgets/text_surface_test.dart`
  -> `test/features/chat/transcript/presentation/widgets/status_surface_test.dart`
  -> `test/features/chat/transcript/presentation/widgets/ssh_surface_test.dart`
  -> `test/features/chat/transcript/presentation/widgets/request_surface_test.dart`
  -> `test/features/chat/worklog/presentation/worklog_surface_test.dart`
  -> `test/features/chat/worklog/presentation/changed_files_surface_test.dart`
  -> `test/features/chat/transcript/presentation/widgets/completion_surface_test.dart`
- `test/chat_screen_presentation_test.dart`
  -> `test/features/chat/lane/presentation/screen_presenter_test.dart`
  -> `test/features/chat/transcript/presentation/transcript_surface_projector_test.dart`
  -> `test/features/chat/transcript/presentation/transcript_item_projector_test.dart`
  -> `test/features/chat/requests/presentation/request_projector_test.dart`
  -> `test/features/chat/transcript/presentation/pending_request_placement_projector_test.dart`
  -> `test/features/chat/transcript_follow/presentation/follow_host_test.dart`
  -> `test/features/chat/composer/presentation/draft_host_test.dart`
  -> `test/features/chat/lane/presentation/screen_effect_mapper_test.dart`

### Why This Order

- `chat_screen_presentation_test.dart` is not one ownership seam.
- `codex_ui_block_surface_test.dart` also mixes transcript, request, SSH, and
  worklog surfaces.
- Those files must be dismantled before the lane integration layer is cleaned
  up, otherwise the later phases will keep inheriting the same structural
  mistake.

### Gate

- Run all files under:
  - `test/features/chat/transcript/`
  - `test/features/chat/worklog/`
  - `test/features/chat/transcript_follow/`

## Phase 8: `chat/lane` And Feature-Level Integration

### Goal

Finish the lane orchestration and cross-surface chat integration tests after
the lower-level chat slices already have stable homes.

### Work

Move and split:

- `test/chat_conversation_recovery_policy_test.dart`
  -> `test/features/chat/lane/application/conversation_recovery_policy_test.dart`
- `test/chat_session_errors_test.dart`
  -> `test/features/chat/lane/application/session_errors_test.dart`
- `test/chat_session_controller_test.dart`
  -> `test/features/chat/lane/application/session_controller_prompt_flow_test.dart`
  -> `test/features/chat/lane/application/session_controller_draft_flow_test.dart`
  -> `test/features/chat/lane/application/session_controller_resume_test.dart`
  -> `test/features/chat/lane/application/session_controller_approval_flow_test.dart`
  -> `test/features/chat/lane/application/session_controller_user_input_flow_test.dart`
  -> `test/features/chat/lane/application/session_controller_conversation_management_test.dart`
  -> `test/features/chat/lane/application/session_controller_error_feedback_test.dart`
  -> `test/features/chat/lane/application/session_controller_history_hydration_test.dart`
- `test/chat_root_adapter_test.dart`
  -> `test/features/chat/lane/presentation/root_adapter_actions_test.dart`
  -> `test/features/chat/lane/presentation/root_adapter_effects_test.dart`
  -> `test/features/chat/lane/presentation/root_adapter_empty_state_test.dart`
  -> `test/features/chat/lane/presentation/root_adapter_rendering_test.dart`
- `test/chat_screen_renderer_test.dart`
  -> `test/features/chat/lane/presentation/widgets/screen_renderer_layout_test.dart`
  -> `test/features/chat/lane/presentation/widgets/screen_renderer_actions_test.dart`
  -> `test/features/chat/lane/presentation/widgets/screen_renderer_timeline_test.dart`
- `test/chat_screen_app_server_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_prompt_flow_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_streaming_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_child_timeline_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_worklog_rendering_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_approval_flow_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_host_requests_test.dart`
  -> `test/features/chat/lane/integration/screen_app_server_usage_and_completion_test.dart`

### Why This Order

- These files depend on transport, transcript, request, and presenter seams.
- By the time this phase starts, the lower-level chat tests should already have
  stable paths and smaller helper surfaces.

### Gate

- Run all files under `test/features/chat/lane/`

## Phase 9: `e2e` And Final Enforcement

### Goal

Land the environment-dependent test last, then flip the size rule from audit to
enforcement.

### Work

Move and split:

- `test/real_remote_connection_app_e2e_test.dart`
  -> `test/e2e/remote/remote_connection_boot_test.dart`
  -> `test/e2e/remote/remote_connection_owner_lifecycle_test.dart`
  -> `test/e2e/remote/remote_connection_live_lane_test.dart`

Then finish the migration:

- make the test-size audit fail when any `*_test.dart` exceeds 500 lines
- update `README.md`, `justfile`, and any docs that still reference old test
  paths
- confirm no test entry files remain directly under the flat `test/` root
  except support directories

### Why Last

- This file is environment-dependent and should not block the structural
  migration of the regular suite.
- The hard size gate should only be made blocking once the oversized files have
  actually been split.

### Gate

- Run the normal automated suite for the moved files
- Run the size check in failing mode
- Run the remote e2e files only in an environment configured for that flow

## Recommended Execution Order Summary

1. Create the directories, move shared support, and add a non-blocking size
   audit.
2. Clean up the app/core/widgetbook/tool roots.
3. Move and split `connection_settings`.
4. Move and split workspace presentation files.
5. Move and split workspace controller/state/storage files.
6. Move and split smaller chat leaf slices.
7. Move and split chat transport files.
8. Dismantle transcript/worklog/presentation mega-files into owner-based files.
9. Move and split lane orchestration and feature-level chat integration files.
10. Finish with remote e2e and enable the hard 500-line gate.

## Done Criteria

- The flat `test/` root no longer owns feature test entry files.
- Every moved test file lives under the feature or subsystem that owns the
  behavior.
- Repetitive prefixes such as `chat_`, `connection_workspace_`, `codex_`, and
  `pocket_` are removed where the path already carries that meaning.
- No `*_test.dart` file exceeds 500 lines.
- Feature-crossing test files such as `chat_screen_presentation_test.dart`,
  `codex_ui_block_surface_test.dart`, and `widget_test.dart` are dismantled
  into real ownership seams instead of merely renamed.
- The final suite layout reduces future churn instead of preserving the current
  flat-root ambiguity under new names.
