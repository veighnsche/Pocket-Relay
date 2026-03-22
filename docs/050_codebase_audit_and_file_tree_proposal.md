# Codebase Audit And File Tree Proposal

## Baseline

This document is a fresh audit after the reflector cleanup work completed
through:

- controller thread-transition consolidation
- app-server request helper extraction
- shared fake app-server client
- persistence/legacy cleanup
- transcript reset-path consolidation
- work-log classifier normalization

The audit below is based on the current post-refactor `master` baseline.

## Current Structural Findings

### 1. `chat` is still too wide for one feature root

The current `chat` feature contains all of these in one broad tree:

- app-server transport and protocol code
- runtime/event mapping
- transcript domain and projection logic
- lane/session controller logic
- composer state
- request/approval/user-input flows
- work-log classification
- transcript rendering widgets

This is the single biggest file-tree problem in the repo.

Evidence:

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/presentation/chat_work_log_item_projector.dart`
- `lib/src/features/chat/presentation/widgets/transcript/...`
- `lib/src/features/chat/infrastructure/app_server/...`

The issue is not just file count. It is that one feature folder currently means:

- protocol/runtime ingestion
- product state management
- screen composition
- transcript semantics
- tool-call presentation

That makes the directory too semantically overloaded.

### 2. File-size hotspots still point to unresolved subdomain boundaries

The largest files in `lib/src` are concentrated in `chat`:

- `chat_work_log_item_projector.dart` ~2700 lines
- `chat_session_controller.dart` ~1200 lines
- `codex_session_state.dart` ~1100 lines
- `transcript_reducer.dart` ~900 lines
- `transcript_policy.dart` ~750 lines
- `codex_runtime_event.dart` ~700 lines
- `work_log_group_card.dart` ~700 lines
- `codex_app_server_request_api.dart` ~600 lines

This is a boundary problem, not just a style problem.

The tree is still telling us that these subdomains should exist as first-class
ownership areas:

- session/lane orchestration
- transcript domain
- runtime event mapping
- work-log/tool activity
- app-server protocol

### 3. `workspace` is acting as both app shell and connection domain

`workspace` currently mixes:

- workspace state and controller behavior
- desktop/mobile shell decisions
- conversation history surfacing
- dormant/live lane switching

The controller and shells are coherent product surfaces, but the tree does not
separate:

- workspace shell/app-level navigation
- connection catalog management
- live lane hosting

Key files:

- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`
- `lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart`
- `lib/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart`
- `lib/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart`

### 4. `settings` is presentation-only and under-modeled as a feature

`settings` currently exists almost entirely as a presentation seam:

- contract
- draft
- host
- presenter
- overlay delegate
- sheet surface

That works for now, but it means the file tree treats settings as “UI for a
thing” rather than a domain with:

- editable connection configuration state
- validation
- mutation lifecycle
- overlay/sheet presentation

This is not as urgent as `chat`, but it is part of the same architectural
pattern.

### 5. `app.dart` still owns too much composition glue

`PocketRelayApp` still wires:

- repositories
- conversation state store
- lane binding creation
- app-server client ownership
- platform-specific shell selection
- wake-lock host

This is not wrong, but it is too much app composition logic for one file.

It suggests a missing app composition root around:

- dependency graph
- workspace bootstrap
- renderer/shell selection

### 6. Tests mirror the current width problem

The largest test files are also clustered around the same overloaded areas:

- `codex_session_reducer_test.dart`
- `chat_screen_app_server_test.dart`
- `codex_ui_block_card_test.dart`
- `chat_session_controller_test.dart`
- `chat_screen_presentation_test.dart`
- `codex_app_server_client_test.dart`

This is useful evidence that the current tree is still organized around broad
technical layers more than stable product subdomains.

## Proposed Direction

The best next file-tree is not “move files into more folders.”

The best next file-tree is:

- app composition separated from product features
- `chat` split into stable subdomains
- `workspace` reduced to workspace shell and lane coordination
- `settings` treated as a connection-editing feature instead of only a sheet
- protocol code separated from transcript/product state code

## Proposed File Tree

