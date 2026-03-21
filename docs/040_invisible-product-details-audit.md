# 035 Invisible Product Details Audit

## Purpose

This document exists because the current Widgetbook is now good enough to look
authoritative, but the underlying product design is not actually complete.

That creates a dangerous failure mode:

- the catalog makes the current UI look more finished than it is
- important product details are still visually absent, weak, or inconsistent
- the team can stop discovering missing information because the previews appear
  tidy

This document corrects that by listing the product details that are currently
hidden, underspecified, or not represented clearly enough.

It should be read alongside
[032_visual-component-inventory.md](/Users/vince/Projects/Pocket-Relay/docs/032_visual-component-inventory.md),
[033_designer-redesign-brief.md](/Users/vince/Projects/Pocket-Relay/docs/033_designer-redesign-brief.md),
and
[038_atomic-design-system-audit.md](/Users/vince/Projects/Pocket-Relay/docs/038_atomic-design-system-audit.md).

Those documents explain that the current UI is too noisy and not yet grounded
in a true design system.

This document explains a different problem:

the product is not yet showing enough of what is happening.

## Core Diagnosis

The current UI has two conflicting weaknesses at the same time:

1. Too much ornamental styling.
2. Too little visible operational detail.

That means the product can feel both busy and under-informative.

The immediate risk is that Widgetbook turns into a gallery of polished-looking
cards instead of a discovery tool for what the product still fails to reveal.

## What Widgetbook Must Not Pretend

Widgetbook must not imply any of the following unless we have explicitly
designed and verified them:

- that the current transcript hierarchy is correct
- that the current card set exposes all meaningful state
- that the current labels are sufficient for trust and diagnosis
- that the current settings forms expose enough context for safe decisions
- that empty, warning, and recovery states already communicate what users need
- that the current board views represent the full decision surface

The current catalog is useful, but it is still an inventory and review tool.

It is not yet a validated product spec.

## Missing Or Weakly Visible Details By Surface Family

### 1. Transcript

Primary files:

- [assistant_message_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart)
- [reasoning_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart)
- [approval_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart)
- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)
- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
- [usage_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart)
- [turn_boundary_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart)
- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)

Important details that are still weak, missing, or inconsistent:

- whether a transcript item is informational, blocking, dangerous, or merely
  historical
- whether an item is still live, partially complete, stale, or final
- whether an item belongs to the current turn or a previous turn
- whether a visible action is optional, required, or preventing progress
- whether a card is user-facing summary, machine event, or operational trace
- whether a file/tool/action row is a headline result or only supporting detail
- whether a detail belongs inline in the transcript or should be hidden behind
  progressive disclosure

Specific invisible transcript details that should become explicit design
questions:

- assistant messages do not yet clearly distinguish summary, decision, warning,
  and narration tones
- reasoning blocks do not yet establish when reasoning is primary versus
  supporting context
- approval requests do not yet clearly communicate impact, consequence, or what
  changes if the user denies the request
- changed-files rows show path and stats, but they do not yet establish which
  changes are high risk, user-visible, structural, or trivial
- work-log rows show activity, but they do not yet express importance,
  recency, duration, or whether a command mattered materially
- usage summaries in [usage_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart)
  are compact, but they do not yet establish when usage deserves user
  attention versus quiet background accounting
- turn separators in [turn_boundary_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart)
  mark boundaries, but they do not yet communicate what meaning a turn
  boundary carries in the product
- user input requests show fields and actions, but they do not yet communicate
  urgency, safety sensitivity, or why this request surfaced now

### 2. SSH And Trust States

Primary files:

- [ssh_unpinned_host_key_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart)
- [ssh_connect_failed_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_connect_failed_card.dart)
- [ssh_host_key_mismatch_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_host_key_mismatch_card.dart)
- [ssh_auth_failed_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_auth_failed_card.dart)
- [ssh_remote_launch_failed_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_remote_launch_failed_card.dart)

Important details that still need explicit design treatment:

- which failures are trust warnings versus configuration failures
- which failures block progress completely versus allow partial recovery
- what data users need to verify a host key safely
- what should be visible immediately versus tucked into an expandable detail
- when the correct next step is retry, edit settings, trust host, or stop

The current cards show the event, but they do not yet establish a fully
credible trust and recovery language.

### 3. Composer And Input Flow

Primary files:

- [chat_composer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_composer.dart)
- [chat_composer_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_composer_surface.dart)
- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)

Missing or weakly visible details:

- whether the current draft is safe to send
- whether the agent is busy, interrupted, awaiting approval, or waiting for the
  user
- what keyboard affordances or shortcuts exist
- what send actually does in each mode
- whether attachments, context, or model settings affect the next action

