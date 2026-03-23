# Tmux Migration Path Source Investigation

## Status

This document records the source-backed findings that support the chosen remote
continuity architecture.

It is not the final implementation plan. Its job is to answer:

- what the repo does today
- what upstream `codex app-server` already supports
- why the chosen explicit server-ownership model is credible in source

Related docs:

- [`066_durable_remote_owner_options.md`](./066_durable_remote_owner_options.md)
- [`068_tmux_ws_user_path_timeline.md`](./068_tmux_ws_user_path_timeline.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)

## Executive Conclusion

The source investigation supports this architecture:

- remote server lifetime is user-owned
- the running remote app-server lives inside `tmux`
- Pocket Relay discovers existing servers instead of silently inventing them
- Pocket Relay connects to those servers through websocket
- reconnect-time `thread/resume` is the right live reattach primitive

The investigation also rules out several shortcuts:

- `tmux attach` is not a clean app-server transport
- current SSH stdio cannot remain the primary remote continuity model
- implicit server start/stop during connect/disconnect would keep ownership
  muddy and create churn

## Current Repo Shape

### Remote transport today

Remote mode still means:

- SSH from Pocket Relay
- remote launch of `codex app-server --listen stdio://`
- JSON-RPC over that launched process stdio

Confirmed in:

- [`README.md`](../README.md)
- [`lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart`](../lib/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart)
- [`lib/src/features/chat/transport/app_server/codex_app_server_connection.dart`](../lib/src/features/chat/transport/app_server/codex_app_server_connection.dart)

Important consequence:

- the current remote path is process-shaped
- the launched process is too tied to the phone-owned SSH session

### Recovery foundation today

The repo already has the right recovery baseline:

- selected-lane recovery state is persisted
- cold-start restore exists
- ordinary app switching does not self-disconnect the lane by default

That foundation should be preserved.

## Upstream App-Server Findings

### 1. Upstream supports two runtime transports

Bundled upstream `codex app-server` supports:

- `stdio://`
- `ws://IP:PORT`

That matters because Pocket Relay is not forced to stay inside the original
SSH-launched pipe model forever.

### 2. `stdio` and websocket do not have the same process-lifetime behavior

Upstream source treats `stdio` as single-client mode.

In that mode:

- the process exits when the last connection closes

Upstream websocket mode does not use that same
`shutdown_when_no_connections` behavior.

That makes websocket materially better for a long-lived user-started server
that can exist with zero currently attached phone clients.

### 3. Connection close is not the same thing as explicit thread shutdown

Upstream source distinguishes:

- closing a connection
- explicitly unsubscribing the last subscriber from a thread
- shutting down the whole app-server process

Relevant source behavior:

- connection close removes the connection
- explicit `thread/unsubscribe` on the last subscriber unloads the thread
- websocket-mode server process itself is not defined as "die when no clients
  remain"

This distinction is exactly what the explicit user-owned server model needs.

### 4. `thread/resume` is stronger than Pocket Relay currently uses it

The upstream implementation already supports more than a shallow history read:

- attach the reconnecting connection to an existing loaded thread
- merge active-turn state when a turn is still in flight
- replay pending server requests for that thread
- re-establish thread subscription on the new connection

That makes reconnect-time `thread/resume` the strongest source-backed basis for
live re-entry.

## What This Means Structurally

### `tmux` should own process lifetime only

`tmux` should answer:

- is the user-started server still alive?

It should not become the protocol surface.

### Websocket should be the protocol door

Websocket should answer:

- can a fresh Pocket Relay process talk to that still-running server again?

### Pocket Relay should own discovery and client attachment

Pocket Relay should:

- probe `tmux` and `codex`
- discover existing Pocket Relay-managed servers
- verify readiness/health
- connect to an already-running server
- reattach the selected thread with `thread/resume`

Pocket Relay should not:

- pretend that connect/disconnect is the same thing as server lifecycle
- silently replace one server with another during reconnect

## Code Ownership Seams The Repo Still Needs

### 1. Transport abstraction

Current code is still too coupled to launched-process streams.

The repo needs a transport-shaped boundary so websocket can be a first-class
remote path.

### 2. Remote server inventory and control

The repo needs a seam that can:

- list Pocket Relay-managed remote servers
- verify whether one is healthy
- start one explicitly
- stop one explicitly
- restart one explicitly

This must not be hidden inside ad hoc launcher glue.

### 3. Workspace recovery state expansion

Workspace recovery needs to distinguish:

- prerequisite missing
- server not running
- server unhealthy
- reconnecting to existing server
- truthful fallback restore

### 4. Reattach-first recovery

The reconnect path still needs to stop using history restore as the normal
answer to interrupted continuity.

## Rejected Shortcuts

Do not treat these as the migration path:

- `tmux attach` as a transport
- implicit server creation during reconnect
- implicit server stop on disconnect
- history-first reconnect for a live continuity architecture

## Bottom Line

The source code does not support keeping the current SSH stdio ownership model
and merely "adding `tmux`."

The source does support a cleaner path:

- user-owned remote server lifecycle
- `tmux` for process survival
- websocket for reconnectable transport
- reconnect-time `thread/resume` for live re-entry

That is the architecture the later docs now lock in.
