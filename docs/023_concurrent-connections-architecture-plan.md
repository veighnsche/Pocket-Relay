# Concurrent Connections Architecture Plan

## Status

This document proposes the structural changes required for Pocket Relay to
support multiple concurrent live connections on mobile.

The target product behavior is:

- multiple live connection lanes can exist at the same time
- each live lane has its own transcript, requests, turn state, and connection
  lifecycle
- horizontal swipe navigates between live lanes
- swiping past the live lanes reveals a right-side roster of dormant
  connections that are not currently instantiated
- instantiating or terminating one connection must not disturb the others

## Problem Summary

Pocket Relay is still structurally single-connection at the app boundary.

The current app root owns:

- one `CodexAppServerClient`
- one saved profile and secret set
- one saved conversation handoff
- one `ChatRootAdapter`
- one `ChatSessionController`

That assumption currently appears in:

- `lib/src/app.dart`
- `lib/src/core/storage/codex_profile_store.dart`
- `lib/src/core/storage/codex_conversation_handoff_store.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`

The transport layer is not the real blocker.

`CodexAppServerClient` and `CodexAppServerConnection` are already
instance-scoped. The real limitation is that the app only creates and persists
one of them.

## Important Distinction

Pocket Relay already has partial support for multiple timelines inside one
connection.

That work is about:

- one app-server connection
- multiple Codex threads or child-agent timelines within that connection

Concurrent connections are a different problem.

They require:

- multiple independent app-server clients
- multiple independent SSH or local process lifecycles
- multiple independent session controllers
- multiple independent drafts, follow state, and connection handoff state

Do not reuse the child-agent timeline model as the connection-instance model.

The correct hierarchy is:

1. app workspace
2. connection lane
3. selected timeline inside that lane

## Product Model

The first product cut should treat saved connections and live lanes as separate
concepts.

### Connection identity

Connection identity must not be derived from host or IP address.

That is a hard requirement because users may need multiple saved connections
that share:

- the same host or IP
- the same SSH username
- the same auth method

while differing in:

- workspace directory
- Codex launch command
- run-mode flags
- pinned fingerprint policy
- human-facing label

The model must therefore use a stable opaque `connectionId`.

Host, workspace directory, and label are attributes of a saved connection, not
its identity.

### Saved connection

A saved connection is a reusable configuration:

- label
- transport settings
- workspace directory
- Codex launch command
- auth mode and secrets
- run-mode flags

Saved connections can be:

- dormant: visible in the roster but not currently instantiated
- live: currently instantiated as a lane

### Live lane

A live lane is an active runtime owner for one saved connection.

It owns:

- one `CodexAppServerClient`
- one `ChatSessionController`
- one composer draft host
- one transcript follow host
- one screen-effect subscription
- one per-connection conversation handoff

For the first cut, there should be at most one live lane per saved connection.

That matches the requested dormant/live roster behavior and avoids introducing
duplicate live sessions for the same saved target before the product needs it.

## Proposed Ownership Model

### App workspace owner

Introduce a new app-level owner above `ChatRootAdapter`.

Recommended responsibility:

- load and save the connection catalog
- track connection ordering
- track which connections are live vs dormant
- own the selected lane
- instantiate and dispose live lanes
- coordinate workspace-level navigation

Suggested names:

- `ConnectionWorkspaceController`
- `ConnectionWorkspaceState`
- `ConnectionWorkspaceAdapter`

This must become the app root composition seam for connection instances.

### Lane owner

Move the current single-screen session ownership into a lane-local owner.

Recommended responsibility:

- own one `ChatSessionController`
- own one `CodexAppServerClient`
- own one `ChatComposerDraftHost`
- own one `ChatTranscriptFollowHost`
- own lane-local snackbar or effect routing

Suggested names:

- `ConnectionLaneController`
- `ConnectionLaneBinding`
- `ConnectionLaneAdapter`

This is where most of the current `ChatRootAdapter` behavior should move.

### Presentation layer

Keep the current chat presentation contracts mostly lane-local.

Each live lane should continue to render one selected timeline at a time inside
that lane.

Do not flatten connection navigation into the existing timeline selector.

