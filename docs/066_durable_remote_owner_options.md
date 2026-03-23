# Durable Remote Owner Options

## Status

This document records the durable-owner option sweep after the background
continuity discussion on 2026-03-23.

It is no longer an open-ended options document. The preferred first
implementation path is now clear.

Related docs:

- [`059_background_execution_publishability_findings.md`](./059_background_execution_publishability_findings.md)
- [`060_background_execution_publishability_phased_plan.md`](./060_background_execution_publishability_phased_plan.md)
- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)

## Problem

Pocket Relay currently launches the remote process through a phone-owned SSH
session:

- SSH connection from the client device
- remote launch of `codex app-server --listen stdio://`
- JSON-RPC over that stdio stream

That shape is acceptable for foreground use, but it is the wrong ownership
model for true live-turn continuity on iPhone.

The core requirement is now fixed:

- the remote turn must keep running while the phone app is away
- the phone app must not own the remote server lifetime
- the user must be able to come back to the same still-running server and
  thread

## Option 1: User-Owned Remote Server Under `tmux`

### What it means

The user explicitly controls the remote server lifecycle:

- `Start server`
- `Stop server`
- `Restart server`

The server itself runs inside a Pocket Relay-managed `tmux` session on the
remote host.

Pocket Relay may:

- probe prerequisites
- discover already-running servers
- connect to a healthy server automatically

Pocket Relay must not:

- silently start the server during ordinary reconnect
- silently stop the server when the phone disconnects
- silently replace the server with a new one

### Why this is the preferred first path

It fixes the ownership problem directly:

- durable owner is remote-side, not phone-side
- server lifetime becomes explicit instead of accidental
- disconnect no longer implies stop
- reconnect can be framed as "find the running server and attach"

It also keeps Pocket Relay honest about what it does and does not own.

### What it still requires

`tmux` alone is not enough. This path still needs:

- deterministic server discovery
- a reconnectable transport such as websocket
- reconnect-time `thread/resume`
- truthful fallback restore when the server is gone

## Option 2: Implicit `tmux` Lifecycle Managed By Pocket Relay

### What it means

Pocket Relay would silently create, reuse, replace, and stop `tmux`-owned
servers as a side effect of connect/disconnect behavior.

### Why this was rejected

This pushes hidden backend decisions into the client:

- reconnect starts becoming lifecycle control
- disconnect starts becoming accidental teardown
- user intent becomes ambiguous
- downstream churn grows because the ownership model stays muddy

This is the exact shortcut the later planning docs now reject.

## Option 3: Desktop Pocket Relay UI App As Relay Owner

### Why it remains unattractive

The desktop UI process would become a hidden backend:

- frontend quits would kill the relay
- ownership would be unclear
- product complexity would grow in the wrong place

This remains technically possible, but not structurally attractive.

## Option 4: Dedicated Headless Relay Or Gateway

### Why it is still credible

A separate service could own:

- remote server lifecycle
- authentication/session identity
- multi-client coordination
- replay/gap policies

### Why it is not the first implementation

It adds a new service layer before the simpler upstream-backed path is proven.

That is higher churn than:

- `tmux` as the durable owner
- websocket as the transport
- explicit user-owned server lifecycle

## Final Direction

The preferred first implementation path is now:

1. require `tmux`
2. make remote server lifetime user-owned
3. run the remote app-server inside `tmux`
4. discover already-running servers deterministically
5. connect to them over websocket
6. use reconnect-time `thread/resume` for live reattach

Pocket Relay therefore becomes:

- a client that can discover, connect to, and reattach to a running server
- not the hidden owner of when that server should live or die

## What this doc now implies

The follow-up questions are no longer:

- should Pocket Relay auto-start or auto-stop the server?
- should the phone app own remote lifetime implicitly?

The follow-up questions are now narrower:

- how does Pocket Relay discover the expected server?
- how does it verify server health?
- what exact metadata identifies one running server from another?
- what UI states expose `Start server`, `Stop server`, and `Restart server`?

Those answers are carried forward in:

- [`067_tmux_migration_path_source_investigation.md`](./067_tmux_migration_path_source_investigation.md)
- [`068_tmux_ws_user_path_timeline.md`](./068_tmux_ws_user_path_timeline.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)
