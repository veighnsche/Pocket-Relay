# True Live-Turn Continuity Contract

## Status

This document replaces the ambiguous shorthand "`Release Bar B`" with a
literal requirement name:

- `True Live-Turn Continuity`

Date: 2026-03-23

Related docs:

- [`052_ios_background_ssh_resilience_plan.md`](./052_ios_background_ssh_resilience_plan.md)
- [`060_background_execution_publishability_phased_plan.md`](./060_background_execution_publishability_phased_plan.md)
- [`066_durable_remote_owner_options.md`](./066_durable_remote_owner_options.md)
- [`067_tmux_migration_path_source_investigation.md`](./067_tmux_migration_path_source_investigation.md)
- [`068_tmux_ws_user_path_timeline.md`](./068_tmux_ws_user_path_timeline.md)

## Purpose

Pocket Relay's primary product value is preserving a live Codex turn while the
user moves in and out of the app.

This document defines the stronger continuity requirement in literal product
terms so future implementation work does not drift back into "truthful restore
only" behavior.

## Definition

`True Live-Turn Continuity` means:

- if a Codex turn is actively running on the remote machine
- and the user stops looking at Pocket Relay
- and the remote machine remains alive

then that same remote turn must keep running anyway, and Pocket Relay must
bring the user back into that same still-live work when the user returns.

In plain language:

- the work keeps moving even when the phone app is not in the foreground
- the phone app must not be the owner of the remote turn's lifetime
- reconnecting later must target the same surviving remote owner, not just
  rebuild history from a replacement process

## Hard Prerequisite

For remote Pocket Relay connections, `tmux` is a required host dependency for
true live-turn continuity.

That means:

- a remote host without `tmux` does not satisfy the supported continuity
  contract
- Pocket Relay must treat missing `tmux` as an unmet prerequisite
- Pocket Relay must not silently downgrade that host into a weaker continuity
  variant

This does not remove truthful restore after real external failures.

It only removes the idea that "remote continuity without `tmux`" is still a
supported product mode.

## Chosen Lifecycle Framing

The remote continuity path also has an explicit ownership rule now:

- the remote app-server lifecycle is user-owned
- the user explicitly starts and stops the remote server
- Pocket Relay may discover and reconnect to an already-running server
- Pocket Relay must not interpret ordinary disconnect, backgrounding, or
  reconnect as permission to stop or silently replace that server

This matters because true continuity is not only "can a process survive?"

It is also:

- who decides when that process should exist at all
- whether reconnect attaches to the same deliberate server or silently creates a
  new one

## What Counts As Success

The contract is satisfied only if all of the following are true.

### 1. Ordinary phone-side interruptions do not stop the remote turn

These cases are in scope:

- the user locks the screen
- the user switches to another app
- the user opens the app switcher
- the user replies to a message, takes a call, or uses another foreground app
- iOS backgrounds Pocket Relay during routine use

In these cases:

- Pocket Relay must not intentionally sever the live lane
- the remote turn must keep running if the remote machine is still alive

### 2. The remote owner survives loss of the phone-owned foreground session

If the original phone-driven connection disappears:

- the remote Codex owner must still exist
- the active turn must still belong to that same owner
- Pocket Relay must be able to find that owner again

### 3. Returning later means re-entering the same live work

When the user comes back:

- Pocket Relay restores the selected lane identity
- Pocket Relay reconnects to the same surviving remote owner
- Pocket Relay reattaches to the same selected thread if it still exists
- the user sees the real current live state, not only stale cached state

### 4. Pending turn state remains attached to the same run

If the live turn was waiting on user action while Pocket Relay was away:

- approval requests must still belong to that same thread
- pending input requests must still belong to that same thread
- resolving them must continue the same live turn

### 5. Finished turns remain truthful when the user returns

If the turn finished while the app was away:

- Pocket Relay should reconnect if possible
- if the turn is no longer actively running, the lane must still restore
  truthfully from Codex thread history

This is not a weaker requirement. It is part of continuity:

- live if still live
- truthful finished state if already finished

