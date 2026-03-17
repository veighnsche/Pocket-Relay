# Bad design decisions

This document records design mistakes that came up during the chat transcript
work, why they initially looked attractive from an implementation or process
perspective, and why they are bad decisions in practice.

The common mistake behind both proposals was optimizing for state ownership and
transport clarity before optimizing for the user's actual reading position on a
phone screen.

## 1. Cards that update in-place, so that the user has to scroll up to see the changes

### Why this initially looked desirable

This idea came from a data-model mindset:

- If there is "one plan for the current turn", updating one plan card in place
  feels structurally clean.
- If there is "one changed-files artifact for the current turn", updating one
  changed-files card in place feels like a good way to avoid duplication.
- In reducer terms, mutating one existing block is simpler to reason about than
  creating repeated blocks for every intermediate event.
- It also looks attractive when trying to avoid transcript spam, because a
  single card appears more disciplined than many event rows.

That reasoning is internally coherent from a state-management perspective, but
it treats the transcript like a mutable dashboard instead of a reading surface.

### Why it is bad

It is bad because the user is usually reading from the bottom of the screen,
near the composer and the latest output. If an earlier card mutates somewhere
above the viewport, the user does not actually receive the update. The state
changed, but the user experience did not.

On mobile this is worse because:

- The screen is short, so content leaves the viewport quickly.
- Returning to an earlier card costs real effort.
- The user has to remember where the relevant card was.
- The user has to re-establish context after scrolling.
- The latest interaction point is at the bottom, so asking the user to scroll
  upward to monitor current progress fights the natural reading flow.

This means in-place mutation creates a hidden-update problem:

- The interface technically contains the newest state.
- The user is not made aware of it where they are currently looking.
- The burden of finding the update is shifted onto the user.

That is the opposite of good chat UX. In a conversational interface, new
important information should arrive where the user's attention already is, not
silently rewrite something outside the viewport.

The core failure is this: "single logical artifact" was treated as more
important than "update visibility". For a transcript-style mobile interface,
visibility is the higher-priority constraint.

## 2. Pinned components, where the component is always visible even when the information is not useful anymore

### Why this initially looked desirable

This idea came from trying to solve the first problem too literally.

The reasoning was:

- If the user should never have to scroll up, keep live progress visible at all
  times.
- If plans and file changes are important, pin them near the composer.
- If the current turn has active state, a persistent live region seems like a
  reliable place to put it.

From a control-panel perspective, this sounds reasonable. It guarantees
visibility and avoids the hidden-update issue described above.

### Why it is bad

It is bad because "always visible" quickly turns into "always occupying space",
even when the information is no longer the most important thing on screen.

Pinned UI creates a permanent screen tax:

- It reduces the vertical space available for the actual conversation.
- It competes visually with the newest assistant output.
- It keeps shouting for attention after the user no longer needs it.
- It turns temporary workflow state into semi-permanent chrome.

On a phone, that cost is severe. Every persistent strip, dock, or panel steals
space from the main thing the user came to read.

It is also bad because it freezes one particular interpretation of importance:

- The system decides that the pinned panel matters at all times.
- The user may already understand that information and want it out of the way.
- The UI keeps prioritizing old state over current reading.

So while pinning solves one problem, it creates another:

- The user no longer has to scroll up for updates.
- But now the user is forced to keep seeing a component that may already have
  done its job.

That is still bad UX, just in a different direction. It replaces "hidden
important information" with "persistent no-longer-important information".

The core failure is this: "guaranteed visibility" was treated as more important
than "screen economy and relevance over time". For a mobile chat interface, a
component should not stay dominant after its useful moment has passed.

## 3. Naming a document in a way that ignores the repository's filename convention

### Why this initially looked desirable

This happened because the request was interpreted too literally.

The reasoning was:

- The user asked for a document named `Bad design decisions`.
- Using that exact string as the filename looked like a direct execution of the
  request.
- It seemed safer to mirror the requested wording exactly than to reinterpret
  it.

That sounds obedient, but it ignores local context.

### Why it is bad

It is bad because the repository already has a clear documentation naming
pattern:

- lowercase
- hyphen-separated
- no spaces

Creating `Bad design decisions.md` broke that pattern immediately.

That causes avoidable friction:

- The file name becomes inconsistent with the rest of `docs/`.
- It is less predictable when scanning the directory.
- It is more annoying to reference in shell commands because of spaces.
- It makes the repo look less disciplined for no product benefit.

The mistake was treating the requested document title as if it had to be the
literal filesystem name. Those are not the same thing.

The correct interpretation was:

- keep the human-readable title inside the document
- use the repository's established filename convention on disk

The core failure is this: "literal wording compliance" was treated as more
important than "local convention and maintainability". In a real codebase, that
is the wrong priority.

## Summary

These mistakes failed for different reasons:

- In-place updating hides important changes outside the current viewport.
- Pinning keeps information on-screen after its value has dropped.
- Inconsistent document naming creates needless friction and breaks repo
  conventions.

The larger lesson is the same in each case:

- optimize for how the system is actually used
- respect local conventions
- do not choose a structurally neat or literal-looking answer if it creates
  friction for the user or the codebase
