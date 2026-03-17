# UX Hardening Audit

This audit focuses on one specific failure mode:

- the app infers or preserves a user-facing story that is stronger than the
  underlying remote truth

The thread-resume fallback that was removed in `8c37dde` is the reference bug
for this class:

- the UI preserved conversation continuity
- the transport silently created a new remote thread
- the user was shown one conversation while talking to another

## Decision Rule

Use this rule for future hardening work:

- Fail hard when the heuristic changes conversation ownership, request
  semantics, or transcript truth.
- Infer state only when the inference is local, reversible, and clearly labeled
  as inferred.
- Keep noise-reduction hardening only when it removes duplication without
  changing product truth.

## Audit Results

### 1. Live tracked thread reuse

- File: `lib/src/features/chat/application/chat_session_controller.dart`
- Current behavior:
  - If local continuation ownership is missing, the controller can reuse
    `appServerClient.threadId`.
  - It presents this as "Recovered the active conversation from the live
    session."
- Evidence:
  - `_trackedThreadReuseCandidate()`
  - `_ensureAppServerThread()`
  - tests in `test/chat_session_controller_test.dart`
- Risk: High
- Why:
  - This still chooses remote conversation ownership by heuristic.
  - It is explicit, unlike the removed silent fallback, but it can still attach
    the next prompt to a thread the user did not explicitly choose.
- Recommended policy:
  - Do not auto-recover thread ownership from `appServerClient.threadId` alone.
  - Either:
    - fail hard and ask the user to start fresh or explicitly reconnect, or
    - require stronger proof than "the transport currently tracks one thread"
      before continuing.

### 2. Thread-object fallback from bare thread ids

- File: `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart`
- Current behavior:
  - `_asThread(...)` can construct a thread model from `payload['threadId']` or
    the requested thread id even when the server does not provide a full
    `thread` object.
- Introduced in:
  - `50b8e82`
- Risk: Medium
- Why:
  - This hides malformed or incomplete server responses.
  - The app may treat thread ownership and metadata as confirmed when they were
    only inferred.
- Recommended policy:
  - `thread/start` and `thread/resume` should fail hard if the server does not
    provide the expected thread object.
  - A bare id fallback is acceptable only for clearly labeled read-only display
    paths, not for ownership-establishing flows.

### 3. Fallback free-form user-input field

- File: `lib/src/features/chat/presentation/pending_user_input_presenter.dart`
- Current behavior:
  - When a pending user-input request has no questions, the presenter invents a
    generic `Response` field.
- Introduced in:
  - `8ee3567`
- Risk: Medium
- Why:
  - This is good UX only if the request type is known to be intentionally
    free-form.
  - If the request payload is malformed or incomplete, the UI pretends it knows
    the intended form shape.
- Recommended policy:
  - Keep this only for request types with a documented free-form fallback, such
    as known elicitation flows.
  - For other request types, surface a malformed-request error instead of
    inventing form structure.

### 4. Oldest-only pinned request selection

- File: `lib/src/features/chat/presentation/chat_pending_request_placement_projector.dart`
- Current behavior:
  - Only the oldest pending approval and the oldest pending user-input request
    are surfaced in the pinned region.
  - Other pending requests stay hidden until the visible one resolves.
- Introduced in:
  - `c3e6a22`
- Risk: Medium
- Why:
  - This suppresses real pending state in order to simplify the surface.
  - It is not a hidden transport rewrite, but it is still a UI-level
    compression of truth.
- Recommended policy:
  - Keep it only if the UI also shows that more pending requests exist, for
    example "1 of N".
  - If there is no queue indicator, broaden the surface or add explicit queue
    state so hidden requests are not effectively invisible.

### 5. Unknown lifecycle rendered as "Starting"

- File: `lib/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart`
- Current behavior:
  - `CodexAgentLifecycleState.unknown` is rendered as `Starting`.
- Risk: Low
- Why:
  - `unknown` and `starting` are not the same state.
  - This is a wording-level overclaim that can mislead the user about progress.
- Recommended policy:
  - Render `unknown` as `Unknown` or `Syncing`, not `Starting`.

### 6. Synthesized changed-file patches

- File: `lib/src/features/chat/application/transcript_changed_files_parser.dart`
- Current behavior:
  - The parser can synthesize a unified diff from structured change data when a
    real diff is not present.
- Introduced in:
  - `8f44034`
- Risk: Low
- Why:
  - This is useful for continuity, but a synthesized patch can look canonical if
    the UI does not say it was derived.
- Recommended policy:
  - Keep the synthesis, but label derived diffs as previews or synthesized
    output in the UI.

## Hardening That Looks Acceptable

These do not currently look like the same class of trust bug.

### 7. Duplicate SSH failure suppression

- File: `lib/src/features/chat/application/chat_session_controller.dart`
- Current behavior:
  - If a typed SSH bootstrap failure is already shown, the controller suppresses
    the generic duplicate runtime error.
- Risk: Low
- Recommended policy:
  - Keep as-is.
  - This removes duplicate noise without rewriting user-visible ownership or
    session truth.

### 8. Exact local user-message echo suppression

- File: `lib/src/features/chat/application/transcript_item_policy.dart`
- Current behavior:
  - Provider user-message echoes are suppressed only when they match the local
    pending user message.
- Risk: Low
- Recommended policy:
  - Keep as-is.
  - This is bounded deduplication, not semantic rewriting.

### 9. Ignore stale async UI completions after rebind

- File: `lib/src/features/chat/presentation/chat_root_adapter.dart`
- Current behavior:
  - Old overlay or send completions are ignored after the adapter rebinds.
- Introduced in:
  - `10be505`
- Risk: Low
- Recommended policy:
  - Keep as-is.
  - This prevents stale async work from mutating a new screen instance.

## Practical Follow-Up Order

1. Remove or tighten live tracked thread reuse.
2. Fail hard on missing thread objects in ownership-establishing app-server
   responses.
3. Narrow fallback free-form input fields to known-safe request types.
4. Add explicit queue visibility for suppressed pending requests.
5. Relabel inferred or unknown UI states so the app stops sounding more certain
   than it is.

## Red-Line Rule

No recovery heuristic should ever do all three of these at once:

- preserve the visible transcript
- change the remote ownership target
- avoid forcing the user to acknowledge that the target changed

That combination is the trust break.