### 6. Brief post-turn lock and unlock must not immediately degrade the lane

This case is in scope:

- the active turn finishes
- the wake lock and finite background grace may drop because the turn is no
  longer active
- the screen turns off or the user locks the phone shortly afterward
- the user unlocks again after only a few seconds

Expected result:

- if the same Pocket Relay process and lane binding still exist, Pocket Relay
  must preserve the current detailed lane state in memory
- Pocket Relay must not voluntarily rebuild the lane from scratch just because
  the app briefly left the foreground after the turn completed
- a short lock/unlock must not be enough reason by itself to downgrade the lane
  to history-only restore

This matters because the user may still be inspecting the completed turn.

Losing non-message detail after a few seconds of screen-off is not acceptable
if the app did not truly cold-start.

## What Does Not Count As Success

The contract is not satisfied by these weaker outcomes.

### 1. History-only recovery

This is insufficient:

- Pocket Relay restarts later
- launches a new app-server
- reads historical thread content
- shows the prior transcript

Why it fails:

- the same live run was not preserved
- the same live owner was not re-entered
- any in-flight turn continuity was lost

### 2. Cosmetic "still connected" UI without real remote ownership

This is insufficient:

- the UI keeps the lane visible
- but the underlying remote process died
- or the client silently switched to a replacement process

Why it fails:

- continuity is a backend/runtime fact, not a visual illusion

### 3. Continuity only while Pocket Relay remains foregrounded

This is insufficient:

- the turn stays live only while the app is visible
- routine backgrounding breaks the run

Why it fails:

- the user's requirement is specifically about not losing a live turn when the
  user is not looking

### 4. Implicit server lifecycle hidden inside reconnect behavior

This is insufficient:

- Pocket Relay silently starts a new remote server during reconnect
- Pocket Relay silently stops the remote server when the client disconnects
- Pocket Relay silently replaces one server with another and still calls that
  continuity

Why it fails:

- server lifetime is part of product truth
- hidden lifecycle decisions make continuity ambiguous
- reconnect must target the same running server, not a silent replacement

## Allowed Failure Boundary

Continuity is a hard requirement for ordinary phone-side interruptions.

It is not a promise against every external failure. These failures remain
outside Pocket Relay's control:

- the remote computer powers off
- the remote computer crashes
- the remote user kills `tmux`, the app-server, or the shell account
- the network path fails long enough that reconnect cannot be re-established
- the upstream app-server crashes or corrupts its own runtime state

When those failures happen:

- Pocket Relay must be honest about loss of continuity
- Pocket Relay must fall back to the best truthful restore it can perform
- Pocket Relay must not pretend the same live turn survived if it did not

Missing `tmux` is not part of this allowed runtime failure boundary.

It is a host prerequisite failure and must be treated as unsupported setup, not
as an acceptable continuity variant.

## Concrete User Paths Covered By This Contract

### Path 1: User locks the phone during a long turn

Expected result:

- the remote turn keeps running
- the remote owner survives the phone app leaving the foreground
- when the user unlocks later, Pocket Relay reconnects to the same live thread

### Path 2: User opens another app for several minutes

Expected result:

- the long turn continues remotely
- if the phone app process is suspended or killed, continuity is still
  preserved on the remote side
- returning later re-enters the same live run if the remote owner still exists

### Path 3: User backgrounds Pocket Relay while approval is pending

Expected result:

- the approval remains attached to the same running thread
- when the user returns, the same request is still actionable
- approving continues the same live turn

### Path 4: User backgrounds Pocket Relay and the turn finishes before return

Expected result:

- if the live run is already finished by the time the user returns, Pocket
  Relay shows the truthful completed result
- the app must not degrade this into a false "stale lane" state if upstream
  truth can be restored

### Path 5: Turn finished, screen locks briefly, user unlocks again

Expected result:

- Pocket Relay should continue showing the same completed lane if the process
  survived
- completed-turn detail that still exists in memory must remain visible
- Pocket Relay must not throw away that lane and reconstruct it from history
  after only a brief lock/unlock

## Why This Implies Both A Durable Owner And A Reconnectable Transport

