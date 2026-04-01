# Agent Adapter Architecture And Codex Claude Differences

## Scope

This document records the second-pass decoupling work that moved Pocket Relay
toward first-class `agent adapters`.

The implementation work for this pass lives on:

- `feat/agent-adapters-foundation`

This branch split was created before any new commits for the refactor were
made, so there were no refactor commits to undo from the previous branch.

The purpose of this document is:

1. define the term `agent adapter`
2. describe the current Pocket Relay architecture after this pass
3. list the remaining Codex-specific seams honestly
4. compare upstream Codex and Claude Code realities from the local reference
   snapshots
5. state how Pocket Relay should adapt so future host support is additive
   instead of invasive

## Terms

### Agent adapter

An `agent adapter` is the app-owned boundary between Pocket Relay and an
upstream agent host implementation.

An adapter is responsible for:

- launching or attaching to the upstream runtime when applicable
- translating Pocket Relay configuration into upstream transport/session calls
- mapping upstream events into Pocket Relay runtime state
- advertising the capabilities that upstream host actually supports

An adapter is not:

- a UI theme
- a local cache of historical transcripts
- a cosmetic alias for Codex
- permission to pretend all hosts expose the same transport or lifecycle model

### Host vs agent adapter

`host` is still a useful informal term for the upstream system, but the app
surface should standardize on `agent adapter` as the product-owned boundary.

That distinction matters because a host may expose:

- a local CLI
- a local app-server
- a remote bridge service
- a WebSocket session transport
- some combination of the above

Pocket Relay owns the adapter boundary. It does not own the upstream host.

## What Changed In This Pass

### First-class adapter identity in saved state

Connection and workspace state now persist adapter identity and adapter command
instead of only a Codex path:

- `lib/src/core/models/connection_models_host.dart`
- `lib/src/core/models/connection_models_profile.dart`
- `lib/src/core/models/connection_models_workspace.dart`
- `lib/src/features/connection_settings/domain/connection_settings_draft.dart`

Key changes:

- `AgentAdapterKind` is now the top-level enum.
- `agentAdapter` and `agentCommand` are the real persisted fields.
- legacy `hostKind`, `hostCommand`, and `codexPath` compatibility remains in
  constructors, getters, and JSON so existing data still loads cleanly.

This is the correct ownership model. Adapter choice belongs in app-owned saved
connection state, not inside Codex-only transport code.

### App-owned adapter seams now exist

Pocket Relay now has explicit app-owned adapter interfaces:

- `lib/src/features/chat/transport/agent_adapter/agent_adapter_client.dart`
- `lib/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart`
- `lib/src/agent_adapters/agent_adapter_registry.dart`

Current roles:

- `AgentAdapterClient`
  - runtime transport/session boundary used by lane and workspace code
- `AgentAdapterRuntimeEventMapper`
  - adapter-owned mapping from upstream events into Pocket Relay transcript
    events
- `agent_adapter_registry.dart`
  - central factory/registry for adapter definitions, default commands, labels,
    runtime mappers, and default client creation

Compatibility shims still exist so old `host adapter` imports do not break:

- `lib/src/features/chat/transport/host/host_adapter_client.dart`
- `lib/src/features/chat/runtime/application/host_adapter_runtime_event_mapper.dart`

### Top-level app and lane boundaries are now adapter-named

Generic app-owned boundaries now accept `agentAdapterClient`, with deprecated
compatibility for the old `appServerClient` name:

- `lib/src/app/pocket_relay_app.dart`
- `lib/src/app/pocket_relay_dependencies.dart`
- `lib/src/features/chat/lane/presentation/connection_lane_binding.dart`
- `lib/src/features/chat/lane/application/chat_session_controller.dart`

This matters because `app-server` is a Codex transport detail, not a valid
cross-host abstraction.

### Conversation history ownership moved to a generic file path

Conversation-history loading now lives on a generic app-owned path:

- `lib/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart`

The old Codex-named path remains as a compatibility re-export:

- `lib/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart`

