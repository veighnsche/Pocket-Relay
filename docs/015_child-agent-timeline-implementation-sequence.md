# Child-Agent Timeline Implementation Sequence

This document translates
`docs/014_child-agent-timeline-architecture-plan.md` into a repo-specific
execution order.

The goal is not to redesign the whole chat stack at once. The goal is to make
the ownership cut in the right order so child-agent support becomes correct,
testable, and incremental.

## Target Outcome

Pocket Relay should support Codex child agents with these behaviors:

- parent collaboration control rows stay in the parent timeline
- child transcript output stays in the child timeline
- the UI shows one selected timeline at a time
- pending requests stay attached to the owning timeline
- turn boundaries and end markers do not leak across timelines
- the composer remains root-thread-only in the first product cut

## Current Chokepoints

These files currently enforce the single-thread assumption:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/models/codex_runtime_event.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/application/runtime_event_mapper.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

The concrete failure is simple: thread ownership is flattened before the UI
ever gets a chance to choose a timeline.

## Implementation Strategy

The safest sequence is:

1. preserve thread and collaboration metadata in the event layer
2. cut state ownership into workspace state plus per-thread timeline state
3. route reducer work by timeline ownership
4. retarget controller actions by owning timeline
5. switch presentation from one transcript surface to one selected timeline
6. remove leftover transport shortcuts that still assume one tracked thread

Do not start with widgets. The renderer is downstream of the real problem.

## Migration Rules

- Keep single-thread behavior working as the degenerate case of one timeline.
- Do not flatten child output into the main timeline as a transitional hack.
- Do not introduce "best guess" ownership from the latest active turn.
- Keep the root composer intentionally scoped to the root thread in phase 1.
- Preserve enough compatibility getters during the migration so tests can move
  in slices instead of all at once.

## Slice 0: Capture a Real Multi-Agent Fixture

This slice must happen before the structural rewrite.

### Files

- add fixture files under `test/fixtures/` for one real child-agent run
- extend `test/codex_runtime_event_mapper_test.dart`
- extend `test/chat_screen_app_server_test.dart` or add a dedicated fixture test

### Work

- capture one app-server trace that includes:
  - parent thread start
  - collab spawn row
  - child thread creation
  - child transcript output
  - child request or blocked state if available
  - child completion
- store the raw notification and request payloads in fixture form
- record whether child-thread metadata is present directly in notifications or
  requires follow-up reads

### Exit Criteria

- the team has one canonical multi-agent trace fixture
- the trace answers whether `thread/started` is sufficient for metadata
- the trace answers whether child events arrive on the main session stream

### Why First

The biggest structural branch is still unknown:

- if live notifications already include enough thread metadata, the mapper work
  stays local
- if not, the transport layer needs an explicit follow-up read path before the
  reducer rewrite starts

## Slice 1: Preserve Thread Metadata and Collaboration Routing

This slice is still mostly additive. It should not change transcript ownership
yet.

### Primary Files

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_models.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- `lib/src/features/chat/application/runtime_event_mapper.dart`
- `lib/src/features/chat/application/runtime_event_mapper_notification_mapper.dart`
- `lib/src/features/chat/application/runtime_event_mapper_support.dart`
- `lib/src/features/chat/models/codex_runtime_event.dart`
- `test/codex_runtime_event_mapper_test.dart`

### Work

- extend app-server session and thread model parsing so metadata is not thrown
  away when present:
  - `agentNickname`
  - `agentRole`
  - thread source/session source
- preserve collaboration routing metadata from `collabAgentToolCall` items:
  - `senderThreadId`
  - `receiverThreadIds`
  - tool kind
  - per-agent status when available
- prefer a dedicated collaboration runtime payload over hiding this data inside
  `detail` text or generic snapshots
- if Slice 0 shows metadata gaps, add a focused `thread/read` style request in
  `CodexAppServerRequestApi` and call it only when a newly discovered thread is
  missing required metadata

### Design Recommendation

Keep the existing item lifecycle events if possible, but extend them with a
typed collaboration payload. Do not create a second parallel "work-log only"
path for child-agent ownership.

### Exit Criteria

- canonical runtime events preserve parent/child routing data
- thread lifecycle events can carry agent metadata
- mapper tests prove the metadata survives round-tripping from fixtures

## Slice 2: Introduce Workspace State Behind Compatibility Getters

This is the first real ownership cut.

### Primary Files

- `lib/src/features/chat/models/codex_session_state.dart`
- `test/codex_session_reducer_test.dart`
- `test/chat_session_controller_test.dart`
- `test/chat_screen_presentation_test.dart`

### Work

- replace the single-thread session shape with:
  - workspace-global transport state
  - `rootThreadId`
  - `selectedThreadId`
  - `timelinesByThreadId`
  - `threadRegistry`
  - `requestOwnerById`
- move timeline-local state into a dedicated type:
  - committed blocks
  - active turn
  - pending approvals
  - pending user-input requests
  - local prompt correlation
- keep temporary compatibility getters on `CodexSessionState` so existing code
  can still ask for:
  - selected timeline transcript blocks
  - selected timeline pending requests
  - selected timeline active turn

### Design Recommendation

Keep the public type name `CodexSessionState` for this migration step even
though it now stores workspace state. Renaming the type before the ownership
rewrite lands adds churn without improving the product model.

### Exit Criteria

- one state object can represent root plus child timelines at once
- current single-thread tests still pass through compatibility getters
- no reducer logic depends on a global `threadId` or global `activeTurn`
  field anymore

## Slice 3: Split the Reducer into Workspace Routing and Timeline Reduction

This slice is the core correctness change.

### Primary Files

- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/application/transcript_request_policy.dart`
- `lib/src/features/chat/application/transcript_item_policy.dart`
- `lib/src/features/chat/application/transcript_turn_segmenter.dart`
- `lib/src/features/chat/application/transcript_policy_support.dart`
- `test/codex_session_reducer_test.dart`

### Work

- turn `TranscriptReducer` into a workspace router:
  - session-global transport events update workspace state
  - thread lifecycle events upsert timeline and registry entries
  - content, item, request, and turn events route by owning `threadId`
- move transcript mutation into a per-timeline reducer or policy layer
- reduce collaboration control rows into the parent timeline only
- update thread registry links when collaboration events name child threads
- ensure `session/exited` closes timelines without inventing duplicate turn
  boundaries in unrelated timelines

### Invariants

- a child `turn/completed` event can only finalize the child timeline
- a child approval can only appear in the child timeline's pending request set
- parent collaboration rows remain visible even when the child timeline is
  selected separately

### Exit Criteria

- reducer tests prove parent and child blocks do not cross timelines
- repeated end markers stop appearing across unrelated threads
- single-thread behavior still matches current transcript chronology rules

## Slice 4: Retarget Controller Actions by Timeline Ownership

Once reducer ownership is correct, the controller must stop acting on global
state.

### Primary Files

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- `test/chat_session_controller_test.dart`
- `test/chat_screen_app_server_test.dart`
- `test/support/fake_codex_app_server_client.dart`

### Work

- add explicit selection state operations:
  - `selectTimeline(threadId)`
  - possibly `selectRootTimeline()`
- resolve actions through ownership maps instead of global pending sets:
  - approve
  - deny
  - submit input
  - stop active turn
- keep the composer sending only to the root timeline in phase 1
- change stop behavior so it requires the owning `threadId` and `turnId`
  instead of falling back to connection-global pointers
- if elicitation decline/cancel support is still needed, add it in this slice
  because request ownership is being rewritten anyway

### Invariants

- pressing stop on a child timeline never interrupts the root turn
- resolving a visible request always targets the timeline that owns it
- selecting a timeline does not change transcript ownership, only visibility

### Exit Criteria

- controller tests cover cross-thread request routing
- the app no longer depends on `appServerClient.threadId` for user-facing
  state decisions

## Slice 5: Cut Presentation Over to a Workspace Surface

Do this only after state and controller ownership are real.

### Primary Files

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`
- `lib/src/features/chat/presentation/chat_pending_request_placement_projector.dart`
- transcript widgets under
  `lib/src/features/chat/presentation/widgets/transcript/`
- `test/chat_screen_presentation_test.dart`
- `test/chat_screen_renderer_test.dart`
- `test/cupertino_chat_app_chrome_test.dart`
- `test/codex_ui_block_card_test.dart`

### Work

- replace the single transcript surface contract with a workspace contract:
  - timeline summaries
  - selected timeline id
  - selected timeline surface
  - root composer contract
- render one selected timeline at a time
- add a simple agent switcher:
  - `Main` for the root timeline
  - one chip or tab per child thread
  - stable first-seen order
- scope pinned requests and turn indicator to the selected timeline
- show agent label and status from registry metadata rather than from ad hoc
  transcript content

### Design Recommendation

Copy the TUI interaction model, not the web layout model:

- explicit current timeline
- stable spawn-order navigation
- child timelines stay inspectable after closure

Do not attempt simultaneous multi-column transcripts in this slice.

### Exit Criteria

- selecting an agent switches the transcript surface cleanly
- the selected timeline owns its own pinned requests and timer
- closed child agents remain available for review

## Slice 6: Remove Leftover Single-Thread Transport Assumptions

This slice pays off technical debt created by the current connection layer.

### Primary Files

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- transport tests that cover request and disconnect behavior

### Work

- stop treating connection-side tracked thread and turn pointers as UI truth
- remove or heavily demote:
  - `setTrackedThread(...)`
  - `setTrackedTurn(...)`
  - `connection.threadId` as a controller dependency
  - `connection.activeTurnId` as a stop-action dependency
- keep explicit ids flowing from state to outbound requests
- if the protocol requires child-thread attachment, isolate that logic in the
  transport layer rather than leaking it into reducer or widgets

### Exit Criteria

- transport convenience state is optional, not authoritative
- child-agent correctness no longer depends on whichever notification arrived
  last

## Test Plan by Slice

The minimum verification per slice should be:

- Slice 0: one real trace fixture checked into the repo
- Slice 1: mapper tests for thread metadata and collab routing
- Slice 2: state tests for multiple timelines existing simultaneously
- Slice 3: reducer tests for parent/child ownership and end-marker isolation
- Slice 4: controller tests for request and stop targeting
- Slice 5: presentation tests for agent selection and per-timeline pinned
  requests
- Slice 6: transport tests for explicit outbound targeting and disconnect
  behavior

The highest-value suites to extend are:

- `test/codex_runtime_event_mapper_test.dart`
- `test/codex_session_reducer_test.dart`
- `test/chat_session_controller_test.dart`
- `test/chat_screen_presentation_test.dart`
- `test/chat_screen_app_server_test.dart`

## Recommended Patch Boundaries

Keep the implementation in small structural slices:

1. fixture and mapper metadata preservation
2. state shape cut with compatibility getters
3. reducer routing by thread id
4. controller action targeting
5. workspace presentation
6. transport cleanup

Do not merge slices 2 through 5 into one patch. If something breaks, the team
needs to know whether the failure is in ownership, action routing, or UI
selection.

## Definition of Done

This project is done when:

- a real multi-agent trace can be replayed without parent/child transcript
  leakage
- selecting a child agent shows only the child timeline
- closing or completing a child agent does not append duplicate end cards to
  the parent timeline
- pending requests remain attached to the owning timeline
- the root timeline still behaves like today's single-thread experience when no
  child agents exist
