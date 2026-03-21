# Codex Frontend Parity Status

## Purpose

Record the current parity status between upstream Codex and Pocket Relay's
Flutter frontend.

This document is a status snapshot, not a speculative roadmap.

## Scope

When this document says "parity", it separates three different meanings:

- backend-semantic parity
- runtime/data-model parity
- frontend interaction parity

These are not the same thing.

Pocket Relay should aim for backend-semantic parity first. It must not fake a
Codex feature in Flutter if the backend semantics do not match.

## Overall Status

Pocket Relay has strong parity with Codex in several backend-driven flows, but
it does not have literal UI parity with the TUI and should not try to.

Current assessment:

- backend-semantic parity: medium to high
- runtime/data-model parity: medium to high
- literal TUI interaction parity: low by design
- product-meaning parity for implemented features: medium to high

## What "Good Parity" Means Here

For Pocket Relay, good parity means:

- the same upstream protocol or app-server primitive is used
- the same source of truth is used
- the same lifecycle truth is preserved
- the same destructive or stateful consequences are represented honestly

It does not mean:

- the same keyboard shortcuts
- the same overlay structure
- the same visual layout
- the same exact interaction sequence as the terminal UI

## Areas With Stronger Parity

### 1. Historical transcript restoration

Pocket Relay restores saved conversations from upstream `thread/read`, not from
an app-local transcript archive.

Parity assessment:

- backend-semantic parity: high
- frontend interaction parity: medium

### 2. Thread continuation and resume

Pocket Relay resumes real upstream threads via `thread/resume` semantics rather
than inventing a local continuation model.

Parity assessment:

- backend-semantic parity: high
- frontend interaction parity: medium

### 3. Prompt rewind / continue from earlier prompt

Pocket Relay now matches the important upstream Codex rollback semantics.

Implemented behavior:

- select an earlier sent user prompt
- compute rollback depth from that prompt position
- call upstream `thread/rollback`
- restore returned upstream history after success
- prefill the composer from the selected earlier prompt

Pocket Relay entry points:

- long-press on eligible prompt
- visible inline `Continue From Here` action
- desktop secondary-click context menu

Upstream TUI entry point:

- `Esc`
- `Esc`
- navigate transcript overlay
- `Enter`

Parity assessment:

- backend-semantic parity: high
- frontend interaction parity: intentionally different
- product-meaning parity: high

### 4. Transcript/work-log lifecycle mapping

Pocket Relay preserves a large amount of upstream lifecycle truth in the
transcript and work-log projection layers rather than collapsing everything
into generic chat bubbles.

Examples:

- approvals
- user input requests
- changed files
- SSH lifecycle failures
- work-log rows for commands, searches, reads, MCP calls

Parity assessment:

- backend-semantic parity: medium to high
- frontend interaction parity: medium

## Areas That Are Intentionally Not Literal Parity

### 1. TUI-specific keyboard state machines

Pocket Relay is not a terminal application. It should not attempt literal
shortcut parity where the only shared behavior is key choreography.

Examples:

- `Esc`-driven backtrack state
- transcript overlay keyboard routing
- terminal-native alternate-screen flows

Assessment:

- literal parity: intentionally low
- semantic parity target: only where backend state changes are involved

### 2. Visual structure

Pocket Relay should not mirror the TUI visually just to claim parity.

Assessment:

- literal parity: intentionally low
- product parity target: preserve meaning, not terminal layout

## Current Known Gaps

These are parity gaps worth tracking, not proof of failure.

### 1. Some implemented features may still differ in edge-case interaction flow

Pocket Relay can be semantically correct while still differing from Codex TUI
in:

- intermediate preview behavior
- transient selection states
- exact affordance sequencing

### 2. Fork/branch behavior is not part of the rewind flow

Pocket Relay now supports rollback-based rewind semantics, but this should not
be confused with explicit branch/fork parity.

### 3. There is no goal of complete TUI mimicry

If a feature is TUI-specific and not backend-owned, Pocket Relay should only
mirror it when the product meaning matters in Flutter.

## Current Honest Summary

Pocket Relay is not a TUI clone.

Pocket Relay does have meaningful parity with upstream Codex where it matters
most:

- backend-owned thread semantics
- transcript restoration truth
- request and lifecycle truth
- rewind/rollback semantics

Pocket Relay does not claim:

- literal interaction parity
- terminal overlay parity
- keyboard shortcut parity

That is the correct parity target for this project.

## Related Docs

- `docs/004_codex-parity-maturity-plan.md`
- `docs/018_codex-app-server-emission-parity.md`
- `docs/042_codex-tui-flutter-widget-parity-gaps.md`
- `docs/046_prompt_rewind_resume_investigation.md`