This is an important downstream-cost reduction. Generic app seams should not
continue to live under Codex-named file ownership when their job is to support
multiple adapters.

## Current Architecture

### Stable app-owned adapter layer

The architecture is now split like this:

1. persisted connection/workspace state
   - `AgentAdapterKind`
   - `agentAdapter`
   - `agentCommand`
2. adapter registry
   - label
   - default command
   - client factory
   - runtime mapper factory
3. lane/runtime consumers
   - `ConnectionLaneBinding`
   - `ChatSessionController`
   - workspace conversation-history loading
4. provider-specific implementation
   - current Codex transport/runtime stack

This is materially better than the previous state, where Codex was the assumed
transport shape and the app surface treated that assumption as product truth.

### Current registry shape

Today the registry defines one adapter:

- `AgentAdapterKind.codex`

Registry responsibilities currently include:

- `agentAdapterDefinitionFor`
- `agentAdapterCapabilitiesFor`
- `createAgentAdapterRuntimeEventMapper`
- `createDefaultAgentAdapterClient`
- `agentAdapterLabel`
- `localConnectionLabelForAgentAdapter`
- `defaultCommandForAgentAdapter`

That is the correct app-owned location for host-specific branching.

Registry definitions now also declare `AgentAdapterCapabilities`, so shared
surfaces can gate behavior from explicit capability data instead of silently
assuming that every future adapter exposes the full Codex feature set.

Current shared consumers of capability metadata include:

- connection-settings model refresh and run-mode toggles
- branch-conversation and continue-from-here affordances
- image-attachment availability
- workspace conversation-history discovery affordances

### Current settings and profile surface

Connection settings now treat the adapter as a first-class concept:

- section title: `Agent adapter`
- field label: `Agent command`

Relevant files:

- `lib/src/features/connection_settings/application/presenter/section_host.dart`
- `lib/src/features/connection_settings/application/connection_settings_presenter.dart`
- `lib/src/features/connection_settings/domain/connection_settings_contract.dart`

This is deliberately conservative. The UI is not yet pretending there are
multiple selectable adapters because only `codex` exists today, but the state
ownership no longer blocks that future.

### Shared test harnesses

Shared test infrastructure now also uses agent-adapter seams instead of
requiring Codex concrete types at the harness boundary.

Relevant files:

- `lib/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart`
- `test/support/builders/app_test_harness.dart`
- `test/features/chat/lane/presentation/root_adapter_test_support.dart`
- `test/features/chat/lane/integration/screen_app_server_test_support.dart`

The current generic fake still reuses the Codex app-server fake underneath, but
future adapter tests can plug into the shared app and lane harnesses through
`AgentAdapterClient` without first widening those harness contracts.

The transport/client boundary is now also app-owned:

- `lib/src/features/chat/transport/agent_adapter/agent_adapter_models.dart`
  - app-owned transport DTOs for adapter events, sessions, threads, turns, and
    model metadata
- `lib/src/features/chat/transport/agent_adapter/agent_adapter_client.dart`
  - now uses `AgentAdapter*` DTOs instead of `CodexAppServer*` DTOs
- `lib/src/features/chat/transport/app_server/codex_app_server_agent_adapter_bridge.dart`
  - isolates Codex-only turn-input and elicitation translation inside the
    Codex adapter implementation

## What Is Still Codex-Specific

This still did not remove all Codex assumptions. The transport/client boundary
is now app-owned, but several deeper seams remain structurally Codex-shaped.

### 1. Runtime event mapping now feeds a transcript-owned runtime domain

`AgentAdapterRuntimeEventMapper` now maps:

- `AgentAdapterEvent -> List<AgentAdapterRuntimeEvent>`

Files:

- `lib/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart`
- `lib/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart`
- `lib/src/features/chat/runtime/application/runtime_event_mapper.dart`
- `lib/src/features/chat/runtime/application/agent_adapter_runtime_event_bridge.dart`