These are separate requirements.

### Durable owner

Pocket Relay needs a remote owner that survives loss of the phone-owned launch
context.

Without a durable owner:

- the remote turn may die when the phone session disappears
- there may be nothing left to reconnect to

In the current migration path, `tmux` is the best candidate durable owner.

### Reconnectable transport

Pocket Relay also needs a transport path that a fresh phone app process can use
to talk to that same surviving remote owner.

Without a reconnectable transport:

- the remote owner may still be alive
- but Pocket Relay has no clean way to re-enter the same running app-server

In the current migration path, app-server websocket is the best first
reconnectable transport candidate.

### Live reattach contract

Even if the owner survives and the transport reconnects, Pocket Relay still
needs an explicit way to re-enter the same live thread.

Without live reattach:

- the app may reconnect to the server
- but still only restore history
- which breaks true continuity

In the current upstream contract, `thread/resume` is the strongest basis for
this reattach behavior, while `thread/read` remains the truthful fallback when
the turn is no longer live.

## Current Gap Against This Contract

The current repo is not fully compliant with true live-turn continuity.

### What already aligns

- the app already treats ordinary app switching as a no-regression live-lane
  case in workspace lifecycle logic
- the app already persists lane-level runtime state such as selected thread and
  draft text
- the app already restores truthful thread history from Codex instead of using
  a Pocket Relay-owned transcript archive

### What is still missing

- the remote owner is still too tied to the phone-owned SSH stdio launch path
- the remote server lifecycle is still implicit in the current product surface
- reconnect is still primarily history restore, not real live reattach
- the transport boundary is still process-shaped instead of reconnectable
- remote host capability enforcement for the required `tmux` prerequisite does
  not yet exist
- brief post-turn lock/unlock can still degrade into lane rebuild and detail
  loss too aggressively if reconnect policy treats transport recovery like cold
  lane recreation

## Current Behavior Audit: Delete, Demote, Keep

This section answers a different question than the contract itself:

Which current runtime behaviors should go away, and which should remain but
change role, once true live-turn continuity is implemented?

### Delete Or Replace

These behaviors should no longer remain the continuity path.

#### 1. SSH stdio launch as the durable owner model

Current shape:

- Pocket Relay SSHes into the remote host
- launches `codex app-server --listen stdio://`
- treats that launched stdio process as the app-server connection

Why it must go:

- the phone-owned launch session is too close to process lifetime
- this does not provide a credible durable owner for continuity

What replaces it:

- a user-started remote server owned by `tmux`
- an explicit `Start server` / `Stop server` lifecycle
- a reconnectable transport to that owner-managed app-server

#### 2. History restore as the primary reconnect behavior

Current shape:

- on cold-start recovery or reconnect, Pocket Relay reconnects transport
- then restores the selected conversation via `readThreadWithTurns`

Why it must go:

- this restores truthful history
- it does not re-enter the same still-live running thread as the primary path

What replaces it:

- real live reattach first
- history restore only when continuity is no longer available
- preserve the existing lane binding in memory when only transport was lost and
  the lane still exists locally

#### 3. Waiting until the next outbound prompt to resume the selected thread

Current shape:

- Pocket Relay often does not fully attach the selected thread until the user
  sends the next prompt
- `startSession(resumeThreadId: activeThreadId)` is used from the prompt-send
  path

Why it must go:

- true continuity requires the lane to become live again when the user returns
- re-entry cannot depend on the user sending another prompt first

What replaces it:

- explicit reconnect-time live thread reattach

#### 4. Process-shaped transport as the continuity boundary

Current shape:

- the app-server transport is modeled around spawned process `stdin`, `stdout`,
  and `stderr`

Why it must go:

- a continuity architecture needs a transport that a fresh client process can
  reconnect to
- a launched process pipe is the wrong primary shape for that

What replaces it:

- a transport abstraction where reconnectable transport is a first-class path

#### 5. Treating remote continuity without `tmux` as a supported variant

Current shape:

- remote connections do not yet enforce `tmux` as a host prerequisite

