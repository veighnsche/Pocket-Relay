# Changed File Diff Drawer Overhaul Plan

## Why This Doc Exists

The changed-file drawer currently renders real diff data, but it does not
present that data in a way that is easy for a human to review.

The problem is specifically inside the drawer body:

- too much width is spent on diff mechanics instead of code
- the renderer reads like terminal output instead of a review surface
- the main reading flow is cluttered by raw patch metadata
- the current hierarchy makes it hard to understand where a change starts,
  what changed, and how much unchanged context matters

This document defines a narrow overhaul of the changed-file diff drawer body.
It does not authorize a broader redesign of the sheet shell, the changed-files
row list, or adjacent transcript surfaces.

## Scope

Allowed to change:

- the file-content and diff presentation inside the changed-file drawer
- the application-owned presentation shaping that feeds that drawer
- tests that currently lock the old drawer-body behavior

Must remain materially the same:

- the drawer entry point and callback boundary
- the drawer shell, close action, header ownership, and metrics ownership
- the changed-files list surface outside the drawer
- backend-facing diff parsing and file matching behavior unless a small parser
  extension is required

Non-goals:

- no redesign of the surrounding drawer chrome
- no language-specific review modes
- no fake product states beyond real diff/runtime truth
- no Widgetbook-owned implementation
- no new card/panel treatment inside the drawer

## Product Goal

The drawer should stay diff-native, but it should stop looking like raw Git
output.

The target user experience is:

- one quick scan reveals where the change blocks are
- code gets most of the horizontal space
- the viewer remains truthful to the underlying patch
- the default view favors comprehension over patch syntax
- exact patch fidelity is still available when needed

## Current Source Investigation

### 1. Entry And Scope Boundary Are Already Clean

The drawer opens through the existing overlay boundary in
[`lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart`](../lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart).
That means the overhaul can stay local to the changed-file drawer without
rewiring the transcript surface or lane routing.

The actual sheet shell is owned by
[`lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet.dart).
That file already gives us a clean edit boundary:

- header stays in `_ChangedFileDiffSheetHeader`
- metrics stay in `_ChangedFileDiffSheetMetrics`
- preview notice stays in `_PreviewNotice`
- the body is isolated behind `_DiffCodeFrame`

That is the correct place to keep the scope narrow.

### 2. The Current Body Is A Terminal-Style Table

The current drawer body lives in
[`lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart).

Today it renders every visible diff line as:

- old line number column
- new line number column
- diff marker column
- code column

This is structurally expensive on a drawer-sized surface, especially on narrow
widths. Even with fixed numeric widths, the reading experience is dominated by
gutter mechanics instead of code.

Additional current issues:

- the whole body is one horizontally scrolling code canvas
- meta lines, hunk lines, and code lines all compete in the same visual stream
- per-line full-width tinting makes the surface noisy
- the body uses generic `'monospace'` instead of an app-owned code typography
  decision

### 3. The Parser Is Better Than The Current Presentation

The unified diff parser in
[`lib/src/features/chat/worklog/application/chat_changed_files_item_projector_diff.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_item_projector_diff.dart)
already does useful work that should be preserved:

- splits patches by file
- matches renamed paths
- derives additions/deletions
- detects binary patches
- tracks hunk boundaries
- tracks old/new line cursors

The main issue is not that the parser lacks truth. The issue is that the UI is
rendering parsed diff lines too literally.

### 4. The Contract Is Too Flat For A Human-Oriented Viewer

The drawer is fed by `ChatChangedFileDiffContract` in
[`lib/src/features/chat/worklog/application/chat_changed_files_contract.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_contract.dart).
That contract currently exposes:

- a flat `lines` list
- a diff line kind
- old and new line numbers per row

That is enough to reproduce a raw patch viewer, but it is not enough to express
a better reading model such as:

- metadata separated from content
- humanized hunk sections
- collapsed unchanged runs
- unified single-gutter display rows
- optional raw-patch fallback

This is the main architectural gap.

### 5. Existing Tests Lock The Wrong Default Experience

The current widget coverage in
[`test/codex_ui_block_surface_test.dart`](../test/codex_ui_block_surface_test.dart)
proves the feature exists, but some assertions currently lock the old visual
model:

- tests assert raw `diff --git` headers are visible in the drawer
- rename coverage expects raw patch lines in the primary reading flow
- large-diff preview tests reason in terms of visible raw patch lines

Those tests should be updated, not defended, if the drawer moves to a better
default review model.

## Recommended UX Model

The default drawer body should become a **hunk-based unified review viewer**.

It should preserve actual code lines and actual diff truth, but stop forcing the
user to read raw patch syntax as the primary view.

### Default Reading Model

- one code column
- one compact leading gutter token per code row
- hunk sections instead of raw hunk syntax
- metadata separated from the code stream
- collapsed unchanged gaps
- subdued syntax highlighting
- diff state more visually important than syntax color

### What The User Sees

For normal code diffs:

- file summary and rename status remain in the sheet header area
- a compact metadata strip shows only meaningful file-level facts
- change blocks are grouped by hunk
- each hunk is labeled with a readable location such as `Around line 142`
- rows use a unified gutter token:
  - `142` for unchanged context
  - `+143` for additions
  - `-142` for deletions
- long unchanged runs collapse to a divider such as `12 unchanged lines`

For binary diffs:

- keep a truthful binary surface
- do not try to invent code review structure where no code exists
- file-level binary messaging can remain much closer to the existing model

### What The User Does Not See By Default

These lines should not dominate the main reading flow:

- `diff --git`
- `index`
- `---`
- `+++`
- raw `@@ -x,y +a,b @@`

They remain valid diff truth, but they should move behind a compact metadata or
raw-patch affordance instead of being the default body.

### Visual Hierarchy

The drawer body should communicate change with restraint:

- use a thin left accent or narrow gutter emphasis for add/remove state
- avoid strong full-width color bands on every row
- make hunk separators feel like structural dividers, not code
- keep labels and section framing in the normal app type
- keep code in code typography

## Recommended Architecture

### Ownership Decision

The new review model should be owned in app code under
`lib/src/features/chat/worklog/application/...`, not improvised inside the
widget tree.

Reason:

- grouping, collapsing, metadata suppression, and humanized hunk labeling are
  product presentation logic
- that logic is too important to hide inside a local widget helper
- widget code should render a prepared review model, not decide diff semantics

### Best Upgrade Path

The lowest-risk path is:

1. keep the existing unified diff parser as the source of truth
2. keep the existing per-file patch matching and row-opening pipeline
3. add a new review-model shaping layer on top of the existing parsed diff
4. replace only the drawer body renderer to consume that new review model

This preserves current backend truth and matching behavior while changing the
human-facing reading model.

### Proposed New Presentation Layer

Add a new application-owned transformer that converts a `ChatChangedFileDiffContract`
into a review-oriented model.

Suggested ownership:

- new file near
  [`lib/src/features/chat/worklog/application/chat_changed_files_item_projector.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_item_projector.dart)
- or a dedicated review-model file under
  `lib/src/features/chat/worklog/application/`

Suggested model shape:

- `ChatChangedFileReviewContract`
- `ChatChangedFileReviewSectionContract`
- `ChatChangedFileReviewRowContract`

Suggested section kinds:

- metadata
- hunk
- collapsedGap
- binaryMessage

Suggested row kinds:

- context
- addition
- deletion

Suggested row fields:

- `displayLineToken`
- `content`
- `syntaxLanguage`
- `kind`
- `oldLineNumber`
- `newLineNumber`

The raw old/new numbers should still exist in the model for truth and for a
possible raw-patch toggle, but they should no longer force the default layout.

## Phased Implementation Plan

### Phase 1: Introduce Review Model Without Changing Parser Truth

Goal:

- keep `_parseUnifiedDiff()` as the authoritative patch parser
- add a separate review-model shaping layer

Work:

- add application-owned review contracts
- transform flat diff lines into:
  - file-level metadata
  - hunk sections
  - display rows
  - collapsed unchanged gaps
- keep binary files on a dedicated fallback path

Why first:

- this is the structural change that prevents the widget from owning product
  logic
- it also makes the renderer rewrite much simpler

Primary files:

- [`lib/src/features/chat/worklog/application/chat_changed_files_contract.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_contract.dart)
- [`lib/src/features/chat/worklog/application/chat_changed_files_item_projector.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_item_projector.dart)
- [`lib/src/features/chat/worklog/application/chat_changed_files_item_projector_diff.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_item_projector_diff.dart)
- [`lib/src/features/chat/worklog/application/chat_changed_files_item_projector_support.dart`](../lib/src/features/chat/worklog/application/chat_changed_files_item_projector_support.dart)

