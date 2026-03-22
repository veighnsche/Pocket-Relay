# Memory Pressure Status

## Status

Pocket Relay still has an unresolved memory-pressure problem.

Current observed symptom:

- the app can be suspended or restarted under apparent memory overload

This document records that the issue remains open. It is not a claim that the
exact root cause has already been profiled or isolated.

## What This Means Right Now

- transcript windowing work is still justified, not optional
- iPhone background-resilience work is still justified, not optional
- current behavior must still be treated as vulnerable to memory pressure
- any recent feature work should not be described as having solved app memory
  safety unless it is backed by measurement

## What Is Known

- the repo already has an explicit iPhone background/suspension risk plan in
  [`docs/052_ios_background_ssh_resilience_plan.md`](../docs/052_ios_background_ssh_resilience_plan.md)
- the repo already has an explicit transcript windowing memory plan in
  [`docs/054_transcript_windowing_memory_plan.md`](../docs/054_transcript_windowing_memory_plan.md)
- that planning work does not yet prove the problem is gone

## What Is Not Yet Proven

- whether the latest suspension or restart was caused primarily by transcript
  retention, restore-time allocation spikes, large diff/image surfaces, lane
  retention, or some other object graph
- whether the observed app stop was a pure foreground memory kill, a
  background suspension followed by termination, or another OS-level resource
  event
- whether current mitigations materially changed peak memory on device

## Required Interpretation

Until profiling proves otherwise, treat the memory issue as still active.

Do not mark the app as memory-safe on iPhone.
Do not assume recent transcript work eliminated the restart/suspension risk.

## Next Verification Work

- capture a reproducible scenario for the latest suspend/restart
- profile device memory during long transcript use, restore, and lane switching
- compare before/after memory behavior once transcript windowing lands
- verify whether iOS background-return behavior is failing because of transport
  loss, memory pressure, or both
