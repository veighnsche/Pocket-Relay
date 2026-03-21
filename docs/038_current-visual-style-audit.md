# 038 Current Visual Style Audit

This document records the current visual identity and style choices that exist in
the codebase today.

It is also an explicit assessment:

This is not the visual direction I had in mind.

In its current state, the app looks inconsistent, over-framed, and
unprofessional. The system has some real primitives and shared tokens, but the
overall result still reads more like an engineering-first assembly of cards,
badges, and tinted containers than a deliberate product design language.

## 1. Current visual identity

The current identity is a warm-light / cool-dark Material 3 foundation with:

- warm beige light backgrounds
- dark teal-green dark backgrounds
- rounded surfaces almost everywhere
- soft panel borders instead of sharp separation
- many tinted accent surfaces for transcript states
- compact badges/chips for status signaling
- low-contrast neutral typography with colored headings

The overall feeling is:

- safe
- soft
- muted
- card-heavy
- utility-oriented
- not especially premium
- not especially opinionated

The problem is not that there is no styling.

The problem is that the styling does not yet feel like a coherent product
identity. It feels like a collection of locally reasonable UI decisions.

## 2. Theme foundation

The root theme is defined in
[pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart).

### Light palette

- `backgroundTop`: `#F4EFE5`
- `backgroundBottom`: `#ECE4D4`
- `sheetBackground`: `#F4EFE5`
- `surface`: `#FFFCF6`
- `surfaceBorder`: `#D7CDB8`
- `subtleSurface`: `#EEE7D8`
- `inputFill`: `#FFFFFF`
- `dragHandle`: `#D6CCB7`
- `shadowColor`: `#14000000`

### Dark palette

- `backgroundTop`: `#0E1415`
- `backgroundBottom`: `#071011`
- `sheetBackground`: `#111A1B`
- `surface`: `#162123`
- `surfaceBorder`: `#2D4245`
- `subtleSurface`: `#203033`
- `inputFill`: `#1C2A2C`
- `dragHandle`: `#466164`
- `shadowColor`: `#66000000`

### Theme characteristics

- Material 3 is enabled
- seed color is teal: `#0F766E`
- scaffold/app bar surfaces inherit from the palette instead of default Material
- inputs use rounded outlined borders and filled backgrounds
- bottom sheets default to transparent Material shell handling, with custom sheet
  surfaces provided elsewhere

## 3. Layout tokens

The layout scale is defined in:

- [pocket_spacing.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/layout/pocket_spacing.dart)
- [pocket_radii.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/layout/pocket_radii.dart)

### Spacing scale

- `xxs`: `4`
- `xs`: `8`
- `sm`: `10`
- `md`: `12`
- `lg`: `14`
- `xl`: `18`
- `xxl`: `20`
- `xxxl`: `24`
- `huge`: `28`
- `giant`: `32`

Derived paddings:

- `panelPadding`: `18`
- `cardPadding`: `fromLTRB(14, 12, 14, 14)`

### Radius scale

- `sm`: `14`
- `md`: `18`
- `lg`: `20`
- `xl`: `24`
- `xxl`: `28`
- `hero`: `32`
- `pill`: `999`

### Assessment

This is one of the strongest parts of the current system because there is at
least a real shared scale.

But the scale is still very soft and rounded by default. Almost everything
wants to become a rounded panel. That contributes to the “too many soft cards”
problem.

## 4. Shared primitives and surfaces

The actual app-owned primitive layer currently exposed in code is mostly under
[lib/src/core/ui](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui).

### Panel surface

[pocket_panel_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_panel_surface.dart)

Used for:

- bordered panels
- shared surface shells
- settings-like containers
- support/meta surfaces

Design characteristics:

- background color
- border color
- optional gradient
- optional shadow
- large rounded corners by default

### Transcript frame

[pocket_transcript_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/surfaces/pocket_transcript_frame.dart)

Used for:

- transcript cards
- changed files
- approval request
- plan cards
- reasoning cards
- SSH transcript surfaces

Design characteristics:

- bounded width
- rounded card shell
- border and shadow
- default transcript padding

### Badge primitives

[pocket_badge.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/primitives/pocket_badge.dart)

Current badge families:

- `PocketTintBadge`
- `PocketSolidBadge`
- `TranscriptBadge`
- `InlinePulseChip`
- `StateChip`

Design characteristics:

- pill radius
- small, dense typography
- tinted fills
- color-coded semantic labels

### Meta card primitive

[pocket_meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/ui/primitives/pocket_meta_card.dart)

