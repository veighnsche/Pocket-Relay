# Codex Parity And Maturity Plan

## Status

This document captures the implementation work needed to make Pocket Relay feel
closer to upstream Codex while keeping the Flutter codebase maintainable.

The reference audit was done against the local Codex clone at:

- commit `49edf311ac3ae84659b0ec5eacd5e471c881eee8`
- date `2026-03-14`

Reference code paths that drove this plan:

- `.reference/codex/codex-rs/tui/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui/src/history_cell.rs`
- `.reference/codex/codex-rs/tui/src/status_indicator_widget.rs`
- `.reference/codex/codex-rs/tui/src/bottom_pane/mod.rs`
- `.reference/codex/codex-rs/tui/src/markdown_render.rs`
- `.reference/codex/codex-rs/app-server/README.md`

## What “Parity” Should Mean Here

Parity should not mean cloning the terminal UI literally.

It should mean:

1. We follow the same event semantics.
2. We measure time the same way Codex measures visible work time.
3. We group transcript content the same way where it affects meaning.
4. We present reasoning, work logs, approvals, and file references with the
   same priorities Codex uses.
5. We keep the Flutter code easy to extend and test instead of recreating a
   giant `chatwidget.rs`-style god object.

## What We Should Copy

- local timing instead of waiting for protocol-level turn timestamps
- pauseable work-time semantics for blocked turns
- stronger separation between in-flight content and committed transcript
- reasoning as transient status first, transcript artifact second
- custom handling for local file links and cwd-relative display
- clear transcript grouping boundaries between assistant output and tool/work

## What We Should Not Copy

- the full TUI layout and terminal-specific constraints
- bottom-pane modal mechanics exactly as implemented in Rust
- every internal telemetry metric or session detail
- a single mega-dispatcher file that owns all rendering decisions

## Current Gaps

### 1. Timer semantics

Current Pocket Relay behavior:

- elapsed time is derived from wall-clock `DateTime`
- the timer keeps advancing while the turn is blocked on approvals or user input
- completion UI always shows explicit elapsed text

Target behavior:

- use a local monotonic clock
- pause visible elapsed work time while the turn is waiting on the user
- keep final elapsed duration frozen after completion or abort

### 2. Transcript segmentation

Current Pocket Relay behavior:

- events reduce directly into immutable blocks
- grouping is mostly post-hoc

Target behavior:

- add an explicit in-flight segment model
- flush assistant streaming before work cells begin
- flush work groups before assistant streaming resumes

This is the main architectural gap between “functional” and “Codex-like”.

### 3. Reasoning presentation

Current Pocket Relay behavior:

- reasoning streams as a visible markdown card

Target behavior:

- reasoning summary drives transient live status while the turn is active
- final reasoning becomes a compact, lower-emphasis transcript artifact
- raw reasoning should not dominate the live transcript

### 4. Request and waiting UX

Current Pocket Relay behavior:

- approvals and user input render below the transcript
- timer semantics do not treat waiting as paused work

Target behavior:

- waiting states should be treated as blocked work
- timer pause and resume should follow request lifecycle exactly
- the UI can keep the current Flutter layout as long as the semantics match

### 5. Markdown and file-link rendering

Current Pocket Relay behavior:

- generic markdown rendering via `flutter_markdown_plus`
- local file links use whatever label the markdown provides

Target behavior:

- preprocess or custom-render markdown so local file links display the real
  target path
- normalize cwd-relative display consistently across reasoning, plans, and
  assistant output where file links appear

## Recommended Implementation Order

### Phase 1: Timer parity subset

Scope:

- move turn timing to a monotonic local clock
- pause and resume turn timers around approvals and user input
- keep final elapsed values frozen

Why first:

- highest parity gain for the smallest code change
- directly aligned with Codex semantics
- no transcript redesign required

Status:

- implemented as part of this task

### Phase 2: Reasoning parity

Scope:

- stop rendering live reasoning as a full transcript card
- add a compact live status surface for reasoning summaries
- emit a final collapsed reasoning summary card after the reasoning block ends

Why next:

- this is the largest visible parity gap after timing

### Phase 3: In-flight segment model

Scope:

- introduce a session-level active transcript segment
- define explicit flush rules for assistant output, work logs, and request
  boundaries
- keep immutable blocks as committed history only

Why next:

- this is the structural change that will make parity work stop feeling like
  exceptions layered onto reducers

### Phase 4: Markdown/file-link normalization

Scope:

- add a markdown preprocessing layer for local links
- normalize file labels relative to cwd
- reuse the same link rules for reasoning, plans, and assistant output

Why after segmentation:

- link rendering belongs in the final display pipeline, and that pipeline should
  settle first

### Phase 5: Runtime metrics and work-only separator semantics

Scope:

- distinguish work-bearing turns from simple answer turns
- only show “worked for …” style completion UI when the turn actually performed
  work
- consider adding lightweight runtime metrics once the app-server side provides
  stable values we want to surface

Why later:

- useful for polish, but not a prerequisite for correct timer semantics

## Codebase Maturity Rules

These rules should guide future parity work.

1. Keep runtime mapping, transcript policy, and rendering separate.
2. Prefer small, typed policy helpers over adding logic to widgets.
3. Preserve reducer-style domain transitions; do not jump to Redux-style churn
   just for branding.
4. Use focused tests for timer, request lifecycle, and transcript segmentation.
5. Do not mix large visual redesigns with event-model refactors.

## Test Expectations

Every parity phase should end with:

- `flutter analyze`
- focused reducer tests for the changed semantics
- widget tests for the user-visible surface that changed

For timer parity specifically, tests should prove:

- monotonic elapsed time can differ from wall-clock timestamps
- approvals pause the timer
- resolving the last blocking request resumes the timer
- completion freezes the elapsed duration

## Immediate Next Steps After This Task

1. Ship the timer parity subset.
2. Refactor live reasoning into status-first UI.
3. Introduce an explicit in-flight segment model before larger transcript
   parity work.
