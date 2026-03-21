# Concurrent Connections Phase 2 Best Upgrade Path

## Status

This document defines the best upgrade path for Phase 2 of concurrent
connections.

Phase 2 should establish multi-connection persistence and one-lane bootstrapping
on the correct ownership seams.

It should not try to deliver the full multi-lane UI yet.

That split is intentional.

## Phase 2 Slice Count

Phase 2 should be implemented in 4 development slices.

Those slices are:

1. catalog models, repository, and legacy migration
2. keyed handoff store and connection-scoped adapters
3. catalog-backed single-lane app bootstrap
4. test harness migration and hardening

This is the right slice count because it keeps:

- storage migration separate from lane bootstrapping
- lane bootstrapping separate from test-harness churn
- Phase 2 separate from the later workspace and multi-lane UI work

## What Phase 2 Must Actually Achieve

Phase 2 is successful when the app can:

- persist many saved connections keyed by stable `connectionId`
- persist per-connection conversation handoffs
- migrate the old singleton profile, secrets, and handoff into the new keyed
  model
- keep the current one-lane app behavior working as the degenerate case
- prepare the codebase for lane extraction without teaching the current lane
  controller about workspace ownership

Phase 2 is not the phase for:

- horizontal lane paging
- a desktop sidebar
- live vs dormant runtime orchestration
- multiple simultaneous `CodexAppServerClient` instances in the running UI

Those belong to later phases.

## Current Code Facts That Matter

### 1. Storage is singleton and asymmetric

Today:

- `codex_profile_store.dart` persists one profile payload in
  `SharedPreferencesAsync`
- the same file persists one password, one private key, and one passphrase in
  `FlutterSecureStorage`
- `codex_conversation_handoff_store.dart` persists one handoff in
  `SharedPreferencesAsync`

That matters because Phase 2 is not replacing one storage key with many keys.

It is replacing:

- one implicit current-connection record

with:

- an explicit saved-connection catalog
- keyed per-connection secret storage
- keyed per-connection handoff storage

### 2. `ChatSessionController` is already close to the right lane seam

`ChatSessionController` currently owns:

- one profile
- one secrets object
- one session state
- one app-server client
- one resume thread id

That is exactly the right shape for one connection lane.

What is wrong today is not the controller’s internal ownership.

What is wrong is that the rest of the app treats this lane-local object as the
whole app session owner.

### 3. The controller only loads profile data during `initialize()`

This is an important detail.

`ChatSessionController.initialize()` loads only `profileStore.load()`.

The handoff seed is injected through the constructor via
`initialSavedConversationHandoff`.

That means a future lane binding cannot rely on the controller to discover its
handoff state later unless that contract changes.

For Phase 2, the safer move is:

- keep the controller contract stable
- keep loading per-connection handoff before controller construction

### 4. `ChatRootAdapter` is sensitive to dependency identity

`ChatRootAdapter.didUpdateWidget()` rebuilds its controller when any of these
change:

- `profileStore`
- `conversationHandoffStore`
- `appServerClient`
- `initialSavedProfile`
- `initialSavedConversationHandoff`

Two consequences follow:

1. Phase 2 must not create connection-scoped store wrappers inline during
   `build()`
2. `SavedProfile` should gain value equality, or Phase 2 should avoid passing
   fresh-but-equal bootstrap objects through widget updates

The current `SavedConversationHandoff` type already has value equality.
`SavedProfile` does not.

### 5. Tests are heavily wired to the singleton app bootstrap

The largest hotspot is `test/chat_screen_app_server_test.dart`.

It repeatedly boots `PocketRelayApp` with:

- one `MemoryCodexProfileStore`
- optionally one `MemoryCodexConversationHandoffStore`
- one fake app-server client

That means the best Phase 2 path must give tests a clean single-connection
compatibility harness on top of the new catalog shape.

If it does not, the migration cost will spread across almost every integration
test at once.

## Options Considered

### Option 1: Widen the existing singleton store interfaces

Example direction:

```text
CodexProfileStore.load(connectionId)
CodexProfileStore.save(connectionId, ...)
CodexConversationHandoffStore.load(connectionId)
```

This is not the best path.

Problems:

- it pushes `connectionId` into every current singleton caller immediately
- it still does not model saved-connection ordering or catalog membership
- it couples controller migration to catalog migration
- it creates a misleading store name because the store is no longer “the
  current profile store”

Most importantly, it would spread catalog concerns into lane-local code before
the workspace layer exists.

That is the wrong direction.

### Option 2: Add a workspace controller first and fake storage for now

This is also the wrong path.

Problems:

- it creates multi-lane UI pressure before the storage model is correct
- it would force temporary heuristics for “current connection”
- it would hide migration bugs behind widget churn

This would recreate the current ownership problem in a more complicated form.

