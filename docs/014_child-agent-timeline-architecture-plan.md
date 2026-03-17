# Child-Agent Timeline Architecture Plan

## Status

This document proposes the structural changes required for Pocket Relay to
support child agents correctly.

The current app is still fundamentally single-thread / single-active-turn in
its runtime state, reducer, and presentation contracts. That model is
insufficient for Codex multi-agent sessions where the parent thread can spawn,
wait on, resume, or close child-agent threads.

The goal of this plan is to move Pocket Relay closer to the Codex TUI
ownership model while still staying appropriate for a mobile GUI.

## Problem Summary

Pocket Relay currently collapses the session into:

- one `threadId`
- one `activeTurn`
- one transcript surface
- one pending-request placement surface

That assumption appears in:

- `lib/src/features/chat/models/codex_runtime_event.dart`
- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

This causes three structural failures for child agents:

1. Parent and child events compete for the same lifecycle slots.
2. Turn-end, request, and status artifacts can be rendered in the wrong
   transcript context.
3. The UI has no ownership boundary for choosing which agent transcript the
   user is actually looking at.

This is why the fix cannot be a renderer-only patch.

## Reference Findings

### 1. Codex TUI treats child agents as separate threads

The TUI does not flatten sub-agent output into one transcript.

Important reference points:

- `.reference/codex/codex-rs/tui/src/app.rs`
- `.reference/codex/codex-rs/tui/src/app/agent_navigation.rs`
- `.reference/codex/codex-rs/tui/src/multi_agents.rs`

Observed behavior:

- The app listens for new thread creation separately from the active thread
  event stream.
- Each thread gets its own listener and cached session metadata.
- The UI tracks a currently displayed thread, not just one global transcript.
- Multi-agent navigation follows stable spawn order, not thread-id sort order.
- The footer shows the active agent label only when more than one thread is
  known.

Relevant implementation patterns:

- `handle_thread_created()` in the TUI attaches a new listener for each child
  thread and pulls thread metadata before presenting it.
- `AgentNavigationState` stores stable picker order and current agent labels.
- The current displayed thread is explicit state.

Design implication for Pocket Relay:

- Child agents should become first-class timeline owners keyed by thread id.
- The UI should switch between timelines rather than mix them into one flat
  surface.

### 2. Codex protocol history keeps collaboration actions in the parent thread

Important reference points:

- `.reference/codex/codex-rs/app-server-protocol/src/protocol/thread_history.rs`
- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/ThreadItem.ts`
- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/Thread.ts`

Observed behavior:

- Collaboration actions are represented as `collabAgentToolCall` items.
- Those items record:
  - `senderThreadId`
  - `receiverThreadIds`
  - tool kind
  - per-agent status
- Threads themselves carry sub-agent metadata:
  - `agentNickname`
  - `agentRole`

This matters because the protocol already distinguishes:

- parent-thread control activity
- child-thread transcript ownership

Design implication for Pocket Relay:

- Parent collaboration control cards should stay in the parent timeline.
- Child transcript output should stay in the child timeline.
- Thread metadata should be preserved in app state, not discarded.

### 3. The web timeline reference stays mostly flat

Important reference points:

- `.reference/t3code/apps/web/src/session-logic.ts`
- `.reference/t3code/apps/web/src/components/chat/MessagesTimeline.tsx`

Observed behavior:

- The web UI derives one `TimelineEntry[]` for one active thread surface.
- `collab_agent_tool_call` is handled mainly as a work-log entry with its own
  icon and compact label.
- It is good at compact timeline rendering, but it is not a model for
  multi-thread child-agent transcript ownership.

Design implication for Pocket Relay:

- The web code is useful as a presentation reference for compact tool rows.
- It is not the right ownership reference for child-agent transcript routing.

## Design Decision

Pocket Relay should adopt a multi-timeline workspace model, not a single flat
transcript and not a simultaneous multi-column layout.

For phase 1, the app should behave closer to the Codex TUI:

- one visible timeline at a time
- explicit thread / agent switcher
- parent timeline keeps collaboration control rows
- child timelines keep their own transcript, requests, timers, and endings

This is the correct mobile-first compromise.

Why not simultaneous columns or stacked live transcripts?

- The TUI reference does not depend on simultaneous rendering.
- Mobile screen width is constrained.
- Most state bugs today come from missing ownership, not missing density.
- A selected-timeline model is much easier to verify.

## Proposed Product Model

The session should be presented as a workspace containing:

- one main thread timeline
- zero or more child-agent timelines
- one selected timeline
- shared transport/session status

User-visible behavior:

1. The main timeline shows the normal conversation plus collaboration control
   rows such as spawn, wait, resume, and close.
2. When Codex spawns a child agent, a new agent chip/tab appears.
3. Selecting that agent shows the child timeline only.
4. Turn completions, request cards, token usage, and status cards only affect
   the owning timeline.
5. The footer/header can show the selected agent label when not on the main
   thread.

## Ownership Model

### Session-global state

This state belongs to the app-server session as a whole:

- SSH bootstrap state
- app-server transport state
- connection settings
- root thread id
- selected timeline id
- thread registry

### Timeline-local state

This state belongs to one thread timeline:

- thread metadata
- active turn
- committed transcript blocks
- in-progress artifacts
- pending approvals
- pending user-input requests
- local user-message correlation state
- turn timer / blocked state

### Parent-to-child linkage

This linkage belongs in a thread registry, not in ad hoc UI heuristics:

- `parentThreadId`
- `childThreadIds`
- `spawnCallId`
- agent nickname
- agent role

## Proposed State Shape

The current `CodexSessionState` should evolve into a workspace graph.

Suggested shape:

```dart
class CodexSessionWorkspaceState {
  final CodexRuntimeSessionState transportStatus;
  final String? rootThreadId;
  final String? selectedThreadId;
  final Map<String, CodexTimelineState> timelinesByThreadId;
  final Map<String, CodexThreadRegistryEntry> threadRegistry;
}

class CodexThreadRegistryEntry {
  final String threadId;
  final String? parentThreadId;
  final List<String> childThreadIds;
  final String? agentNickname;
  final String? agentRole;
  final bool isClosed;
  final bool isPrimary;
}

class CodexTimelineState {
  final String threadId;
  final CodexRuntimeSessionState connectionStatus;
  final CodexActiveTurnState? activeTurn;
  final List<CodexUiBlock> committedBlocks;
  final Map<String, CodexSessionPendingRequest> pendingApprovalRequests;
  final Map<String, CodexSessionPendingUserInputRequest> pendingUserInputRequests;
  final List<String> pendingLocalUserMessageBlockIds;
  final Map<String, String> localUserMessageProviderBindings;
}
```

This is intentionally not a cosmetic extension of the existing state. The
ownership cut must be real.

## Runtime Event Model Changes

The current runtime events preserve too little metadata for multi-agent
ownership.

Required additions:

- thread metadata event or payload support:
  - `agentNickname`
  - `agentRole`
  - `sourceKind`
- collaboration routing metadata:
  - `senderThreadId`
  - `receiverThreadIds`
  - collaboration tool kind
  - per-child status map when available
- explicit thread registry events if needed:
  - thread discovered
  - thread linked to parent
  - thread metadata updated

Important rule:

- `threadId` stays the owner of transcript-bearing events.
- collaboration control events may mention multiple thread ids, but they do not
  transfer ownership of content into the parent timeline.

## Mapper Changes

The mapper should stop discarding thread metadata from `thread/started` and
related payloads.

Required work:

1. Extend app-server session / thread models to preserve thread metadata when
   the protocol provides it.
2. Extend runtime events so thread lifecycle events can carry agent metadata.
3. Parse `collabAgentToolCall` snapshots into structured collaboration runtime
   events instead of only collapsing them into generic work-log semantics.

If live notifications do not provide enough metadata for child threads, add a
follow-up request path such as `thread/read` for newly discovered child thread
ids. The TUI effectively does this by attaching to newly created threads and
reading their session configuration before presenting them.

## Reducer Changes

The reducer should become a workspace router plus per-timeline reducers.

Suggested structure:

- `WorkspaceReducer`
  - owns timeline lookup and thread registry mutations
- `TimelineReducer`
  - owns transcript, active turn, pending requests, and turn lifecycle for one
    thread

Routing rules:

1. Session-global transport events update workspace state.
2. Thread lifecycle events upsert or close timeline entries for the owning
   thread id.
3. Content, item, request, and turn events are reduced only into the owning
   timeline.
4. Collaboration control events append parent-thread control blocks and update
   thread registry links.
5. `session/exited` closes all timelines, but does not invent duplicate per-turn
   boundaries across unrelated threads.

This split is the core structural fix for duplicated end components.

## Request Ownership Changes

Pending requests must become timeline-owned.

The current projection layer chooses the oldest pending request globally, which
is wrong for a multi-timeline workspace.

Required changes:

- each timeline tracks its own pending approvals and user-input requests
- request actions resolve through `requestId -> owningThreadId`
- the selected timeline shows its own pinned requests
- the main timeline does not steal child-agent requests unless product
  explicitly wants that behavior

