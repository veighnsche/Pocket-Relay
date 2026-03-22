# Remaining PR Split And Review Process

## Goal

Work through the 6 currently open PRs in parallel without overlapping branch
ownership, while clearing the actual outstanding review threads on each PR.

This document is the coordination source of truth for the split. It is not a
request to chat with the remote AI agent. Each side works its assigned PRs
independently and uses the same review process.

## PR Split

The split is by surface area so each side stays in one coherent part of the
codebase and avoids cross-branch churn.

### This agent

- PR #24: restore legacy singleton profile bootstrap to preserve host key
  pinning
- PR #26: reject unpinned SSH host keys
- PR #31: fix capture tool launcher command injection

### Remote agent

- PR #27: bound retained changed-file diffs to global unified-diff budget
- PR #29: bound live model catalog pagination
- PR #30: stop persisting workspace drafts in SharedPreferences-backed recovery
  store

## Shared Process

Each assigned PR should be handled in the same sequence:

1. Check out the PR branch and read the current diff plus every unresolved
   review thread on that PR.
2. Validate each review comment against the actual code before changing
   anything. Do not accept or reject comments by summary alone.
3. Keep the fix scoped to the review issue and its direct tests. Do not widen
   into adjacent redesign.
4. Add or update tests that prove the specific regression is closed.
5. Run the smallest verification that proves correctness, then run broader
   verification if shared infrastructure changed.
6. Push the branch update only after the branch is green locally.
7. Resolve GitHub review threads only after the code change is on the branch
   and the relevant verification has passed.

## Guardrails

- Do not work on a PR assigned to the other side.
- Do not answer the remote AI agent directly. Coordination happens through this
  document, branch ownership, and the PR thread state.
- Do not resolve a thread unless the branch actually addresses that thread.
- Do not collapse a real product requirement into a cosmetic workaround just to
  clear a review.
- If a review comment implies a broader product or backend contract change,
  stop and document the blocker before widening scope.

## PR Worklists

### This agent

#### PR #24

Outstanding review issues to clear:

- make legacy profile JSON parsing resilient to corrupted
  `pocket_relay.profile` data
- restore the migration path even when a broken intermediate build already
  seeded a default catalog entry
- only migrate legacy secrets when a real legacy profile exists, so stale
  secure-storage data cannot synthesize a new default connection by itself

Verification expectation:

- targeted repository migration tests covering corrupt legacy JSON, seeded
  default-catalog recovery, and no-profile/no-migration behavior

#### PR #26

Outstanding review issues to clear:

- treat unpinned host-key failures as SSH bootstrap failures so the app does
  not emit an extra generic send failure for the same event
- preserve a real way to pin host keys from the conversation-history path,
  instead of turning that path into an opaque load failure on unpinned remotes
- optional cleanup: tighten the unpinned-host-key test assertion style if the
  branch is already touching that test block

Verification expectation:

- targeted transport and conversation-history tests proving one failure path,
  correct event mapping, and a pinning path that still exists for history loads

#### PR #31

Outstanding review issues to clear:

- keep fixture capture compatible with the app's shell-command launcher
  contract while still removing command-injection risk
- if tokenizer/parsing remains, remove duplicated escape handling and avoid
  rebuilding the whitespace matcher repeatedly
- extend the regression tests to cover more quoting and escaping edge cases

Verification expectation:

- targeted tool tests covering existing shell-style launcher cases plus the
  injection regression

### Remote agent

#### PR #27

Outstanding review issues to clear:

- dropping an entry diff must actually clear it instead of flowing through a
  `copyWith` path that preserves the old diff
- make `_lineCount` correct for empty strings
- reduce duplicated line-count logic in the test file

Verification expectation:

- targeted transcript segmenter tests proving the global changed-file diff
  budget is respected across multiple entries

#### PR #29

Outstanding review issues to clear:

- do not truncate healthy model catalogs just because the backend chose small
  pages
- do not overwrite a previously healthy cached catalog with a partial result
  when the repeated-cursor or guard path trips
- optional cleanup: simplify the cursor normalization block if the branch is
  already changing that loop

Verification expectation:

- targeted settings/catalog tests for repeated cursors, bounded failure
  handling, and healthy large-catalog behavior

#### PR #30

Outstanding review issues to clear:

- scrub legacy `draftText` before building a recovery-state object from decoded
  storage data
- preserve production cold-start draft restoration instead of silently dropping
  drafts from the existing recovery flow

Verification expectation:

- targeted recovery-store and workspace lifecycle tests proving drafts are no
  longer written to SharedPreferences but are still restored through the real
  app recovery path

## Definition Of Done Per PR

A PR is only done when all of the following are true:

- the unresolved review threads on that PR are either fixed or explicitly
  blocked with a concrete reason
- the branch has the tests needed for the reviewed behavior
- local verification for the touched surface has passed
- the final PR state matches the real product and backend/runtime contract
  instead of a narrowed approximation
