# Tmux And Websocket User Path Timeline

## Status

This document answers one narrow question:

Why does the upgraded remote continuity path still need both:

- `tmux`
- websocket

even after the server lifecycle becomes explicit and user-owned?

Related docs:

- [`066_durable_remote_owner_options.md`](./066_durable_remote_owner_options.md)
- [`067_tmux_migration_path_source_investigation.md`](./067_tmux_migration_path_source_investigation.md)
- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)

## Short Answer

Because they do different jobs.

- `tmux` keeps the user-started remote server alive
- websocket is the bidirectional protocol door clients use to talk to that
  running server

The new ownership model does not remove either responsibility. It only makes
server lifetime explicit:

- the user decides when the server starts and stops
- Pocket Relay discovers whether a server is already running
- Pocket Relay connects to it if healthy

So the stack is:

- user controls lifetime
- `tmux` provides durable process ownership
- websocket provides client transport
- `thread/resume` provides live thread re-entry

## Important Ownership Split

### User owns server lifetime

The user explicitly:

- starts the remote server
- stops the remote server
- restarts the remote server

### Pocket Relay owns client attachment

Pocket Relay:

- checks prerequisites
- discovers existing servers
- verifies server health
- connects to a healthy server
- reattaches the selected thread

Pocket Relay does not decide that ordinary disconnect means the server should
die.

### Saved connections owns connection inventory

The UI ownership split follows the same rule:

- `Saved connections` lists every saved connection, including ones that already
  have an open lane
- connection-owned server state and explicit server controls belong to that
  saved inventory surface
- the live lane still owns lane-specific continuity notices
- if desktop keeps `Open lanes`, it is quick-switch UI only, not the sole place
  an active saved connection exists

## Why `tmux` Still Matters

Even with explicit controls, the server still needs a durable owner after the
phone app disappears.

Without `tmux`:

- the user may have explicitly started a server
- but that server still may not survive the loss of the original phone-owned
  launch context

`tmux` answers:

- is the user-started remote server still alive?

## Why Websocket Still Matters

Even with explicit controls, Pocket Relay still needs a clean way to talk to a
server that was started earlier.

Without websocket or another reconnectable transport:

- the server may still be alive in `tmux`
- but a fresh Pocket Relay client has no clean protocol endpoint to reconnect
  to

Websocket answers:

- can this new client process talk to that same already-running server?

## Summary Matrix

| Scenario | Need `tmux`? | Need websocket? | Need `thread/resume`? | Need explicit user server controls? |
| --- | --- | --- | --- | --- |
| Foreground turn, app never loses process or transport | No | No | No | No |
| Brief app switch, same binding survives | No | No | No | No |
| Remote server was already started earlier and app reconnects to it | Yes | Yes | Usually yes | Yes |
| App suspended or killed during active turn, want same live turn on return | Yes | Yes | Yes | Yes |
| User wants to stop remote execution intentionally | Yes | No | No | Yes |
| Turn already finished and only truthful restore is needed | No | No | No | No |

## Timeline 1: User Starts The Remote Server Explicitly

This is the new ownership entry point.

| Time | User | Pocket Relay | SSH | Remote | Result |
| --- | --- | --- | --- | --- | --- |
| T1 | Opens remote connection | Probes `tmux` and `codex` | Runs capability commands | Host answers | App knows whether host is eligible |
| T2 | Taps `Start server` | Sends explicit start request | Boots remote setup | Creates or activates Pocket Relay-managed `tmux` session and launches websocket app-server | Server is now running intentionally |
| T3 | Waits for readiness | Polls discovery/health | Carries structured checks | App-server becomes ready | Running server can now accept clients |

Why both matter here:

- `tmux` makes the started server durable
- websocket is the endpoint that later clients will use

## Timeline 2: User Opens Pocket Relay Later And Connects To An Existing Server

This is the scanner/discovery path.

| Time | User | Pocket Relay | SSH | Remote | Result |
| --- | --- | --- | --- | --- | --- |
| T1 | Opens the same connection later | Runs discovery | Queries expected Pocket Relay-managed `tmux` session and server metadata | Running server still exists | App knows a server is already running |
| T2 | Does not press `Start server` | Verifies readiness | Opens secure forwarding | Existing websocket listener is healthy | No new server is created |
| T3 | Enters lane | Connects websocket client | Carries forwarded websocket traffic | Same server accepts new connection | Client attaches to the running server |

This is why discovery alone is not enough:

- discovery finds the `tmux`-owned server
- websocket is still the actual protocol path into it

## Timeline 2A: User Opens Saved Connections While The Lane Is Already Open

| Time | Situation | Expected Result |
| --- | --- | --- |
| T1 | A saved remote connection already has an open lane | The same connection still appears in `Saved connections` |
| T2 | Its managed server is already running | `Saved connections` shows that running state honestly |
| T3 | The user wants server control, not lane transcript details | `Saved connections` is the correct surface for connection-owned `Start server`, `Stop server`, or `Restart server` actions |
| T4 | The user wants to jump back into the lane quickly | Desktop `Open lanes` may still offer quick switching, but it is not the only inventory |

## Timeline 3: Ordinary App Switch, No Confirmed Transport Loss

| Time | User | Pocket Relay | Remote Server | Result |
| --- | --- | --- | --- | --- |
| T1 | Backgrounds app briefly | Keeps existing binding if still alive | Same server keeps running | No server lifecycle action occurs |
| T2 | Returns quickly | Reuses same in-memory lane/binding | Same server is still there | No discovery or explicit reconnect is required yet |

This is the no-regression path.

The stronger server architecture exists for the loss cases below, not to
justify tearing down this case.

## Timeline 4: App Suspended Or Killed During An Active Turn

| Time | User | Phone App | SSH | `tmux` / Server | Result |
| --- | --- | --- | --- | --- | --- |
| T1 | Previously started server explicitly | Connected to server and starts a long turn | Normal live connection exists | `tmux` owns websocket app-server | Live turn begins |
| T2 | Leaves app long enough for suspension/kill | App disappears | Original client connection dies | `tmux` keeps same app-server alive | Same remote turn keeps running |
| T3 | Returns later | Fresh Pocket Relay process restores lane identity | Opens new SSH forwarding path | Same server is still running | Client can reach the same server |
| T4 | Waits for recovery | Connects websocket and sends `initialize`, then `thread/resume(selectedThreadId)` | Carries protocol traffic | App-server reattaches connection to same loaded thread | Same live thread becomes visible again |

This is the full continuity path.

## Timeline 5: Server Exists, But User Never Wants Pocket Relay To Auto-Start It

| Time | Situation | Expected Result |
| --- | --- | --- |
| T1 | No remote server is running | Pocket Relay reports `server not running` |
| T2 | User opens lane expecting continuity | Pocket Relay does not silently start a new server |
| T3 | User decides whether to start one | `Start server` is an explicit action |

This is the ownership correction that removes the bad implicit lifecycle model.

## Timeline 6: User Explicitly Stops The Server

| Time | User | Pocket Relay | Remote | Result |
| --- | --- | --- | --- | --- |
| T1 | Chooses `Stop server` | Sends explicit stop request | Stops websocket app-server and its `tmux` session | Remote continuity ends intentionally |
| T2 | Reopens the lane later | Runs discovery | No running server exists | App shows truthful stopped/unavailable state until the user starts one again |

This is another reason websocket and `tmux` are not the same thing:

- `tmux` owns lifetime
- websocket is only useful while that lifetime still exists

## Timeline 7: Pending Approval Or Input Request While The App Is Away

| Time | Result |
| --- | --- |
| T1 | Running server sends approval or input request |
| T2 | Phone app disappears |
| T3 | `tmux` keeps the server and thread alive |
| T4 | Pocket Relay reconnects over websocket to that same server |
| T5 | Pocket Relay issues `thread/resume(selectedThreadId)` |
| T6 | Upstream replays pending server requests to the reconnecting client |
| T7 | User resolves the same request and the same turn continues |

This is why `thread/resume` is still required in addition to `tmux` and
websocket.

## Timeline 8: User Returns But No Server Is Running

| Time | Desired Result |
| --- | --- |
| T1 | User expects continuity |
| T2 | Discovery finds no running server, or health verification fails |
| T3 | Pocket Relay must not fake a live server or silently create a replacement |
| T4 | Lane identity and draft are preserved |
| T5 | Truthful fallback restore happens if upstream history is available |
| T6 | UI explains that the live server is not running |

## Bottom Line

The explicit user-owned lifecycle changes who decides when the server lives or
dies.

It does not remove the need for:

- `tmux` to keep that user-started server alive
- websocket to let a fresh client talk to that already-running server
- `thread/resume` to make the selected thread live again on the new connection

That is why the upgraded path still needs both `tmux` and websocket.
