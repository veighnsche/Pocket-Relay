# Lib Architecture Redesign Audit

## Purpose

This document records:

1. what the current `lib/` tree actually contains
2. what behaviors the app currently supports
3. why the current organization is unstable
4. what root design change is required
5. what replacement filetree should exist while keeping the naming vocabulary
   already used in the repo

This is not a rename exercise.

The root claim is:

- the current filetree is bad because the current ownership boundaries are bad
- names like `runtime_event_mapper_notification_mapper.dart` are not cosmetic
  problems, they are evidence of broken design
- the redesign has to change both code organization and code responsibilities
- the path should carry scope so filenames do not have to repeat it

## Current Snapshot

Current size:

- `57` files total under `lib/`
- `47` files under `lib/src/features/chat`
- `24` chat presentation files
- `14` chat application files
- `6` app-server infrastructure files
- `3` chat model files
- `7` files under `lib/src/core`
- `1` file under `lib/src/features/settings`

Current top-level shape:

```text
lib/
  main.dart
  src/
    app.dart
    core/
      models/
      storage/
      theme/
      utils/
    features/
      chat/
        application/
        infrastructure/app_server/
        models/
        presentation/
      settings/
        presentation/
```

Current product shape:

- [`PocketRelayApp`](/home/vince/Projects/codex_pocket/lib/src/app.dart#L11)
  loads a saved profile and always boots into
  [`ChatScreen`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/chat_screen.dart#L14).
- There is no second routed feature surface today.
- The repo is dominated by one remote-session screen and its transcript.

## Current Behavior Inventory

I count `33` concrete shipped behaviors in `lib/`.

### Settings, Connection, and Persistence

1. Load a saved profile before showing chat in
   [`PocketRelayApp`](/home/vince/Projects/codex_pocket/lib/src/app.dart#L82).
2. Persist connection profile JSON in
   [`SecureCodexProfileStore.save()`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L72).
3. Persist SSH secrets separately in secure storage in
   [`SecureCodexProfileStore.save()`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L81).
4. Migrate legacy preferences and legacy secure-storage keys in
   [`SecureCodexProfileStore.load()`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L39)
   and
   [`_migrateLegacyPreferencesIfNeeded()`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L105).
5. Edit label, host, port, and username in
   [`ConnectionSheet`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L134).
6. Edit workspace directory, Codex launch command, and host fingerprint in
   [`ConnectionSheet`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L201).
7. Switch password auth vs private-key auth in
   [`ConnectionSheet`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L251).
8. Validate required password or required private key in
   [`ConnectionSheet`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L272).
9. Toggle dangerous full access in
   [`ConnectionSheet`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L334).
10. Toggle ephemeral session reuse in
    [`ConnectionSheet`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L347).

### Remote Session and App-Server Transport

11. Validate the current profile before sending a prompt in
    [`ChatSessionController._validateProfileForSend()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L192).
12. Open an SSH socket with timeout and authenticate in
    [`openSshCodexAppServerProcess()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart#L10).
13. Verify a pinned host key fingerprint or accept an unpinned key with a
    diagnostic in
    [`openSshCodexAppServerProcess()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart#L24).
14. Launch `codex app-server --listen stdio://` in the configured workspace in
    [`buildSshCodexAppServerCommand()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart#L90).
15. Perform the JSON-RPC `initialize` / `initialized` handshake in
    [`CodexAppServerConnection.connect()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart#L46).
16. Start a thread or resume an existing one, with fallback from
    `thread/resume` to `thread/start`, in
    [`CodexAppServerRequestApi.startSession()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L9).
17. Send a prompt as `turn/start` in
    [`CodexAppServerRequestApi.sendUserMessage()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L86).
18. Interrupt the active turn with `turn/interrupt` in
    [`CodexAppServerRequestApi.abortTurn()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L295).
19. Reply to inbound approvals, permissions requests, user-input requests, and
    MCP elicitation requests in
    [`CodexAppServerRequestApi`](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart#L130).
20. Reject unsupported host requests like auth refresh, dynamic host-side tool
    calls, and legacy file-read approvals in
    [`ChatSessionController._handleUnsupportedHostRequest()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart#L232).

### Session, Transcript, and UI

21. Add a local-echo user message immediately on send in
    [`TranscriptPolicy.addUserMessage()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart#L28).
22. Promote the local echo to sent when the provider reports the matching user
    item in
    [`TranscriptItemPolicy._suppressedLocalUserMessageState()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart#L282).
23. Track session, thread, and turn lifecycle through runtime events in
    [`TranscriptReducer.reduceRuntimeEvent()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_reducer.dart#L30).
24. Track elapsed turn time, including pausing while blocking requests are
    pending, through
    [`CodexSessionTurnTimer`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L5)
    and
    [`TranscriptRequestPolicy`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart#L14).
25. Project active items into turn segments and then into transcript blocks in
    [`TranscriptTurnSegmenter`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart)
    and
    [`projectCodexTurnArtifacts()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L236).
26. Render assistant messages in
    [`AssistantMessageCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart)
    through
    [`ConversationEntryCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart#L37).
27. Render reasoning blocks in
    [`ReasoningCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart)
    through
    [`ConversationEntryCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart#L42).
28. Render structured plan updates in
    [`PlanUpdateCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart)
    through
    [`ConversationEntryCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart#L46).
29. Render streamed proposed-plan markdown in
    [`ProposedPlanCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart)
    through
    [`ConversationEntryCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart#L49).
30. Render grouped work logs in
    [`WorkLogGroupCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
    and
    [`_buildTranscriptBlocks()`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L312).
31. Render changed-files summaries and per-file diff sheets in
    [`ChangedFilesCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart).
32. Render approval requests and user-input request forms in
    [`ApprovalRequestCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart)
    and
    [`UserInputRequestCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart).
33. Render status blocks, error blocks, usage strips, turn boundaries, and the
    live elapsed footer in
    [`StatusCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/status_card.dart),
    [`ErrorCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/error_card.dart),
    [`UsageCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart),
    [`TurnBoundaryCard`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart),
    and
    [`TurnElapsedFooter`](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart).

## Root Diagnosis

The problem is not just file count.

The problem is that the current repo does not have crisp ownership boundaries
for the remote-session pipeline.

Current effective pipeline:

```text
transport event
  -> runtime event
  -> active item
  -> turn segment
  -> transcript block
  -> transcript widget
```

That pipeline is too deep for the product that exists today, and the filetree
is mirroring that confusion.

### 1. Generic Buckets Hide Real Responsibility

Inside `features/chat/`, the current grouping is:

- `application/`
- `models/`
- `infrastructure/`
- `presentation/`

Those names do not answer:

- where transport ends
- where runtime normalization ends
- where session state lives
- where transcript shaping lives

As a result, files accumulate inside generic buckets until helpers have to be
named after the abstractions they are trapped inside.

### 2. Session State and Transcript Projection Are Mixed Together

Examples:

- [`codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L190)
  stores session state and also projects transcript output
- [`TranscriptTurnSegmenter`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart#L19)
  adds another projection stage
- [`TranscriptItemBlockFactory`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_block_factory.dart#L14)
  adds another projection stage on top

This is why one user-visible transcript requires multiple internal
representations.

### 3. Active-Turn Ownership Is Duplicated

Examples:

- `_ensureActiveTurn()` in
  [`transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart#L403)
- `_ensureActiveTurn()` in
  [`transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart#L370)
- `_ensureActiveTurn()` in
  [`transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart#L295)

That duplication exists because no single layer cleanly owns turn state.

### 4. Settings Is Not A Real Feature Boundary Yet

The remote-target feature is split across:

- [`connection_models.dart`](/home/vince/Projects/codex_pocket/lib/src/core/models/connection_models.dart#L3)
- [`codex_profile_store.dart`](/home/vince/Projects/codex_pocket/lib/src/core/storage/codex_profile_store.dart#L14)
- [`connection_sheet.dart`](/home/vince/Projects/codex_pocket/lib/src/features/settings/presentation/connection_sheet.dart#L12)

That is one feature split by old layer habits, not by coherent ownership.

### 5. `core/` Owns Product Code

`core/` currently contains connection models and profile storage.

Those are not generic shared primitives. They are product-specific behavior for
the connection feature and should move under `features/settings/`.

### 6. Repeated-Abstraction Filenames Are Structural Failures

The clearest example is:

- `runtime_event_mapper_notification_mapper.dart`

That filename means:

1. the thing called `runtime_event_mapper` already owns too much
2. the helper could not be named by role, only by repeating the parent
   abstraction
3. the boundary was never made explicit

This is a design failure, not a naming nit.

The same rule applies to patterns like:

- `mapper_mapper`
- `policy_policy`
- `factory_factory`

If that pattern appears, the code design is already wrong.

## Required Root Design Change

The redesign should keep the names already familiar in the repo:

- keep `core`
- keep `features`
- keep `settings`
- keep `chat`
- keep `app_server`
- keep `app.dart`

What changes is the ownership model inside those names.

The target pipeline should be:

```text
transport event
  -> runtime event
  -> session state
  -> transcript projector
  -> transcript widgets
```

That shorter pipeline is the basis for the new filetree.

Design rules:

1. `transport/` owns wire-level behavior.
2. `runtime/` owns canonical runtime normalization.
3. `session/` owns live session state and user intents.
4. `transcript/` owns transcript projection and transcript widgets.
5. `presentation/` owns screen composition only.

What this explicitly means:

- `active item -> turn segment -> block` should not survive as separate
  first-class architecture
- session state files must not also own transcript projection
- transcript files must not also decode transport payloads
- helper names must describe role, not repeat the parent abstraction

## Target Filetree

This is the proposed replacement tree while preserving the naming vocabulary
already used in the repo.

```text
lib/
  main.dart
  src/
    app.dart

    core/
      theme/
        pocket_theme.dart
      utils/
        duration_utils.dart
        monotonic_clock.dart
        shell_utils.dart
        thread_utils.dart

    features/
      settings/
        models/
          connection_profile.dart
        storage/
          profile_store.dart
        presentation/
          connection_sheet.dart

      chat/
        runtime/
          runtime_event.dart
          event_mapper.dart
          notification_decoder.dart
          request_decoder.dart
          payload_reader.dart

        session/
          session_controller.dart
          session_reducer.dart
          session_state.dart
          pending_request_state.dart
          turn_timer.dart
          unsupported_request_policy.dart

        transcript/
          ui_block.dart
          projector.dart
          changed_files_parser.dart
          work_log_grouper.dart
          widgets/
            list.dart
            conversation_entry_card.dart
            cards/
              approval_request_card.dart
              assistant_message_card.dart
              changed_files_card.dart
              error_card.dart
              plan_update_card.dart
              proposed_plan_card.dart
              reasoning_card.dart
              status_card.dart
              turn_boundary_card.dart
              usage_card.dart
              user_input_request_card.dart
              user_message_card.dart
              work_log_group_card.dart
            support/
              card_palette.dart
              markdown_style_factory.dart
              meta_card.dart
              chips.dart
              turn_elapsed_footer.dart

        transport/
          app_server/
            client.dart
            connection.dart
            protocol_models.dart
            request_api.dart
            ssh_process.dart
            json_rpc_codec.dart

        presentation/
          screen.dart
          composer.dart
          empty_state.dart
```

## Ownership Rules For The New Tree

### `features/settings/`

This folder owns the entire connection feature:

- connection models
- connection readiness rules
- secure persistence
- migration
- connection editing UI

This corrects the current split across `core/` and `features/settings/`.

### `features/chat/transport/`

This folder owns:

- SSH authentication
- host-key verification
- remote process launch
- JSON-RPC handshake
- request and response plumbing
- thread and turn ids from the remote service
- `app_server` protocol mechanics

This folder does not own transcript shaping or widget logic.

### `features/chat/runtime/`

This folder owns:

- canonical runtime event types
- conversion from transport messages into runtime events
- request decoding
- notification decoding
- raw payload field access

This is the only place where `runtime event mapping` should exist.

### `features/chat/session/`

This folder owns:

- prompt validation
- send and interrupt intents
- approval and denial actions
- user-input submission
- pending-request state
- thread lifecycle
- turn lifecycle
- live session state mutation
- unsupported host-request handling

This folder does not own diff parsing or transcript widgets.

### `features/chat/transcript/`

This folder owns:

- transcript block definitions
- transcript projection from session state
- changed-files parsing
- work-log grouping
- transcript widgets
- transcript card families
- transcript support widgets

This folder does not own SSH, JSON-RPC, or runtime decoding.

### `features/chat/presentation/`

This folder owns only:

- screen composition
- transcript and composer layout
- app-bar actions
- opening the settings sheet
- binding callbacks to the session controller

These files should stay thin.

## Naming Rules

These are architecture rules, not style preferences.

1. The path carries scope; filenames should only add the remaining local
   distinction.
2. Do not repeat ancestor directory names in child filenames.
3. One boundary owner may be called a `mapper`.
4. Its collaborators must be named by responsibility: `decoder`, `reader`,
   `parser`, `projector`, `grouper`.
5. If a file wants to be named `x_y_x.dart`, the boundary is wrong.
6. State files do not own projection logic.
7. Projection files do not own transport decoding.

Examples:

- good: `transport/app_server/client.dart`
- good: `runtime/event_mapper.dart`
- good: `transcript/projector.dart`
- good: `notification_decoder.dart`
- good: `payload_reader.dart`
- bad: `runtime_event_mapper_notification_mapper.dart`
- bad: `transport/app_server/codex_app_server_client.dart`
- bad: `transcript_policy_support.dart` if it only exists to compensate for an
  unclear boundary

## Key Current-To-Target Moves

- `lib/src/core/models/connection_models.dart`
  -> `lib/src/features/settings/models/connection_profile.dart`
- `lib/src/core/storage/codex_profile_store.dart`
  -> `lib/src/features/settings/storage/profile_store.dart`
- `lib/src/features/chat/models/codex_runtime_event.dart`
  -> `lib/src/features/chat/runtime/runtime_event.dart`
- `lib/src/features/chat/application/runtime_event_mapper.dart`
  -> `lib/src/features/chat/runtime/event_mapper.dart`
- `lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart`
  -> `lib/src/features/chat/runtime/notification_decoder.dart`
- `lib/src/features/chat/application/runtime_event_mapper_request_mapper.dart`
  -> `lib/src/features/chat/runtime/request_decoder.dart`
- `lib/src/features/chat/application/runtime_event_mapper_support.dart`
  -> `lib/src/features/chat/runtime/payload_reader.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`
  -> `lib/src/features/chat/session/session_controller.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`
  -> `lib/src/features/chat/session/session_reducer.dart`
- `lib/src/features/chat/models/codex_session_state.dart`
  -> split across:
  `lib/src/features/chat/session/session_state.dart`
  `lib/src/features/chat/session/pending_request_state.dart`
  `lib/src/features/chat/session/turn_timer.dart`
- `lib/src/features/chat/models/codex_ui_block.dart`
  -> `lib/src/features/chat/transcript/ui_block.dart`
- `lib/src/features/chat/application/transcript_changed_files_parser.dart`
  -> `lib/src/features/chat/transcript/changed_files_parser.dart`
- `lib/src/features/chat/application/transcript_item_block_factory.dart`
  -> fold into `lib/src/features/chat/transcript/projector.dart`
- `lib/src/features/chat/application/transcript_turn_segmenter.dart`
  -> fold into `lib/src/features/chat/transcript/projector.dart`
- work-log grouping currently inside
  [`codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart#L312)
  -> `lib/src/features/chat/transcript/work_log_grouper.dart`
- `lib/src/features/chat/infrastructure/app_server/*.dart`
  -> `lib/src/features/chat/transport/app_server/`
- `lib/src/features/chat/presentation/widgets/transcript/**`
  -> `lib/src/features/chat/transcript/widgets/**`
- `lib/src/features/chat/presentation/widgets/chat_composer.dart`
  -> `lib/src/features/chat/presentation/composer.dart`
- `lib/src/features/chat/presentation/chat_screen.dart`
  -> `lib/src/features/chat/presentation/screen.dart`
- `lib/src/features/chat/presentation/widgets/empty_state.dart`
  -> `lib/src/features/chat/presentation/empty_state.dart`

## What Must Explicitly Disappear

These should not survive as organizing concepts inside `features/chat/`:

- `application/`
- `models/`
- `infrastructure/`
- projection logic inside session-state files
- separate segmenter and factory layers for transcript projection
- repeated-abstraction filenames like `*_mapper_*_mapper.dart`
- folder-scope repetition like `transport/app_server/codex_app_server_*.dart`

These should also be reviewed for removal or demotion:

- modeled-but-unused enum values and block kinds
- helper files that exist only to patch over generic layer buckets

## Suggested Migration Order

1. Move connection models and profile storage into `features/settings/`.
2. Reduce `core/` to theme and generic utilities only.
3. Create `features/chat/runtime/` and move runtime event decoding there.
4. Create `features/chat/transport/` and move `app_server/` there unchanged.
5. Create `features/chat/transcript/` and move transcript widgets and parsing
   there.
6. Move the current session controller and session ownership into
   `features/chat/session/`.
7. Split the current `codex_session_state.dart` responsibilities into
   `session_state.dart`, `pending_request_state.dart`, and `turn_timer.dart`.
8. Replace the current `active item -> turn segment -> block` chain with one
   explicit `projector.dart`.
9. Remove dead seams and repeated-abstraction files after imports and tests are
   stable.

## Verification

At the time of this audit:

- `flutter test` passes
- `103` tests are green

This document is based on the live codepath, not stale assumptions.
