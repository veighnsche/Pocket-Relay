# Large File Bug Triage

This note is triage-only.

The active chat refactor plan lives in `docs/app-server-migration-plan.md`.

Phase 5 preflight planning lives in `docs/pre-phase-5-infrastructure-plan.md`.

Counts below are from the current app-server-only workspace snapshot and will drift over time.

## Primary Bug Hotspots

| LOC | File | Why it matters |
| ---: | --- | --- |
| 541 | `lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart` | The main notification switch still owns a large share of protocol normalization. Missing or incorrect mapping silently turns into bad UI behavior. |
| 508 | `lib/src/features/settings/presentation/connection_sheet.dart` | Large settings form with persistence-sensitive behavior. Touch it only when the bug is actually in configuration or settings UX. |
| 507 | `lib/src/features/chat/models/codex_runtime_event.dart` | Not the first place to patch a bug, but the runtime-event model is large enough that mistakes here can destabilize several layers at once. |
| 468 | `lib/src/features/chat/application/chat_session_controller.dart` | Session flow is now centralized here: connect/send/stop, request handling, event subscription, and failure reporting. This is the first place to inspect orchestration bugs after Phase 4. |
| 189 | `lib/src/features/chat/application/transcript_item_policy.dart` | Item lifecycle and content-delta state transitions still live here. It is no longer a large-file problem, but it remains the first place to inspect transcript-state bugs. |

## Infrastructure Note

Phase 5 split the old transport monolith into:

- `infrastructure/app_server/codex_app_server_connection.dart`
- `infrastructure/app_server/codex_app_server_request_api.dart`
- `infrastructure/app_server/codex_app_server_ssh_process.dart`
- `infrastructure/app_server/codex_json_rpc_codec.dart`

No single infrastructure file is now the dominant large-file hotspot, but transport bugs should still be treated as a cluster across those files.

## Transcript Layer Note

Phase 1 split the transcript renderer out of one 2109 LOC file into:

- `presentation/widgets/transcript/conversation_entry_card.dart`
- `presentation/widgets/transcript/cards/`
- `presentation/widgets/transcript/support/`

That layer is still a behavior hotspot, but it is no longer a single large-file hotspot.

Phase 6 split the old 1204 LOC transcript policy into:

- `application/transcript_policy.dart`
- `application/transcript_changed_files_parser.dart`
- `application/transcript_item_block_factory.dart`
- `application/transcript_item_policy.dart`
- `application/transcript_item_support.dart`
- `application/transcript_request_policy.dart`
- `application/transcript_policy_support.dart`

The transcript behavior hotspot moved, but it did not disappear. The main place to inspect transcript-state bugs is still `application/transcript_item_policy.dart`, block-shape bugs should start in `application/transcript_item_block_factory.dart`, diff/file extraction bugs should start in `application/transcript_changed_files_parser.dart`, and stream-kind or snapshot normalization bugs should start in `application/transcript_item_support.dart`.

The biggest remaining transcript file is:

- `348` `lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart`

## Usually Ignore During Bug Triage

| LOC | File | Why it is lower priority |
| ---: | --- | --- |
| 935 | `test/codex_app_server_client_test.dart` | Large, but test-only. Important for coverage, not a production bug source. |
| 705 | `macos/Runner.xcodeproj/project.pbxproj` | Generated Xcode metadata. Touch only for platform/build issues. |
| 620 | `ios/Runner.xcodeproj/project.pbxproj` | Same as macOS project metadata. |
| 578 | `pubspec.lock` | Dependency lockfile. Never a refactor target. |

## Practical Rule

When a chat bug comes in:

1. If the transcript looks wrong, start with `presentation/widgets/transcript/`, especially `transcript_list.dart`.
2. If the transcript behaves wrong, start with `application/transcript_item_policy.dart`, then `application/transcript_policy.dart`, then `application/transcript_reducer.dart`.
   If the bug is specifically about how an item becomes a UI block, check `application/transcript_item_block_factory.dart` first.
   If the bug is specifically about changed-file paths or unified diff parsing, check `application/transcript_changed_files_parser.dart` first.
3. If the app reacts to JSON incorrectly, start with `application/runtime_event_mapper_notification_mapper.dart`.
4. If requests, approvals, connection, or turn control fail, start with `application/chat_session_controller.dart`, then `infrastructure/app_server/`.
5. If the bug is about configuration or theme persistence, check `connection_sheet.dart` and the profile store.

## Next Split Candidates

The current refactor priority is:

1. `application/runtime_event_mapper_notification_mapper.dart`
2. `application/runtime_event_mapper_support.dart`
3. `application/chat_session_controller.dart`
4. `application/transcript_item_policy.dart`
5. `infrastructure/app_server/` only when the bug is clearly transport-side