Done when:

- the widget tree no longer has to interpret raw diff structure directly

### Phase 2: Replace The Drawer Body Renderer

Goal:

- swap the current raw-patch table for the hunk-based unified review viewer

Work:

- replace `_DiffCodeFrame` rendering logic
- remove the dual old/new gutter columns from the default view
- introduce section dividers for hunk labels and collapsed gaps
- separate file-level metadata from code rows
- preserve selection and horizontal code scrolling

Primary files:

- [`lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart)
- [`lib/src/features/chat/worklog/presentation/widgets/changed_files_support.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_support.dart)

Done when:

- the code column is the dominant element in the drawer
- hunk sections are readable without raw patch syntax
- the default view no longer feels like a terminal dump

### Phase 3: Tone Down Syntax And Typography

Goal:

- make the viewer easier to scan without language-specific special cases

Work:

- introduce an app-owned code text style instead of repeated `'monospace'`
- reduce syntax color intensity in diff rows
- ensure add/remove state is stronger than syntax-token coloring
- keep syntax highlighting generic, not language-specific in behavior

Primary files:

- [`lib/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart`](../lib/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart)
- [`lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart)
- [`lib/src/features/chat/transcript/presentation/widgets/transcript/support/markdown_style_factory.dart`](../lib/src/features/chat/transcript/presentation/widgets/transcript/support/markdown_style_factory.dart)

Done when:

- the diff remains readable even without caring about the source language

### Phase 4: Optional Raw Patch Fallback

Goal:

- preserve exact patch visibility without making it the default

Work:

- add a `Raw patch` secondary affordance inside the drawer body area
- render the existing flat diff lines only in that fallback mode

Why optional:

- the main value is the new default viewer
- the raw patch fallback is useful, but it should not block the overhaul

Primary files:

- [`lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet.dart)
- [`lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart`](../lib/src/features/chat/worklog/presentation/widgets/changed_files_diff_sheet_code_frame.dart)

Done when:

- exact diff syntax is still accessible without being the main reading mode

## Verification Plan

### Update Existing Widget Tests

Revise drawer assertions in
[`test/codex_ui_block_surface_test.dart`](../test/codex_ui_block_surface_test.dart)
to verify the new product behavior instead of the old patch dump.

New expectations should focus on:

- tap-to-open still works
- rename and binary flows still work
- hunk sections are visible
- code lines remain visible
- collapsed gaps appear for long unchanged spans
- preview behavior still prevents pathological large renders
- raw patch lines are not required in the default body

### Add Focused Rendering Tests

Add targeted coverage for:

- single-hunk edited file
- multi-hunk file with large unchanged gaps
- created file
- deleted file
- renamed file
- binary file
- very large diff with preview cap

### Keep Parser And Matching Coverage

Existing parser and matching tests should remain because the backend truth has
not changed:

- patch extraction
- rename matching
- unmatched-file behavior
- diff-only payload handling

## Risks And Mitigations

### Risk: Logic Drifts Into The Widget Layer

Mitigation:

- put grouping/collapsing/humanized hunk shaping in application-owned code

### Risk: The Overhaul Breaks Binary Or Rename Handling

Mitigation:

- keep parser truth and file matching intact
- treat binary rendering as an explicit fallback branch
- preserve rename summary ownership in the existing file presentation contract

### Risk: Preview Behavior Regresses On Large Diffs

Mitigation:

- preserve preview limits in phase 1
- consider a lazy list once the review model exists

### Risk: Typography Remains Inconsistent

Mitigation:

- introduce one app-owned code text style instead of repeated hard-coded
  `'monospace'`

## Recommendation

Proceed with the overhaul using the review-model approach, not a direct widget
rewrite of the current flat `lines` list.

That path best fits the current codebase because:

- the diff parser is already good enough
- the drawer shell already has a narrow edit boundary
- the user problem is primarily presentation structure, not backend truth
- the new ownership line reduces future churn instead of creating another local
  widget-specific diff format

The correct implementation is not "make the current table prettier." The
correct implementation is to keep the parser truth and replace the drawer body
with an application-owned, hunk-based unified review model.
