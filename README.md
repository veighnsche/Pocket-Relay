# Pocket Relay

Pocket Relay is a Flutter frontend for Codex.

It connects to a remote machine over SSH, launches `codex app-server`, and
renders the resulting Codex session as a native Flutter interface instead of a
raw terminal.

The important framing is this:

- Pocket Relay does not own the backend
- Codex and its app-server protocol are upstream
- Pocket Relay is a presentation client over that backend reality
- UI and transcript work should move toward parity with real Codex behavior, not
  invent alternate product states

## What This App Is For

Pocket Relay exists to let a user monitor and steer a live Codex session from a
phone or desktop Flutter client.

That includes:

- sending prompts into an active Codex session
- steering Codex while it is already streaming
- reviewing transcript output as structured UI
- handling approvals and user-input requests mid-turn
- inspecting changed files, work logs, SSH failures, and status events
- resuming an existing conversation instead of treating every prompt as a fresh
  one-shot request

This is not a local IDE replacement.

It is a remote session client with a Flutter presentation layer.

## Current Product Understanding

The current product is best understood as:

- a Codex session viewer and controller
- a transcript renderer for backend-driven state
- a remote-session client for SSH-backed developer boxes

The current implementation is app-server-first:

- transport: SSH stdio
- remote process: `codex app-server`
- runtime: JSON-RPC notifications and requests
- app mapping: protocol -> canonical runtime events -> session state ->
  presentation contracts -> Flutter widgets

## Current Status

What is true today:

- the app is app-server-only
- the transcript is rendered as structured cards and surfaces, not raw terminal
  text
- settings, SSH trust/failure states, work logs, approvals, user-input requests,
  changed files, and usage are all rendered as Flutter UI
- Widgetbook exists as a downstream preview/catalog of real app-owned widgets

What is also true today:

- parity with the Codex TUI/reference is still partial, not complete
- the current visual design is documented but not endorsed as the intended final
  design direction

Relevant docs:

- [042_codex-tui-flutter-widget-parity-gaps.md](/Users/vince/Projects/Pocket-Relay/docs/042_codex-tui-flutter-widget-parity-gaps.md)
- [044_current-visual-style-audit.md](/Users/vince/Projects/Pocket-Relay/docs/044_current-visual-style-audit.md)

## Architecture

High-level flow:

```text
Pocket Relay
  -> SSH
  -> codex app-server
  -> JSON-RPC messages
  -> canonical runtime events
  -> session state
  -> presentation contracts
  -> Flutter widgets
```

The important ownership rule is:

- backend/protocol truth comes first
- Flutter presentation comes after runtime mapping

Not the reverse.

## What Works Today

- stores connection profiles locally and secrets in secure storage
- connects to remote hosts over SSH
- launches and talks to `codex app-server`
- streams transcript activity into Flutter transcript surfaces
- supports approvals and user-input requests
- supports sending prompts while Codex is already streaming
- renders changed files, work logs, status, error, SSH trust/failure, usage, and
  turn-boundary states
- supports desktop and mobile Flutter shells
- includes Widgetbook for reviewing real app-owned widgets and transcript lanes

## What Is Still In Progress

- fuller parity with Codex reference transcript/history surfaces
- more complete split of aggregated work-log states into first-class app-owned
  surfaces
- better end-user visual design and stronger design-system clarity
- reducing remaining design debt in transcript composition and hierarchy

If you need the exact parity gap inventory, start with:

- [042_codex-tui-flutter-widget-parity-gaps.md](/Users/vince/Projects/Pocket-Relay/docs/042_codex-tui-flutter-widget-parity-gaps.md)

## Running The App

Typical repo commands:

```bash
flutter pub get
just mobile
```

Useful alternatives:

- `just ios-simulator`
- `just android-dev`
- `just macos-desktop`
- `just linux-desktop`

You can also run Flutter directly:

```bash
flutter run -t lib/main.dart
```

## Running Widgetbook

Widgetbook is for previewing real app-owned surfaces.

Use:

```bash
just widgetbook
just widgetbook-ios
```

Or directly:

```bash
flutter run -t lib/widgetbook/main.dart
```

Important:

- on Apple platforms, use the repo scripts/`just` recipes when possible
- they exist to prevent generated platform target files from being left pointed
  at the Widgetbook entrypoint

## Remote Machine Requirements

The remote machine needs:

- reachable SSH access
- the `codex` CLI installed
- a working Codex login on that machine
- a workspace path Pocket Relay can open

Pocket Relay assumes Codex runs remotely, not inside the phone app itself.

## Project Layout

```text
docs/
lib/
  main.dart
  widgetbook/
  src/
    app.dart
    core/
    features/
      chat/
      settings/
      workspace/
scripts/
test/
justfile
```

Important areas:

- `lib/src/features/chat/`
  runtime mapping, transcript contracts, transcript widgets, session control
- `lib/src/features/settings/`
  connection configuration and settings surfaces
- `lib/src/features/workspace/`
  desktop/mobile workspace shell behavior
- `lib/src/core/ui/`
  app-owned shared primitives and surfaces
- `lib/widgetbook/`
  downstream preview/catalog infrastructure only

## Widgetbook Rule

Widgetbook is not a second component system.

It should:

- import real app-owned widgets
- preview real runtime-real surfaces
- help review primitives, transcript cards, and full lanes

It should not:

- define replacement UI
- invent backend-owned states
- become a shadow product spec

## Design State

The current design language is documented, but it is not the intended final
direction.

The current visual system has:

- real shared tokens
- real shared primitives
- a real transcript surface model

But it still reads as too card-heavy, too soft, too tinted, and not yet
professional enough.

That assessment is recorded in:

- [044_current-visual-style-audit.md](/Users/vince/Projects/Pocket-Relay/docs/044_current-visual-style-audit.md)

## Testing

Run the full suite:

```bash
flutter analyze
flutter test
```

For Widgetbook-only checks:

```bash
flutter analyze lib/widgetbook test/widgetbook_app_test.dart
flutter test test/widgetbook_app_test.dart
```

## Notes

- saved profile data is migrated forward on load
- Widgetbook is a review tool, not an ownership layer
- frontend work should stay literal to backend/runtime truth whenever possible
