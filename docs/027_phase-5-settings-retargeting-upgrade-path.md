# Phase 5 Settings Retargeting Upgrade Path

## Goal

Phase 5 should make connection management truthful in a concurrent-workspace
app.

That means:

- settings edit saved connections, not "the app"
- dormant connection edits save immediately
- live connection edits do not silently disconnect the running lane
- applying saved live edits becomes an explicit workspace action
- users can create more saved connections from the workspace UI

This phase should finish the product seam that earlier phases deliberately left
open.

## What Is Already Sound

The main form stack is reusable as-is:

- `lib/src/features/settings/presentation/connection_settings_host.dart`
- `lib/src/features/settings/presentation/connection_settings_presenter.dart`
- `lib/src/features/settings/presentation/connection_settings_sheet_surface.dart`
- `lib/src/features/settings/presentation/connection_sheet.dart`
- `lib/src/features/settings/presentation/cupertino_connection_sheet.dart`

These pieces already give us:

- renderer-neutral form state
- validation and payload assembly
- desktop/mobile route-mode truthfulness
- identical submit semantics across Material and Cupertino

Phase 5 should reuse this stack.

It should not fork a second settings form for workspace editing.

## Current Ownership Problem

The wrong part is not the form.

The wrong part is the launch and save path.

Today the flow is:

1. lane screen emits `openSettings`
2. `ChatRootAdapter` opens the sheet through `ChatRootOverlayDelegate`
3. `ChatRootAdapter` receives a `ConnectionSettingsSubmitPayload`
4. `ChatRootAdapter` calls
   `ChatSessionController.applyConnectionSettings(...)`
5. the lane immediately saves, disconnects, clears continuation state, and
   detaches its transcript

That is still the old single-lane assumption.

The current implementation is centered in:

- `lib/src/features/chat/presentation/chat_root_adapter.dart`
- `lib/src/features/chat/presentation/chat_root_overlay_delegate.dart`
- `lib/src/features/chat/application/chat_session_controller.dart`

The Phase 4 workspace shells do not yet participate in settings ownership.

## Findings

### 1. Live settings still apply inside a lane

`ChatRootAdapter` still owns settings launch and submit handling.

That is the key mismatch with the concurrent-workspace architecture.

The lane should be able to request editing.
It should not decide what saving means.

### 2. `applyConnectionSettings()` is now a legacy seam

`ChatSessionController.applyConnectionSettings(...)` still performs the old
behavior:

- save the profile
- disconnect the app-server client
- clear continuation state
- detach the transcript

That behavior is not intrinsically wrong.

It is just wrong as the immediate result of pressing `Save`.

For Phase 5, the first-cut workspace should stop calling this method directly
from the settings sheet flow.

### 3. The workspace cannot manage saved connections yet

`ConnectionWorkspaceController` currently supports:

- initialize
- instantiate
- select
- show dormant roster
- terminate

It does not yet support:

- create saved connection
- update saved connection
- delete saved connection
- mark a live lane as needing reconnect
- explicitly apply saved live edits

Phase 5 needs those APIs.

### 4. The current UI cannot add more saved connections

This is now the most important product gap.

The repository supports multiple saved connections, but the workspace UI still
has no creation path.

Without an `Add connection` flow, the user cannot actually grow the dormant
roster from inside the app.

So Phase 5 is not just "edit semantics".
It also needs the first real saved-connection creation path.

### 5. Delete is only safe for dormant connections in the first cut

Deleting a live connection definition while its lane is still running creates
avoidable identity and cleanup complexity.

The first cut should therefore use this rule:

- dormant connections can be deleted
- live connections can be closed
- to delete a live connection, close it first so it becomes dormant, then
  delete it

That keeps lane lifetime and saved-definition lifetime separate.

### 6. Empty-catalog behavior is currently not supported

`ConnectionWorkspaceController.initialize()` still throws when the catalog is
empty.

That is acceptable today only because:

- first-run storage seeds one default saved connection
- the UI cannot yet delete the final saved connection

If Phase 5 adds delete, the workspace must stop assuming the catalog is never
empty.

An empty workspace needs a real shell state and a first-connection create CTA.

### 7. The repository interface is missing a real create seam

`CodexConnectionRepository.saveConnection(...)` requires a fully-formed
`SavedConnection`, including `id`.

That is fine for updates.
It is awkward for UI-driven creation.

The current id generator only lives inside
`SecureCodexConnectionRepository`.

The workspace layer should not synthesize connection ids on its own.

Recommended fix:

- add a repository-level `createConnection(...)` seam
- or add a dedicated connection-creation service above the repository

The simplest durable answer is to put create semantics on the repository
interface itself.

### 8. Reconnect-required state must become explicit workspace state

