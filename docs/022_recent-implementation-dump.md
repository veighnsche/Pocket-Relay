# Recent Implementation Dump

Date: 2026-03-18

This document is a compact dump of the recent implementation work that landed
after the earlier handoff docs. It is meant to answer one question quickly:
what changed, where does it live now, and what is still open.

## 1. Commit Chronology

Recent commits in order:

- `1ae8e16` `with desktop enter behavior`
- `daba542` `Introduce first-class platform policy`
- `2d2d07f` `moved the stop button`
- `a76fe6c` `Make command work logs first-class`
- `88079ed` `Harden command read work logs`

`docs/020_self-handoff.md` and `docs/021_codebase-handoff.md` were part of
this same run of work and already contain more repo-wide context.

## 2. Platform Policy Refactor

The repo now has a real app-level platform seam instead of a mix of widget-local
checks and helper calls.

Primary files:

- `lib/src/core/platform/pocket_platform_behavior.dart`
- `lib/src/core/platform/pocket_platform_policy.dart`
- `lib/src/app.dart`
- `lib/src/features/chat/presentation/chat_root_adapter.dart`

What changed:

- `PocketPlatformBehavior` became the app-wide product behavior model.
- `PocketPlatformPolicy` became the root object that combines behavior with the
  existing renderer-region policy.
- `app.dart` now resolves that policy once at the root.
- downstream renderers/widgets consume the resolved policy instead of asking the
  platform directly

Behavior now owned centrally:

- `mobile` vs `desktop` experience
- support for local connection mode
- support for wake lock
- desktop keyboard submit behavior

Important boundary:

- Cupertino vs Material is still treated as a visual/foundation decision
- mobile vs desktop is treated as product behavior

That split was deliberate and should be preserved.

## 3. Desktop Composer And Busy-Turn UX

The composer path was changed so the UI behaves like a bidirectional interface
instead of a blocked form.

Primary files:

- `lib/src/features/chat/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/presentation/widgets/chat_composer_surface.dart`
- `lib/src/features/chat/presentation/widgets/chat_screen_shell.dart`
- `lib/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart`

What changed:

- desktop Enter-to-send behavior was introduced and then routed through the new
  platform behavior policy
- the composer no longer swaps into a `Stop` button state
- the text input no longer gets disabled when a turn is running
- `Stop` was moved out of the composer and placed next to the elapsed-time
  badge
- the send button stays a send button

Important limitation:

- the UI is now bidirectional in the sense that the input stays live while a
  turn is active
- the session model is still single-active-turn
- true overlapping sends were not implemented

## 4. Work-Log Investigation Outcome

Before the command work landed, the work-log path had a structural problem:
everything was reduced to generic `CodexWorkLogEntry` rows, so the UI could not
differentiate meaningful command intent from raw execution noise.

The key findings were:

- work-log entries were too generic at the presentation seam
- command rows were dominated by shell-wrapper boilerplate like
  `/usr/bin/zsh -lc`
- command/search/tool activity was still mostly rendered as one generic family
- widget-local cleanup was doing too much presentation shaping

The implemented response was not to regex in the widget. The response was to add
a real work-log presentation seam upstream.

## 5. Command Work Logs Became First-Class

Primary files:

- `lib/src/features/chat/application/transcript_item_block_factory.dart`
- `lib/src/features/chat/application/transcript_item_policy.dart`
- `lib/src/features/chat/presentation/chat_transcript_item_contract.dart`
- `lib/src/features/chat/presentation/chat_transcript_item_projector.dart`
- `lib/src/features/chat/presentation/chat_work_log_contract.dart`
- `lib/src/features/chat/presentation/chat_work_log_item_projector.dart`
- `lib/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart`

What changed:

- shell-wrapper normalization for command titles moved upstream
- `commandExecution` titles now strip wrapper noise before rendering
- a typed work-log presentation model was introduced
- `ChatWorkLogGroupItemContract` now carries projected entry contracts instead
  of exposing raw `CodexWorkLogEntry` rows directly
- the work-log card switches on entry contract type instead of trying to infer
  everything from one generic string

Important ownership rule now in place:

- raw command strings are normalized and classified in the projector layer
- widgets render typed intent contracts
- future command-specific UI should extend the projector/contract layer, not
  attach more string parsing inside `work_log_group_card.dart`

## 6. Command-Specific Read Work Logs

The work-log path now has first-class read-command rows for the most common file
read commands seen in this codebase and in cross-platform shells.

### Implemented command types

Supported specialized entries:

- `sed`
- `nl | sed`
- `cat`
- `type`
- `more`
- `head`
- `tail`
- `awk`
- PowerShell `Get-Content`
- PowerShell `Get-Content | Select-Object`

