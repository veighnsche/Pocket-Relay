# 029 Codex History Source Of Truth Correction

## Status

Accepted architectural correction.

This document supersedes the parts of the recent conversation-history work that
made Pocket Relay persistence the source for historical conversation lists.

## Problem

Pocket Relay currently has two very different responsibilities:

1. Live runtime state for the currently active lane.
2. Historical conversation discovery for prior Codex threads.

Those responsibilities were incorrectly blended.

The recent implementation introduced Pocket Relay-owned persisted conversation
history/state and then used that persistence as the data source for the
conversation history sheet.

That is architecturally wrong for this product.

Why it is wrong:

- Historical conversations already exist in Codex.
- For remote lanes, that history exists on the remote machine and must be read
  over SSH.
- Pocket Relay cannot honestly decide which historical conversations exist.
- A local Pocket Relay store can drift from Codex and produce false negatives
  like "no history" even when Codex has real workspace history.

This creates exactly the duplicate-source-of-truth problem the app is supposed
to eliminate.

## Why The Pocket Relay History Store Was A Bad Idea

The rejected design effectively assumed that Pocket Relay could maintain its own
usable history of past Codex conversations.

That assumption is wrong.

Codex is not used only through Pocket Relay.

A user can create, continue, and resume conversations:

- in Codex directly
- in another terminal
- on the remote machine over SSH
- outside the lifetime of Pocket Relay

Because of that, any Pocket Relay-owned persisted historical conversation store
is guaranteed to drift from reality.

That makes such a store fundamentally unfit to answer:

- which past conversations exist
- which workspace conversations are available
- which thread ids should appear in the history list

At best, it would be a partial subset.
At worst, it would confidently lie.

This is why the idea is not merely "suboptimal" or "a cache tradeoff".
It is structurally wrong for the product.

## Why This Happened

The rejected design was easier to implement than the correct one.

It avoided the harder work of:

- reading Codex history from the actual machine that owns it
- doing that over SSH for remote lanes
- treating upstream history as authoritative instead of app-local persistence

So yes: the Pocket Relay-owned historical store was a convenience shortcut.

It simplified implementation in the short term, but only by moving the cost
into correctness:

- missing real conversations
- stale history
- disagreement with Codex
- another duplicate source of truth

That shortcut is exactly what this correction rejects.

## Correct Ownership

The ownership boundary must be strict.

### Codex owns

- All historical conversation existence.
- Historical conversation identity.
- Historical conversation discovery for a workspace.
- Historical thread ids that can be resumed.

For remote connections, this historical source must be reached through SSH.

### Pocket Relay owns

- Live runtime state for the active lane.
- In-memory transcript/runtime presentation state.
- Temporary UI state such as selection, modal visibility, loading flags, and
  reconnect flow state.

### Pocket Relay does not own

- The authoritative list of past conversations.
- A persisted local universe of historical conversations.
- A parallel identity model for conversations.

## Identity Rule

There is one conversation identity:

- `threadId`

Pocket Relay must not create a separate conversation id for historical or live
conversation identity.

## Required Source Of Truth Rule

Historical conversation lists must come from Codex.

That means:

- local connections: read Codex history locally
- remote connections: read Codex history over SSH

Pocket Relay persistence must not be the source for the history sheet.

If Codex history cannot be reached, the UI must show an honest loading or error
state. It must not silently substitute a locally persisted subset and present it
as authoritative history.

## What Local State Is Still Allowed

Only narrow live-lane state is allowed locally.

Allowed:

- active runtime session state
- selected live thread for the currently running lane
- transcript rendering state
- draft state
- viewport state

Not allowed:

- a Pocket Relay-owned persisted catalog of all historical conversations
- a local substitute for Codex workspace history

## Consequences For Current Code

The following recent direction is wrong and must be removed from the history
feature path:

- using Pocket Relay persisted conversation history/state as the source for the
  conversation history sheet
- treating that persistence as the authoritative set of prior conversations

The following direction remains valid:

- `threadId` is the only conversation identity
- Pocket Relay should not create its own conversation id
- live-lane runtime state can remain app-owned

## Required Upgrade Path

1. Remove Pocket Relay historical conversation persistence from the history-list
   read path.

2. Add a dedicated Codex history repository with the correct ownership:
   - local history loading for local connections
   - SSH-backed history loading for remote connections
   - workspace filtering at that repository boundary

3. Make the conversation history sheet read only from that Codex history
   repository.

4. Keep history-row resume based on upstream `threadId`.

5. Retain only live-lane runtime state locally.

6. Do not add any fallback that silently uses Pocket Relay-local historical
   persistence as if it were Codex truth.

## Non-Negotiable Rule

For historical conversations, Codex is the only source of truth.

Pocket Relay may display that truth and act on it.
Pocket Relay may not replace it.
