# Prompt Rewind / Resume Investigation

## Purpose

Record how the Codex reference implementation handles "go back to an earlier
prompt and continue from there", and define the correct Pocket Relay approach
for a mobile-first affordance such as long-pressing a previous user prompt.

This document is an implementation reference, not a speculative product brief.

## Question Being Answered

The target behavior is:

- select a previous user prompt
- go back to that point in the conversation
- continue the conversation from there

The request explicitly is not about reproducing the exact `Esc` / `Esc` / `Enter`
keyboard shortcut. The question is what that reference behavior actually does,
and how Pocket Relay could support the same semantic behavior through a touch
gesture such as long-press.

## Reference Finding

In the Codex TUI, "edit previous message" is a real rollback flow, not merely
composer history recall.

Reference anchors:

- `.reference/codex/codex-rs/tui/src/app_backtrack.rs`
- `.reference/codex/codex-rs/tui/src/bottom_pane/footer.rs`
- `.reference/codex/codex-rs/tui/tooltips.txt`
- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/ThreadRollbackParams.ts`

### What the TUI actually does

The reference state machine in
`.reference/codex/codex-rs/tui/src/app_backtrack.rs` is:

1. First `Esc` primes backtrack mode.
2. Second `Esc` opens transcript backtrack preview.
3. The user navigates among previous user messages.
4. `Enter` confirms the selected earlier user message.
5. The app sends `Op::ThreadRollback { num_turns }`.
6. The composer is prefilled from the selected earlier user message.
7. The local transcript is only trimmed after rollback is confirmed.

That is explicit in the source comments and implementation:

- "rewind to an earlier user message"
- "stage a rollback request"
- "wait for core to confirm"
- "prefill derived from the selected user message"

### This is not just prompt history navigation

The tooltip text says:

- "When the composer is empty, press Esc to step back and edit your last message; Enter confirms."

That wording is easy to misread as local composer recall. The implementation is
stronger than that. It rewinds the actual thread history with a backend
rollback, then lets the user continue from the earlier point.

## Protocol Reality

The relevant upstream protocol method is `thread/rollback`.

From
`.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/ThreadRollbackParams.ts`:

- `threadId`
- `numTurns`

Important contract:

- rollback drops turns from the end of the thread
- rollback only modifies thread history
- rollback does not revert local file changes
- clients remain responsible for file-change reversion

This matters because the UX must not imply full workspace undo if only thread
history is being rewound.

## Related Protocol Surface

The reference protocol also has `thread/fork`.

That is not the same behavior.

`thread/fork` creates a new thread from an existing thread. It is suitable for
branching. It is not the direct semantic match for "rewind this conversation to
that earlier prompt and continue from there in the same thread".

So for the requested behavior, `thread/rollback` is the relevant primitive.

## Pocket Relay Current State

Pocket Relay currently supports:

- restoring a full conversation transcript from upstream `thread/read`
- resuming an existing thread via `thread/resume`
- sending new user turns into the current thread

Key files:

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`

Pocket Relay currently does not expose:

- `thread/rollback`
- `thread/fork`
- any transcript action on user-message cards for rewind/resume

User messages are currently passive transcript surfaces rendered through:

- `lib/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart`
- `lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart`

## Constraint From Repo Rules

Pocket Relay does not own the backend and must adapt to backend reality.

That means Pocket Relay should not fake this feature by:

- only copying old prompt text into the composer
- locally deleting transcript blocks without upstream confirmation
- inventing a Pocket Relay-only rewind model

If the user asks to "continue from here", the implementation must either:

- perform a real upstream rollback and then continue from there

or:

- expose a clearly different action with clearly different semantics

Anything else would violate the repo's ownership and product-truth rules.

## Correct Pocket Relay Interpretation

The correct Pocket Relay equivalent of the reference behavior is:

1. The user long-presses a previous sent user prompt.
2. Pocket Relay offers `Continue From Here`.
3. Pocket Relay confirms the destructive effect:
   newer conversation turns will be discarded.
4. Pocket Relay warns that local file changes are not automatically reverted.
5. Pocket Relay calls upstream `thread/rollback`.
6. Pocket Relay restores the returned upstream history snapshot.
7. Pocket Relay prefills the composer with the selected earlier prompt.
8. The next send continues from that true upstream point.

This is the honest implementation.

## Incorrect Implementations To Avoid

These approaches should not be shipped as "continue from here":

### 1. Composer-only prefill

Copying an old prompt into the composer without rolling back the thread would
only mimic the appearance of the feature.

Why it is wrong:

- newer backend turns would still exist
- the next send would continue from the latest backend state, not the selected
  earlier point
- the UX would make a false product claim

### 2. Local transcript trimming first

Locally removing transcript blocks before upstream rollback succeeds is also
wrong.

Why it is wrong:

- the UI could diverge from backend truth
- rollback could fail
- the selected thread could have changed

The reference TUI explicitly avoids this by waiting for rollback confirmation.

