# Large File Bug Triage

This note is triage-only.

The active chat refactor plan lives in `docs/app-server-migration-plan.md`.

Counts below are from the current app-server-only workspace snapshot and will drift over time.

## Primary Bug Hotspots

| LOC | File | Why it matters |
| ---: | --- | --- |
| 2109 | `lib/src/features/chat/presentation/widgets/conversation_entry_card.dart` | The transcript renderer is still the biggest bug magnet: card selection, markdown rendering, theming, spacing, compact layouts, and card-specific helpers all live together. |
| 1169 | `lib/src/features/chat/services/codex_runtime_event_mapper.dart` | Raw app-server notifications and requests are normalized here. Missing or incorrect mapping silently turns into bad UI behavior. |
| 1162 | `lib/src/features/chat/services/codex_session_reducer.dart` | Transcript ordering, dedupe, suppression, work-log grouping, live streaming, and request state all flow through this reducer. |
| 929 | `lib/src/features/chat/services/codex_app_server_client.dart` | This is the transport boundary: SSH process startup, JSON-RPC request flow, request tracking, and runtime pointer updates. |
| 724 | `lib/src/features/chat/presentation/chat_screen.dart` | The screen still owns too much orchestration: connect/send/stop, event subscription, scroll-follow, status handling, and settings reconnect flow. |
| 508 | `lib/src/features/settings/presentation/connection_sheet.dart` | Large settings form with persistence-sensitive behavior. Touch it only when the bug is actually in configuration or settings UX. |
| 507 | `lib/src/features/chat/models/codex_runtime_event.dart` | Not the first place to patch a bug, but the runtime-event model is large enough that mistakes here can destabilize several layers at once. |

## Usually Ignore During Bug Triage

| LOC | File | Why it is lower priority |
| ---: | --- | --- |
| 935 | `test/codex_app_server_client_test.dart` | Large, but test-only. Important for coverage, not a production bug source. |
| 705 | `macos/Runner.xcodeproj/project.pbxproj` | Generated Xcode metadata. Touch only for platform/build issues. |
| 620 | `ios/Runner.xcodeproj/project.pbxproj` | Same as macOS project metadata. |
| 578 | `pubspec.lock` | Dependency lockfile. Never a refactor target. |

## Dead Weight To Delete Soon

These are not 500+ LOC files, but they should not survive the refactor:

- `lib/src/features/chat/models/conversation_entry.dart`

That model no longer participates in the app-server path and appears to be orphaned after the legacy transport removal.

## Practical Rule

When a chat bug comes in:

1. If the transcript looks wrong, start with `conversation_entry_card.dart`, then `chat_screen.dart`.
2. If the transcript behaves wrong, start with `codex_session_reducer.dart`.
3. If the app reacts to JSON incorrectly, start with `codex_runtime_event_mapper.dart`.
4. If requests, approvals, connection, or turn control fail, start with `codex_app_server_client.dart`.
5. If the bug is about configuration or theme persistence, check `connection_sheet.dart` and the profile store.

## Next Split Candidates

The current refactor priority is:

1. `conversation_entry_card.dart`
2. `codex_session_reducer.dart`
3. `codex_runtime_event_mapper.dart`
4. `chat_screen.dart`
5. `codex_app_server_client.dart` if it is still too large after the upper layers are cut apart
