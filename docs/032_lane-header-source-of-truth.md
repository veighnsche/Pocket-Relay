# Lane Header Source Of Truth

The lane header has two different ownership domains and they must stay
separate.

## Title

- Source of truth: `ConnectionProfile.label`
- Fallback when blank: `Codex`

The title is lane identity, not runtime metadata.

Do not derive the title from:

- workspace path
- Codex `cwd`
- app name
- model name

## Subtitle

- Source of truth for connection descriptor:
  - remote lane: `ConnectionProfile.host`
  - local lane: `local Codex`
- Source of truth for live runtime metadata:
  - Codex session metadata captured from app-server session start/resume
  - Codex turn metadata captured from live `turn/started` events

The subtitle is additive:

- preserve the existing connection descriptor
- append live Codex model and reasoning effort when available

Examples:

- `devbox.local`
- `devbox.local - gpt-5.4`
- `devbox.local - gpt-5.4 - high effort`
- `local Codex - gpt-5.4-mini`

## Boundaries

- `ConnectionProfile` owns lane identity
- live Codex runtime state owns model and effort
- the presenter should not hand-build header strings
- header formatting belongs in a dedicated projector so changes do not churn
  unrelated screen presentation logic

## Non-goals

- Pocket Relay should not invent alternate lane titles from workspace basename
- saved profile model or effort should not be treated as the displayed runtime
  truth