### 3. Treating this as fork by default

Forking is a different user action with different thread semantics.

If Pocket Relay later adds both rollback and branching, they should be separate
actions with separate labels.

## Recommended Pocket Relay UX

### Primary action

On a sent user message in the active thread:

- long-press
- show bottom sheet or context menu
- action label: `Continue From Here`

### Confirmation copy

The confirm surface should say, in substance:

- newer conversation turns will be discarded
- local file changes are not reverted automatically

This warning is not optional because it is part of the real upstream contract.

### Availability rules

The action should not be shown or enabled for:

- unsent local-echo user messages
- messages outside the active thread timeline
- while a turn is still running
- while transcript restore is in progress
- while another rollback is already pending

## Recommended Architecture

Implement this in app-owned code, starting at the real protocol boundary.

### 1. Add app-server rollback support

Files:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`

Add a method shaped like:

- `rollbackThread(threadId, numTurns)`

Behavior:

- validate `numTurns >= 1`
- send `thread/rollback`
- decode the returned thread history through the same typed history decoder path
  used by `thread/read(includeTurns: true)`

This keeps the backend contract explicit and app-owned.

### 2. Add controller-owned rewind intent

File:

- `lib/src/features/chat/application/chat_session_controller.dart`

Add a dedicated controller method for the user intent, for example:

- `continueFromUserMessage(blockId)`

Responsibilities:

- resolve the selected user message in the active/root thread
- compute rollback depth from the current ordered user-message history
- reject invalid states
- call the new app-server rollback method
- rebuild the transcript from returned upstream history
- prefill the composer with the selected earlier prompt after success

The controller should own the semantics. The widget layer should not compute
rollback depth.

### 3. Add app-owned rollback eligibility in transcript contracts

Files:

- `lib/src/features/chat/presentation/chat_transcript_item_contract.dart`
- `lib/src/features/chat/presentation/chat_transcript_item_projector.dart`
- possibly `lib/src/features/chat/presentation/chat_transcript_surface_projector.dart`

Expose enough app-owned contract data for the UI to know:

- whether a user message can continue from here
- which message/block is the intended rollback target

Do not bury this logic inside the card widget.

### 4. Add composer prefill through app-owned draft state

Likely files:

- `lib/src/features/chat/presentation/chat_composer_draft.dart`
- `lib/src/features/chat/presentation/chat_composer_draft_host.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/chat/presentation/chat_screen_contract.dart`

Pocket Relay needs a real application path to replace the composer draft after
rollback succeeds.

### 5. Add long-press UI on the real user-message surface

Files:

- `lib/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart`
- `lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart`
- `lib/src/features/chat/presentation/widgets/transcript/transcript_list.dart`

Implementation rule:

- the card remains a real app-owned transcript surface
- no Widgetbook-owned wrapper or fake surface
- the long-press only triggers app-owned behavior

## State-Update Strategy

Pocket Relay should prefer upstream truth after rollback rather than trying to
mutate the current transcript incrementally.

Recommended sequence after successful rollback:

1. receive rollback response with thread history
2. normalize upstream history
3. restore session state from normalized history
4. prefill composer draft from selected message

This matches the repo rule that Codex history is upstream truth.

## Testing Requirements

Tests should prove lifecycle and ownership, not only text presence.

### Protocol tests

Add tests for:

- request API sends `thread/rollback`
- invalid `numTurns` is rejected
- rollback response decodes through the typed history path

Likely file:

- `test/codex_app_server_client_test.dart`

### Controller tests

Add tests for:

- selecting a prior user message computes the correct rollback depth
- rollback is blocked while a turn is running
- rollback failure leaves transcript state intact
- rollback success restores upstream history and prefills composer draft

Likely file:

- `test/chat_session_controller_test.dart`

### UI tests

Add tests for:

- long-press on an eligible user message opens the action
- ineligible messages do not expose the action
- confirmation triggers controller rollback intent

Likely files:

- `test/chat_screen_app_server_test.dart`
- transcript widget tests as needed

## Suggested Implementation Order

1. Add `thread/rollback` to the app-server client layer.
2. Add controller rollback intent and upstream restore path.
3. Add composer prefill support if the current draft ownership is insufficient.
4. Add transcript item eligibility / action contract.
5. Add long-press UI and confirmation flow.
6. Add tests.
7. Verify manually against a real multi-turn thread.

## One Important User-Facing Limitation

Even with correct rollback support, Pocket Relay must clearly communicate:

- conversation history rewinds
- workspace file changes do not automatically rewind

This is not a temporary wording issue. It is part of the real protocol
contract and must remain visible anywhere the feature is presented.

## Conclusion

The reference behavior is a true thread rewind backed by upstream rollback.

Pocket Relay can support the same semantic behavior through long-press on a
previous user prompt, but only if it implements:

- real `thread/rollback`
- real transcript restoration from the rollback result
- real composer prefill after success

Pocket Relay should not ship a local-only imitation under the same product
claim.