### Option 3: Add catalog-aware storage beside the singleton stores and bind it
back into the existing lane APIs

This is the recommended path.

The core idea is:

- add new catalog-aware boundaries for saved connections and keyed handoffs
- keep `ChatSessionController` and `ChatRootAdapter` lane-local
- use thin connection-scoped adapters to satisfy the current
  `CodexProfileStore` and `CodexConversationHandoffStore` interfaces for one
  `connectionId`

This gives Phase 2 the correct persistence model without forcing the controller,
screen contracts, or transport runtime to understand workspace ownership yet.

## Recommended Phase 2 Structural Cut

### 1. Introduce a connection repository, not just a new low-level store

The public Phase 2 persistence boundary should be a connection repository.

Recommended shape:

```text
abstract class CodexConnectionRepository {
  Future<ConnectionCatalogState> loadCatalog();
  Future<SavedConnection> loadConnection(String connectionId);
  Future<void> saveConnection(SavedConnection connection);
  Future<void> deleteConnection(String connectionId);
}
```

Where:

- `ConnectionCatalogState` contains stable order plus per-connection summaries
- `SavedConnection` contains `id`, `profile`, and `secrets`

The repository should hide the split persistence backends:

- `SharedPreferencesAsync` for catalog order and per-connection profiles
- `FlutterSecureStorage` for per-connection secrets

Why a repository is the right seam:

- the app needs both list-level and item-level operations
- secrets and profiles already live in different storage systems
- future workspace code should ask for saved connections, not reason about
  secure-storage key names

Leverage the existing libraries here:

- use `SharedPreferencesAsync.getAll()` for filtered catalog reads during
  migration and tests
- use `SharedPreferencesAsync.getKeys()` for namespaced key discovery during
  cleanup
- keep using the existing legacy-to-async migration utility already used by the
  singleton stores

### 2. Keep keyed handoff storage as its own boundary

Recommended shape:

```text
abstract class CodexConnectionHandoffStore {
  Future<SavedConversationHandoff> load(String connectionId);
  Future<void> save(String connectionId, SavedConversationHandoff handoff);
  Future<void> delete(String connectionId);
}
```

Do not add `loadAll()` in Phase 2 unless a real consumer appears.

The future workspace shell does not need all handoffs preloaded to render the
roster.

Lane instantiation can load the handoff lazily for the selected connection.

That keeps the boundary smaller and avoids work that the current product does
not consume yet.

Leverage the existing libraries here:

- store keyed handoffs in `SharedPreferencesAsync`
- use `getKeys()` to find `pocket_relay.connection.<id>.conversation_handoff`
  entries for cleanup or diagnostics
- do not add a second indexing layer for handoffs in Phase 2

### 3. Add connection-scoped adapters that preserve the current lane contracts

Recommended adapters:

```text
class ConnectionScopedProfileStore implements CodexProfileStore
class ConnectionScopedConversationHandoffStore
    implements CodexConversationHandoffStore
```

These adapters should:

- hold one `connectionId`
- delegate to the new repository or keyed handoff store
- make the current lane code believe it still has one profile store and one
  handoff store

This is the key Phase 2 move.

It lets:

- `ChatSessionController`
- `ChatRootAdapter`
- the settings form
- host fingerprint persistence
- most controller tests

stay structurally lane-local while the persistence model changes under them.

### 4. Keep the app root temporarily single-lane, but make it catalog-backed

Phase 2 should keep the visible app behavior close to today:

- load the catalog
- choose one connection id
- load that connection plus its handoff
- create one connection-scoped profile store
- create one connection-scoped handoff store
- render one `ChatRootAdapter`

This is not a compromise in product behavior.

It is the correct degenerate runtime for a storage migration phase.

The app root becomes:

- catalog-backed
- connection-id aware
- still visibly one-lane until workspace runtime lands

## Proposed State Shapes For Phase 2

### Connection catalog state

Recommended persisted summary shape:

```text
ConnectionCatalogState
  orderedConnectionIds: List<String>
  connectionsById: Map<String, SavedConnectionSummary>
```

Where `SavedConnectionSummary` contains:

- `id`
- `profile`
- optional created or updated metadata if needed

Secrets should not be loaded into the catalog summary by default.

That keeps roster and bootstrap loading cheap and avoids unnecessary secure
storage reads.

### Full saved connection

Recommended item shape:

```text
SavedConnection
  id: String
  profile: ConnectionProfile
  secrets: ConnectionSecrets
```

This should be the repository return type for `loadConnection`.

## Recommended Storage Keys

Phase 2 should use explicit, namespaced keys.

Recommended keys:

- shared preferences:
  - `pocket_relay.connections.index`
  - `pocket_relay.connection.<id>.profile`
  - `pocket_relay.connection.<id>.conversation_handoff`
