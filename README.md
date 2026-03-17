# Pocket Relay

Pocket Relay is a Flutter app for running remote coding sessions from your phone.
It SSHes into a developer box, runs the Codex CLI remotely, and renders the session as mobile-friendly widgets instead of a raw terminal.

## Status

The shipped app is app-server-only.

- Remote transport: SSH-backed `codex app-server --listen stdio://`
- Runtime pipeline: JSON-RPC events -> canonical runtime events -> session state -> transcript cards
- Ongoing work: cleanup and ownership refactors after the app-server migration

The active architecture cleanup history lives in `docs/000_app-server-migration-plan.md`.

## Why App-Server

Pocket Relay needs a live client protocol so the phone can:

- stream richer turn output
- handle approvals mid-turn
- answer user-input requests mid-turn
- keep a session open instead of spawning one process per message

That is why the app uses `codex app-server`.

## Source Tree

```text
docs/
  000_app-server-migration-plan.md
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
    features/
      chat/
        application/
        infrastructure/
          app_server/
        models/
        presentation/
          chat_screen.dart
          widgets/
            chat_composer.dart
            transcript/
            empty_state.dart
      settings/
        presentation/
          connection_sheet.dart
test/
  codex_app_server_client_test.dart
  chat_screen_app_server_test.dart
  widget_test.dart
```

## Current Architecture

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
- Streams runtime events into transcript cards for assistant output, work logs, approvals, user-input requests, changed files, status, errors, and usage.
- Keeps the remote session open across prompts unless ephemeral mode is enabled.
- Includes reducer, transport, and widget coverage for the app-server path.

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

- Existing saved profile data is migrated forward to the current storage keys on load.
