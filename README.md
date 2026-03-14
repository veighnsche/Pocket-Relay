# Pocket Relay

Pocket Relay is a Flutter app for running remote coding sessions from your phone.
It SSHes into a developer box, runs the Codex CLI remotely, and renders the session as mobile-friendly widgets instead of a raw terminal.

## Status

The repo is currently between two transports:

- Current UI path: the app still uses `codex exec --json` through `lib/src/features/chat/services/ssh_codex_service.dart` and `lib/src/features/chat/services/codex_event_parser.dart`.
- New transport foundation: the repo now includes an SSH-backed `codex app-server --listen stdio://` client in `lib/src/features/chat/services/codex_app_server_client.dart`.
- Migration plan: the app-server migration is documented in `docs/app-server-migration-plan.md`.

That means the codebase already contains the new bidirectional transport layer, but the screen is not fully migrated onto it yet.

## Why App-Server

`codex exec --json` works for one-shot turns, but Pocket Relay needs a live client protocol so the phone can:

- stream richer turn output
- handle approvals mid-turn
- answer user-input requests mid-turn
- keep a session open instead of spawning one process per message

That is why the repo is moving toward `codex app-server`.

## Source Tree

```text
docs/
  app-server-migration-plan.md
lib/
  main.dart
  src/
    app.dart
    core/
      models/
        connection_models.dart
      storage/
        codex_profile_store.dart
      utils/
        shell_utils.dart
        thread_utils.dart
    features/
      chat/
        models/
          codex_remote_event.dart
          conversation_entry.dart
        presentation/
          chat_screen.dart
          widgets/
            chat_composer.dart
            connection_banner.dart
            conversation_entry_card.dart
            empty_state.dart
        services/
          codex_app_server_client.dart
          codex_event_parser.dart
          ssh_codex_service.dart
      settings/
        presentation/
          connection_sheet.dart
test/
  codex_app_server_client_test.dart
  codex_event_parser_test.dart
  widget_test.dart
```

## Current Architecture

Today, the app still launches one remote Codex command per turn:

```text
ChatScreen
  -> SshCodexService
  -> codex exec --json over SSH
  -> CodexEventParser
  -> ConversationEntry cards
```

The target architecture is:

```text
SSH stdio
  -> codex app-server
  -> JSON-RPC / canonical runtime events
  -> session state
  -> widgets
```

## What Works Today

- Stores SSH connection settings locally and secrets in secure storage.
- Starts or resumes remote Codex turns over SSH.
- Parses current `exec --json` output into assistant, command, status, error, and usage cards.
- Includes a tested app-server transport client as the first migration step.

## Run It

```bash
flutter pub get
flutter run
```

The remote box needs:

- a reachable SSH server
- the `codex` CLI installed
- a working Codex login on that machine

## Notes

- The current shipped UI path is still `exec --json`.
- The app-server transport is present in the repo, but not yet wired into the main chat screen.
- Existing saved profile data is preserved under the old storage keys and migrated by fallback.