- secure storage:
  - `pocket_relay.connection.<id>.secret.password`
  - `pocket_relay.connection.<id>.secret.private_key`
  - `pocket_relay.connection.<id>.secret.private_key_passphrase`

`pocket_relay.connections.index` should hold:

- schema version
- ordered connection ids

Do not store one giant catalog JSON blob that includes secrets.

Do not infer connection membership from secure storage enumeration.

The index should remain the source of truth for catalog order and existence.

## Migration Rule

The migration must be one-way, explicit, and retry-safe.

Recommended algorithm:

1. ensure `SharedPreferencesAsync` is ready
2. check whether the new catalog index already exists
3. if it exists, load the new format and stop
4. otherwise, read the legacy singleton profile and secrets
5. read the legacy singleton handoff
6. generate one stable new `connectionId`
7. write the new catalog index
8. write the new per-connection profile
9. write the new per-connection secrets
10. write the new per-connection handoff
11. mark the catalog migration as complete

Implementation note:

- read legacy singleton preferences through the existing
  `SharedPreferencesAsync` plus legacy migration path
- use `FlutterSecureStorage.readAll()` once during migration to discover legacy
  secret keys and any existing namespaced keys safely
- prefer one explicit migration pass over scattered compatibility reads in
  multiple runtime paths

Important rules:

- the id generator must be injectable for tests
- a new install with no legacy data should still seed one default connection
- do not delete the legacy singleton keys during the first migration slice
- once the new catalog exists, prefer it and stop using “current connection”
  reads in app bootstrap

Leaving the legacy singleton keys in place temporarily is safer than deleting
them early.

The new format should simply become authoritative once it exists.

## Best Runtime Upgrade Path

### Step 1: Replace app bootstrap dependencies

`PocketRelayApp` should stop owning:

- one `CodexProfileStore`
- one `CodexConversationHandoffStore`

and start owning:

- one `CodexConnectionRepository`
- one `CodexConnectionHandoffStore`

Phase 2 should still keep one injected `CodexAppServerClient` for the single
visible lane.

Do not combine the storage migration with the later app-server client factory
refactor.

That is a separate phase.

### Step 2: Boot one selected connection from the catalog

Phase 2 should choose the first ordered connection id as the temporary selected
connection.

That choice is valid in this phase because:

- there is still only one visible lane
- there is no dormant roster yet
- there is no user-facing multi-selection UI yet

If the catalog is empty on first boot, the migration path should have already
seeded one default connection.

### Step 3: Construct stable scoped dependencies once per selected connection

This part is easy to get wrong.

The app must not create scoped store wrappers inline during `build()`.

It should cache, in state:

- selected `connectionId`
- scoped profile store
- scoped handoff store
- loaded `SavedConnection`
- loaded `SavedConversationHandoff`

Why:

- `ChatRootAdapter` treats changed dependency identities as a reason to dispose
  and recreate its controller
- recreating these scoped wrappers on every rebuild would create spurious lane
  teardown

### Step 4: Keep lane-local save flows unchanged

After the scoped adapters are in place:

- `applyConnectionSettings()` continues to save one lane’s profile
- `saveObservedHostFingerprint()` continues to save one lane’s profile
- conversation handoff persistence continues to save one lane’s handoff

The only difference is that the persistence is now keyed by `connectionId`.

This is exactly the kind of narrow, ownership-correct migration that Phase 2
should do.

## Recommended Library Leverage

Phase 2 does not need new persistence packages.

It should lean harder on the packages already in the repo.

### `shared_preferences`

Use it for:

- catalog index storage
- per-connection profile storage
- keyed handoff storage
- migration key discovery through `SharedPreferencesAsync.getKeys()`
- migration assertions in tests through `SharedPreferencesAsync.getAll()`

### `flutter_secure_storage`

Use it for:

- per-connection password storage
- per-connection private key storage
- per-connection private key passphrase storage
- migration reads and cleanup through `readAll()`

### `shared_preferences_platform_interface`

Keep using it in tests for:

- in-memory `SharedPreferencesAsync` simulation
- deterministic migration coverage without platform channels

### Libraries Phase 2 should not add

Do not add these just for the catalog migration:

- a SQLite package
- a state-management package
- a repository generator or ORM

The existing storage stack is already capable of supporting the Phase 2 cut.

## Hidden Risks Phase 2 Should Address Immediately

### 1. `SavedProfile` lacks value equality

This is a real risk for future lane bootstrapping and workspace refreshes.

Recommendation:

- add `==` and `hashCode` to `SavedProfile` during Phase 2

That change is small, correct, and prevents false-positive controller rebuilds
once catalog-backed bootstrap starts passing saved connection payloads around.

### 2. There is no test around `applyConnectionSettings()`

