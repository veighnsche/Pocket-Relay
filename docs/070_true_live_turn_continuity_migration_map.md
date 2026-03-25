# True Live-Turn Continuity Migration Map

## Status

This document turns the continuity contract into a concrete migration map.

It answers two practical questions:

1. which current files and behaviors are deleted, replaced, moved, or kept
2. what Pocket Relay should do when the target host does not have `tmux`

Date: 2026-03-23

Related docs:

- [`066_durable_remote_owner_options.md`](./066_durable_remote_owner_options.md)
- [`068_tmux_ws_user_path_timeline.md`](./068_tmux_ws_user_path_timeline.md)
- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)

## Decision Summary

Pocket Relay is targeting `True Live-Turn Continuity`, not only `Truthful
Recovery`.

For the first implementation path, that means:

- durable remote owner: required `tmux`
- remote server lifecycle: explicit user-owned start/stop/restart
- reconnectable transport: app-server websocket
- live reattach path: reconnect-time `thread/resume`
- truthful fallback: `thread/read` only when live continuity is no longer
  possible after real owner loss or external failure

This means remote continuity has a hard host prerequisite.

If a host does not have `tmux`, Pocket Relay must not silently pretend that the
continuity contract is still met.

## Policy When No Remote Server Is Running

This is separate from missing `tmux`.

If the host is eligible but no Pocket Relay-managed remote server is currently
running, Pocket Relay must:

- report that no server is running
- offer explicit server controls such as `Start server`
- refuse to silently create a server as a side effect of ordinary reconnect

If a previously known server is gone, Pocket Relay must:

- treat that as continuity loss
- preserve lane identity and draft
- fall back truthfully when upstream history is available

The important distinction is:

- missing `tmux` means the host is unsupported for remote continuity
- missing server means the host is capable, but no user-started server is
  currently running

## Policy When `tmux` Is Not Available On The Host

This is a product contract issue, not only a technical inconvenience.

### Hard rule

If the selected remote host does not provide `tmux`, Pocket Relay must:

- report that the host does not meet the required remote dependency
- block the continuity path for that connection
- refuse to run a degraded remote mode that pretends continuity still exists

### What Pocket Relay must not do

Do not do this:

- attempt the continuity architecture anyway
- silently fall back to SSH stdio and keep the continuity label
- offer "truthful recovery only" as an alternate remote product mode
- auto-switch the connection into a weaker remote configuration
- behave as if live continuity still exists when the host cannot satisfy it

### Correct behavior

If `tmux` is missing:

- Pocket Relay reports the missing prerequisite
- Pocket Relay blocks the remote connection from claiming continuity
- the fix is to install `tmux` on the host and retry

This is separate from truthful restore after an actual later runtime failure on
an otherwise supported host.

### Capability probe

The host capability must be checked explicitly.

For the first implementation path, that probe should answer at least:

- is `tmux` installed?
- is the configured `codex` launcher available?
- can Pocket Relay create or query the owner session it expects to use?

This capability result is runtime state, not historical truth. It can be cached
for UI convenience, but it must not silently override the saved connection
intent.

### Product framing

The correct product framing is:

- remote continuity requires `tmux`
- truthful restore remains the fallback after real external failure

Not:

- continuity is always available, except when it quietly is not
- remote continuity works without `tmux` if Pocket Relay just degrades enough

## Migration Principles

Apply this map with these rules:

- delete wrong primary paths instead of keeping them as hidden defaults
- keep truthful fallback behavior where it remains honestly needed
- delete the idea of a supported remote no-`tmux` mode
- do not regress ordinary live-lane continuity during foreground app switching
- do not rebuild an existing completed lane after a brief lock/unlock if the
  same app process and lane binding still survived
- do not add app-local transcript ownership

## Immediate Product Failure To Eliminate

This specific user-visible failure must be treated as a first-class migration
requirement, not as incidental cleanup:

- a turn finishes
- the screen turns off or the phone is locked shortly afterward
- only a few seconds pass
- unlocking the phone causes Pocket Relay to suspend/recover aggressively
- the lane is rebuilt from scratch and the detailed in-memory conversation state
  is lost

What is acceptable:

- if the app truly cold-started, Pocket Relay may only be able to restore the
  truthful message/history surface that Codex provides

What is not acceptable:

- a brief screen-off by itself causing Pocket Relay to throw away an existing
  lane that was still in memory
- treating every post-turn foreground return like a full cold recovery

This failure is especially important because it happens after the wake lock and
finite background grace stop protecting the app once the active turn ends.

The transport migration must not preserve that behavior.

## File-By-File Migration Map

The actions below use these labels:

- `Delete`: remove the current behavior entirely from the continuity path
- `Replace`: keep the file or concept, but change its primary ownership model
- `Move`: keep the capability, but move it to fallback or a narrower role
- `Keep`: preserve the behavior because it still matches the contract
- `Add`: introduce a new file or responsibility

### Connection Profile And Settings

#### `lib/src/core/models/connection_models_profile.dart`

Action: `Keep`, with narrow clarification

Current role:

- stores SSH/local connection details

Target role:

- keep `remote` vs `local` ownership intent
- do not add a speculative durable-owner enum if `tmux` is the only supported
  remote continuity owner
- treat remote mode as implicitly requiring `tmux`

Why:

- adding `none` vs `tmux` would create a second supported remote mode the user
  has explicitly rejected
- the missing piece is host prerequisite enforcement, not another saved option

#### `lib/src/features/connection_settings/domain/connection_settings_draft.dart`

Action: `Keep`, with narrow clarification

Current role:

- mirrors editable connection fields

Target role:

- do not add a continuity owner picker
- continue mirroring editable connection fields
- let runtime capability feedback be presented separately from saved form data

Why:

- `tmux` is required, not a user-selectable remote variant

#### `lib/src/features/connection_settings/domain/connection_settings_contract.dart`

Action: `Replace`

Current role:

- defines the current settings surface contract
- has no remote prerequisite or capability controls

Target role:

- add a contract surface for required remote prerequisites
- add a contract surface for host capability feedback

Important distinction:

- required remote prerequisites are product truth
- probed host capability belongs in runtime/presentation state, not in the
  saved profile

#### `lib/src/features/connection_settings/application/connection_settings_presenter.dart`

Action: `Replace`

Current role:

- builds the settings screen without continuity framing

Target role:

- present the `tmux` requirement honestly
- if the host is known to lack `tmux`, present that as capability feedback, not
  as a fake successful continuity setup or an alternate supported mode

#### `lib/src/features/connection_settings/application/connection_settings_presenter_sections.dart`

Action: `Replace`

Current role:

- builds route, authentication, Codex, model, and run-mode sections

Target role:

- add a remote prerequisite section or requirement notice
- add explanatory helper text for:
  - why remote mode requires `tmux`
  - what `tmux` capability is missing when unavailable
  - that the fix is host installation, not mode degradation

### Recovery State And Workspace Persistence

#### `lib/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart`

Action: `Keep`

Current role:

- persists selected connection id
- persists selected thread id
- persists draft text

Target role:

- keep exactly this narrow ownership boundary

Why:

- reconnect still needs local runtime identity
- this file is not a continuity bug
- it must not grow into a Pocket Relay-owned transcript archive

#### `lib/src/features/workspace/domain/connection_workspace_state.dart`

Action: `Replace`

Current role:

- tracks transport reconnect requirement and recovery diagnostics

Target role:

- extend the recovery model to distinguish:
  - reconnecting
  - continuity unavailable because host capability is missing
  - continuity unavailable because no remote server is running
  - continuity unavailable because the remote server is unhealthy
  - continuity lost because the owner disappeared after previously existing
  - fallback historical restore

### Workspace Lifecycle And Reconnect Orchestration

#### `lib/src/features/workspace/application/connection_workspace_controller_lifecycle.dart`

Action: `Replace`

Current role:

- cold-start and reconnect path:
  - create lane binding
  - connect transport
  - restore the selected conversation via history

Target role:

- cold-start and reconnect path:
  - probe required host capability for remote mode
  - if capability missing, enter explicit prerequisite-failed state
  - discover whether an explicit user-started server is already running
  - if no server is running, enter explicit server-not-running state
  - if a healthy server is running, connect to the durable owner transport
  - perform live reattach for the selected thread
  - only if live reattach is impossible, fall back to truthful history restore

Additional required behavior:

- if only transport was lost and the current lane binding still exists in
  memory, reconnect through that existing binding instead of recreating the lane
- a short post-turn lock/unlock must not be treated like a reason to discard
  the completed lane and repopulate it from history

Delete from this file as the primary path:

- reconnect then immediately `selectConversationForResume(...)` as a history
  restore default

#### `lib/src/features/workspace/application/connection_workspace_controller.dart`

Action: `Replace`

Current role:

- tracks transport loss, reconnect-required state, and recovery diagnostics

Target role:

- continue owning recovery orchestration
- expand diagnostics to include:
  - capability failure
  - server-not-running
  - server-unhealthy
  - owner-loss semantics
- keep recovery snapshots narrow and runtime-scoped

### Chat Session Recovery And Reattach

#### `lib/src/features/chat/lane/application/chat_session_controller_history.dart`

Action: `Move`

Current role:

- owns history-based transcript restore
- lazily resumes a thread through `startSession(resumeThreadId: ...)` during the
  next outbound send path

