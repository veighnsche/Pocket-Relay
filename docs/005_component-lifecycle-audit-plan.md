# Component Lifecycle Audit Plan

## Status

This document records the lifecycle-sensitive components in Pocket Relay and the
work needed to make their ownership, update, and teardown behavior reliable.

The goal is not to make every widget stateful or complicated. The goal is to
make sure long-lived resources follow the correct lifecycle:

- create at the right owner boundary
- update when dependencies change
- dispose when the owner goes away
- preserve local UI state only when the underlying model identity is the same

## Lifecycle Categories

### 1. Root-owned dependencies

These objects should be created once at the app boundary and torn down once at
the app boundary:

- `CodexAppServerClient`
- app-level profile store bindings

Problems we had:

- `PocketRelayApp` could create a fresh `CodexAppServerClient()` during build
- dependency swaps had no explicit update path
- owned clients had no final disposal hook

Required behavior:

- bind root dependencies in `initState`
- rebind them in `didUpdateWidget` when injected dependencies change
- dispose only the dependencies the app itself owns

### 2. Screen-owned controllers and subscriptions

These objects should belong to `ChatScreen`:

- `ChatSessionController`
- snackbar stream subscription
- composer controller
- transcript follow controller

Problems we had:

- `ChatScreen` only initialized `ChatSessionController` once
- if `profileStore`, `appServerClient`, or initial saved profile changed, the
  screen had no update lifecycle to rebuild the controller graph

Required behavior:

- create and subscribe in `initState`
- rebuild controller/subscription ownership in `didUpdateWidget`
- dispose everything in `dispose`

### 3. Transport-owned resources

These objects should belong to the app-server transport layer:

- stdout subscription
- stderr subscription
- request tracker state
- inbound request store state
- event stream controller

Problems we had:

- disconnect behavior existed
- final disposal behavior did not
- the event stream controller stayed open forever

Required behavior:

- separate `disconnect` from final `dispose`
- close event streams when the client/connection is permanently dead
- reject reuse after disposal

### 4. Transcript child identity

These widgets hold local UI state:

- `ProposedPlanCard`
- `WorkLogGroupCard`
- `UserInputRequestCard`
- `TurnElapsedFooter`
- diff-sheet and bottom-sheet subtrees spawned from transcript rows

Problems we had:

- transcript rows were not keyed by `block.id`
- stateful card state was tied to list position instead of transcript identity
- expanded/collapsed state and controller state could leak between different
  blocks

Required behavior:

- key transcript and pending-request rows by model identity
- treat `block.id` as the source of truth for widget identity

### 5. Stateful request-entry widgets

The main lifecycle-sensitive widget here is:

- `UserInputRequestCard`

Problems we had:

- controllers were created only in `initState`
- resolved answers or swapped requests did not resync existing controllers

Required behavior:

- rebuild controller shape when question ids change
- update controller text when server answers change
- dispose removed controllers immediately

## Current Inventory

### Components that needed lifecycle fixes

1. `lib/src/app.dart`
2. `lib/src/features/chat/presentation/chat_screen.dart`
3. `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`
4. `lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart`
5. `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`
6. `lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart`

### Components that are currently acceptable

These already had adequate basic lifecycle handling for their current role:

- `lib/src/features/settings/presentation/connection_sheet.dart`
- `lib/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`
  listener attach/detach behavior itself

They may still need future changes if ownership boundaries move, but they are
not the immediate risk area.

## Implementation Order

1. Fix root dependency ownership in `PocketRelayApp`.
2. Fix `ChatScreen` dependency update behavior.
3. Add explicit final disposal to app-server client and connection layers.
4. Key transcript and pending-request rows by `block.id`.
5. Add `didUpdateWidget` synchronization to `UserInputRequestCard`.
6. Add focused regression tests for keyed identity and request-card updates.

## Guard Rails

- Do not create transport clients inside `build()`.
- Do not let stateful transcript widgets depend on list position.
- Do not keep `TextEditingController`s alive for fields that no longer exist.
- Do not silently allow a disposed app-server client to be reused.
- Keep ownership boundaries simple: app owns app-level resources, screen owns
  screen-level resources, widgets own only local UI state.

## Test Expectations

These lifecycle fixes should be covered by tests that prove:

- transcript card state does not leak across block identity changes
- user-input controllers resync when the backing request block changes
- disposed app-server clients close their event stream and reject reuse

This should remain part of the regression suite because lifecycle bugs usually
reappear during UI refactors rather than protocol changes.