This is the main current behavior seam for lane-local profile persistence.

Recommendation:

- add direct controller tests for `applyConnectionSettings()`
- prove it saves through the scoped profile store and disconnects only its own
  client

Even in the single-lane Phase 2 runtime, this closes a real verification gap.

### 3. Phase 2 must not allow an empty catalog unless a true zero-state exists

The current product always has one editable connection surface.

Until the dormant roster and create-connection flow exist, an empty catalog
would create a broken intermediate product.

Recommendation:

- seed one default saved connection on fresh install
- do not expose delete-to-zero behavior in Phase 2

## Recommended Test Upgrade Path

### 1. New storage and migration tests

Add unit tests that prove:

- legacy singleton profile data migrates into one catalog entry
- legacy singleton handoff migrates into that same connection id
- keyed secrets are stored under the new namespaced keys
- fresh install seeds one default connection
- deleting one connection cleans up only that connection’s keys

### 2. Scoped adapter tests

Add tests that prove:

- `ConnectionScopedProfileStore` loads and saves only one connection id
- `ConnectionScopedConversationHandoffStore` loads and saves only one
  connection id

These tests are cheap and prevent the most likely migration bug:

- accidentally writing lane A into lane B’s storage

### 3. App bootstrap tests migrate to a single-connection catalog harness

Add a memory test harness such as:

```text
MemoryCodexConnectionRepository.single(SavedProfile savedProfile)
MemoryCodexConnectionHandoffStore(...)
```

This keeps the current widget and app-server tests readable while moving them
onto the new bootstrap seam.

This is especially important for:

- `test/widget_test.dart`
- `test/chat_screen_app_server_test.dart`

### 4. Leave pure controller tests mostly unchanged in this phase

Most `ChatSessionController` tests can remain on:

- `MemoryCodexProfileStore`
- `MemoryCodexConversationHandoffStore`

until the workspace runtime arrives.

That is acceptable because the controller contract remains lane-local in Phase
2.

The important additions are:

- scoped adapter tests
- direct `applyConnectionSettings()` tests

## Concrete File Plan

Recommended new files:

- `lib/src/core/storage/codex_connection_repository.dart`
- `lib/src/core/storage/codex_connection_handoff_store.dart`
- `lib/src/core/storage/connection_scoped_stores.dart`

Recommended existing files to update:

- `lib/src/core/models/connection_models.dart`
- `lib/src/app.dart`
- `test/widget_test.dart`
- `test/chat_screen_app_server_test.dart`
- `test/codex_profile_store_test.dart`
- `test/chat_session_controller_test.dart`

The old singleton store files should remain temporarily as:

- legacy migration readers
- compatibility test seams for lane-local controller tests

They should stop being the app bootstrap source of truth.

## Non-Viable Shortcuts

Do not do these in Phase 2:

- add `connectionId` parameters directly to every singleton store caller
- patch `PocketRelayApp` to keep reading one singleton profile and fake a
  catalog in memory
- build multi-lane widgets before the catalog migration lands
- refactor transport ownership and storage ownership in the same slice
- create scoped store adapters inline in widget `build()` methods

Each of those would either widen the blast radius or recreate the current
ownership bug.

## Best Phase 2 Sequence

### Slice 1: Catalog repository and legacy migration

- add new catalog models and a connection id generator seam
- add `CodexConnectionRepository`
- migrate the legacy singleton profile and secrets into one catalog entry
- use `SharedPreferencesAsync.getKeys()/getAll()` and
  `FlutterSecureStorage.readAll()` to support migration and cleanup

### Slice 2: Keyed handoffs and scoped stores

- add keyed `CodexConnectionHandoffStore`
- migrate the legacy singleton handoff into the generated connection id
- add `ConnectionScopedProfileStore`
- add `ConnectionScopedConversationHandoffStore`

### Slice 3: Catalog-backed single-lane bootstrap

- move `PocketRelayApp` bootstrap to the catalog-backed single-connection
  runtime
- cache stable scoped store instances in app state
- add `SavedProfile` value equality to avoid false lane rebuilds

### Slice 4: Test harness migration and hardening

- add direct tests for scoped adapter isolation
- add direct `applyConnectionSettings()` coverage
- migrate root and app-server widget tests to the new memory catalog harness

That is the cleanest route through Phase 2.

It changes the persistence ownership model first, while keeping the visible
runtime intentionally narrow.

## Exit Criteria

Phase 2 is done when:

- the app no longer boots from singleton profile storage
- the app no longer boots from singleton handoff storage
- one selected connection is booted from a keyed catalog
- lane-local saves are persisted through scoped keyed stores
- legacy singleton data migrates into the new keyed format
- the existing one-lane runtime still works end-to-end
- the repo is ready for Phase 3 lane extraction without revisiting persistence
  ownership
