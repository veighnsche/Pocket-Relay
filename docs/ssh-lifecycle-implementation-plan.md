# SSH Lifecycle Implementation Plan

## Status

This is a new implementation plan for making SSH a first-class lifecycle domain
inside the app-server chat stack.

Today the app has:

- explicit app-server transport/session lifecycle
- one explicit SSH-specific branch for the unpinned host-key flow
- generic diagnostic-string handling for most other SSH milestones and failures

That is not enough.

SSH still leaks into the app mostly as freeform transport diagnostics instead of
structured lifecycle state.

## Why This Needs Its Own Plan

The remaining gap is not just visual polish.

The app currently treats these very different situations through the same
generic warning/error channel:

- socket/connect failure
- host key mismatch
- auth failure
- remote command launch failure
- stdout/stderr startup failure
- non-fatal SSH startup notices

That creates three problems:

1. the app cannot react differently without parsing message text
2. the UI cannot offer safe, context-specific actions
3. transport bugs and UX bugs stay coupled in the same generic path

The recent fingerprint card fixed one concrete case, but it did not establish a
complete SSH lifecycle model.

## Current Code State

### Explicit today

- [codex_app_server_connection.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart)
  owns app-server process connection, initialize handshake, disconnect, and
  runtime pointer tracking
- [runtime_event_mapper.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/runtime_event_mapper.dart)
  maps transport connect/disconnect into runtime events
- [chat_session_controller.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart)
  owns profile loading, connection settings application, prompt send flow, and
  transport event subscription
- [codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart)
  owns SSH socket connection, host-key verification, auth, and remote command
  launch
- [host_fingerprint_card.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/presentation/widgets/transcript/cards/host_fingerprint_card.dart)
  renders the dedicated unpinned-host-key transcript surface

### Not explicit today

- there is no SSH lifecycle enum or state model
- there is no structured distinction between host verification failure, auth
  failure, and remote launch failure
- there is no first-class notion of SSH stage transitions such as:
  - connecting socket
  - verifying host key
  - authenticating
  - authenticated
  - launching remote process
  - stdio ready
- there is no typed UI action model for SSH failures beyond the fingerprint save
  case
- there is almost no direct infrastructure-level SSH lifecycle test coverage
  beyond command construction

## Refactor Goals

1. Model SSH lifecycle as structured events instead of generic diagnostic text.
2. Separate SSH lifecycle from generic app-server transport/session lifecycle.
3. Make host verification, auth, and remote launch failures distinguishable in
   application logic and UI.
4. Support safe, explicit actions where appropriate:
   - save observed fingerprint
   - open connection settings
   - retry after config changes
5. Stop relying on string content to decide whether a transport problem is an
   SSH trust issue, auth issue, or startup issue.
6. Expand tests so SSH behavior is proven at infrastructure, reducer, and UI
   levels.

## Non-Goals

Do not do these as part of this plan:

- redesign the entire chat transcript UI
- replace `dartssh2`
- add a persistent global connection dashboard
- redesign the settings sheet beyond small SSH-related affordances
- reopen the broader app-server architecture refactor
- automatically replace a mismatched pinned fingerprint with one tap

## Desired Lifecycle Contract

The app should be able to represent the SSH bootstrap as these explicit stages:

1. `connectingSocket`
2. `verifyingHostKey`
3. `hostKeyAcceptedUnpinned`
4. `hostKeyVerifiedPinned`
5. `authenticating`
6. `authenticated`
7. `launchingRemoteProcess`
8. `remoteProcessStarted`
9. `initializingAppServer`
10. `ready`
11. `failed`
12. `closed`

Not every stage must be user-visible.

But each stage transition or failure must be representable as structured data
so the app can decide what to render and what action to offer.

## Proposed Ownership Model

### Infrastructure

Infrastructure should emit structured SSH transport events instead of generic
message strings whenever the meaning is known.

Keep this ownership in:

- [codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart)
- [codex_app_server_models.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_models.dart)

Add explicit event types for:

- socket connection started
- socket connection failed
- host key observed
- host key mismatch
- authentication started
- authentication failed
- authentication succeeded
- remote command launch started
- remote command launch failed
- remote process started

Rule:

- if SSH code already knows what happened, emit a typed event
- use generic `CodexAppServerDiagnosticEvent` only for truly unclassified
  transport text

### Runtime mapping

The runtime mapper should translate SSH transport events into SSH runtime events
without folding them into generic warning/error events.

Prefer a small dedicated transport mapper seam rather than growing the generic
switch further.

Possible target files:

```text
lib/src/features/chat/application/
  runtime_event_mapper.dart
  runtime_event_mapper_transport_mapper.dart
```

The goal is not file count for its own sake.

The goal is a real boundary between:

- app-server protocol notifications
- local transport lifecycle events
- SSH-specific transport events

### Session state and transcript projection

Do not model SSH lifecycle as raw strings on generic status blocks.

