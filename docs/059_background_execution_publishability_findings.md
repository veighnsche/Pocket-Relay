# Background Execution Publishability Findings

## Status

This document records the findings from the current background-execution
investigation for Pocket Relay as of 2026-03-22.

The question was narrow but high stakes:

- can Pocket Relay be made publishable for the use case where a live Codex turn
  keeps running while the user briefly does something else on their phone
- if not with the current transport model, what exact product and architecture
  changes are required

## Executive Conclusion

Pocket Relay is not publishable for this use case if the expected behavior is:

- user backgrounds the app
- a live Codex turn is still running
- the phone app may suspend or be killed
- Pocket Relay still guarantees that the exact same live lane and live stream
  survive without interruption

That guarantee is not achievable with the current architecture on iPhone.

The current architecture is:

- mobile app owns the SSH connection
- mobile app launches `codex app-server --listen stdio://` over that SSH
  session
- the live transport is tied to the phone-owned client process

What is achievable, and what should be treated as the publishable target unless
upstream/backend architecture changes, is:

- ordinary short app switching must not make Pocket Relay disconnect or tear
  down the live lane by itself
- if the OS later suspends or kills the app, Pocket Relay must reconnect,
  resume the real upstream thread, restore the transcript from upstream truth,
  preserve the draft, and show honest recovery state

For the stricter target of true mid-turn continuity after phone backgrounding,
the durable owner of the remote Codex run must move off the phone-owned SSH
session.

## Confirmed Repo Findings

### 1. Pocket Relay already avoids one important regression

The app does not currently force reconnect or lane replacement on ordinary
`inactive` / `hidden` / `paused` / `resumed` cycles.

Confirmed in:

- [`lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)
- [`test/connection_workspace_controller_test.dart`](../test/connection_workspace_controller_test.dart)

Specifically:

- lifecycle handling snapshots recovery state on background-risk transitions
- `resumed` itself does not tear down the selected lane
- tests prove that after `paused` -> `resumed`, the same binding is preserved
- tests also prove that no disconnect is triggered in that path

This is correct and must be preserved.

### 2. Recovery-state persistence already exists

Pocket Relay already persists narrow active-lane recovery state.

Confirmed in:

- [`lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart`](../lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart)
- [`lib/src/features/workspace/application/connection_workspace_controller.dart`](../lib/src/features/workspace/application/connection_workspace_controller.dart)
- [`lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)

Persisted fields include:

- `connectionId`
- `selectedThreadId`
- `draftText`
- `backgroundedAt`

This is aligned with the repo rule that Pocket Relay may persist lane/runtime
state but must not invent a local transcript history source of truth.

### 3. Cold-start restore of the selected lane already exists

Initialization restores the saved selected lane, restores the draft, and when a
saved thread id exists, restores the selected thread from upstream history.

Confirmed in:

