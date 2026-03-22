# Remote Image Input Upgrade Path

Validated on 2026-03-22.

## Purpose

Correct the earlier image-support assumption for Pocket Relay.

The prior branch work assumed backend-local image paths were the primary image
transport. That is wrong for the real default product path:

- on phone, the frontend device is remote from the Codex app-server runtime
- a frontend-local filesystem path is not meaningful on the SSH host
- therefore remote-safe image transport must be the default design, not a later
  add-on

This document identifies the best upgrade path for remote image support.

## Executive Summary

Best immediate upgrade path:

- keep the inline placeholder composer UX
- stop treating backend-local file paths as the primary attachment transport
- promote protocol `image` items to the default image transport
- serialize picked frontend images as data URLs for `turn/start`
- use the existing cross-platform `file_selector` / `XFile` picker path first
- keep local-path transport only as an optional later desktop optimization

Why this is the best path:

- it works for phone/remote without requiring backend filesystem access
- it fits the current Codex app-server protocol we already have
- it fits official OpenAI image-input guidance
- it avoids inventing a new SSH upload/temp-file subsystem
- it avoids requiring Pocket Relay to own OpenAI file-upload credentials

Longer-term optimization path:

- if data-URL payload size or history bloat becomes a real problem, pursue a
  backend/app-server contract extension for uploaded image handles or file IDs
- that is not the best first upgrade because the current app-server protocol
  does not expose a file-id image input variant

## Key Findings

### 1. The current Codex app-server protocol already supports a remote-safe image variant

Reference files:

- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/UserInput.ts`
- `.reference/codex/codex-rs/protocol/src/user_input.rs`

What is true:

- protocol `UserInput` includes both:
  - `image`
  - `localImage`
- Rust protocol shape is:
  - `Image { image_url }`
  - `LocalImage { path }`

Meaning:

- `image` is already the protocol shape for frontend-supplied remote-safe image
  content
- Pocket Relay does not need a new image transport concept to support phone
  uploads

### 2. Upstream local-image paths are only a convenience input, not the fundamental image representation

Reference files:

- `.reference/codex/codex-rs/protocol/src/user_input.rs`
- `.reference/codex/codex-rs/protocol/src/models.rs`
- `.reference/codex/codex-rs/tui/src/clipboard_paste.rs`

What is true:

- protocol comments say `LocalImage` is converted to an `Image` variant during
  request serialization
- upstream model conversion reads the local file and emits
  `ContentItem::InputImage { image_url: image.into_data_url() }`
- TUI clipboard code explicitly notes that a pasted local file will be read and
  base64-encoded during serialization

Meaning:

- upstream itself ultimately sends image data, not path strings, to the model
- local paths are an input convenience when the UI and app-server share a
  filesystem
- phone/remote cannot rely on that convenience

### 3. Upstream already mixes image items and text items in one user turn

Reference files:

- `.reference/codex/codex-rs/tui_app_server/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui_app_server/src/chatwidget/tests.rs`

What is true:

- upstream builds a `Vec<UserInput>` for a user turn
- it can contain:
  - `UserInput::Image`
  - `UserInput::LocalImage`
  - `UserInput::Text`
- upstream sends image items before the text item
- tests cover both remote-style image URLs and local-image paths in the same
  label sequence

Meaning:

- Pocket Relay can keep a text buffer with placeholders and still send image
  items as first-class structured inputs
- inline placeholders do not require embedding image bytes into the text buffer

### 4. Official OpenAI docs support the transport we need

Official OpenAI docs:

- `https://developers.openai.com/api/docs/guides/images-vision`
- `https://developers.openai.com/api/docs/models/gpt-5.4`

What is true in current docs:

- image input may be provided as:
  - fully qualified URL
  - Base64-encoded data URL
  - file ID
- multiple images can be sent in one request
- GPT-5.4 supports image input
- official image input requirements list:
  - PNG, JPEG, WEBP, non-animated GIF
  - up to 50 MB total payload size per request
  - up to 500 image inputs per request

Meaning:

- a Base64 data URL is an officially supported image input path
- data URLs are the best fit for Pocket Relay today because the current Codex
  app-server protocol already has an `image` URL slot but not a file-id image
  slot