This is especially important for approvals and user input, because the current
single pending-request placement projector is fundamentally global.

## Transport and Controller Changes

The connection layer currently tracks only one thread pointer and one active
turn pointer. That is not sufficient once child timelines exist.

Required changes:

- stop treating connection-side thread pointers as the source of truth for UI
  state
- keep explicit thread/turn ids on outbound operations
- let the controller act on the selected timeline or an explicitly targeted
  timeline

For phase 1:

- composer input stays bound to the main thread only
- stop / approve / deny / submit-input actions target the owning timeline of
  the visible request or active turn

This keeps the first cut smaller while still fixing ownership correctly.

## Presentation Changes

The screen contract should move from one transcript surface to one workspace
surface.

Suggested contract split:

```text
ChatWorkspaceContract
  header
  actions
  timelineSummaries[]
  selectedTimelineId
  selectedTimelineSurface
  composer
  connectionSettings
  turnIndicator
```

Each timeline summary should include:

- thread id
- label
- role
- isPrimary
- isClosed
- status
- hasUnreadActivity
- hasPendingRequests

The selected timeline surface should look similar to the current
`ChatTranscriptSurfaceContract`, but scoped to one timeline.

## UI Recommendation

Use a timeline switcher above the transcript.

Phase-1 UI shape:

- horizontally scrollable chips or segmented control
- `Main` for the root thread
- one chip per child agent using nickname or role
- subtle status badge for running / blocked / error / closed

Transcript behavior:

- only the selected timeline transcript is rendered
- collaboration control cards remain visible in the parent timeline
- child timelines show only their own content and requests

This keeps the UI aligned with the TUI mental model while staying usable on
mobile.

## What Should Not Happen

Do not implement child-agent support by:

- appending child output into the main timeline with labels only
- keying ownership off "latest eligible turn"
- keeping one global pending-request queue
- adding special renderer branches without changing state ownership
- inferring child transcript boundaries from work-log text alone

Those would be cosmetic approximations, not structural support.

## Migration Plan

### Phase 0: Trace and fixture work

- capture one or more real multi-agent app-server traces
- record payloads for:
  - child thread creation
  - collab spawn
  - child transcript output
  - child request / approval flow
  - child turn completion

### Phase 1: Event model and registry

- preserve thread metadata in models and runtime events
- add collaboration routing metadata
- add thread registry state

### Phase 2: Workspace state cut

- introduce workspace state plus timeline state
- move per-thread transcript and request ownership into timelines
- keep single-thread behavior as the degenerate case

### Phase 3: Presentation cut

- replace the single transcript surface with a workspace surface
- add timeline switcher and selected timeline rendering
- scope pinned requests and turn indicators to the selected timeline

### Phase 4: Action targeting

- resolve request actions by owning timeline
- stop active turns by owning timeline
- keep composer root-only unless protocol/product work proves child input is
  needed

### Phase 5: Cleanup

- remove obsolete single-thread assumptions
- remove connection-layer UI reliance on one tracked thread / turn

## Test Strategy

The tests must verify ownership, not only text rendering.

Required coverage:

1. mapper tests
   - preserves child thread ids and metadata
   - maps collaboration control items with sender / receiver ownership

2. reducer tests
   - child transcript output stays out of the parent timeline
   - parent collaboration control rows stay in the parent timeline
   - child turn completion does not append a parent end block
   - pending requests stay attached to the owning timeline
   - session exit closes all timelines without cross-thread duplication

3. presentation tests
   - selecting an agent switches transcript surfaces
   - the selected timeline owns its own pinned requests
   - agent chips follow stable first-seen order

4. controller tests
   - stop / approve / deny / submit-input actions target the correct timeline

## Open Questions

These should be answered from captured traces before implementation starts:

1. Do live `thread/started` notifications always include `agentNickname` and
   `agentRole`, or do we need a `thread/read` fetch for child threads?
2. Does the app-server emit child-thread events on the same session stream, or
   do some cases require explicit child-thread attachment?
3. Should the mobile composer support sending input to a selected child agent,
   or should child timelines be view-only in the first product cut?
4. Should parent timelines surface aggregated unread counts from child
   timelines?

## Recommended First Implementation Target

The first implementation should aim for:

- correct child-agent timeline ownership
- one selected timeline visible at a time
- main-thread composer only
- parent collaboration control cards
- per-thread requests and endings

That is the smallest structurally correct cut that matches the protocol and
moves Pocket Relay closer to the Codex TUI.