## Proposed State Shapes

### Connection catalog state

Persisted state should model reusable saved connections explicitly.

Recommended shape:

```text
ConnectionCatalogState
  orderedConnectionIds: List<String>
  connectionsById: Map<String, SavedConnection>
```

Where `SavedConnection` contains:

- `id`
- `profile`
- `secrets`
- optional created or updated metadata

### Workspace runtime state

Runtime workspace state should model live lane ownership separately from saved
connection definitions.

Recommended shape:

```text
ConnectionWorkspaceState
  orderedConnectionIds: List<String>
  liveConnectionIds: List<String>
  selectedConnectionId: String?
```

Derived behavior:

- live roster = `liveConnectionIds`
- dormant roster = ordered connections not in `liveConnectionIds`
- trailing roster page = dormant connections page

### Lane runtime binding

Each live connection id maps to one lane binding.

Recommended shape:

```text
ConnectionLaneBinding
  connectionId: String
  appServerClient: CodexAppServerClient
  sessionController: ChatSessionController
  composerDraftHost: ChatComposerDraftHost
  transcriptFollowHost: ChatTranscriptFollowHost
  screenEffectSubscription: StreamSubscription<ChatScreenEffect>
```

This binding must outlive widget rebuilds and page recycling.

That is critical.

If lane ownership remains widget-local, offscreen page disposal will keep
disconnecting background lanes and the product requirement will not be met.

## Persistence Proposal

Replace the singleton profile store with a catalog store keyed by connection id.

### New catalog store

Recommended store boundary:

```text
abstract class CodexConnectionCatalogStore {
  Future<ConnectionCatalogState> load();
  Future<void> save(ConnectionCatalogState state);
}
```

The catalog should persist:

- stable connection ids
- stable ordering
- per-connection profile payloads

Secrets should remain stored separately and namespaced by connection id.

Recommended key pattern:

- shared preferences:
  - `pocket_relay.connections.order`
  - `pocket_relay.connection.<id>.profile`
- secure storage:
  - `pocket_relay.connection.<id>.secret.password`
  - `pocket_relay.connection.<id>.secret.private_key`
  - `pocket_relay.connection.<id>.secret.private_key_passphrase`

Do not keep one giant secrets blob in shared preferences.

Use the existing storage libraries first:

- use `SharedPreferencesAsync.getKeys()` and `getAll()` to inspect catalog and
  handoff keys during migration and cleanup
- use `FlutterSecureStorage.readAll()` to migrate and clean up namespaced secret
  keys
- do not add a database package just to implement Phase 2 migration

### Conversation handoff store

Replace the singleton handoff store with a keyed store.

Recommended boundary:

```text
abstract class CodexConnectionHandoffStore {
  Future<SavedConversationHandoff?> load(String connectionId);
  Future<Map<String, SavedConversationHandoff>> loadAll();
  Future<void> save(String connectionId, SavedConversationHandoff handoff);
}
```

Recommended key pattern:

- `pocket_relay.connection.<id>.conversation_handoff`

### Migration rule

On first launch after this migration:

1. read the old singleton profile and secret keys
2. create one saved connection entry from them
3. assign it a generated connection id
4. migrate the old singleton handoff into that connection id
5. persist the new catalog format
6. keep compatibility reads only until migration succeeds once

## UI and Navigation Proposal

### Workspace shell

Introduce a workspace shell that owns lateral connection navigation.

Recommended interaction model:

- one horizontal page per live lane
- one trailing page for the dormant connection roster
- swiping horizontally moves across live lanes
- swiping past the last live lane reveals the roster on the right

This satisfies the requested mobile behavior without making the dormant list a
fake overlay attached to the nearest transcript.

### Dormant connection roster

The roster page should list dormant connections only.

First-cut Phase 4 actions:

- instantiate connection

Follow-on management actions once settings ownership is retargeted:

- edit connection settings
- delete connection

Instantiating a dormant connection should:

1. create a new lane binding
2. add the connection id to `liveConnectionIds`
3. select that new lane

### Direct dormant-navigation action

The workspace must expose an explicit action that navigates to the dormant
roster immediately.