Target role:

- keep history restore only as fallback
- remove "wait until next prompt to resume" as the normal reconnect behavior
- do not let history restore become the default answer to a brief post-turn
  foreground return when the lane still exists locally

What moves elsewhere:

- explicit reconnect-time live thread reattach

#### `lib/src/features/chat/lane/application/chat_session_controller_recovery.dart`

Action: `Replace`

Current role:

- recovery entry points ultimately call transcript restore

Target role:

- recovery entry points choose between:
  - live reattach
  - truthful fallback restore

Required new behavior:

- `selectConversationForResume(...)` cannot mean "history restore only"
- it must attempt continuity first when the owner and transport say continuity
  is still available

#### `lib/src/features/chat/lane/application/chat_session_controller.dart`

Action: `Keep`, with narrow updates

Current role:

- session state owner for the lane

Target role:

- keep owning lane runtime state
- accept new explicit live-reattach signals
- do not become the transport owner

### App-Server Transport

#### `lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`

Action: `Replace`

Current role:

- SSH bootstrap
- remote process launch
- hard-coded `codex app-server --listen stdio://`

Target role:

- keep SSH bootstrap responsibilities that still belong here
- remove remote stdio launch as the primary remote continuity path
- replace with:
  - capability probing
  - server discovery
  - explicit server control operations
  - whatever SSH setup is needed for the reconnectable transport

What should no longer be true:

- "connected to app-server" means "Pocket Relay launched a stdio child over SSH"

#### `lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`

Action: `Replace`

Current role:

- process-shaped transport boundary
- direct ownership of spawned process streams

Target role:

- transport-shaped connection boundary
- stdio and reconnectable transport become alternate implementations, not one
  hard-coded process model

#### `lib/src/features/chat/transport/app_server/codex_app_server_connection_lifecycle.dart`

Action: `Replace`

Current role:

- connect/disconnect lifecycle assumes spawned-process semantics

Target role:

- lifecycle must support reconnectable transport without implying that remote
  owner lifetime ends whenever the local client disconnects

#### `lib/src/features/chat/transport/app_server/codex_app_server_client.dart`

Action: `Keep`, with targeted extension

Current role:

- typed request wrapper over the connection

Target role:

- keep as the API client surface
- add any explicit continuity-oriented request methods needed for reconnect-time
  reattach and capability probing

#### `lib/src/features/chat/transport/app_server/codex_app_server_request_api.dart`

Action: `Keep`, with targeted extension

Current role:

- exposes request helpers such as session start and thread read

Target role:

- continue owning request-level mapping
- add explicit API entry points for reconnect-time resume if the higher-level
  client needs them surfaced more directly

#### `lib/src/features/chat/transport/app_server/codex_app_server_request_api_session_thread.dart`

Action: `Keep`, with targeted extension

Current role:

- already knows `thread/start`, `thread/resume`, and `thread/read`

Target role:

- continue decoding these backend contracts
- support a reconnect-time `thread/resume` path that is not hidden behind the
  prompt-send flow

#### `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart`

Action: `Keep`

Why:

- truthful fallback restore still depends on `thread/read`

### Local-Only Or Non-Continuity Paths

#### `lib/src/features/chat/transport/app_server/codex_app_server_local_process.dart`

Action: `Keep`

Current role:

- local desktop app-server launch path

Why it stays:

- local mode is a separate ownership model
- this migration is about remote continuity, not deleting local mode

Important limit:

- do not let the existence of local process launch justify keeping the remote
  continuity path process-shaped

### Presentation

#### `lib/src/features/workspace/presentation/...`

Action: `Replace`, selectively

Current role:

- presents reconnect and restore states

Target role:

- distinguish:
  - reconnecting to live owner
  - continuity unavailable because `tmux` is missing
  - remote server is not running
  - remote server is unhealthy
  - continuity lost because owner disappeared
  - truthful fallback restore in progress
- treat `Saved connections` as the canonical inventory of every saved
  connection, including connections that already have an open lane
- show connection-owned remote server status and lifecycle controls on that
  saved inventory surface
- if `Open lanes` remains on desktop, keep it as quick-switch UI only

What should disappear:

- ambiguous UI that makes all reconnect cases look the same
- implicit transitions where a brief post-turn lock/unlock suddenly looks like
  a full conversation reset

What should be added:

- explicit `Start server`
- explicit `Stop server`
- explicit `Restart server`
- clear distinction between "host unsupported" and "server currently stopped"

#### `lib/src/features/workspace/presentation/workspace_dormant_roster_content.dart`

Action: `Replace`

Current role:

- acts as a dormant-only saved-connections page
- filters live connections out of the saved inventory

