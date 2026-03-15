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

- `docs/codex-parity-maturity-plan.md`
- `docs/component-lifecycle-audit-plan.md`

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

### 2. In-flight transcript segmentation

Current state:

- the app mostly commits directly into immutable transcript blocks

Target state:

- introduce an explicit in-flight segment model
- flush assistant output before tool/work cells begin
- flush work groups before assistant output resumes
- keep committed transcript history separate from active streaming state

This is the largest remaining architecture task.

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

1. Reasoning parity
2. In-flight transcript segmentation
3. Markdown and file-link normalization
4. Work-only completion semantics

This order matters. Reasoning and segmentation affect the shape of the
transcript. File-link work should come after the display pipeline is more
settled.

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
  placement may change once in-flight segmentation exists
- transcript cards with local expansion state depend on `block.id` identity, so
  future list refactors must preserve keys

## If Another Agent Starts Here

Start by reading:

1. `docs/next-agent-handoff.md`
2. `docs/codex-parity-maturity-plan.md`
3. `docs/component-lifecycle-audit-plan.md`

Then inspect:

1. `lib/src/features/chat/application/transcript_reducer.dart`
2. `lib/src/features/chat/application/transcript_policy.dart`
3. `lib/src/features/chat/models/codex_session_state.dart`
4. `.reference/codex/codex-rs/tui/src/chatwidget.rs`

That is the shortest path back into the remaining work.
