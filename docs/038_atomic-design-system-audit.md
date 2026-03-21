# 034 Atomic Design System Audit

## Conclusion

Pocket Relay does not currently have a true atomic design system.

It has:

- centralized theme tokens
- a recognizable visual language
- some reusable presentation helpers
- several feature-level components with good seams

It does not have:

- a formal layer model from tokens to atoms to composed surfaces
- a dedicated shared component library
- consistent primitive ownership
- stable rules for what belongs in `core` versus feature presentation

The current state is best described as:

feature-driven UI with partial shared primitives, not a first-class design
system.

This matches the diagnosis already emerging in
[032_visual-component-inventory.md](/Users/vince/Projects/Pocket-Relay/docs/032_visual-component-inventory.md)
and
[033_designer-redesign-brief.md](/Users/vince/Projects/Pocket-Relay/docs/033_designer-redesign-brief.md):
the problem is systemic, but the system itself is still mostly implicit.

## Audit Standard

For this audit, an atomic design system would require all of the following:

1. Explicit design tokens.
2. Reusable atoms with stable ownership.
3. Reusable molecules built from those atoms.
4. Larger organisms and templates composed from shared pieces.
5. Clear placement rules for what is generic versus feature-specific.
6. Preview and verification support aligned to those layers.

Pocket Relay meets parts of `1` and fragments of `2` and `3`, but not the full
set.

## Current State By Layer

### 1. Tokens

Status: partial, real, but narrow.

Evidence:

- [pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart#L4)
  defines a `PocketPalette` theme extension with shared color tokens.
- [pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart#L103)
  centralizes `ThemeData` construction.
- [pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart#L129)
  standardizes input borders and fill behavior.

What exists:

- background colors
- surface colors
- surface border colors
- subtle surface colors
- input fill
- drag handle color
- shadow color

What is missing:

- typography tokens
- spacing tokens
- shape/radius tokens
- elevation levels
- semantic color roles beyond the basic palette
- state tokens for success, warning, error, info, selection, emphasis

Assessment:

This is the strongest shared design layer in the repo, but it is incomplete.
Many important visual values are still hardcoded in feature widgets.

### 2. Atoms

Status: weak and inconsistent.

Evidence of actual shared atoms:

- [modal_sheet_scaffold.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/widgets/modal_sheet_scaffold.dart#L4)
  provides a reusable sheet scaffold.
- [modal_sheet_scaffold.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/widgets/modal_sheet_scaffold.dart#L59)
  provides a reusable drag handle.
- [transcript_chips.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart#L4)
  defines badge/chip primitives.

Evidence of atom-like things that are not owned like atoms:

- [meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/meta_card.dart#L4)
  is reusable, but feature-owned under chat transcript support.
- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart#L4)
  is a frame primitive for a family of cards, but still lives inside one
  feature slice.

What is missing:

- shared button variants
- shared section headers
- shared panel/container primitive
- shared inline status labels
- shared icon-label row primitive
- shared stack/list spacing helpers
- shared empty-state frame
- shared card frame primitive used across transcript/settings/workspace

Assessment:

There are some atoms, but the repo does not treat them as a design-system
layer. Many atom-like widgets are trapped inside feature folders and cannot be
trusted as stable primitives yet.

### 3. Molecules

Status: present, but mostly feature-local.

Examples:

- [chat_app_chrome.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_app_chrome.dart#L5)
  contains title and overflow menu pieces that are good molecule candidates.
- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart#L159)
  includes a timeline selector composed from smaller pieces.
- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart#L88)
  builds repeated section blocks, but only inside settings.
- [chat_empty_state_body.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart#L219)
  defines a reusable-looking details panel, but it is embedded inside the empty
  state widget.

Assessment:

Molecules exist, but they are not extracted into a shared system. Most are
implemented as private helpers inside larger widgets, which is fine for product
shipping but not enough for a design system.

### 4. Organisms

Status: strong.

Examples:

- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart#L14)
  is a clear screen-level renderer.
- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart#L8)
  is a full feature surface.
- [connection_workspace_mobile_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart#L13)
  is a mobile shell organism.
- [connection_workspace_desktop_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart#L13)
  is a desktop shell organism.
- [connection_workspace_live_lane_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart#L18)
  is a lane-level surface.

Assessment:

This repo is actually better at organisms than atoms. Large UI surfaces are
reasonably well-structured, but they are often built directly from local helper
widgets instead of a shared component layer.

### 5. Templates / Page Structures

Status: implicit, not formalized.

Evidence:

- chat screen structure is repeated via
  [chat_screen_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_screen_shell.dart#L6)
  and
  [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart#L14)
- modal sheet layout is repeated via
  [modal_sheet_scaffold.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/widgets/modal_sheet_scaffold.dart#L4)

Assessment:

There are early template concepts, but they are not documented or framed as a
system layer.

## Where The System Actually Lives Today

The design language currently lives in three places:

1. Theme and palette.
   [pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart#L4)

2. Transcript support helpers.
   [conversation_card_palette.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart#L6),
   [meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/meta_card.dart#L4),
   [transcript_chips.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart#L4)

3. Feature surfaces that reimplement similar container logic.
   [chat_empty_state_body.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart#L146),
   [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart#L88),
   [connection_workspace_desktop_shell.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart#L125)

That is the core problem:

the visual system exists, but it exists as repeated implementation habits more
than as owned primitives.

## Strengths

### 1. Good top-level seams

The app already separates a lot of presentation from transport and storage.
That makes future extraction practical.

### 2. Centralized color palette

Color and some surface behavior are already centralized in
[pocket_theme.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/theme/pocket_theme.dart#L103).

### 3. Reusable sheet scaffold

[modal_sheet_scaffold.dart](/Users/vince/Projects/Pocket-Relay/lib/src/core/widgets/modal_sheet_scaffold.dart#L4)
is a genuine cross-feature primitive.

### 4. Presentation contracts already exist in places

Settings and chat both have contract/view-model layers that make UI extraction
more realistic than in a tightly coupled widget tree.

### 5. Widgetbook is now a viable forcing function

The new Widgetbook work means the repo now has a place where primitives can be
promoted intentionally instead of staying hidden inside features.

## Weaknesses

### 1. Too many hardcoded visual values in features

Examples:

- [chat_empty_state_body.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/chat_empty_state_body.dart#L149)
  hardcodes a large radius and gradient treatment.
- [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart#L93)
  hardcodes another large rounded section container.
- [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart#L217)
  hardcodes chip container styling for the timeline selector.

### 2. Shared-looking components are trapped inside features

Examples:

- [meta_card.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/meta_card.dart#L4)
- [conversation_card_palette.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart#L6)
- [ssh_card_frame.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart#L4)

These may be valid shared primitives, but their ownership says “chat-only.”

### 3. Shape language is not tokenized

Large radii such as `18`, `20`, `24`, `28`, and `32` are used repeatedly across
features without an explicit scale.

### 4. Accent semantics are encoded in helper functions, not a formal token layer

[conversation_card_palette.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart#L91)
maps block kind to accent behavior. That is useful, but it is still one feature
inventing its own semantic system.

### 5. System boundaries are folder-weak

There is no directory that clearly represents:

- atoms
- molecules
- reusable layout primitives
- reusable status primitives
- shared surface frames

## Classification Of Existing Pieces

### Real Shared Primitives

- `PocketPalette`
- `buildPocketTheme`
- `ModalSheetScaffold`
- `ModalSheetDragHandle`

### Candidate Shared Primitives

- `MetaCard`
- `TranscriptBadge`
- `InlinePulseChip`
- `StateChip`
- `SshCardFrame`
- transcript accent helpers from `conversation_card_palette.dart`

### Feature-Owned Organisms That Should Stay Feature-Owned

- `ConnectionWorkspaceMobileShell`
- `ConnectionWorkspaceDesktopShell`
- `ConnectionWorkspaceLiveLaneSurface`
- `ConnectionSettingsSheetSurface`
- `FlutterChatScreenRenderer`

### Mixed-Ownership Widgets That Need Clarification

- `ChatEmptyStateBody`
  It behaves like a designed shared surface, but ownership is chat-specific.
- timeline chips inside
  [flutter_chat_screen_renderer.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart#L189)
  They may remain feature-specific, but they currently read like ad hoc
  component work.
- settings sections inside
  [connection_settings_sheet_surface.dart](/Users/vince/Projects/Pocket-Relay/lib/src/features/settings/presentation/connection_settings_sheet_surface.dart#L88)
  These are clearly reusable section containers, but they are not promoted.

## Verdict

If judged strictly, the repo is at:

- Tokens: `partially present`
- Atoms: `emerging`
- Molecules: `feature-local`
- Organisms: `strong`
- Templates: `implicit`
- Design system maturity overall: `early, not formalized`

This is not a failure state. It is a normal mid-product state.

The important point is:

the next work should not be “build an atomic system from scratch.”
The next work should be “promote the implicit system that already exists into
explicit ownership.”

## Recommended Target Structure

Do not adopt atomic design as a naming religion.
Adopt it as an ownership model.

Recommended shared UI structure:

- `lib/src/core/theme/`
  tokens, semantic roles, spacing/shape/elevation scales
- `lib/src/core/ui/primitives/`
  low-level reusable atoms such as badges, pills, drag handles, framed panels
- `lib/src/core/ui/surfaces/`
  shared containers such as modal sheets, info cards, pane frames
- `lib/src/core/ui/layout/`
  spacing and section scaffolds
- `lib/src/features/...`
  organisms and product-specific compositions

This keeps real primitives shared while preserving feature ownership for large
behaviors.

## Recommended Extraction Order

### Phase 1: Tokenize what is already repeated

Extract:

- radius scale
- spacing scale
- surface elevation/border recipes
- semantic accent roles

Do this before creating more components.

### Phase 2: Promote obvious shared primitives

Promote:

- `MetaCard`
- transcript chip variants
- a shared panel/section container
- a shared framed-card primitive

### Phase 3: Normalize repeated surface patterns

Unify the repeated “rounded bordered container with optional tint/shadow”
patterns used across:

- transcript cards
- settings sections
- empty states
- sidebar items

### Phase 4: Keep organisms where they belong

Do not move full chat screens, workspace shells, or settings flows into
`core`. Their ownership belongs to features.

### Phase 5: Align Widgetbook to the system

After extraction, Widgetbook should be grouped by:

- foundations
- primitives
- composite surfaces
- product screens

That is when Widgetbook becomes useful for both engineering and design review.

## Immediate Next Steps

1. Create a minimal shared UI namespace under `core` for primitives and
   surfaces.
2. Extract a small radius and spacing scale from the hardcoded values already in
   use.
3. Promote `MetaCard` and transcript chip variants into shared primitives if
   they survive a naming pass.
4. Introduce one shared surface container used by settings sections and at least
   one transcript family.
5. Reorganize Widgetbook around foundations, primitives, and product surfaces.

## Bottom Line

Pocket Relay does not currently have an atomic design system.

It has enough raw material to build one without a rewrite.

The right move is not to impose a big abstract framework. The right move is to
formalize the tokens and shared primitives that are already trying to emerge,
then leave feature-owned organisms where they are.
