# AGENTS.md

This file defines repo-level working rules for future agents. These rules are
not limited to one screen, one feature, or one incident.

## 1. Requirements are contracts

- Treat user requirements as product constraints, not suggestions.
- If the user asks for something to be standalone, separate, generic, minimal,
  or not tied to another surface, make that true in structure, not only in
  appearance.
- Do not satisfy a semantic requirement with a cosmetic imitation.
- If the user gives an example, infer the intended behavior first. Do not apply
  an example literally when the surrounding request makes the intent clear.

## 2. Prefer correct ownership over small diffs

- Do not optimize for the smallest patch when the request requires a new
  ownership boundary.
- If a behavior belongs in state, reducer/application logic, domain models, or
  a dedicated component, put it there instead of attaching it to the nearest
  existing widget or code path.
- Avoid piggybacking unrelated behavior onto an existing host component just
  because it is already on screen.
- A change is not "simpler" if it creates hidden coupling that will have to be
  unwound later.

## 3. No compromise-by-default

- Do not silently choose a partial solution, shortcut, or temporary heuristic.
- If the correct implementation is larger than the quickest patch, say that
  before coding.
- Only ship a compromise when it is explicitly described as a compromise and
  explicitly accepted.
- Never present an approximation as if it fully satisfies the requirement.

## 4. Build generic solutions when the problem is generic

- If the user is asking for a reusable behavior or a general rule, do not solve
  it in a one-off way.
- Prefer first-class models, dedicated seams, and reusable components over
  case-specific branching.
- Do not hardcode behavior into one screen, one card, one event type, or one
  styling path when the requirement obviously applies more broadly.
- Generic should mean broadly applicable and maintainable, not abstract for its
  own sake.

## 5. Scope discipline

- Change what was requested, no less and no more.
- Do not reinterpret a precise request into a broader redesign unless the user
  asked for that redesign.
- Do not leave unrelated cleanup mixed into the same change unless it is
  required to keep the code correct.
- If a request appears small but is structurally significant, explain that
  plainly instead of hiding the complexity behind a shortcut.

## 6. Make dependencies explicit

- Prefer explicit data flow and explicit ownership.
- If a surface depends on another component, that dependency should be real and
  easy to explain.
- If something must exist independently, it must not rely on another unrelated
  component for its lifecycle, rendering, or visibility.
- Avoid "latest eligible thing", "nearest existing thing", or similar implicit
  attachment rules unless they are genuinely part of the product behavior.

## 7. Verify behavior, not just output text

- Add tests that prove placement, ownership, lifecycle, and update behavior,
  not only text presence.
- When moving behavior between layers, add coverage that the old host no longer
  owns it.
- Verify the actual runtime path for stateful or streamed behavior; do not rely
  only on static inspection.
- Use the smallest test scope that proves the requirement, then run broader
  verification when the change affects shared infrastructure.

## 8. State, lifecycle, and runtime changes need the right refresh

- Use hot reload only for local widget rendering changes.
- Use hot restart or a fresh run when state shape, startup behavior, app
  wiring, transport behavior, or session lifecycle changed.
- Do not assume stale in-memory UI proves the code is still wrong.
- Do not assume a reload is sufficient when the change affects reducer or
  controller behavior.

## 9. Communication rules

- Be direct about tradeoffs, risks, and uncertainty.
- If there are two plausible interpretations, stop and state the ambiguity
  before building the wrong one.
- If a shortcut caused churn, say so directly and then correct it.
- Do not defend a bad tradeoff after the problem is clear.

## 10. Definition of done

- The implementation matches the requested behavior, not just a nearby version
  of it.
- The ownership model is coherent.
- The verification matches the risk of the change.
- The final explanation accurately describes what is truly implemented.

## 11. Docs chronology and naming

- Files under `docs/` must use a three-digit chronological prefix followed by
  `_`, for example `000_example-plan.md`.
- The numeric prefix is ordered by document creation chronology, earliest first.
- When adding a new doc to `docs/`, assign the next available number instead of
  inserting it into the middle of the sequence unless the user explicitly asks
  for a full renumbering pass.
- When renaming or referencing docs, preserve and use the prefixed filenames in
  links and cross-document references.

## 12. Codex history is upstream truth

- Pocket Relay must not own a persisted local history or transcript archive.
- Historical conversation discovery must come from Codex, not from app-local
  persistence.
- Historical transcript restoration must come from Codex thread history, not
  from a Pocket Relay-maintained cache.
- Pocket Relay may still own local live session state, live conversation
  descriptors, drafts, and other runtime/UI metadata for the active lane, as
  long as that state does not claim to be authoritative historical truth.
- Do not propose, design, or implement a Pocket Relay-owned local transcript
  history store as the primary solution for cross-device resume or historical
  conversation restoration.
- Local persistence is limited to narrow lane state such as `selectedThreadId`,
  drafts, and other UI/runtime state that does not claim to be the historical
  source of truth.
- If historical conversation content is missing on screen, investigate the real
  upstream `thread/read` payload and the restore mapper first. Do not paper
  over missing upstream history with a local substitute.
