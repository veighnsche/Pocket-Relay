# Transcript Immutability Migration Plan

## Status

This document records the transcript design correction that is still required
after several incomplete or incorrect fixes.

The core product requirement is now explicit:

- once something is on the timeline, it must never change again
- chronology must stay readable from top to bottom
- only the active tail may mutate, and only while it is still the same
  contiguous live artifact

This plan exists because previous fixes were too local and treated individual
symptoms instead of the ownership model.

## Deviation Log

The implementation path in the current worktree did **not** follow the ideal
five-commit sequence below.

Specifically:

- the planned "Commit 1: tests only, intentionally failing" step was **not**
  kept as a pure tests-first slice
- reducer and state changes were made before preserving a clean failing-test
  checkpoint
- the document originally implied a future clean sequence, but the worktree is
  already ahead of that idealized path

This must be treated as a documented deviation, not as if the original plan was
executed correctly.

### Actual Rogue Path Taken So Far

#### Slice A: Mixed behavior + tests

This happened instead of a tests-only first commit.

Changes that were implemented together:

- `transcriptBlocks` stopped resorting committed and live rows together
- touched committed-history paths switched from upsert toward append
- `turn/diff/updated` stopped owning a visible changed-files card
- local-echo user message reconciliation was reduced to tail-only mutation
- tests were updated in the same slice instead of first being committed as
  failing expectations

Primary files touched in that slice:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)
- [`test/codex_session_reducer_test.dart`](/home/vince/Projects/codex_pocket/test/codex_session_reducer_test.dart)
- [`test/chat_screen_app_server_test.dart`](/home/vince/Projects/codex_pocket/test/chat_screen_app_server_test.dart)

#### Slice B: Live artifact forking + tail freezing

This corresponds roughly to planned commit 4, but it was also done before the
planned clean commit sequence existed.

Changes implemented:

- active items now track aggregate provider body separately from the currently
  visible artifact body
- resumed same-item output after an intervening visible artifact now forks a
  new visible card instead of rewriting the previous one
- appending a new visible turn segment freezes the previous tail first
- touched active-turn commit paths now append instead of upserting
- the dead committed-history `upsertBlock()` helper was removed
- reducer and widget regressions were added for interrupted assistant and
  changed-files resumption

