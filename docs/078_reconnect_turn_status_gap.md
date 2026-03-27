# Reconnect Turn Status Gap

## Problem

When a live lane reconnects, Pocket Relay can lose the active turn status until
the app-server emits another runtime event.

The user-visible symptom is:

- a lane was running before transport loss
- the lane reconnects successfully
- the lane does not immediately know whether that turn is still running or has
  already completed
- the UI only becomes correct again after the app-server sends another event

This is a product bug because reconnect should restore the real turn state
immediately, not wait for a future emission.

## Source Findings

### 1. Transport loss clears the active turn

On disconnect, transport mapping emits `CodexRuntimeSessionExitedEvent`:

- [`runtime_event_mapper_transport_mapper.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/runtime/application/runtime_event_mapper_transport_mapper.dart)

That event is reduced through `_reduceSessionExitedImpl(...)`, which applies the
session-exit reducer to every timeline:

- [`transcript_reducer_workspace_threads.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/transcript/application/transcript_reducer_workspace_threads.dart)

The session-exit reducer ultimately clears the active turn:

- [`transcript_policy_turns.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/transcript/application/transcript_policy_turns.dart)

So after confirmed transport loss, the lane no longer has authoritative local
`activeTurn` state.

### 2. Live reattach for visible lanes does not restore a turn-status baseline

When a workspace lane reconnects after transport loss, the controller prefers a
live reattach on the existing binding:

- [`reconnect.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/application/controller/reconnect.dart)

That path calls:

- `binding.sessionController.reattachConversation(threadId)`

For lanes that already have visible conversation state, `reattachConversation`
uses `_resumeConversationThread(...)` instead of the history-baseline path:

- [`chat_session_controller_recovery.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart)

`_resumeConversationThread(...)` does:

- `resumeThread(...)`
- emits `CodexRuntimeThreadStartedEvent`

It does not immediately reread `thread/read` with turns, and it does not derive
current turn status from the resume response.

### 3. The history-baseline path already knows how to restore a running turn

The empty-lane fallback path does reread `thread/read` and rebuild state from
history:

- [`chat_session_controller_recovery.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/lane/application/chat_session_controller_recovery.dart)
- [`chat_session_controller_history.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/lane/application/chat_session_controller_history.dart)
- [`chat_historical_conversation_restorer.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/transcript/application/chat_historical_conversation_restorer.dart)

That restore path can keep an incomplete turn active because it:

- starts each historical turn
- only emits `turn completed` for turns that are actually completed
- preserves `in_progress` item status from `thread/read`

There is already coverage proving that an empty-lane restore can bring back the
latest running turn correctly:

- [`session_controller_history_restore_test.dart`](/Users/vince/Projects/Pocket-Relay/test/features/chat/lane/application/session_controller_history_restore_test.dart)

## Actual Gap

Pocket Relay has two reconnect behaviors:

1. `thread/read` baseline restore
2. live reattach without immediate baseline hydration

The first path can determine running vs completed immediately.

The second path cannot, because disconnect already cleared `activeTurn` and the
resume response does not rebuild it. That leaves the lane status stale until the
next live event arrives.

## Why This Matters

- lane activity can appear idle or completed when the turn is still running
- reconnect UX is misleading even though transport recovery succeeded
- user trust drops because the lane state looks arbitrary after reconnect

This is especially bad for long-running remote turns, where there may be a long
delay before the next output or lifecycle event arrives.

## Likely Fix Direction

The reconnect path should restore authoritative turn state immediately after
`resumeThread(...)`, even for lanes that already have visible conversation
state.

The two plausible approaches are:

### Option A: always hydrate a post-resume thread baseline

After a successful `resumeThread(threadId)`, fetch `readThreadWithTurns` and
merge the latest thread state back into the lane before replaying buffered
events.

This is the safest option because the app already has a working source-backed
restore path for `thread/read`.

### Option B: extend the resume contract if upstream exposes active-turn truth

If the upstream `thread/resume` response can expose current active-turn state,
Pocket Relay could restore turn status directly from that response.

Right now the app-owned `CodexAppServerSession` model does not carry that data:

- [`codex_app_server_models.dart`](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/transport/app_server/codex_app_server_models.dart)

So this would require a real upstream/app-server contract change, not a Flutter
surface patch.

## Recommended Follow-up

Preferred follow-up:

1. Keep the current live-reattach flow.
2. After `resumeThread(...)`, hydrate a current `thread/read` baseline for the
   reattached thread.
3. Merge or reapply buffered runtime events on top of that baseline.
4. Add tests that assert the lane immediately knows whether the turn is running
   or completed before any new replayed event arrives.

## Missing Test Coverage

There should be an explicit reconnect test for this exact bug:

- start a running turn
- disconnect transport
- reconnect the same visible lane
- do not emit any new app-server lifecycle/output event yet
- assert the lane already reflects the true running/completed state from the
  reconnect baseline

That test does not exist today.