- [`lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)
- [`docs/053_ios_background_restore_handoff.md`](./053_ios_background_restore_handoff.md)

This means the repo already has a meaningful recovery foundation.

### 4. The transport still depends on a phone-owned SSH session

Remote mode still connects over SSH and launches the remote app-server over
stdio from the client-owned session.

Confirmed in:

- [`README.md`](../README.md)
- [`lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`](../lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart)

The command being launched is:

- `codex app-server --listen stdio://`

This is the architectural choke point.

## Confirmed Platform Findings

### 1. iPhone cannot be treated as an always-on SSH host

Confirmed from Apple documentation:

- general apps are not allowed to keep arbitrary long-running background work
  alive indefinitely
- iOS background execution must fit approved background categories or finite
  background work windows
- extending background execution time is limited and is not an indefinite SSH
  keepalive primitive

Relevant Apple sources:

- <https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app>
- <https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time>
- <https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/WorkLessInTheBackground.html>

Additional Apple archive language found during verification reinforces the same
rule: foreground-only apps move to suspended state shortly after backgrounding,
and suspension means active work cannot keep running normally.

### 2. The repo currently declares no iOS background mode for this

Confirmed in:

- [`ios/Runner/Info.plist`](../ios/Runner/Info.plist)

There is currently no declared `UIBackgroundModes` entry for audio, VoIP,
location, Bluetooth, external accessory, or another specialized background
category.

That is not just a missing implementation detail. It is a signal that the app
currently relies on ordinary foreground behavior and narrow recovery.

### 3. Android has more room, but not unlimited room

Confirmed from Android documentation:

- Android foreground services exist for user-noticeable ongoing work
- they require a visible notification
- they come with restrictions
- recent Android versions apply timeout behavior to some foreground service
  types

Relevant Android sources:

- <https://developer.android.com/develop/background-work/services/fgs>
- <https://developer.android.com/develop/background-work/services/fgs/timeout>
- <https://developer.android.com/guide/components/activities/process-lifecycle>

### 4. The repo currently has no Android foreground-service path for live turns

Confirmed in:

- [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)

There is no declared foreground service, no foreground-service permission, and
no Android service implementation for active-turn continuity.

## Protocol Findings

### 1. Pocket Relay can restore thread identity and thread history

Confirmed in:

- [`lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`](../lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart)

The protocol client supports:

- `thread/start`
- `thread/resume`
- `thread/read`
- `thread/rollback`
- `thread/fork`

That gives the app the primitives needed for:

- reconnect
- conversation resume
- transcript restoration from upstream truth

### 2. True live-stream reattachment is not currently established

Confirmed in the current code search:

- there is support for resuming a thread
- there is support for restoring history
- there is tracking for `activeTurnId`
- there is no clearly established primitive in the current client layer for
  reattaching a new transport to the same already-running live stream and
  continuing token-by-token delivery seamlessly

This is an important distinction.

Thread recovery is not the same as live stream reattachment.

### 3. Inference from the current transport model

This is an inference from the current code, not a separately proven backend
contract:

- if the phone-owned SSH session dies, the remote stdio-backed app-server may
  die with it or become unreachable
- if that happens, `thread/resume` and `thread/read` can still support honest
  recovery only if upstream thread truth survived independently of that session
- if the remote process itself dies with the SSH session, seamless live-turn
  continuation is impossible without architectural change

This is the biggest remaining unknown that must be answered explicitly by the
real backend behavior, not by UI assumptions.

## What This Means For Publishability

### 1. What is not publishable

The following product behavior is not acceptable:

- user backgrounds the app briefly
- Pocket Relay itself disconnects, disposes, or marks the live lane stale just
  because the app left foreground
- user comes back to a dead lane, blank transcript, or lost draft
- app shows stale transcript as if the connection is still live

Also not publishable:

- promising uninterrupted live mid-turn continuity on iPhone while still using
  a phone-owned SSH stdio session as the durable execution owner

That would be claiming a guarantee the platform and current transport do not
support.

### 2. What is publishable

For this app category, the publishable target is:

- ordinary app switching does not cause Pocket Relay itself to sever the lane
- if the OS later suspends or kills the app, the user returns to the same lane
  identity and preserved draft
- Pocket Relay reconnects explicitly
- Pocket Relay resumes the real upstream thread when possible
- Pocket Relay restores transcript truth from upstream history
- Pocket Relay shows honest recovery or failure states instead of pretending the
  original live session survived

This is a real product bar, not a downgrade in rigor. It is the correct bar for
the current platform constraints unless the backend ownership model changes.

## Exact Implementation Path

### Track A: Minimum Publishable Path With Current Upstream Capabilities

This is the exact path if Pocket Relay remains a client over the current
protocol and transport family.

### 1. Preserve the current no-self-disconnect lifecycle rule

Do not reintroduce any policy that:

- reconnects on every `paused` / `resumed`
- disposes a busy lane because the app left foreground
- marks live lanes stale without confirmed transport loss

This rule is already correctly documented in:

- [`docs/052_ios_background_ssh_resilience_plan.md`](./052_ios_background_ssh_resilience_plan.md)
- [`docs/053_ios_background_restore_handoff.md`](./053_ios_background_restore_handoff.md)

### 2. Add narrow platform-specific grace, not fake permanence

On iOS:

- use a finite background task only to finish state persistence and immediate
  housekeeping around a background transition
- do not treat it as an indefinite SSH survival strategy

On Android:

- add a foreground service only while a live turn is actively running
- show the required ongoing notification
- stop the service when the turn is no longer active

This improves resilience, especially on Android, but does not replace the
recovery path.

### 3. Detect confirmed transport loss on foreground

On resume or cold start, Pocket Relay needs explicit logic that answers:

- did the app process survive
- does the selected lane still have a valid live transport
- did the underlying app-server session exit
- did the SSH transport disappear while backgrounded

Only confirmed loss should trigger reconnect-required behavior.

### 4. Reconnect first, then restore truthfully

When transport loss is confirmed:

- recreate the lane transport
- reconnect SSH / app-server
- call `thread/resume` for the preserved thread id when possible
- call `thread/read(includeTurns: true)` to restore transcript history
- preserve the composer draft throughout

### 5. Add explicit recovery UI states

The app should show states such as:

- reconnecting to remote session
- restoring conversation history
- draft preserved
- remote session unavailable
- transcript restore failed

The UI must not collapse into a generic empty state.

### 6. Add diagnostics

Capture at minimum:

- background timestamp
- resume timestamp
- cold-start detection
- whether recovery state existed
- whether reconnect succeeded
- whether `thread/resume` succeeded
- whether `thread/read` restore succeeded
- whether transport loss was explicit or silent

### Track B: Required Path For True Mid-Turn Survival

If the strict product requirement is:

- live Codex keeps running while the phone app is backgrounded
- user comes back and the same in-flight live stream is still there

then Track A is not enough.

The exact required change is:

- move durable remote execution ownership off the phone-owned SSH stdio session

That means one of the following:

- a detached remote `codex app-server` owned by a remote supervisor
- a remote service/gateway that Pocket Relay attaches to and detaches from
- an upstream-supported session model that allows a new transport to reattach to
  the same running live turn

Without that change, the mobile app is still the fragile owner of the transport.

## What Will Not Work

The following approaches should be rejected early:

- trying to outsmart iOS into indefinite arbitrary SSH background execution
- forcing reconnect on every short background cycle
- pretending restored history is equivalent to an uninterrupted live stream
- adding a local transcript cache and treating it as truth
- widening the UI surface with speculative states before the transport truth is
  defined

## Hard Product Decision

Pocket Relay needs an explicit product statement:

- if the mobile client transport disappears, is the product requirement
  "truthful restore of the same conversation" or "seamless continuation of the
  same in-flight stream"

Those are different requirements.

Current findings support:

- truthful restore is achievable in the current architecture
- seamless in-flight stream continuation is not established in the current
  architecture and likely requires backend/transport redesign

## Recommended Next Steps

1. Keep the current ordinary app-switching behavior exactly as-is: no forced
   reconnect on routine `paused` / `resumed`.
2. Add explicit transport-loss detection and reconnect-required state on
   confirmed loss only.
3. Add reconnect-plus-upstream-history restore for the selected active lane.
4. Add honest recovery UI states.
5. Add diagnostics around background, resume, reconnect, and restore outcomes.
6. Add iOS finite background-task handling for narrow shutdown/grace work.
7. Add Android foreground-service support for active turns only.
8. Decide whether the product requires true live stream reattachment.
9. If yes, redesign the remote execution ownership model so the phone is not
   the durable owner of the running Codex session.

## Primary Repo References

- [`docs/052_ios_background_ssh_resilience_plan.md`](./052_ios_background_ssh_resilience_plan.md)
- [`docs/053_ios_background_restore_handoff.md`](./053_ios_background_restore_handoff.md)
- [`README.md`](../README.md)
- [`lib/src/features/workspace/application/connection_workspace_controller.dart`](../lib/src/features/workspace/application/connection_workspace_controller.dart)
- [`lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`](../lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart)
- [`lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart`](../lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart)
- [`lib/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart`](../lib/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart)
- [`lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`](../lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart)
- [`lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`](../lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart)
- [`ios/Runner/Info.plist`](../ios/Runner/Info.plist)
- [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml)

## External Platform References

- Apple:
  - <https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app>
  - <https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time>
  - <https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/WorkLessInTheBackground.html>
- Android:
  - <https://developer.android.com/guide/components/activities/process-lifecycle>
  - <https://developer.android.com/develop/background-work/services/fgs>
  - <https://developer.android.com/develop/background-work/services/fgs/timeout>