Primary files touched in that slice:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart)
- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)
- [`lib/src/features/chat/application/transcript_policy_support.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy_support.dart)
- [`test/codex_session_reducer_test.dart`](/home/vince/Projects/codex_pocket/test/codex_session_reducer_test.dart)
- [`test/chat_screen_app_server_test.dart`](/home/vince/Projects/codex_pocket/test/chat_screen_app_server_test.dart)

#### Slice C: Plan rewrite before implementation checkpoint

This happened after `Commit A` landed, but before `Commit B` implementation had
started.

What went wrong:

- the migration document and handoff were edited to narrow `Commit B` and
  `Commit C`
- that clarification was directionally correct, but it was done before logging
  the deviation itself
- this created the appearance that the plan had simply evolved cleanly, instead
  of recording that the previous framing was loose enough to allow another
  rogue implementation path

What this change actually means:

- the updated `Commit B` / `Commit C` boundaries should be treated as a
  corrective planning fix, not as implementation progress
- no live-artifact ownership work was completed as part of this document change
- the repo must not treat the tighter wording as proof that the migration is
  back on track by itself

### Practical Consequence

The "Five Commit Migration Plan" below is now a **target structure**, not an
accurate log of what already happened.

Future work must assume:

- there is no clean historical "tests only" checkpoint in the current worktree
- some later-plan behavior is already partially implemented
- remaining work should start from the current code reality, not from the
  original ideal sequence
- even the rebased plan has already needed a documented correction of commit
  boundaries after implementation had begun

If a clean history is still desired, the remaining commits should explicitly say
that the original sequence was violated and that the history is being resumed
from an already-mutated baseline.

## Rebased Migration Path From Current Worktree

This section supersedes the original idealized sequence as the practical path
forward from the current code reality.

### Baseline Commit: Partial Immutability Rebase

Status:

- should capture the current worktree as one explicit re-baseline commit

What this baseline already includes:

- committed transcript rows are no longer globally resorted with live rows
- touched commit paths append rather than upsert
- `turn/diff/updated` no longer owns a visible changed-files card
- repeated plan updates append as separate timeline artifacts
- interrupted same-item assistant and changed-files output now fork a new
  visible card
- appending a new visible tail freezes the previous tail first
- regression coverage exists for interrupted item resumption

This baseline is not the end state. It is the starting line for the remaining
cleanup.

### Commit A: Explicit Turn Snapshot State

Status:

- implemented in the current worktree after the partial immutability rebase

Goal:

- stop treating `turn/diff/updated` as either a transcript owner or a silent
  no-op

Changes:

- add explicit turn snapshot fields under active turn state
- store `turn/diff/updated` there
- keep token-usage and similar turn-level snapshot data in the same ownership
  domain where appropriate
- use snapshot state only for supporting/detail surfaces, never timeline
  ownership

Exit criterion:

- turn-level aggregate data exists in state explicitly, with zero visible
  transcript mutation

### Commit B: Replace Ad Hoc Segment Mutation With First-Class Live Artifacts

Status:

- implemented in the current worktree for live artifact ownership
- remaining immutable-history cleanup is intentionally deferred to Commit C

Goal:

- finish the ownership split that is currently only partially enforced

Changes:

- replace generic segment mutation rules with explicit live artifact instances
- define artifact boundary rules by visible interruption, not by helper
  convention
- make assistant, reasoning, work, plan, changed-files, and resolved-request
  artifacts all obey the same contiguous-tail rule
- stop relying on shared projection/grouping logic to infer transcript
  semantics after the fact
- remove render-time work-log grouping from transcript projection and make work
  grouping a first-class live artifact concern instead
- stop routing resolved request artifacts through generic segment upsert helpers
  that still imply mutable transcript ownership

Explicitly not in this commit:

- optimistic user-message provider/local-echo reconciliation
- cleanup of committed-history mutation for already-sent user messages
- broader removal of legacy helper APIs whose only remaining caller is the
  user-message flow

Exit criterion:

- one active contiguous artifact may mutate, and every older artifact is frozen
  by construction

What the current worktree now covers:

- `CodexActiveTurnState` owns explicit live artifacts instead of generic
  segments
- assistant, reasoning, plan, changed-files, and resolved-request cards all
  project one artifact to one visible block
- work grouping is now owned by a live work artifact instead of being inferred
  in `transcriptBlocks`
- consecutive work items append into one live work artifact until another
  visible artifact interrupts them
- resolved requests append through the same live-artifact append path instead of
  a request-only upsert helper
- reducer and widget coverage exist for grouped work artifacts, interrupted work
  history, and grouped app-server work rendering

### Commit C: Remove Remaining Timeline Mutation Exceptions

Status:

- implemented in the current worktree for optimistic local user-message
  suppression and request-resolution idempotence

Goal:

- eliminate the remaining special cases that still blur committed history with
  live workflow state

Changes:

- move optimistic user-message provider reconciliation out of committed block
  mutation
- ensure pending approvals and pending user-input requests stay off-timeline
  until resolution
- make resolution artifacts append-only events
- remove any remaining helper APIs that imply transcript replacement semantics

Dependency on previous commit:

- do not start this commit until Commit B owns live artifact boundaries directly
- this commit is for the remaining committed-history mutation seams, not for
  finishing live artifact grouping by another route

Exit criterion:

- committed history is append-only across user, request, and item flows

What the current worktree now covers:

- locally appended user prompts are now permanent transcript artifacts instead
  of mutable local-echo cards
- provider user-message echoes bind to those prompts in non-visual state rather
  than rewriting the visible block
- multiple unresolved local prompts are tracked as a queue so late provider
  echoes still suppress the correct prompt without mutating history
- duplicate request-resolution notifications remain idempotent instead of
  appending duplicate `request_$id` artifacts

### Commit D: Chronology And Parity Sweep

Goal:

- verify the architecture against the actual UX contract and the local Codex
  reference

Changes:

- add focused runtime scenarios for interrupted/resumed items, interleaved
  work/assistant output, repeated plans, sequential file changes, and request
  resolution
- run emulator checks on those scenarios
- remove stale tests and docs that still encode the old mutable-timeline model
- update handoff docs from the final state rather than from migration intent

Exit criterion:

- the remaining transcript behavior is described by current docs, not by
  historical cleanup notes

## Reference Interpretation

The local reference Codex clone is:

- `.reference/codex`

Important reference findings:

- plan updates are append-only visible history in the TUI
- file changes are shown as discrete visible artifacts in transcript history
- `turn/diff/updated` is an authoritative turn-level aggregate snapshot, not
  proof that the visible transcript should collapse into one mutable card
- Codex separates live/in-flight behavior from committed history more strongly
  than the current Pocket Relay reducer/state model

Relevant reference paths:

- `.reference/codex/codex-rs/tui/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui/src/history_cell.rs`
- `.reference/codex/codex-rs/tui/src/diff_render.rs`
- `.reference/codex/codex-rs/app-server/README.md`

## What Went Wrong

The repeated failure pattern was:

1. identify one visible symptom
2. patch the nearest reducer or transcript card path
3. preserve the underlying mutable timeline model
4. pass tests that only prove the patch, not the real contract

That produced multiple wrong fixes:

- treating `turn/diff/updated` as the owner of the visible changed-files card
- allowing committed history to be rewritten via upsert semantics
- deriving transcript order by sorting mixed committed and live content
- validating protocol/state correctness while missing transcript chronology

The result is a transcript that behaves more like a mutable dashboard than a
permanent event history.

## Non-Negotiable Contract

These are the target semantics.

### 1. Committed history is immutable

Once a block is committed to the timeline:

- its content does not change
- its relative position does not change
- it is never replaced in place
- later events may add new blocks, but may not rewrite old ones

### 2. Only the live tail may mutate

There is one allowed exception:

- the currently active tail card may change while it is still the same
  contiguous live artifact

That means:

- repeated deltas for the same still-live artifact may update the tail
- if a different artifact appears, the previous tail is frozen forever
- if the same item type resumes later, it gets a new card

### 3. Aggregate snapshots are state, not timeline owners

Events like `turn/diff/updated` may update turn state, but they must not own or
rewrite committed history.

### 4. The past should preserve reading order

The transcript must reflect chronological arrival order, not a re-sorted view
computed from mixed state.

## Current Mutation Seams

These are the concrete code paths that currently violate or weaken the target
contract.

### Committed history mutation

Current status:

- the shared committed-history `upsertBlock()` helper has already been removed
  from [`lib/src/features/chat/application/transcript_policy_support.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy_support.dart)
