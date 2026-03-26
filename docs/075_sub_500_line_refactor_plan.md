# 075 Sub-500-Line Refactor Plan

## Goal

Reduce oversized Dart files into coherent ownership slices so that:

- no non-test Dart file exceeds 500 lines
- public import paths stay stable unless there is a clear product reason to change them
- private controller and presenter internals keep library privacy where it already exists
- the split reduces future churn instead of creating a second shadow structure

## Current Large Files

- `lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`
- `lib/src/features/workspace/application/connection_workspace_controller.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart`
- `lib/src/features/connection_settings/application/connection_settings_presenter_sections.dart`
- `lib/src/features/connection_settings/presentation/connection_settings_host.dart`
- `lib/src/features/chat/worklog/application/chat_work_log_item_projector_parser_read.dart`
- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`
- `lib/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart`
- `lib/src/features/workspace/application/connection_workspace_controller_catalog.dart`
- `lib/widgetbook/story_catalog.dart`
- `lib/widgetbook/support/widgetbook_fixtures.dart`
- `tool/capture_live_thread_read_fixture.dart`

## Structural Rules

- Keep `connection_workspace_controller.dart`, `connection_settings_presenter.dart`, and `connection_settings_host.dart` as the stable entry files.
- Split controller and presenter internals with `part` files when they depend on private state.
- Split public model families with `export` barrels, not by moving everything into one more giant facade.
- Keep Widgetbook downstream-only. Story registration stays thin, and fixtures stay separate from real app code.
- Treat `tool/` scripts as CLI entrypoints plus helpers, not monolith scripts.

## Target Tree

```text
lib/
  src/
    features/
      workspace/
        application/
          connection_workspace_controller.dart
          controller/
            bootstrap.dart
            reconnect.dart
            conversation_selection.dart
            app_lifecycle.dart
            delete_connection.dart
            live_bindings.dart
            catalog_storage.dart
            catalog_live_edits.dart
            model_catalogs.dart
            remote_runtime.dart
            remote_owner_actions.dart
            diagnostics.dart

      chat/
        transport/
          app_server/
            codex_app_server_models.dart
            models/
              events.dart
              thread_history.dart
              model_catalog.dart
              session.dart
              turns.dart
              inputs.dart
              transport_contracts.dart
              exceptions.dart
            codex_app_server_remote_owner_ssh.dart
            remote_owner_ssh/
              host_probe.dart
              owner_inspector.dart
              owner_control.dart
              command_builder.dart
              parsers.dart
              polling.dart
              support.dart
            testing/
              fake_codex_app_server_client.dart
              fake_client/
                session.dart
                threads.dart
                turns.dart
                requests.dart
                history.dart
                notifications.dart

        worklog/
          application/
            chat_work_log_item_projector_parser_read.dart
            parser_read/
              read_projection_models.dart
              cat_parser.dart
              sed_parser.dart
              select_object_parser.dart
              file_projection_builder.dart
              support.dart

        composer/
          presentation/
            chat_composer_surface.dart
            surface/
              editor.dart
              shortcuts.dart
              attachments.dart
              input_formatters.dart
              editing_delta.dart

      connection_settings/
        application/
          connection_settings_presenter.dart
          presenter/
            presentation_state.dart
            section_profile.dart
            section_route.dart
            section_remote_target.dart
            section_remote_server.dart
            section_authentication.dart
            section_codex.dart
            section_model.dart
            submit_payload.dart
            helper_text.dart
        presentation/
          connection_settings_host.dart
          host/
            contract_builder.dart
            field_updates.dart
            model_catalog_refresh.dart
            remote_runtime_refresh.dart
            remote_server_actions.dart
            host_models.dart

  widgetbook/
    story_catalog.dart
    stories/
      workspace_stories.dart
      connection_settings_stories.dart
      chat_screen_stories.dart
      transcript_stories.dart
      worklog_stories.dart
    support/
      widgetbook_fixtures.dart
      fixtures/
        connections.dart
        workspace.dart
        settings.dart
        transcript.dart
        worklog.dart
        runtime.dart

tool/
  capture_live_thread_read_fixture.dart
  capture_live_thread_read_fixture/
    args.dart
    codex_launch.dart
    profile_loading.dart
    preferences.dart
    thread_read_extract.dart
    json_io.dart
```

## Execution Order

1. Split `workspace/application/controller/` first.
   This is the biggest concentration of continuity ownership and the most important downstream cost reducer.
2. Split `chat/transport/app_server/remote_owner_ssh/`.
   This is the second highest-risk area because it mixes host probing, command construction, parsing, and lifecycle polling.
3. Split `connection_settings/application/presenter/`.
4. Split `connection_settings/presentation/host/`.
5. Split `chat/transport/app_server/models/`.
6. Split `chat/worklog/application/parser_read/`.
7. Split `chat/composer/presentation/surface/`.
8. Split Widgetbook story registration and fixtures.
9. Split `tool/capture_live_thread_read_fixture.dart`.
10. Split `testing/fake_client/`.

## First Slice

The first implementation slice is:

- keep `connection_workspace_controller.dart` as the stable import path
- replace the single giant lifecycle part with smaller part files under `workspace/application/controller/`
- do not change behavior
- prove the split with focused workspace tests and analysis before moving on

## Done Criteria

- every targeted file lands under 500 lines
- no new public import churn is introduced without a product reason
- the workspace continuity behavior stays unchanged during structural splits
- tests stay green after each slice, not only at the end
