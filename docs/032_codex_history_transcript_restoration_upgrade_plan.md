# 032 Codex History Transcript Restoration Upgrade Plan

## Status

Proposed architectural upgrade plan.

This plan defines the correct upgrade path for historical conversation
restoration while keeping Codex as the only source of truth.

## Goal

Make conversation history restoration architecturally sound.

That means:

- conversation discovery comes from Codex
- historical transcript content comes from Codex
- Pocket Relay does not invent or persist its own historical transcript archive
- restoring a saved conversation shows the real transcript on screen when
  upstream Codex provides it
- failures are honest when upstream Codex does not provide enough information

## Non-Negotiable Constraints

- Pocket Relay will not own a persisted local history store.
- Pocket Relay will not own a persisted local transcript archive.
- Pocket Relay may still own local live session state and live conversation
  descriptors for the active UX, as long as those remain non-authoritative and
  are not treated as historical truth.
- Cross-device resume must work from upstream Codex truth, not from app-local
  data.
- `threadId` remains the only historical conversation identity.
- The upgrade path must reduce ambiguity and hidden coupling, not add another
  provisional layer that will need to be removed later.

## Current Architecture

### Discovery Path

The history drawer currently loads conversation summaries through:

- `lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`

That repository:

- connects to Codex
- lists threads
- filters them by workspace path
- reads per-thread details
- produces summary rows for the drawer

### Selection Path

Selecting a history row currently flows through:

- `lib/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart`
- `lib/src/features/workspace/presentation/connection_workspace_controller.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`

### Persistence Path

The only durable local conversation state is:

- `selectedThreadId`

It is stored through:

- `lib/src/core/storage/codex_connection_conversation_history_store.dart`

That is the correct local ownership boundary.

### Restoration Path

Historical transcript restoration currently happens in:

- `lib/src/features/chat/application/chat_session_controller.dart`

It reads:

- `readThreadWithTurns(threadId: ...)`

Then it rebuilds transcript by replaying synthetic runtime events through:

- `lib/src/features/chat/application/runtime_event_mapper_history_mapper.dart`
- `lib/src/features/chat/application/runtime_event_mapper.dart`
- `lib/src/features/chat/application/transcript_reducer.dart`

## Current Architectural Problems

### 1. Overloaded Upstream Model

`CodexAppServerThread` is used for both:

- thread summary/discovery data
- historical transcript restoration data

That is structurally weak.

The summary case and the full-history case are different contracts and should
not share one partially-typed model.

### 2. History Parsing Is Based On Raw Maps

The current restore path depends on:

- `thread.turns`
- `turn.items`

stored as raw `Map<String, dynamic>` data.

That means the core restore path has no explicit upstream contract.

### 3. Snapshot Restore Is Mixed Into Live Event Mapping

`RuntimeEventMapper` is meant for live app-server events.

Historical thread restoration is a different concern:

- it is a snapshot load, not a live event stream
- it should not depend on guessed synthetic event replay unless that replay is
  formally defined and contract-backed

Right now the code blurs those responsibilities.

### 4. `ChatSessionController` Owns Too Much Of Restore

The controller currently:

- persists selected thread intent
- fetches upstream thread history
- translates that history
- rebuilds transcript state
- handles load failure

That is too much ownership concentration.

### 5. Empty Restore Can Still Look Like Success

The restore path currently treats "request succeeded but produced no visible
transcript" as a normal success path.

That is not acceptable for historical transcript restoration because the user
cannot distinguish:

- true empty upstream history
- partial upstream payload
- parser mismatch
- restoration bug

### 6. Tests Are Too Synthetic

Current restore tests fabricate a narrow `thread.turns[].items[]` shape that
matches the current parser assumptions.

That does not prove compatibility with the real upstream `thread/read` payload.

## Target Architecture

The correct end state should have four explicit layers.

### 1. Codex History Discovery Boundary

Responsibility:

- load historical conversation summaries for the workspace

Owner:

- `CodexWorkspaceConversationHistoryRepository`

Output:

- summary rows only

No transcript reconstruction belongs here.

### 2. Codex Thread History Contract Boundary

Responsibility:

- decode the real `thread/read(includeTurns: true)` payload into explicit typed
  upstream models

Owner:

- chat app-server infrastructure layer

Recommended model split:

- `CodexAppServerThreadSummary`
- `CodexAppServerThreadHistory`
- `CodexAppServerHistoryTurn`
- `CodexAppServerHistoryItem`

This removes the current overloaded `CodexAppServerThread` responsibility.

### 3. Historical Conversation Normalization Boundary

Responsibility:

- transform the typed upstream history payload into a normalized
  app-consumable history snapshot

Owner:

- dedicated history decoder / normalizer under
  `lib/src/features/chat/application/` or `infrastructure/`

Recommended output:

- a normalized historical conversation snapshot model
- not raw maps
- not synthetic live events as the primary representation

### 4. Transcript Restoration Boundary

Responsibility:

- project a normalized historical snapshot into `CodexSessionState`

Owner:

- dedicated restoration service or projector

Recommended collaborator:

- `ChatHistoricalConversationRestorer`

`ChatSessionController` should orchestrate this boundary, not implement it.

## Upgrade Strategy

