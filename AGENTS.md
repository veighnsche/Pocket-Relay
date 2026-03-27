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
- If the user names a specific sub-surface such as a drawer body, modal
  contents, row layout, header, footer, or interaction, scope the work to that
  sub-surface unless they explicitly authorize broader redesign.
- A request to change one part of a surface is not permission to restyle its
  surrounding chrome, parent container, sibling widgets, or adjacent flows.
- If the requested target is narrower than the currently convenient edit
  boundary, keep the implementation narrow anyway. Do not widen scope to match
  the easiest refactor.
- Before editing UI, restate in concrete terms what is allowed to change and
  what must remain untouched whenever there is any risk of collateral redesign.

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

## 4A. Active turn continuity is a hard product constraint

- The primary value of Pocket Relay is preserving a live Codex turn and stream
  while the user is actively using the app.
- Do not disconnect, dispose, rebuild, reconnect, or mark a live lane stale on
  ordinary app switching, short backgrounding, or routine
  `inactive`/`hidden`/`paused`/`resumed` transitions just because the app left
  the foreground.
- Background-kill recovery and cold-start restoration are not permission to
  degrade the normal live-turn path. Those flows must be designed separately.
- Never trade active-turn continuity for speculative lifecycle safety. If
  transport loss, process death, or session invalidation has not been
  confirmed, preserve the live lane.
- If a proposed change can sever SSH, stop a stream, drop an active turn, or
  rebuild the lane during ordinary app switching, stop and get explicit user
  approval before implementing it.
- A recovery feature that protects against an occasional background kill by
  breaking the normal active-turn experience is a product regression, not a
  safety improvement.

## 4B. Active work-surface real estate is a hard product constraint

- While a lane or other primary work surface is active, prioritize transcript,
  editor, and composer space over lifecycle chrome.
- Do not pin secondary, destructive, or low-frequency actions into always-
  visible headers, strips, footers, or other persistent chrome on an active
  work surface.
- If an action is not required for the user to continue the task they are
  actively performing, it belongs in overflow, a menu, a sheet, or another
  contextual affordance instead of persistent chrome.
- Disabled secondary actions must not remain visible on active work surfaces
  just for discoverability, consistency, or reassurance.
- Extra visibility alone is not a valid reason to promote connection lifecycle
  actions such as disconnect, close lane, restart, or similar controls into
  persistent chrome.
- Promote lifecycle actions only when the current runtime state makes them the
  primary next step, such as disconnected, recovery-required, setup, or
  explicit destructive confirmation states.
- Tests must verify that secondary actions remain accessible without locking the
  product into always-visible placement on active work surfaces unless the user
  explicitly asked for persistent controls.

## 4C. The agent is a bad judge of what deserves permanent visibility

- Do not trust the agent's instinct about what is "important for the user to
  see" without explicit product evidence.
- The agent consistently overvalues orientation copy, helper text, onboarding
  prose, explanatory paragraphs, and secondary controls, and undervalues live
  working space. Treat that bias as a known failure mode.
- When choosing between more explanation and more room for the user's actual
  task, default to more room for the task.
- If text is not required for the user's next action, do not pin it into fixed
  headers, fixed footers, persistent sheets, or other always-visible chrome.
- Users do not read large paragraphs just because they are visible. Visibility
  alone does not make copy useful.
- Do not promote descriptive or instructional text into permanent space to make
  the UI feel "clearer" or "more guided". If the form, flow, or control labels
  are not clear enough without a paragraph, fix the ownership and structure of
  the form instead.
- On configuration surfaces, prefer concise labels, field-level helper text,
  progressive disclosure, and contextual affordances over persistent
  explanatory blocks.
- Before adding any permanently visible copy, ask what user action it unlocks
  right now, what would break if it were absent, and why that benefit is worth
  the fixed space cost. If those answers are weak, the copy does not belong.

## 5. No speculative product surface area

- Do not invent product states, labels, summaries, UX categories, or review
  artifacts because they seem useful.
- A widget configuration is not automatically a real end-user state.
- Widget capability is not product truth.
- Fixtures must represent real runtime/app situations, not internal dev
  narratives or design-review theater.
- If the reference is incomplete, stay literal and conservative. Do not fill
  gaps with speculation.
