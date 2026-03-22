# Codex Multimodal Image Support Investigation

## Purpose

Record the current reference behavior for Codex image and multimodal input, and
map that behavior against Pocket Relay's real implementation seams.

This document is an investigation, not an implementation plan disguised as
finished product truth.

Assumption for this doc: the request's "code X" means `Codex`.

Validated against local reference sources and official OpenAI docs on
2026-03-22.

## Scope

This investigation is about supporting user-originated images in Pocket Relay.

Requested target for this note:

- placing a local image attachment in the middle of a sentence inside the text
  input
- preserving that inline placeholder through editing, recall, and submission

Out of scope for this note:

- remote image URL entry paths
- broader image-surface design beyond what is needed for inline local image
  placement

It separates four concerns:

- upstream Codex product behavior
- upstream app-server / protocol contract shape
- Pocket Relay runtime and transcript ownership
- official OpenAI model capability guidance

It does not claim that Pocket Relay should copy the Codex TUI visually.

## Executive Summary

Pocket Relay does not currently support image-bearing user turns.

Upstream Codex does support multimodal user input:

- user turns are typed arrays, not plain strings
- local image input is represented as structured input, not plain text
- composer behavior is gated by model `input_modalities`
- local session history and backtrack restore inline image attachments
- persistent cross-session history intentionally does not persist attachments

Pocket Relay currently stops at text-only composition and text-only `turn/start`
submission. It does already recognize some image-related runtime item types such
as image view and image generation, but only as work-log-style output categories.

Supporting images correctly in Pocket Relay will require app-owned changes in:

- composer draft ownership
- transport request building
- model capability gating
- historical restore / transcript mapping
- transcript presentation
- tests around unsupported-image behavior and restore semantics

This is not a one-widget change.

## Reference Findings: Codex

### 1. Codex treats user input as structured items, not a single prompt string

Reference files:

- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/TurnStartParams.ts`
- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/UserInput.ts`
- `.reference/codex/codex-rs/protocol/src/user_input.rs`

Relevant findings:

- `TurnStartParams.input` is `Array<UserInput>`.
- Generated `UserInput` variants include:
  - text
  - image
  - localImage
  - skill
  - mention
- Rust `UserInput` defines:
  - `Text { text, text_elements }`
  - `Image { image_url }`
  - `LocalImage { path }`
  - `Skill { name, path }`
  - `Mention { name, path }`
- Rust comments explicitly state that `LocalImage` is converted to an `Image`
  variant during request serialization.

Implication:

Pocket Relay should own structured composer input, not bolt images onto a plain
string API as an afterthought.

### 2. Codex composer owns real attachment state

Reference files:

- `.reference/codex/docs/tui-chat-composer.md`
- `.reference/codex/codex-rs/tui/src/bottom_pane/chat_composer.rs`

Relevant findings from the doc:

- Codex tracks local image paths.
- Local session history restores text elements and image attachments.
- Persistent on-disk history restores only text and intentionally does not
  rehydrate attachments.
- Backtrack prefill restores text elements and local image paths from the
  selected prior user message.
- Attachment support is re-checked at submit time so unsupported-image cases
  warn instead of silently losing draft state.

Implication:

If Pocket Relay wants correct rewind/restore behavior, image attachments must be
part of app-owned draft state and not just temporary UI chrome.

### 2a. Placement semantics: local images are inserted inline as atomic placeholders

Reference files:

- `.reference/codex/docs/tui-chat-composer.md`
- `.reference/codex/codex-rs/tui/src/bottom_pane/chat_composer.rs`

What is true for local images:

- `attach_image(...)` calls `textarea.insert_element(&placeholder)`, so the
  local image placeholder is inserted at the current cursor position in the text
  buffer
- the placeholder is treated as an atomic text element, not as ordinary
  character-by-character text
- tests show placeholders can appear:
  - at the start of the buffer
  - adjacent to other placeholders
  - after typed text
  - in reordered positions inside existing text
- external editor replacement rebuilds placeholder elements from the edited text
  and preserves only attachments whose placeholder labels still appear

What is not true:

- the binary image itself is not embedded into the text buffer

Operational details worth preserving:

- deleting a local placeholder removes the corresponding attachment mapping and
  renumbers remaining placeholders in the text
- if an external edit removes a placeholder token from the text, the matching
  local attachment is dropped

Conclusion:

The correct literal answer for the requested target is:

- yes, a local image attachment placeholder can be inserted anywhere the caret
  is in the textarea
- the placeholder is atomic and survives as a structured element, not as raw
  image bytes mixed into the sentence text

### 3. Codex gates image features on model capabilities

Reference files:

- `.reference/codex/docs/contributing.md`
- `.reference/codex/codex-rs/protocol/src/openai_models.rs`
- `.reference/codex/codex-rs/core/models.json`
- `.reference/codex/codex-rs/docs/codex_mcp_interface.md`

Relevant findings:

- Codex defines `InputModality` with `text` and `image`.
- Reference clients are expected to consume `input_modalities` when deciding
  whether image attach/paste should be available.
- `model/list` documentation exposes `inputModalities` as a real client-facing
  contract.
- The current bundled model catalog includes `input_modalities: ["text",
  "image"]` for `gpt-5.3-codex`.
- The reference defaults omitted `input_modalities` to text + image for
  backward compatibility, but the contributing doc explicitly says to set the
  field for models that do not support images.

Implication:

Pocket Relay should not hardcode image support. It should expose model
capabilities from upstream and gate attach/paste UI off that signal.

### 4. Codex preserves image-bearing user messages in legacy event mappings

Reference file:

- `.reference/codex/codex-rs/protocol/src/items.rs`

Relevant findings:

- `UserMessageItem.content` is `Vec<UserInput>`.
- Legacy user-message events flatten text into `message`, but still include:
  - `images`
  - `local_images`
  - `text_elements`

Implication:

Even when a surface renders a simplified message, the upstream model still
treats images and text elements as real first-class user input.

### 5. Codex already has image-related output families

Reference files:

- `.reference/codex/codex-rs/tui/src/history_cell.rs`
- `docs/042_codex-tui-flutter-widget-parity-gaps.md`

Relevant findings:

- The reference transcript includes dedicated surfaces for:
  - view-image tool calls
  - image-generation calls
- Pocket Relay already tracks these as parity gaps in
  `docs/042_codex-tui-flutter-widget-parity-gaps.md`.

Implication:

Pocket Relay's current image-related support is output-oriented and incomplete.
It does not yet solve user-originated multimodal input.

## Official OpenAI Docs Findings

Official sources:

- OpenAI Images and Vision guide:
  `https://developers.openai.com/api/docs/guides/images-vision`
- GPT-5.3-Codex model page:
  `https://developers.openai.com/api/docs/models/gpt-5.3-codex`
- OpenAI image generation guide:
  `https://developers.openai.com/api/docs/guides/tools-image-generation`

Relevant findings from current docs:

- The Images and Vision guide says image input can be provided by:
  - fully qualified image URL
  - base64-encoded data URL
  - file ID
- The same guide says multiple images can be included in a single request by
  placing multiple image items in the `content` array.
- The GPT-5.3-Codex model page currently lists:
  - text: input and output
  - image: input only
  - audio: not supported
  - video: not supported
- The image-generation guide documents generation and multi-turn image editing
  as separate image-tooling flows.

Implication:

For Pocket Relay's Codex chat surface, the primary requirement is image input in
user turns. Generated-image display is related, but it is a separate transcript
surface problem.

## Current Pocket Relay State

### 1. Composer ownership is text-only

Relevant files:

- `lib/src/features/chat/lane/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/composer/presentation/chat_composer.dart`
- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`

Current facts:

- `ChatComposerContract` only carries:
  - `draftText`
  - `isSendActionEnabled`
  - `placeholder`
- `ChatComposerSurface` renders a single `TextField` and a send button.
- There is no app-owned image attachment state in the contract or surface.

Conclusion:

Pocket Relay currently has no ownership boundary for image-bearing drafts.

### 2. Transport submission is text-only

Relevant files:

- `lib/src/features/chat/transport/app_server/codex_app_server_request_api.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`

Current facts:

- `sendUserMessage(...)` only accepts `threadId`, `text`, `model`, and
  `effort`.
- `_sendUserMessage(...)` builds `turn/start` with a one-item `input` array:
  `{ "type": "text", "text": trimmedText, "text_elements": [] }`
- Controller send flow only passes a prompt string into transport.

Conclusion:

Pocket Relay cannot currently send local images or the structured text elements
needed for inline image placeholders.

### 3. History decoding keeps raw payloads, but no image input is projected

Relevant files:

- `lib/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`
- `lib/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart`
- `lib/src/features/chat/transcript/application/transcript_item_support.dart`
- `lib/src/features/chat/runtime/application/codex_runtime_payload_support.dart`

Current facts:

- History items are stored as `id`, `type`, `status`, and `raw`.
- The normalizer preserves raw snapshots.
- Text extraction helpers look for text-like fields and structured text content.
- Repo-wide search shows no current Pocket Relay handling for:
  - `input_image`
  - `image_url`
  - `local_image`
  - inline local image placeholder state in composer/history state

Conclusion:

Pocket Relay preserves enough raw payload to build correct image support later,
but it does not currently materialize user image input into app-owned runtime
state or UI contracts.

### 4. Pocket Relay only partially maps image-related runtime items today

Relevant files:

- `lib/src/features/chat/runtime/application/codex_runtime_payload_support.dart`
- `lib/src/features/chat/transcript/application/transcript_item_block_factory.dart`
- `test/codex_runtime_event_mapper_test.dart`
- `docs/042_codex-tui-flutter-widget-parity-gaps.md`

Current facts:

- Runtime payload support recognizes canonical item types:
  - `imageView`
  - `imageGeneration`
- Transcript block factory maps both to work-log entries.
- Tests already verify official item-type mapping for image generation.
- Existing parity docs still mark view-image and image-generation widgets as
  missing first-class transcript surfaces.

Conclusion:

Pocket Relay recognizes some image-related output events, but does not yet have
full transcript parity for those outputs and does not support image input.

## Important Contract Caveat

The bundled reference sources do not present a perfectly uniform image payload
shape across generated artifacts.

Observed mismatch across generated artifacts:

- Generated TypeScript `UserInput` shows variants like:
  - `{ type: "image", url: string }`
  - `{ type: "localImage", path: string }`
- Generated JSON schema in
  `.reference/codex/codex-rs/app-server-protocol/schema/json/v2/ThreadResumeParams.json`
  shows content items like:
  - `{ type: "input_image", image_url: string }`

These may represent adjacent protocol layers rather than a literal contract
contradiction, but they are still enough to make guessing unsafe.

Conclusion:

Pocket Relay should not guess the final live wire shape from one generated file.
Before transport implementation, we should verify the actual app-server payload
with a live capture or the authoritative server-side Rust type used by the
running Codex build.

## What Has To Change In Pocket Relay

The correct ownership order remains:

1. reference behavior
2. backend / app-server contract
3. Pocket Relay runtime mapping
4. Flutter presentation

Concrete work items:

### 1. Introduce structured composer draft state

Needed app-owned fields:

- text buffer
- text elements
- local image attachments
- capability state for whether the selected model accepts images

This should live under `lib/src/...`, not in preview infrastructure.

### 2. Expose upstream model `input_modalities`

Pocket Relay should consume the real capability signal from upstream model data
and use it to:

- show or hide image attach affordances
- disable paste/attach when unsupported
- warn instead of silently dropping draft state

### 3. Replace the text-only send contract with structured user input

`sendUserMessage(...)` should stop pretending the turn input is a string.

It should accept an app-owned structured input payload and serialize that into
the verified upstream `turn/start` shape.

### 4. Preserve image-bearing user messages through restore and rewind

History restore and rollback-prefill should preserve:

- text
- text elements
- local attachments

If Pocket Relay restores only text, it will diverge from the upstream Codex
editing model for in-session recall and backtrack.

### 5. Add real transcript surfaces for image-bearing content

At minimum:

- a composer attachment presentation
- transcript rendering for user messages with attachments
- dedicated output surfaces for image-view and image-generation items, instead
  of only aggregated work-log treatment

### 6. Add tests at the correct ownership seams

Minimum test coverage should prove:

- structured `turn/start` payload generation
- unsupported-image gating by model capability
- restore/backtrack rehydration of image-bearing drafts
- transcript mapping for image-bearing history items
- output rendering for image-view / image-generation items

## Recommended Implementation Sequence

1. Verify the live app-server image input payload shape against a running Codex
   build.
2. Add app-owned structured composer draft models and controller state.
3. Thread model capability metadata into the chat lane contract.
4. Upgrade transport from text-only `sendUserMessage` to structured user input.
5. Upgrade history normalization and transcript state to preserve image-bearing
   user messages.
6. Add minimal UI for local image attachments first.
7. Add dedicated transcript surfaces for image-view and image-generation output.
8. Add regression tests before expanding UX polish.

## Honest Current Assessment

Pocket Relay is not blocked by backend impossibility. The upstream Codex model
already supports image input and the reference client already treats image
attachments as real draft state.

Pocket Relay is blocked by its own current text-only ownership model.

The shortest correct path is not "add an image button." The shortest correct
path is:

- structured draft ownership
- verified transport contract
- capability gating
- restore-safe runtime mapping
- then presentation

## Source Anchors

Local repo:

- `lib/src/features/chat/lane/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_turn_requests.dart`
- `lib/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart`
- `lib/src/features/chat/transcript/application/transcript_item_support.dart`
- `lib/src/features/chat/runtime/application/codex_runtime_payload_support.dart`
- `docs/042_codex-tui-flutter-widget-parity-gaps.md`

Bundled upstream reference:

- `.reference/codex/docs/tui-chat-composer.md`
- `.reference/codex/codex-rs/protocol/src/user_input.rs`
- `.reference/codex/codex-rs/protocol/src/items.rs`
- `.reference/codex/codex-rs/protocol/src/openai_models.rs`
- `.reference/codex/codex-rs/core/models.json`
- `.reference/codex/codex-rs/docs/codex_mcp_interface.md`
- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/TurnStartParams.ts`
- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/UserInput.ts`
- `.reference/codex/codex-rs/app-server-protocol/schema/json/v2/ThreadResumeParams.json`

Official docs:

- `https://developers.openai.com/api/docs/guides/images-vision`
- `https://developers.openai.com/api/docs/models/gpt-5.3-codex`
- `https://developers.openai.com/api/docs/guides/tools-image-generation`
