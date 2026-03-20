# ThreadId Identity Architecture

## Goal

Pocket Relay should adopt the upstream Codex conversation identity instead of
inventing its own.

Based on the app-server contract currently used in this repo, that identity is
`threadId`.

This document explains:

- why a Pocket Relay-specific conversation id is the wrong architecture
- what `threadId` already does in the upstream contract
- what must change so the app consistently uses `threadId`
- what local state is still acceptable without creating a parallel universe

## Current Upstream Reality

In the app-server contract used by Pocket Relay today:

- conversations start with `thread/start`
- conversations resume with `thread/resume`
- both flows are keyed by `threadId`
- turns are sent with `turn/start(threadId: ...)`
- thread metadata is read with `thread/read(threadId: ...)`

Relevant code:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`

No separate `conversationId` was found in the current app-server contract used
by this app.

That means the best available upstream conversation identity is `threadId`.

## Why A Pocket Relay Conversation Id Is Bad

Creating a Pocket Relay-only conversation id would be a structural mistake.

### 1. It creates two sources of truth for the same thing

If Pocket Relay invents its own conversation id while Codex already uses
`threadId` for start, resume, and thread lookup, the app now has two identities
for one conversation:

- the upstream id that actually works with Codex
- the local id that only Pocket Relay understands

That is the beginning of drift.

Soon the app has to answer bad questions such as:

- which id is the real conversation?
- which one should the UI use?
- which one should persistence use?
- what happens if one exists without the other?

Those questions should not exist in the first place.

### 2. It forces mapping logic everywhere

A local conversation id does not remove complexity.
It relocates complexity into permanent mapping code.

Once Pocket Relay invents its own id, every feature must translate between:

- local conversation id
- `threadId`
- saved history rows
- resume actions
- transcript caches
- lane state

That mapping layer becomes a permanent tax on the codebase.

### 3. It makes bugs harder to reason about

When a resume fails or a row opens the wrong conversation, debugging is much
harder if the app has two ids for the same concept.

Instead of checking one identity path, engineers have to inspect:

- local id creation
- local-to-thread mapping
- mapping persistence
- mapping invalidation
- stale references after reconnect or restart

That is avoidable.

### 4. It creates fake product semantics

If the product concept is "a Codex conversation", but the app persists a
different local identity as the main key, then the product model and runtime
model no longer match.

That mismatch leads to bad design language such as:

- "resumable conversation" versus "conversation"
- "history item id" versus "thread id"
- "selected conversation" that is not the same as the upstream thread

Those distinctions are usually symptoms of the wrong architecture, not
meaningful product concepts.

### 5. It makes future parity harder, not easier

If Codex later exposes better thread metadata, transcript readback, search, or
history APIs, Pocket Relay should be able to adopt them directly.

A bespoke local id layer gets in the way because every new upstream feature
must now be retrofitted through a translation model the app did not need.

## What Is Acceptable Local State

Rejecting a bespoke conversation id does not mean rejecting all local state.

Local state is still valid when it is clearly treated as cached or app-owned
metadata attached to `threadId`.

Examples of acceptable local state:

- saved preview text for a `threadId`
- prompt count for a `threadId`
- timestamps for a `threadId`
- whether a `threadId` is currently selected in the UI
- whether a connection currently hands off to a `threadId`
- local transcript cache keyed by `threadId`

The rule is:

- `threadId` is the identity
- local state may decorate that identity
- local state must not replace that identity

## What The App Should Do Fundamentally

Pocket Relay should use this rule everywhere:

- a conversation is a `threadId`

That means:

1. The history list should be a list of `threadId`-keyed records.
2. Resume should always target `threadId`.
3. Handoff should persist `threadId`.
4. Any cached metadata should be stored under `threadId`.
5. Any future transcript persistence should also be keyed by `threadId`.

If a row appears in the conversation list, it should have a real `threadId`.

If the app does not have a real `threadId` for something, it is not yet a
real resumable conversation and should not be presented as one.

## What Is Wrong In The Current Failure Mode

The recent conversation-history failure happened because the app treated
"history rows" and "resume target" as different worlds.

That kind of split is exactly what happens when identity is not kept strict.

The correct model is simpler:

- the list contains thread-backed conversations
- the row key is `threadId`
- the click action resumes `threadId`
- any extra metadata is optional decoration

The app should never need a second identity to explain the same row.

## Recommended Upgrade Path

### 1. Standardize terminology around `threadId`

The code should stop using terms that imply a different identity model, such as
"resumable conversation" when the product simply means "conversation".

Preferred framing:

- conversation history keyed by `threadId`
- conversation handoff storing a `threadId`
- conversation metadata cached for a `threadId`

### 2. Centralize thread registration

Whenever the app learns about a real thread through:

- `thread/start`
- `thread/resume`
- `turn/start`

it should update one thread-based persistence path.

This should be the only place that grows the conversation list.

### 3. Merge existing handoff behavior into the same thread model

The saved handoff thread is already a real upstream identity.

It should not live in a separate conceptual category from conversation history.

If the app knows a saved `threadId`, that is already a valid conversation
identity and should be visible through the same thread-based list.

### 4. Keep metadata cache thin

The local persistence layer should cache only things the app actually needs for
presentation:

- preview
- counts
- timestamps

Those values may be incomplete.
That is acceptable.

What is not acceptable is replacing `threadId` with a local id.

### 5. Add richer upstream adoption later, not a local identity now

If Codex later exposes:

- full thread listing
- transcript readback
- richer thread metadata

Pocket Relay should adopt those APIs directly around `threadId`.

That is the right place to grow capability.
It is not the right place to introduce a bespoke conversation identity.

## Decision

Pocket Relay should not create its own conversation id.

Pocket Relay should adopt Codex `threadId` as the single conversation identity
used for:

- list rows
- resume
- handoff
- metadata caching
- future transcript persistence

Any local state should exist only as metadata attached to that upstream id.

That keeps the product model truthful, reduces mapping code, and avoids a false
second source of truth.