This layer is now app-owned end to end. The bridge resolves
`AgentAdapterRuntimeEvent` values into `TranscriptRuntimeEvent`, and the shared
transcript reducer no longer depends on Codex-named runtime types.

### 2. Transcript and session domain are now app-owned

The transcript/session backbone is now named and structured around generic
app-owned transcript types:

- `TranscriptRuntimeEvent`
- `TranscriptSessionState`
- `TranscriptUiBlock`

Representative files:

- `lib/src/features/chat/transcript/domain/transcript_runtime_event.dart`
- `lib/src/features/chat/transcript/domain/transcript_session_state.dart`
- `lib/src/features/chat/transcript/domain/transcript_ui_block.dart`

This is the structural change that stops adapter B from having to impersonate a
Codex-shaped reducer or session model. Codex-specific logic still exists in the
Codex mapper and history normalizer, which is correct, but the shared state
backbone is no longer Codex-owned.

### 3. Model and reasoning selection are now split between app-owned and adapter-owned layers

The shared app layer now owns:

- `AgentAdapterReasoningEffort`
- generic model-catalog selection helpers such as
  `normalizedReasoningEffortForModel`
- app-owned `ConnectionModelCatalog` data shapes

The Codex adapter still owns:

- the Codex reference snapshot in `connection_models_codex_models.dart`
- the Codex-backed registry catalog returned by
  `referenceModelCatalogForAgentAdapter(AgentAdapterKind.codex, ...)`

Files:

- `lib/src/core/models/connection_models.dart`
- `lib/src/core/models/connection_models_model_catalog.dart`
- `lib/src/core/models/connection_models_model_selection.dart`
- `lib/src/core/models/connection_models_codex_models.dart`
- `lib/src/agent_adapters/agent_adapter_registry.dart`

This is the right ownership split for now: shared model settings no longer
depend on Codex helpers directly, but Codex still remains the only concrete
adapter catalog implementation.

### 4. Remote runtime probing now has an adapter seam, but only Codex implements it

Pocket Relay’s remote continuity path now resolves an
`AgentAdapterRemoteRuntimeDelegate` by adapter kind instead of wiring Codex SSH
types directly into the shared settings/controller layer.

The shared layer now owns:

- `AgentAdapterRemoteRuntimeDelegate`
- adapter-driven remote runtime delegate factories
- generic host capability issues such as `agentCommandMissing`

Codex still owns the only concrete implementation:

- `codex_agent_adapter_remote_runtime_delegate.dart`
- `codex_app_server_remote_owner.dart`
- `codex_app_server_remote_owner_ssh.dart`

Relevant files:

- `lib/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart`
- `lib/src/agent_adapters/codex_agent_adapter_remote_runtime_delegate.dart`
- `lib/src/agent_adapters/agent_adapter_registry.dart`
- `lib/src/features/connection_settings/application/connection_settings_remote_runtime_probe.dart`
- `lib/src/features/workspace/application/connection_workspace_controller.dart`
- `lib/src/core/models/connection_models_remote_runtime.dart`

That is the correct midpoint: the shared app no longer assumes Codex SSH probe
types, but Claude will still need its own delegate implementation.

### 5. Workspace conversation history is now app-owned at the summary layer

Workspace conversation-history loading now returns the app-owned
`WorkspaceConversationSummary` model instead of a Codex-named summary type.

The shared layer now owns:

- `WorkspaceConversationSummary`
- `WorkspaceConversationHistoryRepository`
- `WorkspaceConversationHistoryUnpinnedHostKeyException`

Relevant files:

- `lib/src/features/workspace/domain/workspace_conversation_summary.dart`
- `lib/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart`
- `lib/src/features/workspace/presentation/workspace_conversation_history_sheet.dart`

Deprecated Codex aliases still exist only as compatibility shims while tests
and downstream code finish migrating.

## Upstream Reality: Codex

The local reference snapshot shows that Codex exposes an explicit app-server
surface, not just an internal implementation detail.

### Evidence

Codex CLI supports an `app-server` command and remote app-server connection
options:

- `.reference/codex/codex-rs/cli/src/main.rs`

