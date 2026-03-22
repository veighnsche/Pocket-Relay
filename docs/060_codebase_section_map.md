# Codebase Section Map

## Purpose

This document is the first step of the repo-wide simplification and refactor
review.

Before judging whether the abstractions are correct, the tree has to be split
into stable sections. The goal here is not to redesign anything yet. The goal
is to define the sibling groups that should later be compared for consistency.

## What A Section Is

A section is a repo-owned sibling slice under one parent.

For this review, a section is valid when all of the following are true:

- it answers one clear ownership question
- it is compared against its siblings, not arbitrary cousins
- a new sibling could be added by following the same shape
- it is real repo-owned code, config, docs, or assets, not generated output

Working rule:

- sections are siblings first
- cousins are only useful as a secondary comparison after the sibling set is
  already clean

In other words, if we want to ask whether the abstraction is right, the first
question is not "what looks similar anywhere in the repo?" The first question
is "what contract should every child of this parent share?"

At the repository root, one section may map to a small set of sibling paths
when the root mixes files and directories. That is still a valid section as
long as the grouped paths share one ownership purpose.

## Non-Sections

These paths should not be treated as architectural sections for the review:

- `.git/`
- `.dart_tool/`
- `build/`
- `.idea/`
- `.reference/`
- `android/.gradle/`
- `android/.kotlin/`
- `ios/Flutter/ephemeral/`
- `linux/flutter/ephemeral/`
- `macos/Flutter/ephemeral/`
- `windows/flutter/ephemeral/`

They are caches, local state, or generated output, not durable ownership
boundaries.

## Repo-Wide Sections

These are the top-level review sections for the whole repository.

### 1. Root Contracts And Config

Paths:

- `AGENTS.md`
- `README.md`
- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `justfile`

Shared contract:

- repo policy
- package/build definition
- top-level developer entrypoints

### 2. Product Assets

Paths:

- `assets/`
- `icon.png`

Shared contract:

- shipped static visual assets

### 3. App Product Code

Paths:

- `lib/main.dart`
- `lib/src/`

Shared contract:

- real Flutter application behavior

Current size snapshot:

- `lib/`: `273` files
- `lib/src/`: `268` files

### 4. Preview Code

Paths:

- `lib/widgetbook/`

Shared contract:

- downstream preview and story registration for real app-owned surfaces

Current size snapshot:

- `lib/widgetbook/`: `4` files

### 5. Verification

Paths:

- `test/`

Shared contract:

- tests
- fixtures
- test-only support seams

Current size snapshot:

- `test/`: `55` files

### 6. Developer Tooling

Paths:

- `tool/`
- `scripts/`

Shared contract:

- developer-run automation, fixture capture, and helper commands

Current size snapshot:

- `tool/`: `2` files
- `scripts/`: `4` files

### 7. Platform Shells

Paths:

- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

Shared contract:

- platform packaging
- platform runner glue
- platform-specific app bootstrap/config

### 8. Architecture And Review Docs

Paths:

- `docs/`

Shared contract:

- architecture plans
- audits
- migration notes

Current size snapshot:

- `docs/`: `60` files including this one

## App Product Code Sections

Inside `lib/src/`, the first real sibling set is:

- `app/`
- `core/`
- `features/`

These are true siblings because they answer different ownership questions at
the same level.

### `lib/src/app/`

Purpose:

- app composition root
- dependency assembly
- top-level shell/bootstrap decisions

Current file siblings:

- `pocket_relay_bootstrap.dart`
- `pocket_relay_dependencies.dart`
- `pocket_relay_app.dart`
- `pocket_relay_shell.dart`

### `lib/src/core/`

Purpose:

- cross-feature infrastructure and primitives that are not owned by one product
  feature

Current sibling sections:

- `device/`
- `models/`
- `platform/`
- `storage/`
- `theme/`
- `ui/`
- `utils/`
- `widgets/`

Current size snapshot:

- `device/`: `1` file
- `models/`: `6` files
- `platform/`: `2` files
- `storage/`: `10` files
- `theme/`: `1` file
- `ui/`: `6` files
- `utils/`: `4` files
- `widgets/`: `1` file

Notable nested sibling set:

- `lib/src/core/ui/`
  - `layout/`
  - `primitives/`
  - `surfaces/`

### `lib/src/features/`

Purpose:

- product-owned runtime surfaces and their supporting state/logic

Current sibling sections:

- `workspace/`
- `connection_settings/`
- `chat/`

Current size snapshot:

- `workspace/`: `24` files
- `connection_settings/`: `9` files
- `chat/`: `200` files

## Feature Sections

### `lib/src/features/workspace/`

Shared contract:

- workspace-level shell, lane selection, history surfacing, and live/dormant
  workspace coordination

Current sibling sections:

- `domain/`
- `application/`
- `infrastructure/`
- `presentation/`

Current size snapshot:

- `domain/`: `2` files
- `application/`: `5` files
- `infrastructure/`: `2` files
- `presentation/`: `15` files

### `lib/src/features/connection_settings/`

Shared contract:

- editing and presenting connection configuration

Current sibling sections:

- `domain/`
- `application/`
- `presentation/`

Current size snapshot:

- `domain/`: `2` files
- `application/`: `3` files
- `presentation/`: `4` files

### `lib/src/features/chat/`

Shared contract:

- the live Codex conversation pipeline and the UI that presents it

Current sibling sections:

- `composer/`
- `lane/`
- `lane_header/`
- `requests/`
- `runtime/`
- `transcript/`
- `transcript_follow/`
- `transport/`
- `worklog/`

Current size snapshot:

- `composer/`: `6` files
- `lane/`: `30` files
- `lane_header/`: `1` file
- `requests/`: `7` files
- `runtime/`: `9` files
- `transcript/`: `89` files
- `transcript_follow/`: `2` files
- `transport/`: `19` files
- `worklog/`: `37` files

Recommended meaning of each chat sibling:

- `composer/`: prompt drafting and attachment preparation
- `lane/`: live lane/session orchestration and root lane presentation
- `lane_header/`: lane-header projection/presentation
- `requests/`: approval and pending-user-input contract/presentation
- `runtime/`: mapping transport payloads into runtime events
- `transcript/`: transcript state, reduction, policy, projection, and rendering
- `transcript_follow/`: transcript follow behavior
- `transport/`: app-server protocol/process/connection layer
- `worklog/`: tool/work-log parsing, projection, and presentation

## Nested Feature Section Sets

These are the next sibling sets that are real enough to review later for
shared abstractions.

### Layered Feature Sets

These features already have an internal layer-based sibling contract:

- `lib/src/features/workspace/`
  - `domain/`
  - `application/`
  - `infrastructure/`
  - `presentation/`
- `lib/src/features/connection_settings/`
  - `domain/`
  - `application/`
  - `presentation/`
- `lib/src/features/chat/transcript/`
  - `domain/`
  - `application/`
  - `presentation/`
- `lib/src/features/chat/worklog/`
  - `domain/`
  - `application/`
  - `presentation/`
- `lib/src/features/chat/requests/`
  - `domain/`
  - `presentation/`

### Thin Or Single-Layer Feature Sets

These are still valid sections, but they do not yet have a deeper sibling set
that needs standardization:

- `lib/src/features/chat/runtime/`
  - `application/`
- `lib/src/features/chat/lane_header/`
  - `presentation/`
- `lib/src/features/chat/transcript_follow/`
  - `presentation/`
- `lib/src/features/chat/transport/`
  - `app_server/`
    - `testing/`

## Section Map For The Later Review

These are the sibling sets that matter most when we later ask whether new
siblings would be trivial to add:

1. repo-wide sections at the repository root
2. `lib/src/`: `app`, `core`, `features`
3. `lib/src/features/`: `workspace`, `connection_settings`, `chat`
4. `lib/src/features/chat/`: the nine chat subfeatures
5. each layer set inside `workspace`, `connection_settings`, `transcript`,
   `worklog`, and `requests`

## Initial Observation, Not Yet A Fix Plan

The section map already exposes the main structural question for the next
review pass:

- `workspace` and `connection_settings` are layer-first feature sections
- `chat` is a feature made of subfeatures first, then layers inside some of
  those subfeatures

That does not automatically mean the tree is wrong, but it is the first place
where sibling consistency should be challenged when the simplification review
starts.