Instead:

- add explicit runtime event classes for SSH milestones/failures
- project only the user-relevant ones into transcript/UI blocks
- keep non-user-facing milestones as internal state only if they are needed for
  orchestration

Likely first-class transcript surfaces:

- unpinned host key
- pinned host key mismatch
- authentication failed
- remote launch failed

Likely internal-only milestones:

- connecting socket
- authenticating
- authenticated
- launching remote process

### Controller actions

Keep SSH actions narrow and explicit in
[chat_session_controller.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/chat_session_controller.dart)
or a dedicated collaborator extracted from it.

Required behaviors:

- save observed fingerprint without disconnecting the active session
- refuse one-tap replacement when a different fingerprint is already pinned
- route settings-opening through the existing settings overlay path
- keep reconnect behavior explicit and separate from simple fingerprint save

## Proposed Phase Plan

### Phase 1: Establish SSH event taxonomy

Add structured SSH transport events in infrastructure.

Minimum first-wave event set:

- `ssh/socketConnectFailed`
- `ssh/hostKeyObservedUnpinned`
- `ssh/hostKeyMismatch`
- `ssh/authFailed`
- `ssh/remoteLaunchFailed`
- `ssh/authSucceeded`

Exit criteria:

- [codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart)
  emits typed events for these cases
- generic diagnostics are no longer the primary source of meaning for SSH

### Phase 2: Add runtime SSH lifecycle mapping

Translate typed SSH transport events into runtime SSH events.

Required outcomes:

- no SSH UI behavior depends on parsing `message` text
- mismatch/auth/startup failures remain distinguishable after mapping
- existing transport connected/disconnected behavior stays intact

Exit criteria:

- focused runtime mapper tests cover each SSH event path

### Phase 3: Add first-class SSH transcript/UI surfaces

Keep the new fingerprint card.

Add dedicated cards or card families for:

- pinned host-key mismatch
- authentication failure
- remote launch failure

Guidelines:

- mismatch should be high-friction and settings-oriented
- auth failure should explain which auth mode failed when possible
- launch failure should point to workspace or command configuration, not trust

Do not show an endless stream of repeated SSH cards.

Upsert or dedupe when the same failure repeats in one session unless chronology
really matters.

Exit criteria:

- the user can see what failed without reading generic transport text
- each SSH card offers only actions that are safe for that scenario

### Phase 4: Separate SSH recovery actions from generic settings application

Today full settings save disconnects the app-server session.

That is correct for broad config changes, but too blunt for every SSH-related
action.

Add explicit recovery flows:

- save fingerprint only
- open settings focused on SSH trust/auth fields
- retry connection only when the user actually requests it

Do not auto-retry on mismatch or auth failure without user intent.

Exit criteria:

- small SSH-specific actions do not cause hidden reconnect churn
- broad settings changes still use the existing reconnect path

### Phase 5: Tighten tests and remove leftover generic branches

Expand focused tests at three levels.

Infrastructure:

- host-key mismatch event emission
- auth-failure event emission
- remote-launch-failure event emission

Application:

- runtime mapping for each SSH event
- reducer/state behavior for dedupe/upsert rules
- controller save/retry/settings flows

Presentation:

- dedicated card rendering and actions
- mismatch does not expose one-tap replace
- fingerprint save updates settings-backed value

Exit criteria:

- the main SSH paths are covered without relying only on full chat integration
  tests

## Testing Plan

### New or expanded unit tests

- `test/codex_app_server_ssh_process_test.dart`
- `test/codex_runtime_event_mapper_test.dart`
- `test/codex_session_reducer_test.dart`
- `test/chat_session_controller_test.dart`
- `test/chat_screen_app_server_test.dart`

### Live verification after implementation

Run a real Android session against a reachable SSH box and verify:

1. first connection with no pinned fingerprint shows the save card
2. saving the fingerprint updates the saved profile without disconnecting the
   active session
3. reconnect with the same host key produces no trust warning
4. reconnect with a different host key shows the mismatch surface
5. wrong password or invalid key shows the auth-failure surface
6. bad workspace or bad `codexPath` shows the remote-launch-failure surface

## Sequencing Notes

Do not start with UI expansion.

The correct order is:

1. infrastructure event taxonomy
2. runtime mapping
3. transcript/UI surfaces
4. recovery actions
5. cleanup of generic SSH diagnostic fallbacks

If we start by adding more cards while SSH still arrives as generic text, we
will create another round of text-driven branching that has to be unwound
later.

## Definition Of Done

This plan is complete when:

- SSH lifecycle meaning no longer depends on parsing generic diagnostic strings
- trust, auth, and launch failures are first-class and distinguishable
- the UI exposes safe, scenario-specific actions
- fingerprint save remains narrow and non-disconnecting
- focused tests cover SSH transport, mapping, reducer, controller, and UI
- emulator or device verification confirms the real runtime paths