- the original seam is therefore no longer the primary risk
- the remaining risk is any still-mutable live path that later commits into
  history incorrectly

### Transcript built from mixed committed + live state

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart)
  `transcriptBlocks` combines committed `blocks` with projected `activeTurn`
  segments.

Current status:

- the old sort-by-`createdAt` reconstruction was already removed
- the remaining architectural issue is that committed history and projected live
  state still share one rendering pipeline instead of being modeled as more
  explicit ownership domains

### Active-turn mutation by stable item identity

- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart)
  `upsertItem()` still exists, but the worktree now partially compensates by
  forking a new visible artifact when the old segment is no longer the tail.

Current status:

- interrupted same-item assistant and changed-files output now fork new visible
  cards
- this area is improved but still not the clean final model described below

### Committing active-turn content by upsert

- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
  `_commitActiveTurn()` used to project live segments and upsert them into
  committed history.

Current status:

- the touched commit path now appends projected blocks instead of upserting
- this seam is partially closed

### Mutable turn-level changed-files ownership

- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
  `applyTurnDiffUpdated()` used to create one stable changed-files block per
  turn id, causing visible accumulation into a single mutable card.

Current status:

- the worktree currently keeps `turn/diff/updated` out of visible transcript
  history
- explicit turn snapshot ownership is still missing; the event is effectively a
  visible no-op right now rather than a modeled turn snapshot

### Committed local-echo user message reconciliation

- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)
  the old committed local-echo rewrite path used to mutate already committed
  user message blocks.

Current status:

- locally appended user prompts no longer mutate when provider user-message
  events arrive
- provider linkage now lives in non-visual session state instead of rewriting
  the visible user-message block

## Design Direction

The architecture should be split into two explicit ownership domains.

### A. Committed timeline history

Properties:

- append-only
- arrival-order preserving
- immutable after commit
- directly rendered as transcript history

Suggested shape:

- `committedBlocks: List<CodexUiBlock>`

### B. Live tail state

Properties:

- mutable
- transient
- bounded to the active turn
- not part of committed history until frozen/committed

Suggested shape:

- `activeTurn.liveSegments`
- optional turn snapshots such as current diff snapshot, pending usage snapshot,
  pending approvals, pending input

The transcript surface should render:

- committed immutable history
- followed by projected live tail blocks

No sort pass should reorder that final list.

## Edge Cases That Must Be Supported

The next implementation must handle these explicitly.

### Repeating deltas for the same live artifact

Allowed:

- the tail mutates while the artifact is still contiguous and active

Not allowed:

- an old card higher in history changes after later cards exist

### Same item resumes after interruption

If the same item continues after another visible artifact appears:

- the previous visible card is frozen
- the resumed output starts a new visible card

### Turn-level diff snapshots

`turn/diff/updated` may still matter for:

- authoritative current turn state
- detail sheets
- internal reconciliation

But it must not rewrite visible file-change history.

### Pending requests

Pending approvals and user input are live workflow state, not committed history.
Their eventual resolution should append immutable history artifacts.

### Local-echo user messages

The optimistic local echo should not be rewritten after commit. Provider linkage
must be tracked outside the committed block itself.

## Five Commit Migration Plan

This work should be executed as five separate commits so progress and mistakes
are easy to inspect and revert.

### Commit 1: Lock The Contract In Tests

Goal:

- make the intended behavior executable before changing state ownership

Changes:

- add reducer tests that prove committed blocks never mutate
- add widget tests that prove chronology is preserved
- add tests that prove only the live tail may mutate
- add tests that prove `turn/diff/updated` does not own visible transcript
  history
- replace existing tests that currently lock in the wrong changed-files
  convergence behavior

Required failing cases to encode:

- past changed-files cards must not merge into one mutable card
- past plan cards must not change
- resumed same-item output after an interruption must create a new card

Exit criterion:

- tests fail on current implementation for the right reasons

### Commit 2: Split Committed History From Live Tail State

Goal:

- make the ownership model explicit

Changes:

- refactor `CodexSessionState` so committed history and live tail state are
  stored separately
- remove transcript construction that mixes committed blocks and live segments
  and then sorts them
- make `transcriptBlocks` render committed history first and live tail second

Primary files:

- [`lib/src/features/chat/models/codex_session_state.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_session_state.dart)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)

Exit criterion:

- the state model can express immutable history plus mutable tail separately

### Commit 3: Remove Aggregate Snapshot Ownership From Timeline

Goal:

- stop `turn/diff/updated` from owning visible changed-files history

Changes:

- move turn diff handling to live turn snapshot state only
- keep visible changed-files transcript ownership on file-change item artifacts
- ensure plan updates remain append-only
- ensure turn snapshots can still power any detail views without mutating
  committed history

Primary files:

- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
- [`lib/src/features/chat/application/transcript_changed_files_parser.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_changed_files_parser.dart)

Exit criterion:

- no visible transcript card is rewritten by `turn/diff/updated`

### Commit 4: Replace Stable Item Upserts With Live Artifact Instances

Goal:

- implement the “only the active tail may mutate” rule

Changes:

- stop treating one `itemId` as one permanently mutable visible segment
- introduce live artifact instances representing one contiguous visible run
- mutate only the last active instance while it stays contiguous
- freeze and fork a new instance when another visible artifact interrupts the
  stream

Primary files:

- [`lib/src/features/chat/application/transcript_turn_segmenter.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_turn_segmenter.dart)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)

Exit criterion:

- the same item can create multiple immutable visible artifacts over time

### Commit 5: Finalize Commit Semantics And Remove Legacy Mutation Paths

Goal:

- make append-only history the only transcript model left in the codebase

Changes:

- change active-turn commit to append frozen blocks in order
- remove committed-history `upsertBlock()` call sites for transcript ownership
- remove committed user-message reconciliation
- keep pending request workflow state off-timeline until resolution
- clean out obsolete helper paths and incorrect tests
- update handoff docs after behavior is verified

Primary files:

- [`lib/src/features/chat/application/transcript_policy_support.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy_support.dart)
- [`lib/src/features/chat/application/transcript_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_policy.dart)
- [`lib/src/features/chat/application/transcript_item_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_item_policy.dart)
- [`lib/src/features/chat/application/transcript_request_policy.dart`](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/transcript_request_policy.dart)

Exit criterion:

- committed history is append-only by construction

## Verification Requirements

Each commit in the migration must end with:

- `dart analyze`
- focused reducer tests for the changed invariant
- focused widget tests for the visible transcript behavior

Additional runtime verification is required after commits 3 through 5:

- emulator check for repeated plan updates
- emulator check for sequential file changes
- emulator check for interrupted and resumed same-item output
- emulator check for approval/input request resolution history

## Definition Of Done

The migration is only done when all of the following are true:

- committed timeline blocks never mutate after commit
- transcript order matches event arrival order
- only the live tail may mutate
- repeated file changes no longer collapse into one mutable “all changes so far”
  card
- `turn/diff/updated` no longer owns visible timeline artifacts
- the reducer and widget tests prove those semantics directly

## Immediate Next Read

The next agent working on transcript parity should read this document before
touching transcript reducers again.
