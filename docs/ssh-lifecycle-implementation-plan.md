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

## Phase 1 Investigation Findings

This section is based on the current app code plus the local `dartssh2` package
source in the pub cache.

### What the public dependency surface gives us reliably

The current app uses the public `SSHSocket` and `SSHClient` APIs from
`dartssh2`.

Concrete hooks:

- [ssh_socket.dart](/home/vince/.pub-cache/hosted/pub.dev/dartssh2-2.13.0/lib/src/socket/ssh_socket.dart)
  exposes `SSHSocket.connect(host, port, timeout:)`
- [ssh_socket_io.dart](/home/vince/.pub-cache/hosted/pub.dev/dartssh2-2.13.0/lib/src/socket/ssh_socket_io.dart)
  delegates directly to `Socket.connect(...)`, so initial connect failures are
  raw socket/connect failures before an `SSHClient` exists
- [ssh_client.dart](/home/vince/.pub-cache/hosted/pub.dev/dartssh2-2.13.0/lib/src/ssh_client.dart)
  exposes these useful callbacks/futures:
  - `onVerifyHostKey`
  - `onPasswordRequest`
  - `onUserauthBanner`
  - `onAuthenticated`
  - `Future<void> get authenticated`
  - `Future<SSHSession> execute(...)`
- [ssh_errors.dart](/home/vince/.pub-cache/hosted/pub.dev/dartssh2-2.13.0/lib/src/ssh_errors.dart)
  exposes typed error classes we can pattern-match without parsing strings:
  - `SSHHandshakeError`
  - `SSHAuthFailError`
  - `SSHAuthAbortError`
  - `SSHHostkeyError`
  - `SSHChannelOpenError`
  - `SSHChannelRequestError`
  - `SSHSocketError`

### What those hooks mean for Phase 1

Reliable typed lifecycle points we can emit without heuristics:

- socket connect failed
  - from `SSHSocket.connect(...)` throwing before `SSHClient` is created
- host key observed as unpinned
  - from `onVerifyHostKey`
- host key mismatch against a pinned fingerprint
  - from our own `onVerifyHostKey` closure because we already know expected and
    actual fingerprints there
- authentication failed
  - from `await client.authenticated` throwing `SSHAuthFailError` or
    `SSHAuthAbortError`
- authentication succeeded
  - from `await client.authenticated` completing or `onAuthenticated`
- remote launch failed
  - from `await client.execute(...)` throwing `SSHChannelOpenError` or
    `SSHChannelRequestError`
- remote process started
  - from `await client.execute(...)` returning an `SSHSession`

### What is available but should not drive Phase 1

- [ssh_transport.dart](/home/vince/.pub-cache/hosted/pub.dev/dartssh2-2.13.0/lib/src/ssh_transport.dart)
  has lower-level transport internals like `onReady`, `remoteVersion`, and
  explicit host-key verification closure handling, but our app does not own
  `SSHTransport` directly
- Phase 1 should not reach into `SSHTransport` internals or fork around
  package-private implementation details just to get more milestones
- `onUserauthBanner` exists, but banner messages are informational and are not a
  necessary first-wave lifecycle boundary

### Important caveats from the dependency behavior

1. Host-key rejection will produce two signals unless we suppress the duplicate.

   Our `onVerifyHostKey` closure can emit a precise mismatch event immediately.
   After returning `false`, `dartssh2` will later close with
   `SSHHostkeyError('Hostkey verification failed')`.

   Phase 1 must avoid surfacing both the typed mismatch event and a second
   generic host-key failure for the same cause.

2. Authentication failure detail is coarse.

   `dartssh2` distinguishes auth failure vs abort, but it does not tell us
   which credential specifically failed beyond the auth method path we already
   chose.

   That is still good enough for Phase 1 because our profile already knows the
   chosen auth mode.

3. Remote launch failure is distinguishable, but remote stderr is not part of
   SSH lifecycle.

   `SSHChannelOpenError` and `SSHChannelRequestError` tell us the remote command
   failed to start at the SSH layer.

   Once `execute(...)` succeeds, later stderr or process failure belongs to
   app-server startup/runtime, not SSH bootstrap.

4. The fingerprint format is MD5-based today.

   `dartssh2` computes the fingerprint passed to `onVerifyHostKey` as an MD5
   digest of the host key bytes in
   [ssh_transport.dart](/home/vince/.pub-cache/hosted/pub.dev/dartssh2-2.13.0/lib/src/ssh_transport.dart).

   Phase 1 should preserve the existing format to avoid changing stored profile
   data and UI behavior mid-cut.