If a live connection is edited and the saved definition changes immediately,
the workspace needs to remember that the running lane is out of date.

That should not be inferred by comparing random objects during rendering.

Recommended runtime state:

```text
ConnectionWorkspaceState
  catalog
  liveConnectionIds
  selectedConnectionId
  viewport
  reconnectRequiredConnectionIds
```

The reconnect-required set is runtime-only state.
It should not be persisted.

### 9. First-cut live edits should all be reconnect-gated

A tempting shortcut is to classify fields like:

- cosmetic: apply immediately
- transport: require reconnect

That sounds nicer, but it creates a second policy matrix immediately.

The current lane controller still owns one monolithic applied profile, and the
workspace catalog owns the saved profile.

So the first cut should stay simple:

- any saved edit to a live connection marks that lane `needs reconnect`
- the running lane continues unchanged until the user explicitly applies the
  saved definition

This may feel slightly conservative for label-only edits.

Architecturally, it is still the right first move.

It avoids a fragile partial-hot-swap policy before the product needs one.

## Recommended Target Architecture

### 1. Promote settings launch to the workspace layer

Create a workspace-usable settings launcher in the settings feature.

Recommended seam:

```text
abstract interface class ConnectionSettingsOverlayDelegate {
  Future<ConnectionSettingsSubmitPayload?> open({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    required ConnectionSettingsRenderer renderer,
  });
}
```

Why:

- live lane edit requests need it
- dormant roster edit requests need it
- add-connection requests need it

Do not keep `ChatRootOverlayDelegate.openConnectionSettings(...)` as the only
entry point.

Settings are no longer chat-owned.

### 2. Add a workspace-level connection editor coordinator

The form should stay reusable, but the save semantics now differ by context.

Recommended wrapper concept:

```text
ConnectionEditorCoordinator
  openCreateConnection(...)
  openEditDormantConnection(connectionId)
  openEditLiveConnection(connectionId)
```

This wrapper should:

- open the shared settings form
- interpret submit results according to workspace rules
- call workspace-controller APIs

The form remains generic.
The coordinator owns meaning.

### 3. Add saved-connection management APIs to the workspace controller

Recommended new controller surface:

```text
Future<void> createConnection(ConnectionSettingsSubmitPayload payload)
Future<void> saveDormantConnection(
  String connectionId,
  ConnectionSettingsSubmitPayload payload,
)
Future<void> saveLiveConnectionEdits(
  String connectionId,
  ConnectionSettingsSubmitPayload payload,
)
Future<void> reconnectConnection(String connectionId)
Future<void> deleteDormantConnection(String connectionId)
```

Expected semantics:

- `createConnection(...)`
  saves a new catalog entry and leaves it dormant by default
- `saveDormantConnection(...)`
  updates the catalog immediately
- `saveLiveConnectionEdits(...)`
  updates the catalog immediately and marks the lane reconnect-required
- `reconnectConnection(...)`
  explicitly applies the saved definition to the live lane
- `deleteDormantConnection(...)`
  removes the saved definition and keyed handoff

### 4. Reconnect should replace the lane binding, not hot-swap it

The cleanest first-cut reconnect path is workspace-owned lane replacement.

Recommended behavior:

1. load the latest saved connection definition
2. create a fresh `ConnectionLaneBinding`
3. replace the live binding for that `connectionId`
4. dispose the old binding
5. clear `reconnectRequiredConnectionIds` for that connection

This is better than routing reconnect back through
`ChatSessionController.applyConnectionSettings(...)`.

Why:

- reconnect is now a workspace lifecycle action
- the lane binding already owns the runtime boundary
- lane replacement preserves the architecture we just established in Phases 2-4

The first cut may reset that lane's transcript and draft state when reconnect
is applied.

That is acceptable.

It is still materially better than silently dropping the lane on `Save`.

### 5. Keep the current running lane unchanged until reconnect

When a live connection is edited:

- save the new definition to the catalog
- keep the current lane binding alive
- mark the lane reconnect-required

Do not immediately mutate:

- `ChatSessionController.profile`
- `ChatSessionController.secrets`
- the active transport
- lane-local transcript state

That keeps `Save` side-effect free with respect to the running session.

### 6. Make reconnect-required visible in the workspace shell

The user needs truthful UI after editing a live connection.

Recommended first-cut visibility:

- mobile lane overflow adds `Apply saved settings`
- desktop live row shows a small reconnect-needed badge or subtitle state
- selected live lane shows a compact banner or inline notice

The exact visual treatment can stay light.

But the state must be explicit and testable.

### 7. Support create/edit/delete from the dormant roster surfaces

Phase 5 should make the dormant roster a true management surface.