The composer can look clean while still hiding too much operational context.

### 4. Header, Conversation Context, And Top Controls

Primary files:

- [chat_app_chrome.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_app_chrome.dart)
- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart)
- [connection_workspace_live_lane_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart)

Missing or weakly visible details:

- which conversation or lane the user is currently affecting
- whether the current view is live, historical, or detached
- whether the transcript is still updating
- whether switching timeline/conversation view changes only the view or changes
  the active working context
- what connection or environment this work is happening against

This is a real product risk.

If the header stays too quiet, users can lose context.

If it becomes too loud, it competes with the transcript.

That balance is not yet fully designed.

### 5. Workspace Navigation

Primary files:

- [connection_workspace_desktop_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart)
- [connection_workspace_mobile_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart)
- [connection_workspace_dormant_roster_content.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_dormant_roster_content.dart)

Missing or weakly visible details:

- what distinguishes saved, dormant, active, reconnecting, and failed
  connections at a glance
- whether a lane is idle, busy, or needs intervention
- whether navigation rows represent sessions, profiles, machines, or views
- which connection is safe to edit without disrupting current work
- what metadata is important enough to show in a row versus on a detail screen

The navigation currently risks looking organized while still hiding too much
state meaning.

### 6. Settings And Configuration

Primary files:

- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart)
- [connection_sheet.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_sheet.dart)

Missing or weakly visible details:

- which fields are required versus optional
- which changes are risky, security-sensitive, or performance-sensitive
- whether a setting affects current sessions, future sessions, or both
- whether a field is prefilled from discovery, saved from history, or manually
  entered
- whether save will validate, reconnect, overwrite, or only persist locally
- what local mode and remote mode fundamentally change for the user

The current settings sheet has structure, but not enough operational guidance.

### 7. Empty States, Recovery States, And Failure States

Primary files:

- [chat_empty_state_body.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart)
- [empty_state.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/empty_state.dart)
- transcript status and error cards under
  [lib/src/features/chat/presentation/widgets/transcript/cards](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards)

Missing or weakly visible details:

- what the user can do next from each empty state
- whether a state is expected, temporary, recoverable, or exceptional
- whether a failure is local, remote, network, trust, or tool related
- what degree of confidence the user should have that retry will help
- what minimum diagnostic detail should always be visible without expanding

The current product does not yet have a fully designed failure language.

## Missing Detail Types

Across the product, the same kinds of detail are repeatedly absent or
under-developed.

These missing detail types should become an explicit checklist during design
review:

- severity
- blocking status
- recency
- execution state
- ownership
- environment or connection scope
- consequence of an action
- reversibility
- trust and security relevance
- whether a detail is summary, evidence, or raw trace

If a surface communicates only title plus body plus accent color, it is
probably hiding at least one of these.

## Where Widgetbook Currently Misleads

Primary file:

- [story_catalog.dart](/Users/vince/Projects/Pocket-Relay/lib/widgetbook/story_catalog.dart)

The current catalog is strongest at:

- isolated component visibility
- grouped visual comparison boards
- deterministic screenshot review

It is still weak at:

- showing what information is absent
- marking unknown or undesigned states explicitly
- distinguishing inventory from approval
- showing when a component needs more product detail rather than more polish

The main problem is not that Widgetbook includes the wrong components.

The problem is that it mostly catalogs visible surfaces, while the current
product problem is partly about invisible semantics.

## Required Documentation Output

From this point on, design documentation should explicitly capture the
following for each major surface family:

1. What the user must know immediately.
2. What the user may need on demand.
3. Which details are operationally critical.
4. Which details can stay secondary.
5. Which details are currently absent from the UI.
6. Which details are currently shown, but not with enough hierarchy.

If a design review artifact does not answer those questions, it is incomplete.

## Recommended Next Docs

This document is the inventory of missing visibility.

The next useful docs should be narrower and more operational:

1. A transcript information hierarchy spec.
2. A trust and recovery state spec for SSH and connection failures.
3. A settings visibility spec describing what users must understand before
   saving.
4. A Widgetbook review standard that labels stories as one of:
   inventory, comparison, scenario, or validated reference.

## Immediate Widgetbook Implication

We should stop treating every neat-looking board as if it represents approved
design.

Some boards should instead become explicit discovery boards with labels like:

- missing metadata
- unresolved hierarchy
- unknown severity treatment
- needs product decision

That is the honest use of the catalog at the current maturity level.

## Conclusion

The current problem is not only that the design language is noisy.

It is also that important product details are still hidden, flattened, or
unspecified.

If we only keep polishing visible components, Widgetbook will become a
beautiful record of an incomplete product language.

The next phase of design work has to document what the UI is still failing to
say.