```text
lib/
  src/
    app/
      pocket_relay_app.dart
      pocket_relay_bootstrap.dart
      pocket_relay_dependencies.dart
      pocket_relay_router.dart
      pocket_relay_shell.dart

    core/
      device/
      platform/
      theme/
      ui/
      utils/

    storage/
      connections/
        connection_repository.dart
        connection_catalog_recovery.dart
        connection_conversation_state_store.dart
        connection_scoped_stores.dart
      profile/
        profile_store.dart
      shared_preferences/
        shared_preferences_async_migration.dart

    features/
      workspace/
        domain/
          connection_workspace_state.dart
          codex_workspace_conversation_summary.dart
        application/
          connection_workspace_controller.dart
          connection_workspace_copy.dart
        infrastructure/
          codex_workspace_conversation_history_repository.dart
        presentation/
          workspace_desktop_shell.dart
          workspace_mobile_shell.dart
          workspace_live_lane_surface.dart
          workspace_dormant_roster_content.dart
          workspace_conversation_history_sheet.dart

      connection_settings/
        domain/
          connection_settings_contract.dart
          connection_settings_draft.dart
        application/
          connection_settings_presenter.dart
        presentation/
          connection_settings_host.dart
          connection_settings_sheet_surface.dart
          connection_settings_overlay_delegate.dart
          connection_sheet.dart

      chat/
        lane/
          application/
            chat_session_controller.dart
            chat_conversation_selection_coordinator.dart
            chat_conversation_recovery_policy.dart
            chat_historical_conversation_restorer.dart
          presentation/
            connection_lane_binding.dart
            chat_root_adapter.dart
            chat_root_overlay_delegate.dart
            chat_screen_contract.dart
            chat_screen_effect.dart
            chat_screen_effect_mapper.dart
            chat_screen_presenter.dart

        transcript/
          domain/
            codex_ui_block.dart
            codex_session_state.dart
            codex_runtime_event.dart
            chat_conversation_recovery_state.dart
            chat_historical_conversation_restore_state.dart
          application/
            transcript_reducer.dart
            transcript_policy.dart
            transcript_policy_support.dart
            transcript_item_policy.dart
            transcript_item_support.dart
            transcript_item_block_factory.dart
            transcript_request_policy.dart
            transcript_turn_segmenter.dart
            transcript_changed_files_parser.dart
            codex_historical_conversation.dart
            codex_historical_conversation_normalizer.dart
          presentation/
            chat_transcript_item_contract.dart
            chat_transcript_item_projector.dart
            chat_transcript_surface_projector.dart
            chat_pending_request_placement_contract.dart
            chat_pending_request_placement_projector.dart
            widgets/
              transcript/
                ...

        runtime/
          application/
            runtime_event_mapper.dart
            runtime_event_mapper_support.dart
            runtime_event_mapper_transport_mapper.dart
            runtime_event_mapper_notification_mapper.dart
            runtime_event_mapper_request_mapper.dart
            codex_runtime_payload_support.dart

        requests/
          domain/
            codex_request_display.dart
          presentation/
            chat_request_contract.dart
            chat_request_projector.dart
            pending_user_input_contract.dart
            pending_user_input_draft.dart
            pending_user_input_form_scope.dart
            pending_user_input_presenter.dart

        composer/
          presentation/
            chat_composer.dart
            chat_composer_surface.dart
            chat_composer_draft.dart
            chat_composer_draft_host.dart

        transcript_follow/
          presentation/
            chat_transcript_follow_contract.dart
            chat_transcript_follow_host.dart

        lane_header/
          presentation/
            chat_lane_header_projector.dart

        worklog/
          domain/
            chat_work_log_contract.dart
          application/
            chat_work_log_item_projector.dart
            chat_changed_files_item_projector.dart
            chat_changed_files_contract.dart
          presentation/
            widgets/
              work_log_group_card.dart
              exec_command_card.dart
              tool_activity_card.dart
              changed_files_card.dart

        transport/
          app_server/
            codex_app_server_client.dart
            codex_app_server_connection.dart
            codex_app_server_models.dart
            codex_app_server_request_api.dart
            codex_app_server_thread_read_decoder.dart
            codex_json_rpc_codec.dart
            codex_app_server_process_launcher.dart
            codex_app_server_local_process.dart
            codex_app_server_ssh_process.dart
            testing/
              fake_codex_app_server_client.dart
```

## Why This Tree Is Better

### 1. It separates orchestration from transcript semantics

Today `chat_session_controller.dart` and transcript domain files live as peers
inside one broad `chat` layer split.

The proposed tree separates:

- lane/session orchestration
- transcript domain and reducers
- runtime mapping
- request flows
- work-log specialization

That is the most important structural change.

### 2. It stops using `presentation` as a dumping ground

Right now `chat/presentation` contains:

- adapters
- presenters
- contracts
- projectors
- lane binding
- composer state
- transcript follow logic

That is too much meaning under one folder.

The proposed tree keeps `presentation` closer to actual surface ownership and
moves other concerns into subdomains with clearer names.

### 3. It makes the app-server boundary explicit

The transport/protocol code is real infrastructure and should remain grouped,
but it should no longer visually compete with transcript/product state in the
same broad `chat` feature root.

Putting it under `chat/transport/app_server/` makes that boundary obvious.

### 4. It gives `workspace` a narrower mission

`workspace` should primarily own:

- connection catalog + live lane coordination
- shell-level layout
- conversation-history discovery surface

It should not appear to own all chat internals just because it hosts live lanes.

### 5. It sets up future extraction without immediate churn

This tree is designed so you can move in slices:

- first create subfolders and move files without behavior changes
- then split large files within each new subdomain

That reduces downstream unwind cost compared with mixing file moves and logic
rewrites in one pass.

## Recommended Migration Order

### Slice 1

Create the new `chat` subdomain folders without changing behavior:

- `lane`
- `transcript`
- `runtime`
- `requests`
- `composer`
- `worklog`
- `transport`

Move files only.

### Slice 2

Extract app composition out of `lib/src/app.dart` into:

- app bootstrap/dependencies
- app shell

### Slice 3

Retarget `workspace` into:

- domain
- application
- presentation

without changing workspace behavior.

### Slice 4

Retarget `settings` into:

- domain
- application
- presentation

### Slice 5

Only after the tree is stable, split the remaining giant files:

- `chat_work_log_item_projector.dart`
- `chat_session_controller.dart`
- `codex_session_state.dart`
- `transcript_reducer.dart`
- `transcript_policy.dart`

## What I Would Do First

The best first move is not `settings` and not `workspace`.

The best first move is:

1. create `features/chat/lane`
2. create `features/chat/transcript`
3. create `features/chat/runtime`
4. create `features/chat/worklog`
5. move files only, no behavior changes

That gives the rest of the codebase a real shape to grow into.

## Summary

The current codebase is cleaner than it was before the reflector work, but the
file tree still reflects an older broad-layer organization:

- `chat` is too wide
- `presentation` still means too many things
- app composition is too centralized in `app.dart`
- `workspace` and `settings` are still structurally narrower than the real
  product responsibilities they now carry

The proposed tree above is the best next structure because it follows the real
product/runtime boundaries that already exist in the code.