Recommended first-cut actions:

- `Add connection`
- `Edit`
- `Delete`
- `Open lane`

That should appear in:

- mobile dormant roster page
- desktop dormant section

New connections should be created dormant by default.

That keeps the saved-definition concept clean and avoids surprising auto-launch.

### 8. Allow lane settings requests, but route them out of the lane

The lane still needs a settings action because it appears in:

- app chrome
- first-launch empty state
- SSH recovery cards

But those paths should become requests, not local save logic.

Recommended adapter seam:

```text
ChatRootAdapter(
  onOpenConnectionSettingsRequested: ...
)
```

Then:

- the lane asks for editing
- the workspace opens the shared settings editor
- the workspace decides what save means

That preserves the lane UX while removing the old ownership bug.

## Best Upgrade Path

The best Phase 5 path is:

1. extract a workspace-usable settings overlay delegate
2. add workspace controller APIs for create, save, reconnect, and delete
3. add reconnect-required runtime state
4. wire dormant create/edit/delete first
5. retarget live lane settings to the workspace coordinator
6. remove the direct `ChatRootAdapter -> applyConnectionSettings()` save path

Do not start by rewriting the settings form.

That would spend effort in the one part of the stack that is already on the
right abstraction level.

## Recommended Slice Breakdown

Phase 5 should be split into 5 slices.

### Slice 5.1: Workspace settings infrastructure

- extract a generic settings overlay launcher out of the chat-only overlay seam
- add workspace controller methods for connection create/update/delete intent
- extend `ConnectionWorkspaceState` with reconnect-required runtime state

Exit condition:

- settings can be launched from the workspace layer without going through
  `ChatRootAdapter` save semantics

### Slice 5.2: Dormant management path

- add `Add connection` to roster surfaces
- add dormant `Edit` and `Delete`
- save dormant edits immediately through the workspace controller
- delete dormant connections and keyed handoffs safely

Exit condition:

- the user can create, edit, and delete dormant connections from the workspace
  UI

### Slice 5.3: Empty-workspace support

- stop throwing on empty catalog
- add an empty-workspace shell state
- surface a first-connection create CTA

Exit condition:

- deleting the final dormant connection does not crash bootstrap

### Slice 5.4: Live edit staging and explicit apply

- retarget live-lane settings requests to the workspace coordinator
- save live edits to the catalog only
- mark lanes reconnect-required
- add explicit `Apply saved settings` or equivalent reconnect action

Exit condition:

- pressing `Save` in a live lane no longer disconnects that lane

### Slice 5.5: Cleanup and hardening

- remove the direct adapter save path to
  `ChatSessionController.applyConnectionSettings(...)`
- either delete that method or keep it internal-only if still needed by a
  lower-level reconnect implementation
- add controller and widget tests around live edit isolation and dormant
  management

Exit condition:

- settings ownership is workspace-level end to end

## Test Strategy

Phase 5 verification should cover:

1. dormant create/edit/delete
   - creating a saved connection appends it in stable order
   - editing a dormant connection updates the roster immediately
   - deleting a dormant connection removes its keyed handoff

2. empty-workspace behavior
   - deleting the final saved connection shows a create CTA instead of crashing
   - creating a new connection from empty state restores a valid workspace

3. live edit staging
   - saving live edits does not disconnect the current lane
   - saving live edits marks only that lane reconnect-required
   - saving live edits does not affect unrelated live lanes

4. explicit apply
   - applying saved settings replaces only the targeted lane binding
   - applying saved settings clears reconnect-required state for that lane
   - applying saved settings does not clear any other lane's transcript

5. settings request routing
   - toolbar settings requests route through the workspace coordinator
   - empty-state and SSH-card settings requests route through the same path
   - stale settings results are ignored if the lane or shell context changes

## Main Risks

### 1. Mixing saved and applied profile state in one view

If the shell starts rendering some fields from catalog state and others from the
live lane controller, the user will get contradictory UI.

Use reconnect-required state explicitly instead of silently mixing sources.

### 2. Deleting the final saved connection without empty-state support

This would leave the workspace bootstrap path in an invalid state.

Do not ship delete before Slice 5.3 is in place.

### 3. Keeping `applyConnectionSettings()` as a public convenience path

If that method stays available and casually callable, the old anti-pattern will
keep reappearing.

Phase 5 should sharply narrow or remove it.

## Recommended Immediate Next Step

Start with Slice 5.1.

The first implementation cut should:

- extract a generic settings overlay launcher
- add reconnect-required state to `ConnectionWorkspaceState`
- add workspace controller APIs for saved-connection management

That unlocks both dormant management and truthful live-edit semantics without
rewriting the settings form or destabilizing the workspace shell first.