Why it must go:

- true live-turn continuity depends on a durable owner
- for the chosen architecture, `tmux` is that required owner
- allowing remote continuity configuration without `tmux` creates a false
  product state

What replaces it:

- explicit host prerequisite checking
- hard failure when the required `tmux` dependency is missing

#### 6. Implicit remote server start/stop during reconnect

Current shape:

- connect/reconnect logic is allowed to drift into remote owner creation or
  replacement behavior
- disconnect can be mistaken for a server stop signal

Why it must go:

- server lifetime needs explicit ownership
- continuity should mean reconnecting to the same running server
- hidden creation/replacement decisions produce false product states

What replaces it:

- explicit user controls for `Start server`, `Stop server`, and `Restart server`
- deterministic discovery of already-running servers
- reconnect that only attaches to an existing healthy server

### Demote To Fallback Only

These behaviors are still needed, but they stop being the primary continuity
path.

#### 1. Historical transcript restore

Keep this behavior for:

- finished turns
- missing remote owner
- reconnect failure where continuity can no longer be proven

Do not keep it as:

- the default answer to an interrupted live turn

#### 2. Historical restore notices and related restore UI

Keep this behavior for:

- truthful fallback restore states
- unavailable thread history
- failed recovery after continuity loss

Do not keep it as:

- the normal resumed-live-lane experience

### Keep And Preserve

These behaviors are already aligned with the contract and should not be deleted.

#### 1. Do not self-disconnect on ordinary app switching

This is already the correct product direction.

#### 2. Preserve lane-level runtime state such as selected thread and draft

This remains necessary because reconnect still needs:

- selected connection identity
- selected thread identity
- local draft state

#### 3. Keep Codex as the source of historical truth

True continuity does not authorize a Pocket Relay-owned transcript archive.

The fallback path still depends on real upstream thread history.

## Product Invariants

Future implementation work must preserve these invariants.

- ordinary app switching must not voluntarily drop a live lane
- Pocket Relay must not choose lifecycle neatness over active-turn continuity
- ordinary disconnect/backgrounding must not be interpreted as a remote server
  stop signal
- reconnect must not silently replace the remote server and still claim
  continuity
- local persistence must not replace Codex as the source of historical truth
- reconnect must target the same surviving remote owner when continuity is
  still possible
- fallback restore must be honest when continuity is no longer possible

## Implementation Consequences

Any architecture proposed as the continuity solution must satisfy all of these
questions with concrete runtime answers.

### Ownership

- what exact remote thing owns process lifetime?
- how is the running server identified?
- what explicit user actions start, stop, or restart it?
- what runtime states distinguish running, stopped, unhealthy, and
  prerequisite-missing?

### Transport

- how does a new Pocket Relay process reconnect to that same owner?
- how is the transport re-established securely?
- how does the app distinguish a surviving owner from a replacement one?

### Reattach

- how does the app re-enter the selected live thread?
- how are pending approval or input requests restored?
- what is the fallback path if the turn finished or the owner is gone?

If a proposal cannot answer all three categories, it is not a complete
continuity architecture.

## Acceptance Standard

Pocket Relay meets `True Live-Turn Continuity` only if this user story is true:

1. The user explicitly starts the remote server, or one is already intentionally
   running for that connection.
2. The user starts a long Codex turn.
3. The user locks the phone or opens another app.
4. Pocket Relay may be suspended or killed locally.
5. The remote machine stays alive.
6. The same remote turn keeps running.
7. The user comes back later.
8. Pocket Relay reconnects to the same running remote server.
9. Pocket Relay re-enters the same live thread if it is still live.
10. If it already finished, Pocket Relay shows the truthful finished state from
   Codex.

If step 6 or step 9 is false during ordinary phone-side interruption, the
contract is not met.

## Naming Going Forward

Do not use "`Release Bar B`" in future docs unless quoting older discussion.

Use:

- `True Live-Turn Continuity`

If contrast with the weaker requirement is needed, use:

- `Truthful Recovery`

Those names are literal and avoid introducing non-repo shorthand as product
truth.