Used for:

- informational support cards
- compact icon + title + body blocks

Design characteristics:

- accent-colored heading
- inline icon
- bordered panel shell
- dense text layout

## 5. Transcript-specific visual language

Transcript surfaces are driven by
[conversation_card_palette.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart).

### Core transcript neutrals

Light:

- primary text: `#1C1917`
- secondary text: `#57534E`
- muted text: `#78716C`
- code surface: `#F0EBDE`
- code text: `#1C1917`

Dark:

- primary text: `#F4F2ED`
- secondary text: `#D6D0C5`
- muted text: `#A8A29E`
- code surface: `#0F191B`
- code text: `#E7F3F4`

### Terminal palette

Light:

- shell: `#1F2937`
- body: `#111827`
- text: `#E5E7EB`

Dark:

- shell: `#111B1D`
- body: `#0A1112`
- text: `#E5F0F1`

### Accent colors

Defined in the same file:

- teal: `#0F766E` / `#2DD4BF`
- blue: `#2563EB` / `#60A5FA`
- violet: `#7C3AED` / `#C4B5FD`
- pink: `#DB2777` / `#F9A8D4`
- purple: `#9333EA` / `#D8B4FE`
- amber: `#B45309` / `#FBBF24`
- red: `#DC2626` / `#F87171`

These are applied to:

- reasoning
- plan/proposed plan
- changed files
- work log families
- warnings / approvals / SSH states

### Assessment

This is functional, but still feels too “status palette driven.” The interface
leans heavily on tinted semantic containers instead of stronger hierarchy,
typography, or layout rhythm.

## 6. Current component families

These are the main visual families currently present in the app:

### Transcript cards

Examples:

- assistant message
- reasoning
- proposed plan
- plan update
- approval request / approval decision
- changed files
- work log group
- user input request / result
- usage / turn boundary
- SSH trust and failure states

Shared characteristics:

- bounded card width
- rounded bordered containers
- frequent accent-colored headings
- badge-heavy state signaling
- many nested status rows and inner containers

### Sheet and settings surfaces

Examples:

- connection settings
- modal sheet scaffold

Shared characteristics:

- rounded top sheet silhouette
- internal header + divider + scrollable body structure
- dense content zones in a pale sheet background

### Workspace and empty states

Examples:

- empty state
- desktop workspace sidebar
- dormant roster surfaces

Shared characteristics:

- panel grouping
- bordered soft surfaces
- subdued neutral background layers

## 7. What is stylistically common across the app

These are the strongest current common traits:

- large radii
- soft borders
- muted beige/teal neutral base
- accent-tinted component states
- compact badges and pills
- medium-density padding
- low drama typography
- panels and cards as the dominant organizational tool

This means the current shared language is less about composition and more about:

- “put it in a panel”
- “tint it by state”
- “add a badge”

That is exactly why the result starts to feel repetitive and over-containerized.

## 8. What currently looks weak or unprofessional

This is the blunt assessment.

### Too many cards

The UI relies too heavily on rounded bordered cards and sub-cards. Even after
cleanup, the system still tends to solve hierarchy by adding another container.

### Too much tinted state treatment

Many surfaces use semantic tint as the primary signal. That makes the system
look busy and slightly amateur instead of precise and intentional.

### Not enough typographic authority

The interface does not yet get enough hierarchy from typography alone. It falls
back to color and containment too often.

### Softness without sophistication

The current palette is soft and pleasant, but it does not read as especially
sharp, premium, or confident.

### Engineering-first composition

A lot of the current visual system still feels like it was assembled from
reasonable reusable parts rather than designed as one coherent language.

### Inconsistent abstraction depth

Some surfaces are fairly polished; others still look like direct renderings of
runtime state objects with styling attached afterward.

## 9. What this means for design work

Design should not assume the current style language is the target.

The current system should be treated as:

- an implementation baseline
- a real inventory of what exists
- a record of current dependencies and shared primitives

It should not be treated as:

- the intended final brand language
- a mature design system
- a professional visual identity worth preserving wholesale

## 10. Practical implication for redesign

Any redesign needs to decide, deliberately:

- how many surfaces should really be cards at all
- when color should signal meaning vs when layout/typography should do that
- what the true neutral palette should feel like
- whether the product should feel calmer, sharper, more technical, or more
  editorial
- which primitives remain foundational and which should be replaced

The current codebase already has real shared primitives and tokens, which is
useful.

But the current look is still not good enough. It is documented here as the
truth of what exists, not as an endorsement.