The Python SDK explicitly starts `codex app-server --listen stdio://` and
describes itself as a typed JSON-RPC client for that process:

- `.reference/codex/sdk/python/src/codex_app_server/client.py`

The protocol crate defines stable request and notification method names:

- `.reference/codex/codex-rs/app-server-protocol/src/protocol/common.rs`

### Observed Codex method surface

From the reference snapshot, Codex exposes at least these app-server methods:

- `thread/start`
- `thread/resume`
- `thread/fork`
- `thread/rollback`
- `thread/list`
- `thread/read`
- `thread/archive`
- `thread/unarchive`
- `thread/name/set`
- `thread/compact/start`
- `turn/start`
- `turn/steer`
- `turn/interrupt`

And at least these notifications:

- `thread/started`
- `thread/status/changed`
- `turn/started`
- `turn/completed`
- `turn/diff/updated`
- `turn/plan/updated`
- `item/started`
- `item/completed`
- `item/agentMessage/delta`

### What that means for Pocket Relay

Codex gives Pocket Relay a strong upstream contract for:

- session/thread lifecycle
- historical discovery
- model listing
- live turn streaming
- plan/diff incremental updates
- approval and elicitation request flows
- local launch over stdio
- remote attach over websocket-backed app-server flows

That is why Codex was able to become the first working integration.

## Upstream Reality: Claude Code

The Claude Code reference snapshot does not show an equivalent public local
`app-server` surface.

Instead, it shows hidden CLI flags and remote session infrastructure oriented
around Anthropic-hosted session APIs and bridge environments.

### Evidence

Hidden CLI flags:

- `.reference/claude-code-main/src/main.tsx`
  - `--remote`
  - `--remote-control`
  - `--teleport`

Remote session manager and session websocket:

- `.reference/claude-code-main/src/remote/RemoteSessionManager.ts`
- `.reference/claude-code-main/src/remote/SessionsWebSocket.ts`

The websocket implementation explicitly documents a session subscription path:

- `/v1/sessions/ws/{sessionId}/subscribe`

Bridge and session APIs:

- `.reference/claude-code-main/src/bridge/bridgeApi.ts`
- `.reference/claude-code-main/src/bridge/createSession.ts`
- `.reference/claude-code-main/src/utils/teleport/api.ts`

Observed API families:

- `POST /v1/environments/bridge`
- `DELETE /v1/environments/bridge/{environmentId}`
- `POST /v1/sessions`
- `GET /v1/sessions/{id}`
- `PATCH /v1/sessions/{id}`
- `POST /v1/sessions/{id}/archive`
- `POST /v1/sessions/{id}/events`
- `GET /v1/sessions`

### What that means

Claude Code appears to be built around:

- remote session creation/resume
- Anthropic-hosted session/event APIs
- bridge environment setup/teardown
- WebSocket subscription to hosted sessions
- CLI modes that attach to that backend model

What the reference snapshot does not show is a Codex-style public local app
server that Pocket Relay can simply launch with a stable stdio JSON-RPC
contract.

## Codex vs Claude: Practical Difference Matrix

| Dimension | Codex | Claude Code | Adapter implication |
| --- | --- | --- | --- |
| Local standalone process boundary | Explicit `codex app-server` | Not evident in reference snapshot | Do not assume every adapter can be locally launched the same way |
| Public typed client contract | Present in Python SDK and protocol crate | Not evident as an equivalent local app-server SDK | Adapter contract cannot be “Codex client but renamed” |
| Session/thread lifecycle surface | Explicit thread/turn RPC methods | Session-centric hosted API plus bridge/session events | Need provider-neutral app lifecycle concepts |
| Historical conversation discovery | `thread/list` and `thread/read` | Appears session/event API driven | History loading must be capability-driven |
| Live event streaming | App-server notifications | WebSocket session subscription | Transport abstraction must not assume JSON-RPC notifications only |
| Remote runtime assumptions | SSH, workspace, tmux, Codex binary, app-server | Bridge environment plus hosted sessions | Remote diagnostics must remain adapter-specific |
| Local command field | Works as adapter command today | May not be sufficient or may mean something else later | Future adapter settings may need adapter-specific config blocks |

