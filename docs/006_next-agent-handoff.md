# Next Agent Handoff

## Baseline

Pocket Relay is currently at a stable baseline for these completed areas:

- system theme only, with the manual light/dark toggle removed
- per-turn elapsed timer footer
- monotonic timer semantics with pause/resume for blocked turns
- lifecycle hardening for app ownership, screen ownership, transport disposal,
  keyed transcript identity, and user-input controller resync
- markdown package migration to `flutter_markdown_plus`
- preferences migration to `SharedPreferencesAsync`

Reference Codex source is available locally at:

- `.reference/codex`

The most relevant planning documents already in the repo are:

- `docs/004_codex-parity-maturity-plan.md`
- `docs/011_transcript-immutability-migration-plan.md`
- `docs/005_component-lifecycle-audit-plan.md`

Important note:

- `docs/011_transcript-immutability-migration-plan.md` is now the canonical
  transcript chronology status summary
- the transcript ownership rewrite is already in place; the remaining work is
  live verification plus the local build/runtime blocker described in that doc

This document is the short operational handoff for the next agent.

## What Is Still Left To Do

### 1. Reasoning parity

Current state:

- live reasoning is still represented as transcript content

Target state:

- live reasoning should drive a transient status surface first
- completed reasoning should become a compact, lower-emphasis artifact
- reasoning should stop dominating the main transcript during streaming

Primary code areas:

- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy_support.dart`
- `lib/src/features/chat/models/codex_ui_block.dart`
- `lib/src/features/chat/presentation/widgets/transcript/`

Reference Codex areas:

- `.reference/codex/codex-rs/tui/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui/src/history_cell.rs`

### 2. Transcript chronology parity finish

Current state:

- the transcript ownership rewrite is already in place
- live artifacts now explicitly own assistant/reasoning/plan/changed-files/work
  and resolved-request transcript runs
- render-time work-log grouping has been removed in favor of live work
  artifacts
- local user prompts no longer mutate when provider user-message echoes arrive
- duplicate request-resolution notifications are now idempotent
- opening an approval or user-input request now freezes the current live tail
  before the pending overlay takes over
- reducer and widget parity coverage landed for:
  - interrupted/resumed assistant history
  - assistant -> work -> assistant chronology
  - repeated plan updates
  - sequential distinct file-change artifacts
  - pending request chronology and request-open tail freeze
  - same-item file-change resumption after approval interruption

Live verification status:

- a real app-server run already confirmed chronological `assistant ->
  assistant -> updated plan` behavior, with earlier cards staying frozen
- a real emulator run also confirmed sequential file changes render as separate
  `Changed files` cards in order
- the current worktree fixes one additional live transport bug:
  `approvalPolicy` now uses `on-request` instead of `onRequest`
- a fresh live rerun is currently blocked by local build/runtime issues:
  Android rebuilds cannot currently be installed from this environment, and
  Linux debug runs are missing `libsecret`

Remaining concrete tasks:

- rerun the emulator/manual Commit D sweep once a fresh build can be launched:
  - assistant -> work -> assistant
  - assistant -> approval open -> resolved -> assistant resumes
  - assistant -> user-input open -> resolved -> assistant resumes
  - repeated plan updates
  - sequential file changes
  - resumed same-item output after warnings/requests
- confirm during that sweep that older transcript cards never mutate or reorder
- compare those flows against `.reference/codex/codex-rs/tui/src/chatwidget.rs`
  chronology behavior
- if a mismatch appears, add the smallest focused reducer/widget regression and
  patch only that behavior
- if the live rerun stays clean, treat transcript chronology as done and move
  on to reasoning parity

Primary code areas:

- `lib/src/features/chat/application/transcript_reducer.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/application/runtime_event_mapper.dart`
- `lib/src/features/chat/models/codex_session_state.dart`

Reference Codex areas:

- `.reference/codex/codex-rs/tui/src/chatwidget.rs`

### 3. Markdown and file-link normalization

Current state:

- markdown rendering is generic
- file links do not yet follow Codex-style path presentation

Target state:

- normalize local file links before rendering
- display cwd-relative paths consistently
- apply the same link rules to assistant content, plans, and reasoning artifacts

Primary code areas:

- `lib/src/features/chat/presentation/widgets/transcript/support/markdown_style_factory.dart`
- `lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart`
- `lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart`
- `lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart`

Reference Codex areas:

- `.reference/codex/codex-rs/tui/src/markdown_render.rs`

### 4. Work-only completion semantics

Current state:

- elapsed completion UI is always available when a turn timer exists

Target state:

- distinguish turns that actually performed work from simple answer turns
- consider suppressing explicit completion text for short or non-work turns
- align more closely with Codex "worked for ..." semantics

Primary code areas:

- `lib/src/features/chat/models/codex_session_state.dart`
- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart`

Reference Codex areas:

- `.reference/codex/codex-rs/tui/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui/src/history_cell.rs`

## Recommended Execution Order

1. Finish transcript chronology parity close-out (`Commit D`)
2. Reasoning parity
3. Markdown and file-link normalization
4. Work-only completion semantics

This order matters. The transcript ownership rewrite is already in place, so it
should be closed out with the remaining live parity rerun before broader parity
work moves on. File-link work should still come after the display pipeline is
more settled.

## Guard Rails For The Next Agent

- Do not reintroduce a manual theme toggle.
- Do not replace the current reducer/domain logic with Redux-style churn just to
  use a named library.
- Keep timer logic monotonic and local. The app-server still does not expose an
  authoritative turn duration field.
- Do not collapse new behavior into large widget-side conditionals if it can
  live in reducer or policy code.
- Preserve keyed transcript identity in list rendering.
- Keep app-level ownership in `PocketRelayApp`, screen-level ownership in
  `ChatScreen`, and transport teardown in the app-server client/connection
  layer.

## Verification Expectations

Each follow-on task should end with:

- `flutter analyze`
- focused reducer tests for the changed semantics
- focused widget tests for the changed surface
- full test suite before final handoff

## Current Watch List

These are not active blockers, but they should be watched during future work:

- `ConnectionSheet` is safe because it is currently remounted per sheet open;
  if that ownership model changes, it will need update-lifecycle handling
- `TurnElapsedFooter` is currently correct for its timer role, but transcript
  placement may still change if the transcript layout is consolidated further
- transcript cards with local expansion state depend on `block.id` identity, so
  future list refactors must preserve keys

## If Another Agent Starts Here

Start by reading:

1. `docs/006_next-agent-handoff.md`
2. `docs/011_transcript-immutability-migration-plan.md`
3. `docs/004_codex-parity-maturity-plan.md`
4. `docs/005_component-lifecycle-audit-plan.md`

Then inspect:

1. `lib/src/features/chat/application/transcript_reducer.dart`
2. `lib/src/features/chat/application/transcript_policy.dart`
3. `lib/src/features/chat/models/codex_session_state.dart`
4. `.reference/codex/codex-rs/tui/src/chatwidget.rs`

That is the shortest path back into the remaining work.
