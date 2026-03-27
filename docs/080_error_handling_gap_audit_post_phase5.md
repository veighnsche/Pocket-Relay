# 080 Error Handling Gap Audit Post Phase 5

## Scope

This audit reviews the current `master`-divergent error-handling work on
`feat/error-handling-audit` after the following slices landed:

- core detail formatting centralization
- typed chat guardrail errors
- typed connection settings errors
- typed workspace runtime probe errors
- typed composer image-attachment errors
- typed live-lane disconnect errors

The question for this pass is narrower than the original `078` audit:

1. what user-visible failures are still not typed end to end
2. what failures are still silently degraded or collapsed
3. which silent paths are actually correct non-error behavior and should stay
   non-user-facing

## Current Grade

Current grade: `B-`

Why it improved:

- the app now has a real first-class typed error pipeline in
  `lib/src/core/errors/`
- the biggest chat/workspace guardrail surfaces now emit stable codes
- the composer and live-lane no longer invent their own fallback meanings

Why it is not yet an `A`:

- there are still `66` catch sites in `lib/src/`
- `33` of those are `catch (_)` sites
- several important flows still convert real failure into `null`, `unknown`, or
  a generic unavailable state
- some failures are surfaced, but without their underlying detail
- some non-blocking failures are still completely silent instead of producing an
  explicit diagnostic trail

## Method

This pass reviewed:

- all `catch (...)` and `catch (_) ` sites under `lib/src/`
- remaining `SnackBar` and transient feedback sites
- remaining best-effort / fail-open comments
- the runtime, workspace, connection-settings, device-host, storage, and
  bootstrap layers

## Findings

### 1. High-Priority Typed Error Gaps

These are real user-visible failures that still do not preserve the right typed
meaning or the underlying cause.

#### 1.1 Workspace bootstrap still shows a generic uncoded shell failure

File:

- `lib/src/app/pocket_relay_bootstrap.dart`

Problem:

- workspace initialization failures are stored as raw `Object?`
- the bootstrap shell only renders `Pocket Relay could not finish loading your workspace.`
- there is no stable code
- there is no normalized underlying detail

Why this matters:

- this is a top-level app boot failure
- the user cannot report it precisely
- retry exists, but diagnosis does not

Required direction:

- add an `appBootstrap` domain
- map workspace initialization failure to a typed `PocketUserFacingError`
- render code plus normalized detail in the bootstrap shell

#### 1.2 Cold-start reconnect and live reconnect still lose the real failure detail

Files:

- `lib/src/features/workspace/application/controller/bootstrap.dart`
- `lib/src/features/workspace/application/controller/reconnect.dart`

Problem:

- generic `catch (_) { ... return; }` paths still collapse reconnect failure into
  `transportUnavailable`
- the state transition is correct, but the actual error detail is discarded

Why this matters:

- reconnect failure is one of the highest-value diagnostic surfaces in the app
- the user sees the resulting degraded state, but not the reason that caused it
- attach/SSH/process failures become indistinguishable unless a more specific
  event happened first

Required direction:

- preserve the original thrown error in recovery diagnostics
- add a typed reconnect/bootstrap fallback error path for the generic branch
- make the unavailable notice include stable detail when the runtime probe does
  not already explain the failure

#### 1.3 Live connection settings still collapse model refresh failure into `null`

File:

- `lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart`

Problem:

- `_refreshAvailableModelCatalog(...)` catches all failures and returns `null`
- inner cache-save failures are swallowed completely
- upstream `ConnectionSettingsHost` can only infer
  `ConnectionSettingsErrors.modelCatalogUnavailable()`
  instead of `modelCatalogRefreshFailed(error: ...)`

Why this matters:

- this is no longer just a best-effort convenience
- the app already has typed connection-settings refresh errors
- the live-lane adapter is currently erasing that detail before it reaches the
  connection-settings surface

Required direction:

- stop converting list-models failure into `null`
- propagate a typed refresh failure or a typed wrapper exception
- decide separately whether cache-write failures should be visible or only
  diagnostic

#### 1.4 Host fingerprint save failure still drops the underlying error

File:

- `lib/src/features/chat/lane/application/chat_session_controller_prompt_flow.dart`

Problem:

- `profileStore.save(...)` failure is caught with `catch (_)`
- the user gets the right typed meaning
  `ChatSessionGuardrailErrors.hostFingerprintSaveFailed()`
- but the underlying error detail is thrown away

Why this matters:

- the user learns that saving failed, but not why
- storage/auth/serialization errors become impossible to distinguish

Required direction:

- change the mapper to preserve the underlying detail
- add a typed helper like `hostFingerprintSaveFailed(error: ...)`

### 2. Medium-Priority Silent Degradations

These are not always user-blocking, but they currently fail closed into
best-effort state with no explicit diagnostic channel.

#### 2.1 Chat model-catalog hydration still fails open silently

File:

- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`

Problem:

- `_ensureChatSessionAppServerConnected(...)` catches model hydration failure and
  intentionally ignores it
- the comment explicitly says this is a fail-open path

Why this matters:

- this is what powers image-input support decisions
- the current product behavior is defensible, but there is no explicit record
  that hydration failed

Correct outcome:

- probably not a blocking user error
- should at least emit a typed diagnostic/runtime event or record a visible
  degraded capability state

#### 2.2 Thread metadata hydration is still silent best effort

File:

- `lib/src/features/chat/lane/application/chat_session_controller_thread_metadata.dart`

Problem:

- `readThread(...)` failure is swallowed completely

Why this matters:

- the failure is not catastrophic
- but it does affect visible thread labeling and identity quality

Correct outcome:

- keep it non-blocking
- add explicit diagnostic observability instead of full silence

#### 2.3 Recovery persistence failures are debug-only

File:

- `lib/src/features/workspace/application/controller/recovery_persistence.dart`

Problem:

- save failures only print in `assert`
- release builds lose that information entirely

Why this matters:

- draft/session recovery is a real product promise
- this is a classic silent degradation path

Correct outcome:

- probably not an interrupting user snackbar
- should record an explicit persistence diagnostic in all builds

#### 2.4 Recovery-store decode failure silently discards local state

File:

- `lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart`

Problem:

- malformed stored recovery JSON returns `null`
- no diagnostic survives

Why this matters:

- recovery corruption becomes invisible
- the user just sees restore not happen

Correct outcome:

- do not block app boot
- but emit a typed local-recovery diagnostic and clear the bad payload

#### 2.5 Device capability hosts still ignore platform failures completely

Files:

- `lib/src/core/device/foreground_service_host.dart`
- `lib/src/core/device/background_grace_host.dart`
- `lib/src/core/device/display_wake_lock_host.dart`

Problem:

- permission queries default to success on exception
- foreground-service enable failure is ignored
- background-grace enable failure is ignored
- wake-lock enable failure is ignored

Why this matters:

- these are not cosmetic features
- they protect active turn continuity
- a failure here changes what guarantees the app can realistically provide

Correct outcome:

- not every one of these should be an interrupting snackbar
- but all of them need explicit runtime diagnostics and product-state visibility
- the current silent behavior is too weak for a continuity-first app

### 3. Lower-Priority But Real Cleanup Gaps

These are smaller, but still worth tightening.

#### 3.1 Raw snackbar renderers still exist outside the shared helper

Files:

- `lib/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart`
- `lib/src/features/workspace/presentation/workspace_saved_connections_content.dart`
- `lib/src/features/workspace/presentation/workspace_desktop_shell.dart`

Status:

- these mostly render already-typed `inlineMessage` strings
- the semantic ownership is less wrong than before
- but the rendering path is still inconsistent

Suggested cleanup:

- migrate all typed snackbar sites onto `showPocketErrorSnackBar(...)`
- keep non-error informational snackbars separate

#### 3.2 Live-lane settings cache load failures are still silent

File:

- `lib/src/features/workspace/presentation/workspace_live_lane_surface_settings.dart`

Problem:

- `_loadCachedModelCatalog(...)` and `_loadLastKnownModelCatalog(...)` swallow
  all exceptions and return `null`

Interpretation:

- this may be acceptable as a non-blocking fallback
- but only if we explicitly decide that cache-unavailable is not a user error
- right now it is just silent

### 4. Silent Paths That Are Probably Correct To Keep Non-User-Facing

These should not be promoted into loud user-facing errors, but they may still
deserve debug diagnostics.

#### 4.1 Transport/process teardown cleanup

Files:

- `lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart`

Reason:

- these catches mostly happen during close/cleanup
- surfacing them as user errors would create noise
- they should remain internal unless they change a visible lifecycle result

#### 4.2 Syntax-highlighting fallback to plain text

File:

- `lib/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart`

Reason:

- parse failure should not become a product error
- plain text is the correct non-error fallback

#### 4.3 Legacy decode helpers

Files:

- `lib/src/core/storage/codex_connection_repository_secure.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart`

Reason:

- malformed legacy singleton data or malformed owner logs should not interrupt
  the user
- a debug diagnostic is enough

## What Should Become Loud Next

If the product rule is now "no silent fallbacks or silent degradations unless we
explicitly choose them," the next migration order should be:

1. **Bootstrap and reconnect failure detail**
   - add typed `appBootstrap` errors
   - preserve generic reconnect/bootstrap failure detail in workspace recovery

2. **Live settings model refresh honesty**
   - stop collapsing list-models failure into `null`
   - preserve typed connection-settings refresh failure detail

3. **Device host diagnostics**
   - add explicit runtime diagnostics/state for wake lock, foreground service,
     background grace, and notification permission failures

4. **Recovery persistence visibility**
   - stop losing recovery-store save/load corruption silently in release builds

5. **Best-effort chat diagnostics**
   - thread metadata hydration
   - model catalog hydration fail-open path

## Recommendation

Do not treat the next phase as generic cleanup.

The correct next phase is:

- **error-handling hardening**

That phase should have two rules:

1. a failure that changes what the user can actually do must either:
   - become a typed user-facing error
   - or become an explicit product state with diagnostic detail

2. a failure that is intentionally non-blocking must still have:
   - explicit diagnostic observability
   - tests proving it stays non-blocking by design rather than by accident

## Definition Of Done For The Hardening Phase

The remaining gap audit is done when:

- bootstrap failure is coded
- reconnect/bootstrap generic failure branches preserve detail
- live settings model refresh no longer erases backend failure detail
- device host failures are no longer completely silent
- recovery persistence failures are observable in release behavior
- best-effort paths are explicitly documented as diagnostics-only instead of
  accidental swallow points