## Why The Current Branch Is Only Partially Wrong

These parts are still correct and reusable:

- structured composer draft ownership
- inline `[Image #N]` placeholder insertion
- atomic placeholder editing
- continue-from-here restore of structured drafts
- truthful filename rendering in composer and transcript

These parts are wrong as the default product design:

- `ChatComposerLocalImageAttachment` being path-first
- `CodexAppServerTurnInput.localImagePaths`
- `_turnInputPayload(...)` serializing only `type: "localImage"`
- presenter gating that only exposes image attach in local mode

Conclusion:

- the branch is not throwaway work
- the attachment model and transport assumptions need to be inverted

## Option Analysis

### Option A: Upload image files onto the SSH host, then keep using `localImage.path`

This would require:

- frontend-to-remote file transfer
- remote temp-file lifecycle
- cleanup rules
- failure recovery
- path truth guarantees
- probably a new app-server or SSH file-write seam

Why this is not the best first upgrade:

- it invents a new transport subsystem we do not currently own
- it is more fragile than the existing protocol `image` item
- it adds cleanup and lifecycle churn that does not exist with data URLs

Recommendation:

- reject as the primary path

### Option B: Encode picked images on the frontend and send protocol `image` items as data URLs

This requires:

- picking image bytes on the frontend
- normalizing/compressing them
- encoding to `data:image/...;base64,...`
- sending `UserInput::Image` / protocol `image`

Why this is the best first upgrade:

- works on phone and remote immediately
- uses the current app-server protocol
- matches official OpenAI docs
- does not require new backend endpoints
- keeps ownership in the frontend where the image actually exists

Main downside:

- payloads are larger and may increase thread-history size

Recommendation:

- adopt as the primary upgrade path now

### Option C: Upload to OpenAI Files and send file IDs

Official docs support file IDs for image input.

Why this is not the best first upgrade:

- current Codex app-server protocol does not expose a file-id image variant
- Pocket Relay frontend should not own provider API credentials directly
- this would require backend/app-server upload orchestration or a protocol
  extension

Recommendation:

- treat as a future optimization or upstream/backend feature request
- do not block remote image support on it

## Recommended Product Direction

### 1. Use one app-owned attachment model for all platforms

Replace path-first attachment state with a generic image attachment model, for
example:

- `placeholder`
- `displayName`
- `mimeType`
- `transportKind`
- `transportValue`
- optional `byteLength`

Recommended initial transport kinds:

- `dataUrl`
- `localPath` only for future optional desktop optimization

Important ownership rule:

- composer state should represent what Pocket Relay can actually send
- phone/remote attachments therefore must not depend on host-local paths

### 2. Make frontend-owned data URLs the primary serialization target

Recommended immediate behavior:

- when the user picks an image, read bytes on the frontend
- normalize the image into a supported format
- encode a data URL
- store that data URL in structured draft state
- send it as protocol `image`

Recommended `turn/start` payload shape:

- one `image` item per attachment in placeholder order
- one `text` item containing the draft text plus `text_elements`

This matches upstream’s structured-turn model and avoids inventing a custom
attachment encoding.

### 3. Keep inline placeholders in the UI, even though transport is image items

The UI requirement remains:

- image placeholder can sit in the middle of a sentence

The transport requirement is different:

- the actual image bytes should travel in protocol `image` items

Therefore:

- keep placeholder editing semantics exactly as implemented
- change only the attachment transport backing those placeholders

### 4. Reuse the existing cross-platform picker seam first

Recommended picker strategy:

- use `file_selector` across mobile, desktop, and web
- consume its `XFile` bytes/name/MIME in one shared attachment loader

Why:

- the package is already in the repo
- it already returns the cross-platform file abstraction the transport needs
- this avoids dependency churn while still supporting phone/remote
- it keeps gallery/camera-specific expansion as a later UX decision, not a
  transport blocker

If later product work requires a more gallery-native mobile flow, an
`image_picker` layer can still be added on top of the same attachment model.

## Recommended Technical Plan

### Phase 0: Correct The Contract

Change these app-owned models first:

- `ChatComposerLocalImageAttachment` -> generic image attachment
- `CodexAppServerTurnInput.localImagePaths` -> generic image inputs
- `ChatComposerContract.allowsLocalImageAttachment` -> generic image-attach
  capability

Do not keep `local` in names if the product default is remote-safe.

### Phase 1: Add Remote-Safe Image Payloads

Implement:

- picker returns bytes + filename + MIME
- attachment state stores data URL as the primary transport value

Important note:

- this is the point where the branch stops being local-only in substance, not
  just in UI

### Phase 2: Change `turn/start` Serialization

Replace current local-path serialization with:

- protocol `image` items for data URLs
- protocol `text` item for the placeholder-bearing text

Recommended ordering:

- attachments first
- text item last

Reason:

- upstream reference already does this for image-bearing turns

### Phase 3: Remove Local-Mode-Only Gating

Current gating is wrong for phone/remote.

Replace it with capability gating based on:

- model supports image input
- platform can pick images

Do not gate image attach on `ConnectionMode.local`.

### Phase 4: Add Normalization And Size Controls

This is an inference from the sources and current transport shape, not a direct
doc requirement:

- Pocket Relay should cap payloads much lower than the API’s theoretical
  50 MB request ceiling
- data URLs inflate size and may be replayed through thread/read history

Recommended safeguards:

- accept only supported image types
- normalize HEIC and oversized inputs to a supported format
- resize before Base64 encoding
- reject obviously too-large results before send

Recommended upstream-compatible direction:

- follow upstream’s `ResizeToFit` intent and normalize before encoding

### Phase 5: Restore And History Projection

In-session restore is already mostly solved by the current branch.

Still needed:

- thread/read mapping for protocol `image` items back into app-owned draft
  attachments
- image-bearing user-message restoration for cross-session history
- preservation of filename/display metadata where only `image_url` comes back

Important caveat:

- current historical restore in Pocket Relay does not yet project user-message
  image content back into transcript-owned structured draft state

### Phase 6: Optional Later Desktop Optimization

If needed later:

- local desktop lanes may serialize `localImage` instead of data URLs when the
  frontend and app-server truly share a filesystem

This should be an optimization phase, not the primary architecture.

## Concrete Changes Needed In Pocket Relay

### Rework

- `lib/src/features/chat/composer/domain/chat_composer_draft.dart`
- `lib/src/features/chat/composer/presentation/chat_composer_surface.dart`
- `lib/src/features/chat/lane/presentation/chat_screen_contract.dart`
- `lib/src/features/chat/lane/presentation/chat_screen_presenter.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_support.dart`
- `lib/src/features/chat/lane/application/chat_session_controller_history.dart`

### Keep

- placeholder insertion and atomic editing logic
- structured draft restore logic from `continueFromUserMessage`
- truthful filename rendering in composer and transcript

### Add

- shared image attachment loader from `XFile`
- data-URL image serializer
- size and MIME validation
- history projection for image-bearing user messages

## Recommended Final Decision

Best upgrade path:

1. keep the inline placeholder UX
2. pivot attachment transport to protocol `image` items with data URLs
3. use the existing `file_selector` / `XFile` path across platforms first
4. remove local-mode-only attach gating
5. treat `localImage.path` as a later optional optimization, not the default

This is the lowest-churn path that is actually correct for the phone/remote
product.

## Sources

Local reference sources:

- `.reference/codex/codex-rs/app-server-protocol/schema/typescript/v2/UserInput.ts`
- `.reference/codex/codex-rs/protocol/src/user_input.rs`
- `.reference/codex/codex-rs/protocol/src/models.rs`
- `.reference/codex/codex-rs/tui_app_server/src/chatwidget.rs`
- `.reference/codex/codex-rs/tui_app_server/src/chatwidget/tests.rs`
- `.reference/codex/codex-rs/tui/src/clipboard_paste.rs`
- `lib/src/features/chat/transport/app_server/codex_app_server_models.dart`
- `lib/src/features/chat/transport/app_server/codex_app_server_request_api_support.dart`
- `lib/src/features/chat/lane/presentation/chat_screen_presenter.dart`

Official OpenAI docs:

- `https://developers.openai.com/api/docs/guides/images-vision`
- `https://developers.openai.com/api/docs/models/gpt-5.4`
