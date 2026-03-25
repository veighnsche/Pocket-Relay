# True Live-Turn Continuity Remaining Work Plan

## Status

As of 2026-03-26, `feat/true-live-turn-continuity` no longer has remaining
implementation slices.

The branch has completed:

- Phase 0
- Phase 1
- Phase 2
- Phase 3
- Phase 4
- Phase 5
- Phase 6

This file now serves as the closeout summary for the feature branch rather than
an active execution backlog.

## Completed Outcomes

The branch now has all of the intended architecture outcomes:

- same-process transport recovery preserves an existing live lane instead of
  rebuilding it from history
- remote continuity uses `tmux`-owned websocket servers instead of SSH-launched
  remote stdio ownership
- remote server lifetime is explicit user action:
  - `Start server`
  - `Stop server`
  - `Restart server`
- reconnect uses live `thread/resume` before truthful `thread/read` fallback
- pending approval and input requests replay across live reattach
- remote host capability and owner inspection are real and distinguish:
  - host unsupported
  - host probe failed
  - server not running
  - server unhealthy
  - server running and connectable
- the old remote SSH launch event stack is deleted
- `Saved connections` is the canonical inventory of all saved connections,
  including active/open ones
- saved-inventory edits route correctly by lane state:
  - open rows stage reconnect-required live edits
  - non-live rows update their saved definition immediately
- workspace recovery and lane notices use explicit continuity truth instead of
  the older ambiguous reconnect model

## Remaining Work

There is no remaining architecture or implementation work on this branch for
true live-turn continuity.

What remains before merge or release is normal confirmation work, not product
or ownership redesign:

- run whatever broader repo verification you want as the merge bar
- do a final manual product pass for:
  - saved-connections inventory behavior
  - explicit remote server controls
  - live-lane continuity notices
- finish the normal push / PR / merge flow

If new gaps are discovered later, they should be treated as follow-up bugs or
polish, not as evidence that the continuity architecture is still unresolved.

## Guardrails That Still Apply

Even though implementation is complete, future follow-up work must not
reintroduce the deleted model:

- do not restore remote SSH stdio as a hidden continuity path
- do not auto-start a new server during reconnect
- do not auto-stop a remote server on disconnect or backgrounding
- do not silently replace a missing or unhealthy owner during reconnect
- do not use `thread/read` as the default reconnect answer
- do not make `Saved connections` hide active/open connections again
- do not move connection-owned server truth back into lane-only surfaces
- do not store local transcript history as truth

## References

The canonical supporting docs remain:

- [`069_true_live_turn_continuity_contract.md`](./069_true_live_turn_continuity_contract.md)
- [`070_true_live_turn_continuity_migration_map.md`](./070_true_live_turn_continuity_migration_map.md)
- [`071_tmux_required_execution_plan.md`](./071_tmux_required_execution_plan.md)
- [`072_true_live_turn_continuity_slice_plan.md`](./072_true_live_turn_continuity_slice_plan.md)
- [`074_phase6_cleanup_source_audit.md`](./074_phase6_cleanup_source_audit.md)