Each of these gets:

- a dedicated contract subtype
- a dedicated renderer row
- command-aware summary text
- filename
- full path
- consistent hierarchy instead of raw shell syntax

### Implemented semantics

Current summaries:

- `sed`: `Reading line ...` / `Reading lines ... to ...`
- `nl | sed`: `Reading line ...` / `Reading lines ... to ...`
- `cat`: `Reading full file`
- `type`: `Reading full file`
- `more`: `Reading full file`
- `head`: `Reading first N lines`
- `tail`: `Reading last N lines`
- `awk`: `Reading line ...` / `Reading lines ... to ...`
- `Get-Content`: full-file / first-lines / last-lines variants
- `Get-Content | Select-Object`: first-lines / last-lines / line-range variants

### Supported command forms

Supported `sed` forms:

- `sed -n '1,120p' file`
- `sed -ne '1,120p' file`
- `sed -n -e '1,120p' file`
- `nl -ba file | sed -n '1,120p'`
- `nl -b a file | sed -n '1,120p'`
- `nl --body-numbering=a file | sed -n '1,120p'`

Supported `head`/`tail` forms:

- `head file`
- `head -n 40 file`
- `head -n40 file`
- `head -40 file`
- same shape for `tail`

Supported full-file read forms:

- `type file`
- `more file`

Supported `awk` forms:

- `awk 'NR==N {print}' file`
- `awk 'NR==N' file`
- `awk 'NR>=A && NR<=B {print}' file`
- `awk 'NR>=A && NR<=B' file`

Supported `Get-Content` forms:

- `Get-Content file`
- `Get-Content -Path file`
- `Get-Content -LiteralPath file`
- `Get-Content -TotalCount N`
- `Get-Content -Tail N`
- `Get-Content -Raw`
- `Get-Content file | Select-Object -First N`
- `Get-Content file | Select-Object -Last N`
- `Get-Content file | Select-Object -Skip N -First M`

Supported wrapper normalization:

- `/usr/bin/zsh -lc "..."` and similar shell wrappers
- `powershell.exe ... -Command "..."`
- `pwsh ... -c "..."`

Windows path handling:

- `.exe` command names are normalized
- quoted Windows paths keep their backslashes intact

### Fail-closed behavior

When the parser cannot prove a safe read shape, it falls back to the generic
command row.

That fallback applies to:

- chained commands
- unsupported pipes
- redirects
- semicolons
- subshell-ish shell operators
- ambiguous or unsupported flag combinations
- reversed `sed` ranges like `40,1p`
- stdin targets like `-`

This was intentional. The parser should fail closed, not guess.

## 7. Renderer Design Direction

The specialized read rows in `work_log_group_card.dart` are not just recolored
generic rows.

They now carry:

- command label chip
- command-specific accent/icon
- summary line with action semantics
- filename as the main text
- full path as secondary monospace text

This is the beginning of a more semantic work-log surface. The UI is still one
shared card family, but it now exposes real intent for common read operations.

## 8. Verification That Was Run

Platform-policy and composer work had targeted verification when it landed.

The later command/work-log passes were verified with:

- `dart analyze`
- `test/chat_screen_presentation_test.dart`
- `test/codex_ui_block_card_test.dart`
- `test/codex_session_reducer_test.dart`
- targeted `test/chat_screen_app_server_test.dart` work-log cases

Important targeted cases now covered:

- shell-wrapper normalization
- PowerShell-wrapper normalization
- `sed` read projection
- `sed -ne` projection
- reversed `sed` fallback
- `cat` projection
- `head` projection
- compact `head -n40` projection
- `tail` projection
- `Get-Content` projection
- app-server rendering of wrapped `sed`
- app-server rendering of wrapped `Get-Content`

## 9. Known Remaining Gaps

The recent work did not try to solve every work-log problem.

Still open:

- true multi-send / overlapping turn semantics are still not implemented
- work-log grouping is still mostly adjacency-based, not semantic-task-based
- only common read commands are specialized so far
- broader `awk` scripts, `less`, and unsupported PowerShell `Select-Object`
  combinations still fall back to the generic row

There is also one unrelated pre-existing test issue worth remembering:

- running the full `test/chat_screen_app_server_test.dart` file still surfaces
  the live turn timer positioning test failure
- that failure predates the final command hardening pass and is outside the
  read-work-log ownership path

## 10. What To Extend Next

If future work continues in this area, the correct extension path is:

1. normalize wrapper noise upstream
2. parse command intent in `chat_work_log_item_projector.dart`
3. introduce a new typed work-log contract only when the UI needs distinct
   semantics
4. render that contract in `work_log_group_card.dart`
5. add projector and widget coverage

Do not move parsing logic back into the widget layer.
