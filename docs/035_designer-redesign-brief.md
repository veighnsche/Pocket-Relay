# 033 Designer Redesign Brief

## Purpose

This document is for the next designer.

It explains the redesign work in product terms, not in engineering terms.

The designer should not need to read code in order to understand the problems
or the task split.

## Overall Problem

The current interface feels visually overdesigned and insufficiently
professional.

The repeated issues are:

- too many rounded corners
- too many card-like containers
- card inside card inside card composition
- too many badges, chips, tags, and status pills
- too many borders, shadows, and accent colors layered together
- spacing that often feels inflated rather than deliberate

The result is that the app feels busy, ornamental, and inconsistent instead of
confident, calm, and professional.

This should be treated as a design-system problem, not as a series of isolated
widget fixes.

## Design Goal

Redesign the app toward a calmer, more professional product language.

That likely means:

- fewer visual layers
- fewer decorative containers
- tighter control of shape language
- less reliance on chips and badges
- clearer hierarchy
- more intentional density
- stronger distinction between important signals and background structure

## Important Constraint

Please rethink the product by surface family, not by tiny components.

The work should be split into a small number of coherent redesign areas so the
visual language stays consistent.

## Workstream 1: Chat Transcript

### What this is

The main conversation area where the user reads what happened.

It includes:

- assistant responses
- reasoning sections
- plans
- changed files summaries
- work log items
- approval prompts
- user input requests
- SSH warnings/failures
- status and error messages
- usage summaries

### What feels wrong today

- too many transcript entries look like separate decorative card systems
- too many entries contain smaller decorated boxes inside them
- status is often shown with both color and chip and border and icon at once
- visual treatment is louder than the actual information

### What needs to be designed

A unified transcript language that answers:

- what a normal transcript item looks like
- when an item gets a container at all
- how special states differ without becoming noisy
- how hierarchy is expressed without stacking multiple emphasis signals

### Desired outcome

The transcript should feel calm, readable, and serious.

The content should be the main event, not the component styling.

## Workstream 2: Chat Composer

### What this is

The input area at the bottom where the user types and sends prompts.

### What feels wrong today

- it has often felt too padded, too tall, or too decorative
- it risks looking like a generic styled box rather than a real chat composer
- small spacing mistakes here are highly visible because it is a primary action
  surface

### What needs to be designed

A composer that feels native to a serious chat tool:

- compact but comfortable
- visually clean
- obvious as the primary input surface
- not ornamental

### Desired outcome

The composer should feel efficient and polished, like a tool people use for
real work.

## Workstream 3: Chat Header and Top Controls

### What this is

The top-of-chat area:

- title
- subtitle
- action buttons
- overflow menu
- conversation/timeline switching controls

### What feels wrong today

- there is a risk of too much chrome competing with the transcript
- controls can become chip-heavy or visually noisy
- the hierarchy between title, subtitle, and controls needs more discipline

### What needs to be designed

A quieter top bar that answers:

- what deserves emphasis
- what should stay visually subtle
- how conversation switching should look without becoming a row of pills

### Desired outcome

The header should orient the user clearly without pulling attention away from
the conversation.

## Workstream 4: Workspace Navigation

### What this is

The parts of the app used to navigate between connections and live lanes.

It includes:

- desktop sidebar
- live lane list
- dormant/saved connections area
- mobile lane navigation framing

### What feels wrong today

- navigation uses too many card-like rows and badge-like states
- active, inactive, reconnect, and saved states may be over-signaled
- the navigation shell can feel visually heavy

### What needs to be designed

A cleaner navigation language for:

- lane rows
- connection rows
- selected state
- reconnect-required state
- empty/saved areas

### Desired outcome

Navigation should feel structured and dependable, not decorated.

## Workstream 5: Settings and Configuration

### What this is

The area where users configure connections and edit connection details.

It includes:

- the connection settings sheet
- all fields
- section grouping
- segmented controls
- save/cancel actions

### What feels wrong today

- the settings experience can feel oversized
- section grouping can feel too card-based
- controls need a denser, more tool-like rhythm

### What needs to be designed

A settings system that feels:

- compact
- clear
- professional
- operational

Not like a decorative onboarding flow.

### Desired outcome

Users should feel like they are configuring a serious tool, not navigating a
stack of styled panels.

## Workstream 6: Modal Sheets and Overlays

### What this is

Any overlay that slides up or appears above the main app.

It includes:

- conversation history
- settings
- diff/detail overlays
- future sheet-style overlays

### What feels wrong today

- overlays can inherit too much decorative chrome
- inner content can become too layered
- sticky areas and body content are not yet disciplined enough

### What needs to be designed

One coherent modal language:

- header height
- action placement
- drag handle treatment
- body density
- rules for nested content

### Desired outcome

All overlays should feel like the same product system, but quieter and more
space-efficient than they are today.

## Workstream 7: Empty States, Warnings, and Recovery States

### What this is

All the system states that are not the happy path.

It includes:

- empty states
- setup prompts
- warnings
- error states
- SSH connection problems
- recovery prompts

### What feels wrong today

- these states can become overly loud
- warnings and helper states can feel like yet another decorative card family
- too much urgency is communicated through too many simultaneous signals

### What needs to be designed

A calmer state-messaging system that answers:

- how severe states differ from informational states
- how to show warnings clearly without visual chaos
- how to make recovery states actionable without overdesign

### Desired outcome

State messaging should be clear and trustworthy, not visually agitated.

## Recommended Order

Recommended redesign order:

1. Chat Transcript
2. Workspace Navigation
3. Chat Header and Top Controls
4. Modal Sheets and Overlays
5. Settings and Configuration
6. Chat Composer
7. Empty States, Warnings, and Recovery States

## Why This Order

This order starts with the surfaces that define the product’s visual identity
most strongly.

The transcript and workspace navigation dominate the app’s feel.
If those become calmer and more coherent, the rest of the redesign can follow
their language.

## Practical Design Direction

The redesign should likely move toward:

- fewer rounded shapes
- fewer nested surfaces
- fewer chips and status pills
- more restraint in accent color usage
- stronger hierarchy through spacing and typography instead of decoration
- calmer visual defaults with more selective emphasis

## Summary For The Designer

This app does not need more styling.

It needs less styling, better hierarchy, and a more disciplined product
language.

Please approach the redesign as a system-level cleanup across the seven surface
families above, not as a widget-by-widget beautification pass.
