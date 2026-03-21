# Codex TUI to Flutter Widget Parity Gaps

## Purpose

This document records the current widget/surface parity gap between:

- the Codex TUI/reference transcript/history surfaces in
  `.reference/codex/codex-rs/tui/src/history_cell.rs` and
  `.reference/codex/codex-rs/tui/src/exec_cell/render.rs`
- the current Pocket Relay Flutter transcript and related UI surfaces under
  `lib/src/...`

This is an app-layer parity document. Missing parity must be implemented in
Flutter app code, not in Widgetbook.

## Source Anchors

Primary reference families:

- active exec command:
  `.reference/codex/codex-rs/tui/src/exec_cell/render.rs:40`
- unified exec interaction:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:638`
- unified exec processes output:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:772`
- approval decision cell:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:794`
- review status line:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:966`
- session info:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1121`
- active MCP tool call:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1583`
- active web search call:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1658`
- completed web search call:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1666`
- warning event:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1740`
- deprecation notice:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1750`
- info event:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1961`
- error event:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1971`
- request-user-input result cell:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:1981`
- plan update:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2122`
- proposed plan:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2128`
- proposed plan stream:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2135`
- patch apply failure:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2268`
- view image tool call:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2294`
- image generation call:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2305`
- reasoning summary block:
  `.reference/codex/codex-rs/tui/src/history_cell.rs:2327`

Protocol/context anchors:

- app-server parity priorities:
  [codex-app-server-emission-parity.md](./codex-app-server-emission-parity.md)
- compacted-thread note:
  [codex-app-server-emission-parity.md](./codex-app-server-emission-parity.md)

## Current Flutter Surfaces

Current app-owned Flutter transcript families already present:

- assistant message:
  `lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart`
- reasoning:
  `lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart`
- user message:
  `lib/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart`
- status:
  `lib/src/features/chat/presentation/widgets/transcript/cards/status_card.dart`
- error:
  `lib/src/features/chat/presentation/widgets/transcript/cards/error_card.dart`
- approval request:
  `lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart`
- plan update:
  `lib/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart`
- proposed plan:
  `lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart`
- changed files:
  `lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart`
- work log group:
  `lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart`
- user input request:
  `lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart`
- usage:
  `lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart`
- turn boundary:
  `lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart`
- SSH trust/failure families:
  `lib/src/features/chat/presentation/widgets/transcript/cards/ssh/...`

## Parity Status Summary

The current state is partial parity, not full parity.

We have:

- many core transcript surfaces
- some Pocket Relay-specific SSH surfaces
- one aggregated work-log family that covers several runtime activities

We do not yet have:

- several first-class Codex reference surfaces
- several result/history surfaces distinct from request surfaces
- several event/information surfaces that the TUI exposes directly
- a one-to-one split between command execution, MCP, web search, and other
  runtime activity families

## Missing App-Owned Widgets

These do not have clear first-class Flutter equivalents today and should be
implemented as app-layer surfaces.

### P0 Missing Widgets

These are the highest-priority parity gaps because they affect visible turn
meaning, blocked-turn lifecycle, or major runtime activity.

1. Approval decision history widget
- Reference: `new_approval_decision_cell`
- Why it matters: the TUI distinguishes the request surface from the final
  decision history surface.
- Current Flutter gap: we have `ApprovalRequestCard`, but not a dedicated
  approved/denied history result widget.

2. Request-user-input result widget
- Reference: `RequestUserInputResultCell`
- Why it matters: the TUI distinguishes the pending user-input form from the
  completed/interrupted result state.
- Current Flutter gap: we have `UserInputRequestCard`, but not the result cell.

3. Active exec command widget
- Reference: `new_active_exec_command`
- Why it matters: live command execution is a core runtime surface.
- Current Flutter gap: `WorkLogGroupCard` is an aggregate summary, not a
  dedicated active exec surface.

4. Unified exec interaction widget
- Reference: `new_unified_exec_interaction`
- Why it matters: terminal interaction/waiting is a distinct runtime meaning.
- Current Flutter gap: no dedicated surface.

5. Unified exec processes output widget
- Reference: `new_unified_exec_processes_output`
- Why it matters: command/process output is richer and more explicit in the
  TUI than our current aggregate work-log display.
- Current Flutter gap: no dedicated surface.

6. Active MCP tool call widget
- Reference: `new_active_mcp_tool_call`
- Why it matters: MCP calls are first-class runtime activity in the reference.
- Current Flutter gap: folded into `WorkLogGroupCard` instead of surfaced as a
  dedicated widget family.

7. Web search widgets
- Reference: `new_active_web_search_call`, `new_web_search_call`
- Why it matters: active and completed web search are distinct surfaces in the
  reference.
- Current Flutter gap: no dedicated web-search widgets.

### P1 Missing Widgets

These are important parity gaps, but less critical than the blocked-turn and
live-runtime surfaces above.

8. Warning event widget
- Reference: `new_warning_event`
- Current Flutter gap: no dedicated warning family distinct from generic
  status/error.

9. Info event widget
- Reference: `new_info_event`
- Current Flutter gap: no dedicated info family.

10. Deprecation notice widget
- Reference: `new_deprecation_notice`
- Current Flutter gap: no dedicated deprecation surface.

11. Patch apply failure widget
- Reference: `new_patch_apply_failure`
- Current Flutter gap: patch failure is not surfaced as its own first-class
  widget.

12. Session info widget
- Reference: `new_session_info`
- Current Flutter gap: session metadata is spread across headers/status, not a
  transcript-level info surface.

13. Review status line widget
- Reference: `new_review_status_line`
- Current Flutter gap: guardian/auto-approval in-progress state is not modeled
  as its own transcript widget.

14. Context compacted widget
- Reference: parity doc `thread/compacted`
- Current Flutter gap: no explicit "Context compacted" transcript/info surface.

### P2 Missing Widgets

These matter for broader parity, but can wait until the higher-priority core
turn/runtime gaps are filled.

15. View-image tool call widget
- Reference: `new_view_image_tool_call`
- Current Flutter gap: no transcript surface for image-view tool results.

16. Image-generation call widget
- Reference: `new_image_generation_call`
- Current Flutter gap: no transcript surface for generated-image output.

## Existing Widgets That Need To Be Updated

These widgets exist, but they do not yet expose the full semantic surface or
detail level that the reference shows.

### P0 Updates

1. `WorkLogGroupCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart`
- Problem: this is doing too much aggregation across several reference families.
- TUI shows more than we do:
  - active exec command
  - unified exec interaction
  - unified exec output
  - active MCP tool call
  - active/completed web search
- Needed change:
  split the aggregated work-log presentation into smaller app-owned runtime
  widgets or explicit sub-surfaces with parity-backed semantics.

2. `ApprovalRequestCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart`
- Problem: request state exists, but result/history parity is missing.
- TUI shows more than we do:
  - final approval decision history
  - actor distinction (`User` vs `Guardian`)
- Needed change:
  keep request UI, but add a separate result/history family and support richer
  consequence/actor detail.

3. `UserInputRequestCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart`
- Problem: pending form exists, but completed/interrupted result parity is
  missing.
- TUI shows more than we do:
  - result state after the question is answered
  - interrupted/unanswered result handling
- Needed change:
  add a separate result widget and map the completed/interrupted runtime states.

4. `StatusCard` and `ErrorCard`
- Files:
  `lib/src/features/chat/presentation/widgets/transcript/cards/status_card.dart`
  `lib/src/features/chat/presentation/widgets/transcript/cards/error_card.dart`
- Problem: these are too generic to cover the TUI event family cleanly.
- TUI shows more than we do:
  - warning events
  - info events
  - deprecation notices
  - specialized error/info wording per event family
- Needed change:
  either split these into explicit event widgets or expand the event model so
  the Flutter surfaces can render the same semantic distinctions.

### P1 Updates

5. `ChangedFilesCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart`
- Problem: file-change rendering is strong, but parity with patch lifecycle and
  patch failure is incomplete.
- TUI shows more than we do:
  - patch event lifecycle
  - patch apply failure as its own surface
- Needed change:
  preserve the current file diff experience, but add explicit failure/result
  handling where the backend emits it.

6. `ReasoningCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart`
- Problem: reasoning exists, but TUI uses both live reasoning status semantics
  and committed summary blocks.
- TUI shows more than we do:
  - live reasoning status updates
  - committed reasoning summary block behavior
- Needed change:
  verify that the current props and rendering cover both running and final
  summary semantics, and add any missing distinction if they do not.

7. `ProposedPlanCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart`
- Problem: streaming/final exist, but parity should be checked against the
  exact reference behaviors and fields.
- TUI shows:
  - streamed plan
  - final proposed plan
- Needed change:
  verify field coverage and visual hierarchy against the reference rather than
  assuming current parity is complete.

8. `PlanUpdateCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart`
- Problem: generally aligned, but it should be checked against TUI step/status
  semantics to confirm full field parity.

### P2 Updates

9. `UsageCard` and `TurnBoundaryCard`
- Files:
  `lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart`
  `lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart`
- Problem: these are Pocket Relay surfaces that overlap with status/turn
  lifecycle, but they are not directly the same as all TUI status/info cells.
- Needed change:
  verify whether these should stay Pocket Relay-specific or be expanded to cover
  more of the TUI turn-completion/session-info semantics.

10. `AssistantMessageCard`
- File:
  `lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart`
- Problem: core parity likely exists for basic streaming/final states, but it
  should be checked for any missing status cues that the TUI exposes during
  streaming.

## Priority Order

This is the recommended implementation order.

### Priority 0

- approval decision history widget
- request-user-input result widget
- active exec command widget
- unified exec interaction widget
- unified exec output widget
- active MCP tool call widget
- active/completed web search widgets
- refactor `WorkLogGroupCard` so these runtime families are not flattened into
  one aggregate surface

### Priority 1

- warning event widget
- info event widget
- deprecation notice widget
- patch apply failure widget
- review status line widget
- context compacted widget
- session info widget
- update `ApprovalRequestCard`, `UserInputRequestCard`, `StatusCard`,
  `ErrorCard`, and `ChangedFilesCard` to cover the richer reference semantics

### Priority 2

- view-image tool call widget
- image-generation call widget
- verify/expand `ReasoningCard`, `ProposedPlanCard`, `PlanUpdateCard`,
  `UsageCard`, `TurnBoundaryCard`, and `AssistantMessageCard` against exact
  reference detail coverage

## Implementation Rule

Do not implement any of these missing parity surfaces in Widgetbook.

The correct order is:

1. create or update the app-owned Flutter widget in `lib/src/...`
2. make the runtime/event mapping produce the right contract/props
3. test the app-owned surface
4. only then add or update Widgetbook coverage

## Short Conclusion

Pocket Relay currently has useful transcript coverage, but it is still behind
the Codex reference in both:

- number of first-class runtime widget families
- amount of visible semantic detail within several existing widget families

The biggest parity debt is concentrated in:

- execution/runtime activity surfaces
- result/history surfaces distinct from request surfaces
- informational event families
- review/guardian lifecycle states
