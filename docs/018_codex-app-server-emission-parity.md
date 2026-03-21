# Codex App-Server Emission Parity Reference

## Status

This document captures the local reference audit for Codex app-server
client/front-end behavior.

Reference snapshot:

- reference repo: `.reference/codex`
- commit: `49edf311ac3ae84659b0ec5eacd5e471c881eee8`
- date: `2026-03-14`

Primary source files:

- `.reference/codex/codex-rs/app-server/README.md`
- `.reference/codex/codex-rs/app-server-protocol/src/protocol/common.rs`
- `.reference/codex/codex-rs/app-server-client/src/lib.rs`
- `.reference/codex/codex-rs/tui/src/app/app_server_adapter.rs`
- `.reference/codex/codex-rs/tui/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui/src/chatwidget/realtime.rs`
- `.reference/codex/codex-rs/tui/src/app.rs`
- `.reference/codex/codex-rs/exec/src/lib.rs`
- `.reference/codex/codex-rs/app-server-test-client/src/lib.rs`
- `.reference/codex/codex-rs/core/src/client.rs`
- `.reference/codex/codex-rs/core/src/model_provider_info.rs`
- `.reference/codex/codex-rs/codex-api/src/endpoint/responses.rs`
- `.reference/codex/codex-rs/codex-api/src/endpoint/responses_websocket.rs`

## Important Caveat

The open-source Codex TUI is not yet a complete typed app-server client.

It starts an in-process app-server in
`.reference/codex/codex-rs/tui/src/lib.rs:239-300`, but the app-server adapter
still ignores `ServerNotification` and rejects `ServerRequest` on that path in
`.reference/codex/codex-rs/tui/src/app/app_server_adapter.rs:20-50`.

That means "Codex frontend handling" in the open-source repo often exists as an
equivalent TUI/core event flow rather than as literal typed
`ServerNotification`/`ServerRequest` handling.

This document therefore distinguishes between:

- `Typed`: the open-source client literally handles the app-server emission.
- `Equivalent`: no typed handler is wired in the TUI, but equivalent UI behavior
  exists through direct `codex-core` events.
- `Test-only`: only `app-server-test-client` handles it literally.
- `Ignored`: the open-source client explicitly no-ops it.
- `None found`: protocol exists, but no useful open-source frontend handling was
  found.

This document only covers the open-source Rust clients in `.reference/codex`.
The actual Codex Desktop frontend implementation is not present in this repo.

## Layer Summary

For architecture parity, the important split is:

- `codex app-server` is the local rich-client protocol boundary.
- upstream model transport is not `app-server`; it is the Responses API over
  HTTP/SSE or websocket.

Evidence:

- `codex app-server` is described as the interface used to power rich clients in
  `.reference/codex/codex-rs/app-server/README.md:1-45`.
- the model client prefers Responses websocket and falls back to Responses HTTP
  in `.reference/codex/codex-rs/core/src/client.rs:1245-1279`.
- the default upstream base URL is
  `https://chatgpt.com/backend-api/codex` for ChatGPT auth or
  `https://api.openai.com/v1` otherwise in
  `.reference/codex/codex-rs/core/src/model_provider_info.rs:155-185`.

## Protocol Inventory

The protocol inventory used here comes from:

- server requests:
  `.reference/codex/codex-rs/app-server-protocol/src/protocol/common.rs:736-794`
- server notifications:
  `.reference/codex/codex-rs/app-server-protocol/src/protocol/common.rs:869-936`

## Server Requests