Recommended first-cut behavior:

- add a `Dormant connections` action to the overflow menu
- selecting it moves the workspace shell directly to the roster page
- this action is available even when live lanes exist

This should be a workspace-navigation action, not a lane-local session action.

It does not belong inside `ChatSessionController`.

### Live lane order

Use stable saved-connection order for lane order in the first cut.

That keeps:

- roster order
- lane order
- settings identity

coherent across the app.

Do not reorder live lanes by latest activity in the first cut.

### Timeline selector inside a lane

Keep the current child-agent or timeline selector inside the selected lane.

That selector remains responsible only for:

- root timeline vs child timelines
- per-lane transcript switching

It must not become the connection navigator.

### Desktop variant

Desktop should not force the mobile swipe interaction model.

Recommended desktop shell:

- persistent left sidebar
- one section for live connections
- one section for dormant connections
- selecting an item switches the main content to that lane or opens the dormant
  connection editor surface

The T3 reference is useful here as a UI pattern, not as a direct ownership
model copy.

Relevant reference observations:

- `.reference/t3code/apps/web/src/routes/_chat.tsx` mounts a persistent left
  sidebar at the route shell
- `.reference/t3code/apps/web/src/components/Sidebar.tsx` groups navigation
  items under a `Projects` heading and treats project identity as separate from
  nested thread state
- `.reference/t3code/apps/web/src/store.ts` preserves stable project ordering
  and expansion state independently from thread/session state

That is the correct desktop-level lesson:

- keep connection or project navigation at the workspace shell
- keep per-connection transcript and thread state below it

For Pocket Relay, the visible desktop label may be `Projects` if the product
wants a project-first mental model, but the underlying architecture should
still be keyed by saved connection ids.

## Lifecycle Proposal

### Instantiation

Instantiating a connection creates lane-local ownership objects but should not
necessarily connect immediately unless the product wants eager startup.

Recommended first cut:

- instantiate lane binding immediately
- connect lazily on first send or explicit session action

That matches today’s `ChatSessionController` behavior and avoids opening several
SSH sessions just because the user browsed the roster.

### Offscreen live lanes

Offscreen lanes must remain instantiated while live.

That means:

- lane controllers must be owned by the workspace layer
- lane widgets may come and go
- lane teardown must happen only from explicit workspace lifecycle actions

Do not let `PageView` recycling define connection lifetime.

### Termination

Terminating one live connection should:

1. dispose that lane binding
2. disconnect only that lane’s app-server client
3. remove the connection id from `liveConnectionIds`
4. return the connection to the dormant roster
5. select an adjacent live lane or the roster page

No other lane should be affected.

## Settings and Editing Proposal

The current settings flow assumes the app has one active connection.

That model must change.

### Required rule

Settings edit a saved connection definition, not the whole app.

### Recommended behavior

- editing a dormant connection updates its saved definition immediately
- editing a live connection must be explicit about reconnect semantics

For live connections, the first cut should avoid silent hot-swapping of a live
transport.

Recommended first-cut behavior:

- save the updated definition
- show that the live lane needs reconnect to apply transport changes
- let the user explicitly reconnect or terminate and reopen the lane

Do not preserve the current global behavior where saving settings disconnects
the app’s only session as a side effect.

## Impact on Existing Files

### `lib/src/app.dart`

Change from:

- load one profile
- load one handoff
- create one `CodexAppServerClient`
- render one `ChatRootAdapter`

To:

- load the connection catalog
- load keyed handoffs
- create one workspace controller
- render one workspace shell

### `lib/src/features/chat/presentation/chat_root_adapter.dart`

This should stop being the app-wide singleton seam.

Its current ownership should be split:

- lane-local state stays in a lane adapter
- workspace-level connection navigation moves above it

### Screen action contracts

The current screen action layer will need a workspace-level navigation action
for dormant connections.

The likely cut is:

- keep lane-local actions such as new thread and clear transcript on the lane
  screen contract
- add a workspace-shell action such as `openDormantConnections`
- route that action at the workspace layer instead of through
  `ChatSessionController`

### `lib/src/features/chat/application/chat_session_controller.dart`

