# 036 Transcript Information Hierarchy Spec

## Purpose

This document defines what the Pocket Relay transcript must communicate, in
what order, and with what level of emphasis.

It is not a component inventory.

It is a product-information spec for the transcript surface.

It exists to correct a current problem:

- the transcript has many visible components
- the transcript still does not make the right details obvious enough
- Widgetbook can currently make that incompleteness look more finished than it
  is

This document turns the transcript redesign problem into explicit hierarchy
rules.

It should be used together with
[033_designer-redesign-brief.md](/Users/vince/Projects/Pocket-Relay/docs/033_designer-redesign-brief.md)
and
[035_invisible-product-details-audit.md](/Users/vince/Projects/Pocket-Relay/docs/035_invisible-product-details-audit.md).

## Scope

This spec applies to transcript content in the chat surface, including:

- assistant responses
- reasoning
- proposed plans
- plan updates
- approvals
- changed files
- work log groups
- user input requests
- usage summaries
- turn boundaries
- status messages
- error messages
- SSH/trust transcript states

Primary implementation area:

- [lib/src/features/chat/presentation/widgets/transcript/cards](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards)

## Core Principle

The transcript should answer the user’s most important question first:

what is happening, and do I need to act?

Everything else is secondary.

That means transcript hierarchy should prioritize:

1. Required user action.
2. Outcome or current state.
3. Scope and consequence.
4. Supporting evidence.
5. Operational trace detail.

The current transcript often inverts this by giving too much visual treatment
to trace detail and too little structure to action and consequence.

## Hierarchy Levels

Every transcript item should be understandable through these levels.

### Level 1: Immediate Meaning

This is the one thing the user must understand without effort.

Examples:

- approval required
- files changed
- connection failed
- assistant answered
- user input required
- turn completed

This should be visible even when the user scans quickly.

### Level 2: Actionability

This answers whether the user needs to do anything now.

Examples:

- no action needed
- optional review available
- input required to continue
- approval required to continue
- warning should be acknowledged
- failure blocks progress

If actionability is present, it must be more visible than decorative status.

### Level 3: Scope And Consequence

This explains what the event affects.

Examples:

- current turn only
- current connection
- remote machine trust
- files in the workspace
- future sessions
- current request blocked

This does not always need top billing, but it must be available without deep
inspection when consequences matter.

### Level 4: Evidence

This is the minimum supporting detail needed to trust the summary.

Examples:

- file paths and diff stats
- command title and preview
- host fingerprint
- approval reason
- error message
- token usage table

Evidence should support the main message, not compete with it.

### Level 5: Raw Or Exhaustive Detail

This is detailed trace information that only some users need.

Examples:

- long command sequences
- many file rows
- full diagnostic text
- verbose reasoning
- detailed token accounting

This level should usually use progressive disclosure.

## Global Transcript Rules

These rules should apply across all transcript item types.

### Rule 1: Show action before decoration

If an item blocks progress or requires input, that must be more visible than
its color treatment, icon, or card accent.

### Rule 2: Do not use multiple signals for the same meaning unless necessary

Do not stack icon, badge, tinted shell, border emphasis, and loud title color
to all say the same thing.

One strong signal plus clear copy is better.

### Rule 3: Summary first, evidence second

The user should be able to understand the item before reading supporting rows.

### Rule 4: Trace detail should not outrank user consequence

Operational logs and file lists must not visually dominate the question of
whether the user should act.

### Rule 5: Use progressive disclosure for density, not concealment

Collapsing is valid for long detail.

It is not valid for hiding information the user needs to make a decision.

### Rule 6: Turn structure should be understandable at a glance

Users should be able to tell what belongs to the current turn, what already
settled, and where one turn ended.

### Rule 7: Similar urgency should look similar across card types

Blocking approval, blocking input, and blocking trust failures should not each
invent a separate urgency language.

## Information Requirements By Transcript Item Type

### 1. Assistant Message

Primary file:

- [assistant_message_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart)

Must show prominently:

- that this is the assistant’s actual answer or update
- whether it is still streaming or final

Must show secondarily when applicable:

- whether the message is summary, decision, warning, or explanation
- whether it references follow-up action elsewhere in the transcript

Can stay secondary or implicit:

- decorative identity markers

Should usually collapse:

- very long body text only if the summary meaning remains visible

### 2. Reasoning

Primary file:

- [reasoning_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart)

Must show prominently:

- that this is supporting reasoning, not the final answer
- whether it is still in progress or complete

Must show secondarily:

- why the reasoning is present
- whether it affected a later action or conclusion

Should usually collapse:

- long reasoning content

Reasoning should never visually outrank the answer it supports.

### 3. Proposed Plan

Primary file:

- [proposed_plan_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart)

Must show prominently:

- that this is a plan, not completed work
- whether the plan is draft, streaming, or settled

Must show secondarily:

- the number of steps
- whether the user must approve or respond before execution

Should usually collapse:

- long step lists after the first visible portion

### 4. Plan Update

