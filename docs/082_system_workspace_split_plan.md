# 082 System Workspace Split Plan

## Problem

Pocket Relay currently overloads one saved "connection" record to mean three
different things at once:

- a reusable machine target
- a saved Codex workspace definition
- a live lane opened in the UI

That single-record model is the root cause of the current UX and ownership
problems:

- workspace settings contain machine credentials and trust fields
- saved-connections UI mixes workspace actions with system actions
- terminology is inconsistent and misleading
- machine reuse is modeled as duplication instead of explicit ownership
- live lanes inherit ambiguity from saved configuration

The structural mistake is that `System` and `Workspace` are not separate owned
models.

## Core Decision

The first and most important change is to separate:

- `System`: machine access, trust, and authentication
- `Workspace`: project and Codex defaults
- `Lane`: live runtime instance of a workspace

Everything else should follow from that split.

## Canonical Product Vocabulary

- `System`
  - A reusable machine target.
  - Owns host, port, username, auth mode, password/private key, fingerprint,
    and system test/trust.
- `Workspace`
  - A saved Codex project definition.
  - Owns label, selected system, workspace directory, Codex path, model,
    reasoning effort, and workspace-level advanced options.
- `Lane`
  - A live open instance of a workspace in the shell.
  - Owns transcript, draft, transport state, reconnect state, and active turn.
- `Conversation`
  - A Codex thread resumed inside a lane.
- `Transport`
  - Technical runtime term for the live session connection state.

`Connection` should stop being a primary user-facing noun.

## Ownership Rules

- `System settings` must own:
  - host/address
  - port
  - username
  - auth mode
  - password
  - private key
  - private key passphrase
  - fingerprint
  - system test / trust state
- `Workspace settings` must own:
  - workspace label
  - selected system
  - workspace directory
  - Codex path
  - model
  - reasoning effort
  - workspace-level advanced options
- `Lane` must own only live runtime/UI state, never saved system or workspace
  truth.

The workspace settings surface must not contain raw system credential fields.

## Target Data Model

Pocket Relay does not need a special relational-data library to do this first
step. The relationship is simple and can be represented with app-owned models,
IDs, and maps.

Suggested model split:

```text
SavedSystem {
  id
  label
  host
  port
  username
  authMode
  hostFingerprint
  secrets
}

SavedWorkspace {
  id
  label
  systemId?
  workspaceDir
  codexPath
  model
  reasoningEffort
  dangerouslyBypassSandbox
  ephemeralSession
}

LiveLane {
  laneId
  workspaceId
  runtime/session state
}
```

Relationship rules:

- one `System` can be reused by many `Workspaces`
- one `Workspace` points to one `System` when remote
- one `Lane` opens one `Workspace`

Do not introduce Realm / Isar / ObjectBox / another database abstraction just
to represent this split. Normalize the app-owned models first.

## Surface Model

### Inventory / Navigation

- `Saved connections` becomes `Workspaces`
- add a separate `Systems` page / inventory surface
- `Add connection` becomes `New workspace`
- add a separate `New system` action

### Settings

- current `Connection settings` becomes `Workspace settings`
- create separate `System settings`
- `Workspace settings` should only let the user:
  - choose a system
  - create a system
  - edit the selected system through a separate surface

### Lane

- lanes continue to open from workspaces
- lane actions stay lane-scoped
- system actions do not get promoted into lane chrome unless runtime state
  makes them the primary next step

## Phased Implementation Plan

### Phase 1. Freeze Vocabulary

- replace user-facing `connection` copy with `workspace`, `system`, and `lane`
  where appropriate
- document the canonical terms in code and docs
- stop introducing any new user-facing `connection` labels

### Phase 2. Introduce Normalized Domain Types

- replace the overloaded saved model with app-owned `SavedSystem` and
  `SavedWorkspace` types
- split catalog state into workspace catalog and system catalog
- make `workspace.systemId` the only persisted relationship
- keep live lane state separate from persisted config

### Phase 3. Add Repository Migration

- migrate the current persisted saved-connection format into separate systems
  and workspaces
- on migration:
  - create one workspace per legacy saved connection
  - create one system for each distinct remote machine identity
  - deduplicate remote systems by normalized host identity
- keep migration explicit and one-way
- preserve local workspaces without a system reference

### Phase 4. Split Controller Ownership

- refactor workspace controller logic so live lanes are keyed by workspace
- resolve remote runtime and system trust through the selected system, not
  through an overloaded saved connection record
- ensure deleting a workspace does not delete a shared system
- ensure editing a system can fan out to all workspaces that reference it

### Phase 5. Split Settings Surfaces

- remove host/auth/fingerprint fields from workspace settings
- build system settings around machine access and trust only
- in workspace settings, replace raw machine fields with:
  - selected system summary
  - change system action
  - create system action
  - edit system action

### Phase 6. Split Inventory Surfaces

- make the current saved-connections page a real `Workspaces` page
- add a separate `Systems` page to mobile and desktop inventory
- remove row actions from workspace inventory that actually belong to systems
- separate workspace actions from system actions

### Phase 7. Re-key Downstream Runtime Ownership

- move system trust/runtime status to the system owner
- review model catalog, reconnect, runtime checks, and owner inspection to keep
  workspace-owned vs system-owned responsibilities clean
- ensure lane recovery continues to work with workspace IDs instead of the
  legacy saved-connection abstraction

### Phase 8. Delete Legacy Connection Semantics

- remove leftover `connection` terminology from user-facing copy
- delete compatibility helpers that only exist to preserve the old conceptual
  model
- collapse temporary adapters once migration and UI split are complete

## Suggested Commit Slices

Recommended execution slices:

1. vocabulary and model type introduction
2. storage migration and repository tests
3. controller split to workspace/system ownership
4. workspace settings split
5. systems surface and inventory/navigation changes
6. runtime ownership cleanup
7. legacy terminology and adapter deletion

## Risks

- storage migration correctness
- preserving active lane continuity during controller refactors
- not leaving half-migrated terminology in the UI
- deciding clean ownership for remote runtime status and trust state
- avoiding accidental deletion of shared systems when deleting one workspace

## Non-Goals

- introducing a new general-purpose relational persistence layer
- redesigning unrelated surfaces just because the model is changing
- changing backend truth; this is a frontend ownership correction

## Definition Of Done

This work is done when all of the following are true:

- system and workspace are separate persisted models
- workspace settings no longer contain host/auth/fingerprint inputs
- systems are managed in their own surface
- workspaces select systems by reference instead of duplicating machine fields
- lanes open from workspaces without reintroducing mixed ownership
- user-facing terminology no longer relies on the overloaded `connection` noun
- migration from existing saved data is covered by tests