| Method | Status | Open-source Codex handling | Pocket Relay recommendation |
| --- | --- | --- | --- |
| `item/commandExecution/requestApproval` | `Equivalent` in TUI, `Typed` reject in `exec` | TUI equivalent routes command approvals into `ApprovalRequest::Exec` in `.reference/codex/codex-rs/tui/src/app.rs:1378-1396` and shows the approval UI in `.reference/codex/codex-rs/tui/src/chatwidget.rs:3296-3315`. `exec` rejects the typed request in `.reference/codex/codex-rs/exec/src/lib.rs:1263-1274`. | Implement. This is a core parity feature. |
| `item/fileChange/requestApproval` | `Equivalent` in TUI, `Typed` reject in `exec` | TUI equivalent routes patch approvals in `.reference/codex/codex-rs/tui/src/app.rs:1397-1409` and renders them in `.reference/codex/codex-rs/tui/src/chatwidget.rs:3318-3336`. `exec` rejects the typed request in `.reference/codex/codex-rs/exec/src/lib.rs:1275-1286`. | Implement. This is a core parity feature. |
| `item/tool/requestUserInput` | `Equivalent` in TUI, `Typed` reject in `exec` | TUI equivalent shows a request-user-input surface in `.reference/codex/codex-rs/tui/src/chatwidget.rs:3378-3386`. `exec` rejects it in `.reference/codex/codex-rs/exec/src/lib.rs:1287-1298`. | Implement. This is a core parity feature. |
| `mcpServer/elicitation/request` | `Equivalent` in TUI, `Typed` auto-cancel in `exec` | TUI equivalent routes to either a dedicated elicitation form or an approval-style fallback in `.reference/codex/codex-rs/tui/src/app.rs:1410-1426` and `.reference/codex/codex-rs/tui/src/chatwidget.rs:3338-3360`. `exec` auto-cancels it in `.reference/codex/codex-rs/exec/src/lib.rs:1202-1218`. | Implement if Pocket Relay wants MCP parity. |
| `item/permissions/requestApproval` | `Equivalent` in TUI, `Typed` reject in `exec` | TUI equivalent routes permissions approvals in `.reference/codex/codex-rs/tui/src/app.rs:1427-1437` and shows them in `.reference/codex/codex-rs/tui/src/chatwidget.rs:3388-3400`. `exec` rejects it in `.reference/codex/codex-rs/exec/src/lib.rs:1335-1346`. | Implement. This is part of approvals parity. |
| `item/tool/call` | `Ignored` in TUI, `Typed` reject in `exec` | The TUI explicitly ignores the equivalent core events `DynamicToolCallRequest` and `DynamicToolCallResponse` in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5410-5416`. `exec` rejects the typed request in `.reference/codex/codex-rs/exec/src/lib.rs:1299-1310`. | Track, but defer unless the backend starts using it for your flows. |
| `account/chatgptAuthTokens/refresh` | `Typed` in `exec` only | `exec` resolves this request from local auth state in `.reference/codex/codex-rs/exec/src/lib.rs:1219-1262`. No TUI UI handling was found. | Likely not needed for SSH remote app-server sessions. |
| Legacy `ApplyPatchApproval` | `Equivalent` legacy TUI path, `Typed` reject in `exec` | TUI still has legacy patch approval interrupt handling, but not via the typed app-server adapter. `exec` rejects the typed legacy request in `.reference/codex/codex-rs/exec/src/lib.rs:1311-1322`. | Do not implement unless Pocket Relay adds legacy APIs. |
| Legacy `ExecCommandApproval` | `Equivalent` legacy TUI path, `Typed` reject in `exec` | TUI still has legacy command approval interrupt handling, but not via the typed app-server adapter. `exec` rejects the typed legacy request in `.reference/codex/codex-rs/exec/src/lib.rs:1323-1334`. | Do not implement unless Pocket Relay adds legacy APIs. |

## Server Notifications

| Method | Status | Open-source Codex handling | Pocket Relay recommendation |
| --- | --- | --- | --- |
| `error` | `Typed` in `exec`, `Equivalent` in TUI | `exec` uses the typed notification to mark non-retry terminal failure in `.reference/codex/codex-rs/exec/src/lib.rs:784-792`. TUI equivalent shows an error cell and finalizes the turn in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2086-2094`. | Implement. |
| `thread/started` | `Test-only`, `Equivalent` in TUI | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1685-1690`. TUI equivalent startup/session initialization happens in `SessionConfigured` handling in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1356-1441`. | Implement if you expose thread lifecycle explicitly. |
| `thread/status/changed` | `None found` | No useful open-source frontend handling found. | Optional unless Pocket Relay adds thread list/history management. |
| `thread/archived` | `None found` | No useful open-source frontend handling found. | Optional unless Pocket Relay adds archive management. |
| `thread/unarchived` | `None found` | No useful open-source frontend handling found. | Optional unless Pocket Relay adds archive management. |
| `thread/closed` | `None found` | No useful open-source frontend handling found. | Optional unless Pocket Relay adds multi-thread lifecycle UI. |
| `skills/changed` | `None found`, `Equivalent` semantic exists | No typed handler found. The equivalent TUI semantic is `SkillsUpdateAvailable`, which triggers a forced skill reload in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5335-5340`. | Implement if you add live skill reload. |
| `thread/name/updated` | `Equivalent` in TUI | TUI equivalent updates the active thread title in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1488-1493`. | Implement if you expose thread names. |
| `thread/tokenUsage/updated` | `Equivalent` semantic exists | No typed handler found. Equivalent TUI/exec semantics come from `TokenCount`, which updates usage snapshots in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5259-5260` and `.reference/codex/codex-rs/exec/src/event_processor_with_jsonl_output.rs:156-160`. | Implement if you want live token-usage updates before turn completion. |
| `turn/started` | `Test-only`, `Equivalent` in TUI/exec | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1691-1695`. TUI equivalent enters running state in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1693-1715`. `exec` human output ignores the display but tracks turn state in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:303-305`. | Implement. |
| `hook/started` | `Equivalent` in TUI/exec | TUI shows a history info entry in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2935-2946`. `exec` prints hook start in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:860-861`. | Implement if Pocket Relay surfaces hooks. |
| `turn/completed` | `Test-only`, `Equivalent` in TUI/exec | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1741-1759`. TUI equivalent finalizes the whole turn in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1717-1786`. `exec` uses equivalent core events to initiate shutdown in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:319-332`. | Implement. |
| `hook/completed` | `Equivalent` in TUI/exec | TUI renders hook status and entries in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2948-2963`. `exec` renders hook completion in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:861-862`. | Implement if Pocket Relay surfaces hooks. |
| `turn/diff/updated` | `Equivalent` in TUI | Equivalent TUI handling just refreshes status-line state in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2917-2920`. The richer patch UI comes from other item events, not this notification alone. | Implement only if your state model needs explicit turn-level diff snapshots. |
| `turn/plan/updated` | `Equivalent` in TUI | Equivalent TUI handling appends a plan-update checklist cell in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2351-2354`. | Implement. |
| `item/started` | `Test-only`, `Ignored` in TUI transcript | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1709-1725`. The TUI explicitly ignores the raw equivalent core event in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5410-5412`. | Optional. Use only if your UI needs item lifecycle placeholders. |
| `item/autoApprovalReview/started` | `Equivalent` in TUI | Equivalent guardian-review in-progress footer handling lives in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2372-2477`. | Implement if you want guardian review parity. |
| `item/autoApprovalReview/completed` | `Equivalent` in TUI | Equivalent guardian-review completion handling appends approved or denied history cells in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2479-2589`. | Implement if you want guardian review parity. |
| `item/completed` | `Test-only`, `Equivalent` in TUI/exec | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1726-1740`. The TUI commits finalized items in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5434-5448`. `exec` maps equivalent core item completion into output items in `.reference/codex/codex-rs/exec/src/event_processor_with_jsonl_output.rs:124-130`. | Implement. |
| `rawResponseItem/completed` | `None found` | Protocol comment marks it internal-only for Codex Cloud in `.reference/codex/codex-rs/app-server-protocol/src/protocol/common.rs:889-891`. No useful open-source frontend handling found. | Ignore for now. |
| `item/agentMessage/delta` | `Test-only`, `Equivalent` in TUI | `app-server-test-client` streams it directly to stdout in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1696-1699`. Equivalent TUI assistant streaming is in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1581-1583`. | Implement. |
| `item/plan/delta` | `Equivalent` in TUI | Equivalent TUI plan streaming is in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1585-1646`. | Implement if Pocket Relay supports plan streaming. |
| `command/exec/outputDelta` | `None found` | No useful open-source TUI/exec frontend handling found for the standalone `command/exec` output delta notification. | Optional unless Pocket Relay adopts standalone `command/exec`. |
| `item/commandExecution/outputDelta` | `Test-only`, `Equivalent` in TUI | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1700-1704`. Equivalent TUI live exec output handling is in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2633-2651`. | Implement. |
| `item/commandExecution/terminalInteraction` | `Test-only`, `Equivalent` in TUI | `app-server-test-client` prints stdin activity in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1705-1708`. Equivalent TUI waiting/background-terminal handling is in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2653-2678`. | Implement if Pocket Relay surfaces live terminal interaction state. |
| `item/fileChange/outputDelta` | `None found` | No useful open-source frontend handling found. The TUI patch UI uses begin/end style events instead. | Optional unless the server starts depending on incremental file-change streaming. |
| `serverRequest/resolved` | `None found` | No useful open-source frontend handling found. | Ignore for now. |
| `item/mcpToolCall/progress` | `Test-only`, `Equivalent` partial semantics exist | `app-server-test-client` prints progress messages in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1761-1763`. The TUI uses MCP begin/end lifecycle events, not explicit progress deltas, in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2845-2853`. | Optional. |
| `mcpServer/oauthLogin/completed` | `None found` | No useful open-source frontend handling found. | Optional unless Pocket Relay adds local OAuth flows. |
| `account/updated` | `None found` | No useful open-source frontend handling found. | Optional. |
| `account/rateLimits/updated` | `Test-only`, no typed TUI use | `app-server-test-client` prints it in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1656-1670`. The TUI instead fetches rate limits directly via `BackendClient` in `.reference/codex/codex-rs/tui/src/chatwidget.rs:9421-9434`. | Optional. |
| `app/list/updated` | `None found` | No typed handler found. The TUI loads connectors/apps directly and has no app-list update notification handler; the relevant loading path is around `.reference/codex/codex-rs/tui/src/chatwidget.rs:6025-6053`. | Optional unless Pocket Relay exposes dynamic connector/app availability. |
| `item/reasoning/summaryTextDelta` | `Equivalent` in TUI | Equivalent reasoning status-first handling updates the live status header from reasoning deltas in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1648-1667`. | Implement if you want reasoning parity. |
| `item/reasoning/summaryPartAdded` | `Equivalent` in TUI | Same reasoning-status semantics as above. Final reasoning summary blocks are committed in `.reference/codex/codex-rs/tui/src/chatwidget.rs:1669-1682`. | Implement if you want reasoning parity. |
| `item/reasoning/textDelta` | `Equivalent` in TUI | Same reasoning-status semantics as above. | Implement if you want reasoning parity. |
| `thread/compacted` | `Equivalent` in TUI/exec | TUI equivalent renders a simple `"Context compacted"` message in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5368`. `exec` also has equivalent core-event handling in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:695`. | Optional, but cheap to support. |
| `model/rerouted` | `Ignored` | The TUI explicitly ignores equivalent core `ModelReroute` events in `.reference/codex/codex-rs/tui/src/chatwidget.rs:5265`, and `exec` also no-ops them in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:239-240`. | Ignore for now. |
| `deprecationNotice` | `Equivalent` in TUI/exec | TUI renders a deprecation notice cell in `.reference/codex/codex-rs/tui/src/chatwidget.rs:2922-2926`. `exec` prints it in `.reference/codex/codex-rs/exec/src/event_processor_with_human_output.rs:241-249`. | Implement if you want close parity. |
| `configWarning` | `None found` | Startup config warnings are passed into the in-process app-server client in `.reference/codex/codex-rs/tui/src/lib.rs:272-297`, but no useful runtime frontend notification handler was found. | Optional. |
| `fuzzyFileSearch/sessionUpdated` | `None found` | No useful open-source frontend handling found. | Ignore unless Pocket Relay adopts this API. |
| `fuzzyFileSearch/sessionCompleted` | `None found` | No useful open-source frontend handling found. | Ignore unless Pocket Relay adopts this API. |
| `thread/realtime/started` | `Equivalent` in TUI | Equivalent realtime voice startup handling is in `.reference/codex/codex-rs/tui/src/chatwidget/realtime.rs:242-257`. | Optional unless Pocket Relay adds realtime voice mode. |
| `thread/realtime/itemAdded` | `Equivalent` partial semantics in TUI | Equivalent realtime event handling exists in `.reference/codex/codex-rs/tui/src/chatwidget/realtime.rs:259-278`, but many payloads are no-oped there. | Optional unless Pocket Relay adds realtime voice mode. |
| `thread/realtime/outputAudio/delta` | `Equivalent` in TUI | Equivalent realtime audio output is enqueued in `.reference/codex/codex-rs/tui/src/chatwidget/realtime.rs:269-307`. | Optional unless Pocket Relay adds realtime voice mode. |
| `thread/realtime/error` | `Equivalent` in TUI | Equivalent realtime errors show an error message and reset voice state in `.reference/codex/codex-rs/tui/src/chatwidget/realtime.rs:273-276`. | Optional unless Pocket Relay adds realtime voice mode. |
| `thread/realtime/closed` | `Equivalent` in TUI | Equivalent realtime close handling is in `.reference/codex/codex-rs/tui/src/chatwidget/realtime.rs:280-288`. | Optional unless Pocket Relay adds realtime voice mode. |
| `windows/worldWritableWarning` | `None found` | No useful open-source frontend handling found. | Ignore unless Pocket Relay runs local Windows app-server sessions. |
| `windowsSandbox/setupCompleted` | `None found` | No useful open-source frontend handling found. | Ignore unless Pocket Relay runs local Windows app-server sessions. |
| `account/login/completed` | `Test-only` | `app-server-test-client` waits for it explicitly in `.reference/codex/codex-rs/app-server-test-client/src/lib.rs:1650-1675`. No useful TUI/exec frontend handling was found. | Optional unless Pocket Relay adds local account login flows. |

## What Pocket Relay Should Copy First

If the goal is front-end parity for the current Pocket Relay app-server path,
the highest-value emissions are:

- `item/commandExecution/requestApproval`
- `item/fileChange/requestApproval`
- `item/tool/requestUserInput`
- `item/permissions/requestApproval`
- `turn/started`
- `turn/completed`
- `item/agentMessage/delta`
- `item/commandExecution/outputDelta`
- `item/commandExecution/terminalInteraction`
- `item/completed`
- `turn/plan/updated`
- `item/plan/delta`
- reasoning delta notifications
- guardian review start/completion notifications

Those are the emissions that drive the transcript, blocked-turn lifecycle,
approval/user-input UX, and live work rendering that users actually see.

## What Pocket Relay Can Safely Defer

Unless the app scope changes, the following are lower priority or likely
unnecessary for a remote SSH-backed mobile client:

- `account/chatgptAuthTokens/refresh`
- `account/login/completed`
- `account/updated`
- `account/rateLimits/updated`
- `app/list/updated`
- `command/exec/outputDelta`
- fuzzy file search session notifications
- Windows sandbox notifications
- realtime voice notifications
- legacy approval request variants

## Implementation Rule For Pocket Relay

Do not mirror the open-source TUI's literal `app_server_adapter.rs` behavior.
That adapter is intentionally incomplete.

Parity work should instead follow this rule:

1. treat the app-server protocol surface as the contract
2. map each emission into Pocket Relay's own canonical runtime events
3. copy the upstream TUI's visible behavior from the equivalent core event
   handlers when typed app-server handling is not wired yet in upstream Codex

That is the only way to get semantic parity without copying the TUI's current
hybrid migration state.
