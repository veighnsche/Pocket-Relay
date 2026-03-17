# UX Hardening Investigation

This document turns the hardening audit into concrete UX guidance.

The goal is not "remove all fallbacks."

The goal is:

- stop the app from sounding more certain than it is
- stop the app from changing remote truth while preserving a conflicting local
  story
- keep helpful recovery where it is genuinely safe

This investigation is based on the current implementation in:

- `application/chat_session_controller.dart`
- `infrastructure/app_server/codex_app_server_request_api.dart`
- `presentation/pending_user_input_presenter.dart`
- `presentation/chat_pending_request_placement_projector.dart`
- `presentation/widgets/flutter_chat_screen_renderer.dart`
- `application/transcript_changed_files_parser.dart`

## Core UX Rule

There are 3 levels of hardening:

1. Safe hardening
   - deduplicates noise
   - ignores stale async work
   - preserves user truth
2. Labeled inference
   - fills a small gap
   - is reversible
   - is clearly presented as inferred, provisional, or derived
3. Unsafe hardening
   - changes conversation ownership, request meaning, or transcript truth
   - but keeps the old user-facing story on screen

Level 3 is the class that caused the lost-thread UX failure.

## UX Principles

### 1. Conversation continuity is sacred

If the app is no longer sure that the user is talking to the same remote
conversation, the UI must stop claiming continuity.

### 2. Ownership and metadata are different

It is acceptable to infer display metadata in some cases.

It is not acceptable to infer ownership from weak signals.

### 3. Unknown is not progress

If the app does not know, it should say it does not know.

`Unknown`, `Syncing`, and `Needs review` are honest.

`Starting`, `Recovered`, and `Ready` imply stronger truth.

### 4. Suppressed state still needs representation

If the app collapses a queue for clarity, the user still needs to know the
queue exists.

### 5. Derived artifacts should be labeled

If the UI is showing a synthesized or inferred artifact, it should say so.

That keeps convenience from turning into deception.

## Case 1: Live Tracked Thread Reuse

### Current behavior

If local continuation ownership is missing, the controller can reuse the
transport's currently tracked thread and tell the user:

- `Recovered the active conversation from the live session.`

### Why this feels bad

This is still a guess about ownership.

The user did not choose that thread in the UI.

The transport may know only:

- one session is connected
- one thread id is tracked

That is weaker than:

- the user intentionally chose this conversation
- the visible transcript belongs to this conversation

### Best UX

Do not auto-send into that thread.

If the app has a typed prompt and only heuristic evidence of the target thread,
show a blocking recovery state before sending.

### Recommended interaction

Show a pinned recovery card or modal:

- Title: `Conversation state needs confirmation`
- Body:
  - `Pocket Relay found a live remote conversation, but it cannot prove it matches the transcript on screen.`
- Actions:
  - `Continue Live Session`
  - `Start New Conversation`
  - `Cancel`

### Important behavior

- Keep the typed prompt in the composer.
- Do not append a local sent message yet.
- Do not mutate the visible transcript.
- If the user chooses `Continue Live Session`, mark the transcript boundary
  explicitly with a status block:
  - `Connected to live session after state recovery.`
- If the user chooses `Start New Conversation`, clear ownership and send into a
  fresh thread.

### Why this is better

It keeps the app helpful without pretending the decision is certain.

## Case 2: Missing Thread Object In Start Or Resume Responses

### Current behavior

The request API can construct a thread model from a bare thread id when the
server does not send a full thread object.

### Why this feels bad

For ownership-establishing flows, a bare id is not enough proof that the start
or resume response is valid in the way the UI expects.

This is not a display convenience anymore.

This is session truth.

### Best UX

Split ownership from ornament.

#### Ownership-establishing responses

For:

- `thread/start`
- `thread/resume`

fail hard if the response shape is incomplete.

Show a transport-level failure:

- Title: `Conversation start failed`
- Body:
  - `The remote session responded without enough conversation data to continue safely.`
- Actions:
  - `Retry`
  - `Start Fresh`

#### Metadata-only enrichment

For:

- `thread/read`
- best-effort timeline naming

it is acceptable to use placeholder labels until metadata arrives.

Examples:

- `Main`
- `Agent`
- `Untitled thread`

### Why this is better

It protects the trust boundary:

- ownership must be proved
- labels can be refined later

## Case 3: Fallback Free-Form Input Field

### Current behavior

If a user-input request contains no questions, the presenter creates a generic
`Response` field.

### Why this is risky

There are two very different situations:

1. the protocol intentionally requested an open-ended answer
2. the request payload is incomplete or malformed

The current UI treats both cases the same.

### Best UX

Only invent a free-form field for request types that are explicitly allowed to
be free-form.

### Recommended interaction

#### Known-safe free-form request

For known elicitation-style requests:

- Title stays as-is
- Body stays as-is
- Field label:
  - `Your response`
- Helper text:
  - `Codex requested an open-ended answer.`

#### Unknown or malformed request

Do not fabricate a form.

Show a request error card:

- Title: `Input request could not be rendered`
- Body:
  - `Pocket Relay received an input request without enough structure to show a safe response form.`
- Actions:
  - `Try again`
  - `Copy request details`

### Why this is better

It preserves the difference between:

- "Codex asked an open question"
- "Pocket Relay could not understand the request"

## Case 4: Oldest-Only Pending Request Selection

### Current behavior

The pinned region shows:

- at most one approval request
- at most one user-input request

The rest are hidden until the visible one resolves.

### Why this feels bad

This is understandable as layout hardening, but if the UI does not show queue
state, the hidden requests feel missing rather than deferred.

The current pinned region is also large enough to support lightweight queue
state.

### Best UX

Keep the current compact surface, but make suppression visible.

### Recommended interaction

#### For approvals

On the visible approval card, add queue status:

- `Approval 1 of 3`

If more approvals exist, add a secondary action:

- `Show remaining approvals`

This can expand an inline list or open a bottom sheet.

#### For user-input requests

On the visible request card, add queue status:

- `Question 1 of 2 pending requests`

If only one request can be active for draft purposes, the others should still be
listed as waiting:

- `Next: "Which second project should I use?"`

### Important behavior

- Preserve separate drafts per request id.
- When the visible request resolves, promote the next request with a subtle
  transition, not a disappearance.
- Never silently discard hidden queue context.

### Why this is better

It keeps the compact layout without implying that only one request exists.

## Case 5: Unknown Lifecycle Rendered As "Starting"

### Current behavior

The timeline chip renders `unknown` status as `Starting`.

### Why this feels bad

`Starting` implies known progress.

`Unknown` means the app does not yet know the state.

This is a small wording bug, but it chips away at trust in the same direction
as the bigger issues.

### Best UX

Use language that matches certainty.

### Recommended labels

- `unknown` -> `Syncing`
- `starting` -> `Starting`
- `idle` -> `Ready`
- `running` -> `Running`

If you want stricter honesty:

- `unknown` -> `Unknown`

### Why this is better

It stops the app from framing uncertainty as progress.

## Case 6: Synthesized Changed-File Diffs

### Current behavior

The parser can synthesize a unified diff from structured change data.

The changed-files UI then presents a diff viewer that can look canonical.

### Why this is risky

A synthesized diff is useful, but it is not always the exact original patch.

If the UI does not distinguish it, the user may assume:

- exact hunk boundaries
- exact context lines
- exact patch fidelity

### Best UX

Keep the synthesized preview, but label it.

### Recommended interaction

On derived diff entries:

- badge: `Derived diff`
- action label: `Preview diff`

Inside the diff sheet:

- banner text:
  - `This preview was reconstructed from structured file-change data and may not match the exact original patch.`

If the diff is exact, keep the current stronger language:

- `Open diff`

### Why this is better

The preview stays useful, but the product stops overstating precision.

## What Should Stay As-Is

These hardening behaviors currently look correct.

### Duplicate SSH failure suppression

Keep it.

This removes duplicate noise after a typed SSH failure is already shown.

### Exact local user-message echo suppression

Keep it.

This deduplicates the provider echo without changing meaning.

### Ignore stale async completions after rebind

Keep it.

This prevents old async work from mutating a newer UI tree.

## Recommended Product Order

### First

Fix conversation ownership recovery.

This is the only remaining case that is closest to the original trust break.

### Second

Separate ownership-establishing protocol failures from metadata enrichment.

### Third

Make hidden pending queues visible.

### Fourth

Narrow free-form input fallbacks to known-safe request types.

### Fifth

Relabel unknown and derived states so they stop sounding definitive.

## Acceptance Criteria

This investigation is satisfied only when the app no longer does any of the
following:

- silently continues a conversation when ownership is uncertain
- invents request structure when the protocol may be malformed
- hides additional pending actions without any queue signal
- labels unknown state as active progress
- presents derived artifacts as exact ones

## Short Product Rule

Pocket Relay may be convenient.

Pocket Relay may not be falsely certain.
