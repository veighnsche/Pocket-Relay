# Workspace UX Failures Called Out In Review

This document records the concrete Pocket Relay UX failures called out in the
current review thread. It is intentionally direct. These are not "taste"
comments. They are product and ownership failures that steal working space,
mislabel state, or make the workspace flow unreliable.

## 1. Saved Connections Surface Leaks Pager State Into Product UI

- The `Current lane` concept is bad on the saved-connections surface.
- On mobile, the saved-connections page is reached by swiping past the live
  lanes. That makes `Current lane` effectively mean "the live lane that was
  selected immediately before entering the saved-connections page".
- That is a navigation artifact, not a meaningful product state.
- The split between `Current lane` and `Open lanes` leaks internal selection
  state into the roster UI instead of showing stable user-meaningful
  categories.
- The roster should show real states such as open lanes, lanes needing
  attention, and saved workspaces. It should not elevate transient selection
  into its own section.

## 2. Connection Settings Drawer Wastes Fixed Space

- The connection settings drawer header takes too much permanent vertical space.
- A long explanatory paragraph is pinned in the fixed header even though it does
  not unlock the user's next action and will usually not be read.
- The drawer also repeats descriptive copy inside the scroll body, so the user
  loses working space twice: once in fixed chrome and again in section
  descriptions.
- This is the wrong optimization target. The form should prioritize editable
  fields and concise labels over orientation prose.

## 3. Mobile Settings Copy Implies Choices That Do Not Exist

- On mobile, the settings header shows `Remote` as a permanent badge even when
  local mode is not actually available there.
- That implies a meaningful mode choice that does not exist on that platform.
- If there is no real local/remote decision on mobile, the header should not
  spend permanent space re-stating `Remote` as if it were a user-controlled
  branch.

## 4. Drawer Components Are Inconsistent

- The app does not behave like it has one coherent drawer/sheet pattern.
- Different drawers use different header conventions, different title
  placement, different close affordances, and different amounts of top-space
  tax.
- This inconsistency makes drawers feel improvised instead of owned by one
  shared product pattern.

## 5. Conversation History Drawer Is Structurally Wrong

- The mobile conversation history drawer has an oversized handle/header row that
  spends space on almost no useful content.
- It adds a dedicated close icon button even though a drawer already has drawer
  dismissal affordances. That extra close control is unnecessary and visually
  noisy.
- Its title and description are rendered below the divider instead of living in
  the actual header/handle area, so the drawer is split into fake header chrome
  above and real header content below.
- This makes the drawer feel backward and inconsistent with the rest of the
  product.

## 6. Connection Lifecycle And Saved-Connections UX Remain Buggy

- The connection lifecycle and saved-connections flows are still unreliable.
- Opening or connecting additional lanes feels buggy instead of trustworthy.
- The reported user experience is that lane connection succeeds only
  inconsistently, roughly "50% of the time".
- Multi-lane support may exist in controller structure, but the shipped user
  experience is not dependable enough to count as correct.
- This needs investigation and correction at the actual product flow level, not
  just architectural justification.

## 7. The Underlying Design Failure Pattern

- Unimportant things were promoted into permanent visibility.
- Important working space was taken away from the user for prose, helper
  explanation, or secondary controls.
- Internal implementation state was surfaced as if it were product truth.
- Several surfaces appear to have been optimized for "clarity through more
  visible stuff" instead of clarity through better structure and better use of
  space.

## 8. One Regression Already Corrected In This Session

- The live lane no longer shows persistent `Disconnect` and `Close lane`
  buttons in permanent lane chrome.
- Those controls were incorrectly promoted into always-visible space and have
  been moved back out of the active lane surface.

