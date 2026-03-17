# Transcript Chronology Status

This document is now the canonical summary of transcript chronology behavior.
It is no longer an active redesign plan.

## Contract

- committed transcript history is append-only
- only the current contiguous live tail may mutate
- request overlays stay off the timeline until they resolve
- turn-level metadata does not own visible transcript cards
- if the same item resumes after any visible interruption, it must fork a new
  card instead of rewriting older history

## Current Code State

The structural rewrite is in place:

- live transcript ownership uses explicit turn artifacts instead of mutating
  committed history
- repeated plan updates append as separate `Updated Plan` cards
- sequential and resumed file changes stay chronological instead of collapsing
  into one mutable card
- opening approval or user-input requests freezes the live tail before the
  pending overlay takes over
- resolved requests append back into history and duplicate notifications are
  idempotent
- local user prompts no longer mutate when provider echoes arrive later
- file-change artifacts are derived from item snapshots and item output, not
  from a separate turn-level transcript owner

Primary code areas:

- `lib/src/features/chat/application/transcript_policy.dart`
- `lib/src/features/chat/application/transcript_item_policy.dart`
- `lib/src/features/chat/application/transcript_request_policy.dart`
- `lib/src/features/chat/application/transcript_turn_segmenter.dart`
- `lib/src/features/chat/models/codex_session_state.dart`

## Verified Parity

Automated reducer and widget coverage exists for:

- interrupted and resumed assistant history
- assistant -> work -> assistant chronology
- repeated plan updates
- distinct sequential file-change items
- same-item file-change resumption after warning or approval interruption
- request-open tail freeze and resolved-request chronology
- richer user-input resolution surviving later generic resolution events

Primary regression suites:

- `test/codex_session_reducer_test.dart`
- `test/chat_screen_app_server_test.dart`

Live verification completed so far:

- an emulator run confirmed `assistant -> assistant -> updated plan`
  chronology, with earlier cards staying frozen
- an emulator run confirmed two sequential file changes render as two separate
  `Changed files` cards in order

## Working-Tree Fix

The current worktree includes one additional live bug fix:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
  now sends approval policy `on-request` instead of the invalid `onRequest`
  variant

Repo-side verification for that fix:

- `dart analyze` on the request API and its transport test passed
- `test/codex_app_server_client_test.dart` passed via the Dart test runner

## Current Blocker

The remaining transcript close-out work is no longer an ownership problem. It
is a live verification problem plus a local build/runtime blocker.

What is still blocked:

- rerunning the fixed Android build on the emulator to verify approval and
  user-input request surfaces after the `on-request` transport fix

Current local environment blockers:

- fresh `flutter run -d emulator-5554` fails because the local `adb` daemon
  cannot start in this environment
- fresh Android builds currently fail before install because Gradle cannot
  determine a usable wildcard IP for this machine
- Linux debug runs are also blocked here because the local machine is missing
  `libsecret-1>=0.18.4`

## Remaining Close-Out

Once a fresh build can be run again, the remaining transcript verification is:

1. rerun the live emulator sweep for:
   - approval open -> resolved -> assistant resumes
   - user-input open -> resolved -> assistant resumes
   - repeated plan updates
   - sequential file changes
   - same-item resumption after warnings or request interruptions
2. confirm during those runs that older cards never mutate or reorder
3. compare the observed order against the local Codex reference in
   `.reference/codex/codex-rs/tui/src/chatwidget.rs`
4. if the live runs stay clean, treat transcript chronology as complete and
   stop using this area as an active migration project