- Do not add visual polish, chrome, hierarchy changes, spacing passes, card
  redesigns, or information panels unless they are part of the requested
  behavior.
- Do not convert a targeted bug fix or scoped UI request into a general
  redesign of the broader feature surface.

## 6. Widgetbook is downstream only

- `lib/widgetbook/` is preview infrastructure, not a shadow component library,
  not a shadow design system, and not a shadow product spec.
- Widgetbook may register, frame, and preview real app-owned surfaces.
- Widgetbook must not own fake boards, scenes, wrappers, pseudo-components, or
  product structure the app itself does not own.
- If something would still need to exist without Widgetbook, it belongs in
  `lib/src/...`, not `lib/widgetbook/...`.
- Do not add review chrome that changes what is being reviewed.
- Every story must import and render a real app-owned widget.
- No visual component may be defined inside Widgetbook.
- No duplicated styling or structure is allowed inside stories.
- No Storybook/Widgetbook-only replacement such as `FakeCard`, local JSX-like
  markup clones, or preview-owned visual widgets.
- If a real component cannot render in Widgetbook, refactor the real component
  or add app-owned seams. Never fake the surface locally in Widgetbook.
- Stories are thin shells only: args, mock data, decorators, providers, and
  composition of real app-owned widgets.
- Stories must not own UI behavior, reimplement visuals, or patch missing
  product features locally.
- If a story hits friction, stop and report the blocker plainly instead of
  silently bypassing it.
- Before finishing Widgetbook work, verify all of the following:
  - every story imports a real component
  - zero Widgetbook-defined visual components remain
  - zero duplicated styling remains
  - deleting Widgetbook would not change app UI
  - changing the app component would change Widgetbook

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
- If implementation work starts drifting into unrelated surface changes, stop,
  revert the widened plan mentally, and return to the smallest boundary that
  satisfies the request.
- If an agent has changed surrounding UI without explicit approval while the
  requested sub-surface is still materially unchanged, that work is wrong work
  and must not be defended as progress.

## 11. Communication

- Be direct about tradeoffs, uncertainty, and mistakes.
- If a shortcut caused churn, say so directly and correct it.
- Do not defend a bad tradeoff after the problem is clear.
- Do not claim something is implemented if it is only approximated.
- If the agent intends to change anything outside the user-named target, it
  must say so before editing and explain why that broader scope is necessary.
- If the agent cannot improve the requested target without broader redesign, it
  must stop and ask instead of silently redesigning the easier surrounding
  surface.

## 12. Definition of done

- The implementation matches the requested behavior.
- The ownership model is coherent.
- The solution reduces future churn instead of deferring it.
- The verification matches the risk.
- The final explanation accurately describes what is truly implemented.
- For scoped UI requests, done also means the untouched surrounding surfaces are
  still materially the same unless the user explicitly asked for broader visual
  change.

## 13. Docs naming

- Files under `docs/` must use a three-digit chronological prefix followed by
  `_`.
- Assign the next available number when adding a new doc unless the user
  explicitly asks for renumbering.
- Preserve prefixed filenames in links and references.

## 14. Codex history is upstream truth

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

## 15. No Card Regression

- If the user says to avoid card design, boxed design, panel design, framed
  design, or similar containerized UI treatment, that is a hard visual
  constraint, not a stylistic preference.
- Do not introduce or reintroduce cards, card-like wrappers, panel shells,
  tinted boxes, framed sections, review containers, or pseudo-card surfaces
  unless the user explicitly asks for them.
- Existing card patterns elsewhere in the app are not permission to spread card
  styling to new or modified surfaces.
- A wrapper added "just for spacing", "just for hierarchy", "just for
  readability", or "temporarily" still counts as a card regression if it
  materially recreates the deprecated boxed treatment.
- For scoped UI work, preserving the existing non-card visual language is part
  of correctness. Reintroducing card chrome is a bug even if the underlying
  behavior is correct.
- Do not solve layout ambiguity by adding another container. First try to
  express the change within the existing visual structure.
- If a design system or prior user direction removed card treatments from a
  surface, future edits must preserve that removal unless the user explicitly
  reverses it.
- Before any UI edit on an existing surface, state in concrete terms which
  visual patterns must remain absent, including card/panel/boxed treatments
  whenever relevant.
