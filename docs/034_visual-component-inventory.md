# 032 Visual Component Inventory

## Purpose

This document inventories the recurring visual components and styling patterns
that currently define the Pocket Relay UI.

It exists to support a deliberate cleanup pass toward a more professional,
quieter visual system.

## High-Level Diagnosis

The current UI has too many overlapping visual signals at the same time:

- large corner radii
- card-on-card nesting
- tinted surfaces inside already decorated surfaces
- many chip, badge, pill, and tag treatments
- repeated borders plus shadows plus accent fills on the same element

The result is not one bad component. It is a repeated pattern language problem.

## Primary Surface Types

### 1. App-Level Shell Surfaces

Used for:

- app background
- bootstrap shell
- top-level lane/shell framing

Key files:

- [app.dart](/Users/vince/Projects/Pocket-Relay/lib/src/app.dart)
- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart)
- [connection_workspace_desktop_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart)
- [connection_workspace_mobile_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart)

Current traits:

- decorative gradient backgrounds
- rounded large shells
- shadowed containers
- occasional pill/rail accents

### 2. Modal / Sheet Surfaces

Used for:

- connection settings
- workspace conversation history
- changed-file diff sheet

Key files:

- [modal_sheet_scaffold.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/widgets/modal_sheet_scaffold.dart)
- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart)
- [connection_workspace_conversation_history_sheet.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_conversation_history_sheet.dart)
- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)

Current traits:

- strong rounding
- drag handle pill
- decorated sheet surface plus decorated items inside it

### 3. Transcript Entry Surfaces

Used for:

- reasoning
- plans
- changed files
- work logs
- approvals
- user input requests
- SSH state cards
- errors / status / usage

Key files:

- [conversation_entry_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart)
- [reasoning_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart)
- [plan_update_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart)
- [proposed_plan_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart)
- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)
- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
- [approval_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart)
- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)
- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart)
- [status_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/status_card.dart)
- [error_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/error_card.dart)
- [usage_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart)

Current traits:

- many independent decorated cards
- each card often adds its own chips, badges, and accent strips
- some cards contain smaller decorated rows inside the outer card

### 4. Input Surfaces

Used for:

- composer
- connection settings form
- user input request forms

Key files:

- [chat_composer_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_composer_surface.dart)
- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart)
- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)
- [pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart)

Current traits:

- rounded outline inputs
- filled buttons
- segmented buttons
- some local spacing overrides

## Shared Visual Primitives

### Rounded Containers

The UI relies heavily on rounded `Container` / `DecoratedBox` surfaces.

Common ranges:

- `18`
- `20`
- `22`
- `24`
- `28`
- `999` for pills

Files with heavy use:

- [connection_workspace_desktop_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart)
- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)
- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart)
- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart)

### Chips / Pills / Tags / Badges

This is one of the biggest clutter sources.

Key files:

- [transcript_chips.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart)
- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)
- [turn_elapsed_footer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart)
- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart)
- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
- [user_input_request_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart)

Examples:

- inline pulse chips
- status chips
- action chips
- timeline signal pills
- diff metadata pills
- operation chips

### Accent-Tinted Inner Rows

Many cards create another decorated row inside the main card, usually with:

- tint
- border
- small radius

This is the main card-in-card pattern.

Heavy users:

- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)
- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)
- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart)

### Accent Palette System

The code already has a centralized accent system.

Key file:

- [conversation_card_palette.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart)

Available accents:

- teal
- blue
- violet
- pink
- purple
- amber
- red

This is good as a primitive, but too many surfaces consume it too aggressively.

## Most Visually Noisy Components

These are the strongest candidates for redesign or simplification.

### 1. Changed Files Card

Why it reads noisy:

- outer card
- inner file row cards
- status chip
- action chip
- diff sheet with additional chips

Key file:

- [changed_files_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart)

### 2. Work Log Group Card

Why it reads noisy:

- grouped shell
- many nested row containers
- additional miniature decorated shells inside rows
- multiple icon and accent treatments in the same block

Key file:

- [work_log_group_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart)

### 3. SSH Cards

Why they read noisy:

- strong frame
- inner highlighted rows
- multiple action buttons
- status messaging and metadata competing for attention

Key files:

- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart)
- [ssh_card_host.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_host.dart)

### 4. Desktop Workspace Shell

Why it reads busy:

- rounded rails
- rounded lane cards
- badge pills
- nested active-state containers

Key file:

- [connection_workspace_desktop_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart)

## Existing Reusable Foundations

These are the pieces worth keeping and simplifying around, not throwing away.

### 1. Theme Base

- [pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart)

Already centralizes:

- palette
- input borders
- scaffold/background theme

### 2. Transcript Palette

- [conversation_card_palette.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart)

Already centralizes:

- neutral surfaces
- text colors
- accent blending

### 3. Shared Modal Scaffold

- [modal_sheet_scaffold.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/widgets/modal_sheet_scaffold.dart)

Already centralizes:

- sheet surface
- handle
- sticky header layout

## Problem Patterns To Target

These are the cleanup targets, not individual bugs.

### Pattern A: Radius Inflation

Current issue:

- too many radii are large by default
- pills and rounded shells appear everywhere

Likely direction:

- shrink the system-wide radius scale
- reserve pill radii for very specific use cases

### Pattern B: Nested Decorated Surfaces

Current issue:

- parent card plus child tinted box plus child pill equals too much structure

Likely direction:

- one primary surface per semantic block
- inner rows should default to flat layout, not mini-cards

### Pattern C: Badge Overproduction

Current issue:

- state is often shown with both color and chip and icon and border

Likely direction:

- pick one dominant signal per row
- use chips only when compact classification is genuinely needed

### Pattern D: Accent Overuse

Current issue:

- many surfaces tint both border and background and icon and chip at once

Likely direction:

- use accent sparingly
- default to neutral surfaces with one accent point

## Recommended Cleanup Order

1. Establish a smaller radius scale and a stricter “one surface per block” rule.
2. Simplify transcript support primitives:
   - [transcript_chips.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart)
   - [meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/meta_card.dart)
3. Redesign the noisiest transcript cards:
   - changed files
   - work log
   - SSH
4. Simplify the desktop workspace shell card language.
5. Revisit sheets and settings after transcript noise is reduced.

## Summary

The problem is not one ugly widget. The current visual system is dominated by:

- too many rounded containers
- too many nested decorated surfaces
- too many chips
- too many simultaneous emphasis signals

The code already has enough reusable seams to fix this systematically. The next
step should be a design reduction pass, not more one-off styling tweaks.