## How Pocket Relay Should Adapt

Pocket Relay should not force all future adapters into the exact Codex shape.
It should instead define a stable app-owned contract at the level the UI and
lane runtime actually need.

### Stable app-owned concepts

These are the concepts Pocket Relay really cares about:

- adapter identity
- connection mode
- workspace identity
- historical conversation discovery
- resume/reattach semantics
- live turn lifecycle
- approvals and elicitation
- changed files / plan / terminal / worklog capabilities
- model catalog capability
- interruption capability
- fork/rollback capability

Those concepts should be generic regardless of whether the underlying host
implements them using:

- JSON-RPC
- WebSocket frames
- HTTP polling
- hosted session events
- local subprocess IO

### What the UI must not assume

The UI must not treat these as universal truths:

- every adapter has a local binary command
- every adapter supports `thread/list`
- every adapter exposes a model catalog
- every adapter supports rollback
- every adapter supports forking
- every adapter exposes the same approval and elicitation semantics
- every adapter can reconnect using the same remote continuity checks
- every adapter uses a thread/turn vocabulary

Any UI surface that assumes those things should be gated by adapter
capabilities, not by global app truth.

## Recommended Next Refactor Slices

These are ordered by downstream cost reduction, not by the smallest diff.

### 1. Rename the transcript runtime domain away from Codex ownership

Eventually these domains should become app-owned and provider-neutral:

- `CodexRuntimeEvent`
- `CodexSessionState`
- `CodexUiBlock`

This should not be a cosmetic rename. It should happen together with a generic
runtime event contract so the ownership is actually true.

### 2. Extend adapter-owned model metadata beyond the Codex reference snapshot

The shared selection logic is now app-owned, and the reference catalog lookup
is routed through the adapter registry.

The next follow-up is not another rename. It is teaching the adapter layer to
own richer per-host model metadata, so a future Claude adapter can:

- expose different model fields
- expose different reasoning controls
- expose no reasoning control at all

### 3. Split remote runtime diagnostics by adapter

Codex continuity checks are built around:

- SSH
- tmux
- workspace path
- Codex binary presence
- app-server availability

A Claude adapter is unlikely to share that exact runtime contract. The app
should keep remote runtime probing adapter-specific and present only adapter-
relevant diagnostics.

## Recommended Adapter Contract Shape

The long-term shape should look more like this:

1. `AgentAdapterDefinition`
   - identity
   - labels
   - capabilities
   - settings schema hooks
2. `AgentAdapterClient`
   - generic conversation/session lifecycle methods
   - generic event stream
3. `AgentAdapterRuntimeMapper`
   - generic upstream event to generic app transcript/event projection
4. adapter-specific transport package
   - Codex app-server implementation
   - future Claude session/bridge implementation

The key rule is:

Pocket Relay app-owned code should depend on generic adapter contracts.
Codex-specific transport files should depend on Codex contracts.
Not the other way around.

## Bottom Line

This second pass accomplished the important structural foundation:

- adapter identity is now first-class in persisted app state
- app-owned adapter seams now exist
- top-level app and lane boundaries are no longer forced to speak only in
  Codex app-server terms
- generic conversation-history ownership has been moved onto a generic file path

But the app is not fully provider-neutral yet.

The main remaining truth is simple:

- Pocket Relay now has an `agent adapter` foundation
- Pocket Relay now has a provider-neutral transport/client contract
- Pocket Relay now has a provider-neutral runtime mapper contract
- Pocket Relay does not yet have a provider-neutral transcript/session domain
- adding Claude will still require real adapter work until the remaining
  `CodexRuntimeEvent*`, `CodexSessionState*`, and Codex-shaped model/runtime
  assumptions are lifted

That is acceptable as long as we describe it honestly and continue the next
refactor slices in the right ownership order.