This remains useful as a lane-local controller.

What must change:

- it should no longer be treated as the app-global owner
- its settings application path must become lane-local
- its handoff persistence must be keyed by connection id

### Storage files

The singleton store files should be replaced or superseded by catalog-aware
versions.

Do not bolt multi-connection behavior onto the old singleton interfaces by
adding “current connection” heuristics.

## Non-Viable Shortcuts

The following shortcuts would recreate the same ownership bug in a new shape:

### 1. Reusing one `CodexAppServerClient` and reconnecting it to different hosts

This is just sequential switching with cached UI, not concurrent connections.

### 2. Keeping lane ownership in page widgets

This would cause offscreen lane disposal to disconnect live background lanes.

### 3. Reusing child-agent timelines as connection lanes

This would flatten two different ownership layers:

- transport instance
- thread timeline inside a transport

### 4. Saving “the current connection” in singleton storage and faking the rest

This would make dormant vs live behavior implicit and fragile.

## Implementation Sequence

The safest order is:

### Slice 1: Connection catalog and migration

- add saved connection ids and catalog store
- migrate singleton profile data into one catalog entry
- add keyed handoff store
- implement this slice as a separate 4-slice Phase 2 rollout described in
  `docs/025_concurrent-connections-phase-2-upgrade-path.md`

### Slice 2: Extract lane-local ownership

- extract current `ChatRootAdapter` state ownership into a lane binding
- keep one-lane behavior working as the degenerate case
- make lane lifecycle independent from widget disposal

### Slice 3: Add workspace controller

- introduce workspace state with live and dormant connection sets
- instantiate and terminate lanes through the workspace controller
- keep one selected lane concept at the workspace level

### Slice 4: Add workspace shell and roster page

- add workspace shell state for live-lane vs dormant-roster visibility
- broaden app chrome so workspace overflow actions can coexist with lane-local
  menu actions
- introduce horizontal paging across live lanes
- add trailing dormant roster page
- wire instantiate and terminate actions
- keep dormant edit and reconnect semantics for Slice 5

Detailed Phase 4 component and primitive guidance lives in
`docs/026_phase-4-ui-primitives-and-upgrade-path.md`.

### Slice 5: Retarget settings flow

- settings operate on saved connections
- live connection edits become explicit reconnect actions
- dormant edits stay immediate

Detailed Phase 5 upgrade guidance lives in
`docs/027_phase-5-settings-retargeting-upgrade-path.md`.

### Slice 6: Hardening and cleanup

- remove leftover singleton connection assumptions
- remove app-global disconnect behavior
- add stronger tests around lane isolation

## Test Strategy

The verification must prove ownership and isolation, not just rendering text.

Required coverage:

1. catalog store tests
   - legacy singleton data migrates into one saved connection
   - keyed secrets and keyed handoffs persist correctly

2. workspace controller tests
   - instantiating one connection does not create side effects on others
   - terminating one lane leaves other live lanes intact
   - dormant vs live roster membership stays correct

3. lane lifecycle tests
   - offscreen page rebuilds do not dispose live lanes
   - lane dispose disconnects only that lane’s transport

4. session isolation tests
   - prompts sent in lane A never target lane B
   - approvals and user input route to the correct lane
   - reconnecting one lane does not clear another lane’s transcript

5. presentation tests
   - horizontal swipe selects different live lanes
   - swiping past the final live lane reveals the dormant roster page
   - instantiating a dormant connection adds a new live lane and selects it
   - child-agent timeline switching still works inside a selected lane

## Recommended First-Cut Constraints

To keep the migration coherent, the first cut should intentionally limit scope:

- one live lane per saved connection
- no simultaneous duplicate live sessions for the same saved target
- no automatic reconnect of every previously live lane on cold app launch
- no redesign of the child-agent timeline model beyond keeping it lane-local

Those constraints still fully satisfy the requested concurrent mobile model.

## Follow-On Extension

If the product later needs multiple simultaneous live sessions for the same
saved target, then split:

- saved connection definition id
- live lane instance id

That should happen only when the product actually requires duplicate live
instantiation of one saved connection.

It should not be a prerequisite for this change.