This work should be done in phases with hard decision gates.

## Phase 0. Contract Capture And Decision Gate

### Goal

Establish the real upstream history contract before making more behavioral
changes.

### Work

1. Capture one or more real `thread/read(includeTurns: true)` payloads from
   Codex.
2. Store sanitized fixtures for tests.
3. Document the observed payload shapes:
   - user prompt items
   - assistant messages
   - reasoning
   - plan updates
   - command/work items
   - file changes
   - usage
   - timestamps
4. Add contract tests for the current decoder against those real fixtures.

### Decision Gate

After contract capture, decide which of these is true:

1. Codex returns enough transcript history to rebuild the lane.
2. Codex does not return enough transcript history.

If case 2 is true, stop the frontend restoration rollout and raise a backend
capability requirement. Do not paper over the missing upstream data with a
local substitute.

### Expected files

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- new sanitized fixture files under `test/fixtures/` or equivalent
- new decoder contract tests

## Phase 1. Separate Summary Models From Full History Models

### Goal

Remove the current overloaded app-server thread model.

### Work

1. Keep one model for summary/listing use.
2. Introduce a dedicated model for `thread/read(includeTurns: true)`.
3. Make `readThreadWithTurns()` return the full-history model, not the summary
   model with a raw `turns` field.
4. Keep the history drawer repository using summary data only where possible.

### Result

- explicit upstream contract
- no more raw-map restore dependency at the top level
- less accidental coupling between drawer summaries and transcript restoration

### Expected files

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_models.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- `lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`

## Phase 2. Introduce A Dedicated History Decoder

### Goal

Normalize the full-history payload without routing it through live event
semantics first.

### Work

1. Add a dedicated decoder/normalizer for historical threads.
2. Normalize upstream item variants into one app-owned snapshot model.
3. Handle missing fields and payload variations explicitly.
4. Keep payload-to-domain mapping isolated from UI and controller code.

### Result

- one place owns upstream history parsing
- real payload shape changes are localized
- tests can validate normalization directly

### Recommended new types

- `CodexHistoricalConversation`
- `CodexHistoricalTurn`
- `CodexHistoricalTranscriptEntry`

### Expected files

- new files under `lib/src/features/chat/application/` or
  `lib/src/features/chat/infrastructure/app_server/`
- new focused tests for normalization

## Phase 3. Replace Synthetic Event Replay With Explicit Restoration

### Goal

Stop treating snapshot restoration as a fake live event stream unless the real
contract proves that replay is the cleanest durable model.

### Work

1. Add a dedicated restorer/projector that converts the normalized historical
   conversation snapshot into `CodexSessionState`.
2. Make `ChatSessionController` delegate to that restorer.
3. Remove or shrink `runtime_event_mapper_history_mapper.dart` if it is no
   longer the right ownership boundary.
4. Keep `RuntimeEventMapper` focused on actual live app-server events.

### Result

- clearer boundary between:
  - live runtime mapping
  - historical snapshot restoration
- less churn when upstream history and live event payloads diverge

### Expected files

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/application/runtime_event_mapper_history_mapper.dart`
- new restorer/projector file(s)

## Phase 4. Honest UI States For Historical Restore

### Goal

Make the product honest when restoration is partial or impossible.

### Work

1. Add an explicit loading state for history restore.
2. Add an explicit empty/incomplete-history state when upstream data is
   insufficient to rebuild the transcript.
3. Distinguish:
   - restore failed
   - restore returned no usable transcript
   - restore succeeded
4. Keep the summary list and restored transcript conceptually separate.

### Result

The user can tell whether:

- the conversation title was found
- the transcript is actually available
- Codex did not return enough history to render the transcript

### Expected files

- `lib/src/features/chat/application/chat_session_controller.dart`
- `lib/src/features/chat/presentation/`
- widget tests for visible restore states

## Phase 5. Verification And Cleanup

### Goal

Prove the architecture is correct and remove transitional seams.

### Work

1. Replace synthetic restore fixtures with real captured payload fixtures.
2. Add end-to-end tests for:
   - history drawer summary discovery
   - tapping a history row
   - transcript restoration
   - honest incomplete-history UI
3. Remove any transitional fallback logic introduced during the migration.
4. Update docs to reflect the final ownership model.

### Result

- one source of truth
- one restore path
- no hidden fallback design
- no synthetic-contract dependency left in the production path

## Recommended File Ownership After Migration

### Workspace layer

- discover available history rows
- route resume intent

### Chat application layer

- request restoration
- apply restored conversation state
- expose honest restore status to presentation

### App-server infrastructure layer

- decode real upstream thread history contracts

### Local storage layer

- persist only narrow lane state such as `selectedThreadId`

## Definition Of Done

The work is done only when all of the following are true:

1. A real Codex `thread/read(includeTurns: true)` contract is captured and
   tested.
2. Historical transcript restoration is based on that real contract, not an
   invented fixture shape.
3. The app does not own a persisted local transcript archive.
4. Restoring a historical conversation either:
   - shows the real transcript on screen, or
   - shows an explicit honest state that Codex did not provide enough history.
5. The controller no longer owns raw history decoding details directly.
6. The final design reduces future churn instead of introducing another
   temporary seam that must later be removed.