Primary file:

- [plan_update_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart)

Must show prominently:

- current execution state
- what changed in the plan state

Must show secondarily:

- affected step count or progress
- whether the update changed user expectations

Plan updates should feel like status transitions, not full content cards.

### 5. Approval Request

Primary file:

- [approval_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart)

Must show prominently:

- approval is required
- what action is being approved
- whether work is blocked until a decision is made

Must show secondarily:

- consequence of approval
- consequence of denial
- scope of impact

Must not hide:

- the fact that the user decision changes what happens next

Can collapse:

- long supporting rationale or detail

### 6. User Input Request

Primary file:

- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)

Must show prominently:

- input is required
- why it is required
- what field or choice is needed to continue

Must show secondarily:

- urgency or sensitivity
- whether the input is secret, optional, or editable later

Must not hide:

- the continuation dependency

The user should know immediately whether the transcript is waiting on them.

### 7. Changed Files

Primary file:

- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)

Must show prominently:

- that files were changed
- whether changes are still being updated
- how many files changed

Must show secondarily:

- which files are likely most important
- whether the changes are additive, destructive, or structural
- whether diff review is available

Should usually collapse:

- long file lists after the most important visible rows

The transcript should not treat every changed file row as equally important.

### 8. Work Log Group

Primary file:

- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)

Must show prominently:

- that work activity occurred
- whether work is still running or settled
- whether the group contains notable failures

Must show secondarily:

- command categories
- recency
- count of entries
- whether any row materially explains the outcome

Should usually collapse:

- long command detail sequences

Work logs are evidence, not the main event, unless the log itself explains a
failure.

### 9. Usage Summary

Primary file:

- [usage_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart)

Must show prominently only when relevant:

- that usage is unusually important in this context

Otherwise:

- usage should remain low-emphasis supporting information

Must show secondarily:

- the minimum trustworthy accounting summary

Should usually collapse or stay de-emphasized:

- detailed token accounting on normal turns

Usage should not visually compete with decisions, failures, or requested
actions.

### 10. Turn Boundary

Primary file:

- [turn_boundary_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart)

Must show prominently:

- where one turn ended

Must show secondarily:

- elapsed duration
- summary usage if it helps orient the user

Turn boundaries are structural markers, not decorative separators.

### 11. Status Message

Primary file:

- [status_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/status_card.dart)

Must show prominently:

- current state
- whether the state is temporary, expected, or needs attention

Must show secondarily:

- what happens next if nothing is done

Status messages should be lightweight unless they affect user action.

### 12. Error Message

Primary file:

- [error_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/error_card.dart)

Must show prominently:

- what failed
- whether progress is blocked
- what the user can do next

Must show secondarily:

- diagnostic detail
- likely cause

Must not hide:

- whether retry is meaningful

### 13. SSH And Trust States

Primary files:

- [lib/src/features/chat/presentation/widgets/transcript/cards/ssh](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh)

Must show prominently:

- trust issue versus configuration issue versus execution issue
- whether progress is blocked
- the safest next action

Must show secondarily:

- host identity evidence
- what changed compared to expected state
- why the user should care

Must not hide:

- the trust consequence of continuing

## What Should Usually Be Inline

The following information generally belongs inline because it affects immediate
understanding:

- blocking status
- required user action
- current execution state
- concise consequence
- minimal evidence needed for trust

## What Should Usually Be Collapsible

The following information should usually be behind expansion or truncation once
the summary is clear:

- long step lists
- long work-log sequences
- long file lists
- verbose reasoning
- detailed diagnostics
- exhaustive usage accounting

## What Widgetbook Should Reflect

The transcript portion of Widgetbook should no longer present only polished
component snapshots.

It should organize stories to prove hierarchy decisions.

At minimum, transcript stories should distinguish:

- inventory story
- comparison story
- scenario story
- unresolved hierarchy story

An unresolved hierarchy story is valid when we do not yet know whether the
current design shows enough actionability, consequence, or evidence.

## Review Questions

Every transcript review should answer these questions:

1. If a user scans this item in two seconds, what do they understand?
2. Do they know whether they must act?
3. Do they understand the consequence of acting or ignoring it?
4. Is the evidence sufficient without becoming the headline?
5. Is any trace detail visually outranking the actual product meaning?

If the answer to any of these is unclear, the transcript design is not done.

## Immediate Next Design Work

This spec implies the next transcript-focused tasks:

1. Label current transcript stories by hierarchy status instead of treating all
   of them as approved references.
2. Add comparison boards that explicitly test actionability and consequence,
   not only visual variation.
3. Add scenarios where the same information is shown with different hierarchy
   treatments so the team can decide what should be primary.
4. Redesign approval, input-request, SSH, and error states first, because they
   carry the highest user consequence.

## Conclusion

The transcript should not be a stack of styled event cards.

It should be a legible record of what happened, what matters, and whether the
user needs to do anything now.

This spec defines that hierarchy so future design and Widgetbook work can be
judged against product meaning instead of surface polish.