## Best Upgrade Path For Phase 1

The best Phase 1 path is narrower than the full desired lifecycle contract.

Do not start by emitting every imagined SSH stage.

Start with the smallest typed event set that:

- is supported by the current public dependency hooks
- removes meaning from generic diagnostic strings
- enables user-relevant UI/action surfaces
- is testable without a real SSH server

### Recommended first-wave event set

Infrastructure events:

- `CodexAppServerSshConnectFailedEvent`
- `CodexAppServerUnpinnedHostKeyEvent`
- `CodexAppServerSshHostKeyMismatchEvent`
- `CodexAppServerSshAuthenticationFailedEvent`
- `CodexAppServerSshAuthenticatedEvent`
- `CodexAppServerSshRemoteLaunchFailedEvent`
- `CodexAppServerSshRemoteProcessStartedEvent`

Do not add these in Phase 1 unless a real consumer appears:

- `connectingSocket`
- `socketConnected`
- `verifyingHostKey`
- `authenticating`
- `launchingRemoteProcess`

Those stages are real, but they currently add event volume without improving
behavior. They can be added later once the typed failure/success boundaries are
in place.

### Recommended structural cut

Before expanding the taxonomy, extract one small test seam inside
[codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart).

Current problem:

- the function directly calls `SSHSocket.connect(...)`
- directly constructs `SSHClient`
- directly awaits `authenticated`
- directly calls `execute(...)`

That makes command-building easy to test, but not lifecycle emission.

Best Phase 1 seam:

- keep the public `openSshCodexAppServerProcess(...)` function stable
- add an internal bootstrap helper with injectable collaborators for:
  - socket connect
  - client creation
  - auth wait
  - execute

This does not need a large new abstraction tree.

It only needs enough structure to make typed event emission unit-testable.

### Recommended ownership split

Keep Phase 1 contained to:

- [codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart)
- [codex_app_server_models.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_models.dart)
- [runtime_event_mapper.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/application/runtime_event_mapper.dart)
- [codex_runtime_event.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/models/codex_runtime_event.dart)
- focused tests

Do not move the logic into `CodexAppServerConnection` yet.

`CodexAppServerConnection` should remain the generic process/JSON-RPC owner.
Phase 1 is about improving what the SSH launcher emits, not changing who owns
the app-server transport.

### Rejected upgrade paths

These paths look plausible but are the wrong first cut.

1. Put SSH meaning onto generic diagnostics with error codes.

   This preserves the wrong ownership model. SSH trust, auth, and launch
   failures would still be diagnostics first and lifecycle data second.

2. Move SSH lifecycle ownership into
   [codex_app_server_connection.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart)
   before the SSH launcher emits typed events.

   This would mix SSH bootstrap semantics into the generic app-server
   process/JSON-RPC owner and make later cleanup harder.

3. Build Phase 1 around `SSHTransport` internals.

   The local dependency source exposes lower-level milestones, but the app does
   not own that layer directly. Reaching into it now would buy event volume at
   the cost of tighter package coupling and weaker tests.

4. Start with UI surfaces before infrastructure typing.

   That would recreate the same text-driven branching problem in a new place.

### Exact Phase 1 cut order

Implement Phase 1 in this order:

1. Add the first-wave SSH event classes in
   [codex_app_server_models.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_models.dart).

2. Extract a small internal bootstrap seam in
   [codex_app_server_ssh_process.dart](/home/vince/Projects/codex_pocket/lib/src/features/chat/infrastructure/app_server/codex_app_server_ssh_process.dart)
   for:
   - socket connect
   - client creation
   - auth wait
   - remote execute

3. Emit typed events from the actual SSH boundaries:
   - `SSHSocket.connect(...)`
   - `onVerifyHostKey`
   - `await client.authenticated`
   - `await client.execute(...)`

4. Suppress duplicate host-key failure signaling so a typed mismatch event does
   not also become a second generic host-key failure.

5. Keep generic `CodexAppServerDiagnosticEvent` only for truly unclassified
   startup text and stderr, not for known SSH lifecycle meaning.

6. Add focused infrastructure tests in
   [codex_app_server_ssh_process_test.dart](/home/vince/Projects/codex_pocket/test/codex_app_server_ssh_process_test.dart)
   for:
   - connect failure
   - host-key mismatch
   - auth failure
   - auth success
   - remote launch failure
   - remote process started

7. Add only the minimal runtime follow-through needed to keep typed SSH events
   distinct in mapping and avoid collapsing them back into generic warnings.

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
