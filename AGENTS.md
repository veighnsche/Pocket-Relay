# AGENTS.md

Repo rules for future agents.

## 1. Optimize for downstream cost, not local speed

- Do not optimize for the fastest local implementation if it increases future
  unwind cost.
- The correct optimization target is reducing downstream churn, rework, token
  waste, time waste, and cleanup cost.
- A quick patch that creates future deletion or migration work is a bad patch.
- If the correct implementation is larger, do that work first instead of
  externalizing the cost into later turns.

## 2. Requirements are contracts

- Treat user requirements as product constraints, not suggestions.
- Do not satisfy a semantic requirement with a cosmetic imitation.
- If the user asks for standalone, generic, minimal, or independent behavior,
  make that true in structure and ownership.
- If there are multiple plausible interpretations, stop and state the
  ambiguity before building the wrong one.

## 3. Ownership is the first design decision

- Put behavior where it actually belongs.
- If something is a real app surface, reusable primitive, runtime mapping, or
  product state, it belongs in app-owned code under `lib/src/...`.
- Do not place real product or presentation logic in preview code, test-only
  glue, or the nearest convenient widget.
- Do not optimize for small diffs when the request requires a new ownership
  boundary.

## 4. Pocket Relay does not own the backend

- Pocket Relay is a frontend over a backend/protocol we do not control.
- Frontend code must adapt to backend reality, not invent alternate product
  states.
- For backend-owned flows, work in this order:
  1. reference behavior
  2. backend/app-server contract
  3. Pocket Relay runtime mapping
  4. Flutter presentation
- If a state, label, or flow is not traceable to backend reality, runtime
  state, existing app behavior, or an approved doc, it must not appear as
  product truth.

## 5. No speculative product surface area

- Do not invent product states, labels, summaries, UX categories, or review
  artifacts because they seem useful.
- A widget configuration is not automatically a real end-user state.
- Widget capability is not product truth.
- Fixtures must represent real runtime/app situations, not internal dev
  narratives or design-review theater.
- If the reference is incomplete, stay literal and conservative. Do not fill
  gaps with speculation.

## 6. Widgetbook is downstream only

- `lib/widgetbook/` is preview infrastructure, not a shadow component library,
  not a shadow design system, and not a shadow product spec.
- Widgetbook may register, frame, and preview real app-owned surfaces.
- Widgetbook must not own fake boards, scenes, wrappers, pseudo-components, or
  product structure the app itself does not own.
- If something would still need to exist without Widgetbook, it belongs in
  `lib/src/...`, not `lib/widgetbook/...`.
- Do not add review chrome that changes what is being reviewed.

## 7. Use literal naming

- Story names, fixture names, docs, and labels must describe literal runtime
  states unless an interpretation has been explicitly approved.
- Do not rename real states into cleaner or more “designed” sounding names.
- Do not invent labels like `Settled Summary`, `Collapsed Draft`, or similar
  implied product states.

## 8. Show the real end-user surface

- Do not show component abstractions when the real need is an end-user page,
  end-user flow, or backend-driven runtime state.
- Do not wrap real surfaces in extra demo chrome that alters padding,
  hierarchy, density, or behavior.
- If the user asks for consolidated pages, build consolidated pages from real
  app-owned widgets and real runtime states.

## 9. Verify the real behavior

- Add tests that prove ownership, lifecycle, placement, and update behavior,
  not only text presence.
- Verify runtime paths for stateful or streamed behavior; do not rely only on
  static inspection.
- Use the smallest test scope that proves the requirement, then run broader
  verification when shared infrastructure changed.
- Use hot reload only for local rendering changes. Use hot restart or a fresh
  run when startup wiring, runtime state, reducers, controllers, or lifecycle
  changed.

## 10. Cut wrong work early

- If speculative churn is discovered, stop expanding immediately.
- Do a keep/move/delete audit before any new feature work.
- Delete the wrong layer instead of renaming or cosmetically justifying it.
- Do not layer new work on top of a speculative foundation to avoid admitting
  churn.

## 11. Communication

- Be direct about tradeoffs, uncertainty, and mistakes.
- If a shortcut caused churn, say so directly and correct it.
- Do not defend a bad tradeoff after the problem is clear.
- Do not claim something is implemented if it is only approximated.

## 12. Definition of done

- The implementation matches the requested behavior.
- The ownership model is coherent.
- The solution reduces future churn instead of deferring it.
- The verification matches the risk.
- The final explanation accurately describes what is truly implemented.

## 13. Docs naming

- Files under `docs/` must use a three-digit chronological prefix followed by
  `_`.
- Assign the next available number when adding a new doc unless the user
  explicitly asks for renumbering.
- Preserve prefixed filenames in links and references.