Target role:

- become the canonical saved-connections inventory for all saved connections
- keep active/open connections visible there instead of removing them
- surface connection-owned remote server state and actions there

What should disappear:

- the assumption that `Saved connections` means "only connections without a
  live lane"
- row disappearance as soon as a lane opens

#### `lib/src/features/workspace/presentation/workspace_desktop_shell_sidebar_expanded.dart`

Action: `Replace`, selectively

Current role:

- splits `Open lanes` and `Saved`, with `Saved` summarizing only dormant
  connections

Target role:

- keep `Saved` as the canonical saved inventory
- let `Open lanes` remain quick-switch chrome only, if retained
- keep active/open connections visible in `Saved`

#### `lib/src/features/workspace/presentation/workspace_mobile_shell.dart`

Action: `Keep and extend`

Current role:

- hosts the saved-connections page as a separate page after live lanes

Target role:

- keep the separate page structure
- change the page contents so `Saved connections` lists all saved connections,
  not only dormant ones

### Tests

#### `test/workspace_app_lifecycle_host_test.dart`

Action: `Keep and extend`

Must continue proving:

- ordinary app switching does not sever the live lane
- brief post-turn lock/unlock does not force lane recreation when the same
  binding survives

#### `test/connection_workspace_controller_test.dart`

Action: `Replace and extend`

Must prove:

- continuity-mode connection probes host capability
- missing `tmux` produces explicit continuity-unavailable state
- host-capable but stopped server produces explicit server-not-running state
- capable host takes live reattach path first
- fallback restore happens only after continuity becomes unavailable
- pure transport reconnect preserves the existing lane binding when no saved
  settings replacement is required
- brief post-turn resume does not rebuild the lane from history if the same
  binding still exists

#### `test/chat_session_controller_test.dart`

Action: `Replace and extend`

Must prove:

- reconnect-time live reattach happens before the next outbound prompt
- history restore is fallback only

#### `test/codex_app_server_client_test.dart`

Action: `Extend`

Must prove:

- explicit reconnect-time resume calls map to the expected backend requests
- transport disconnect does not imply remote owner death semantically

#### `test/codex_app_server_ssh_process_test.dart`

Action: `Replace`

Must prove:

- capability probing is correct
- `tmux` absence is detected honestly
- server discovery distinguishes running vs stopped vs unhealthy
- the old remote stdio launch path is no longer the continuity default

#### `test/connection_settings_presentation_test.dart`

Action: `Extend`

Must prove:

- settings show the continuity choice literally
- settings surface a missing-`tmux` capability state honestly

## New Files That Should Be Added

The migration likely needs explicit new ownership seams instead of forcing the
old files to absorb every new responsibility.

### Add: remote owner capability probe

Purpose:

- ask the remote host whether the required durable owner capability exists

Minimum responsibilities:

- detect `tmux`
- report explicit capability failure reason

### Add: durable owner bootstrap / discovery helper

Purpose:

- discover, validate, and control the expected owner session for a continuity
  connection

Minimum responsibilities:

- owner naming
- server inventory
- explicit start
- explicit stop
- explicit restart
- owner-missing classification

### Add: reconnectable app-server transport implementation

Purpose:

- let a fresh Pocket Relay process talk to the same surviving remote owner

Important limit:

- do not put session policy into the transport layer
- transport reconnectability and owner identity are separate concerns

## Delete And Demote Summary

Delete as the continuity primary path:

- remote SSH stdio ownership
- history-first reconnect
- prompt-send-triggered resume as the first reattach point
- any supported remote mode that does not require `tmux`
- implicit remote server creation during ordinary connect/reconnect
- implicit remote server stop semantics tied to disconnect

Demote to fallback:

- `thread/read` transcript restore
- historical restore notices

Keep:

- ordinary app-switch continuity protections
- selected thread and draft persistence
- Codex as history source of truth

## Acceptance Standard

The migration is structurally complete only when all of the following are true:

1. remote continuity requires `tmux` as a hard prerequisite
2. Pocket Relay can detect whether the host satisfies that prerequisite
3. missing `tmux` is surfaced as an honest prerequisite failure
4. missing `tmux` does not auto-degrade into a weaker remote mode
5. capable hosts expose explicit server controls instead of hidden lifecycle
   decisions
6. capable hosts use durable-owner reconnect plus live thread reattach
7. real external continuity loss still falls back truthfully without pretending
   continuity survived
8. routine app switching still does not sever a live lane
9. brief post-turn lock/unlock does not discard an existing in-memory lane just
   because the active turn already finished
10. `Saved connections` remains the canonical inventory of all saved
    connections, including active/open ones
11. connection-owned server state does not disappear from the saved inventory
    just because a lane is already open
