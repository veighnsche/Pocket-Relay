# AGENTS.md Reinjection Findings

## Goal

Compare the Pocket Relay Flutter client against `.reference/codex` and determine whether each new Flutter message resends `AGENTS.md`, and whether the underlying conversation model differs from the reference implementation.

## Executive Summary

The Flutter client does not send `AGENTS.md` on every `turn/start` request.

What the client sends for a normal prompt is only:

- `threadId`
- the new text input
- an optional model override

The reference implementation loads `AGENTS.md` into session-level `user_instructions`, then injects that content into the model-visible conversation as a contextual user message when initial context is seeded. That is a server/core concern, not a Flutter transport concern.

The main behavioral mismatch is in transcript rendering:

- reference Codex filters contextual user fragments like `AGENTS.md`, environment context, and skills out of the visible user conversation
- Pocket Relay currently treats those items as normal user messages and renders them in the chat transcript

So the most likely explanation is:

1. Pocket Relay is not resending `AGENTS.md` in the wire payload for every prompt.
2. Pocket Relay is surfacing contextual instruction items that the reference client intentionally hides.
3. If `AGENTS.md` truly appears every prompt, then the remote thread is probably being recreated or resumed repeatedly, which causes initial context to be injected again.

## Pocket Relay: How Turns Are Sent

### UI to transport path

The send flow is:

- `ChatScreen._sendPrompt()`
- `ChatSessionController.sendPrompt()`
- `ChatSessionController._sendPromptWithAppServer()`
- `CodexAppServerClient.sendUserMessage()`
- `CodexAppServerRequestApi.sendUserMessage()`

Evidence:

- `lib/src/features/chat/presentation/chat_screen.dart:234`
- `lib/src/features/chat/application/chat_session_controller.dart:106`
- `lib/src/features/chat/application/chat_session_controller.dart:305`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_client.dart:62`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart:86`

### Actual `turn/start` payload

Pocket Relay builds the turn request like this:

```dart
final params = <String, Object?>{
  'threadId': effectiveThreadId,
  'input': <Object>[
    <String, Object?>{
      'type': 'text',
      'text': trimmedText,
      'text_elements': const <Object>[],
    },
  ],
  if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
};
```

Source:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart:103`

There is no `AGENTS.md`, `user_instructions`, `base_instructions`, or `developer_instructions` field in that request.

### Test evidence

The client test asserts the exact outgoing messages:

- `thread/start` contains `cwd`, `approvalPolicy`, `sandbox`, and `ephemeral`
- `turn/start` contains only `threadId` and the new input text

Source:

- `test/codex_app_server_client_test.dart:151`

That test is direct evidence that Pocket Relay is not appending repo instructions to each prompt at the Dart client layer.

## Pocket Relay: How Threads Are Created or Reused

Pocket Relay only reuses the existing thread when:

- the profile is not ephemeral
- `sessionState.threadId` exists
- `appServerClient.threadId == sessionState.threadId`

Source:

- `lib/src/features/chat/application/chat_session_controller.dart:334`

Otherwise it calls `startSession()`, which uses either:

- `thread/start`
- `thread/resume`

Source:

- `lib/src/features/chat/application/chat_session_controller.dart:346`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart:9`

The session start payload includes:

- `cwd`
- `approvalPolicy`
- `sandbox`
- optional `model`
- optional `threadId` when resuming
- `ephemeral` only for `thread/start`

It still does not include `AGENTS.md`, `user_instructions`, `base_instructions`, or `developer_instructions`.

Source:

- `lib/src/features/chat/infrastructure/app_server/codex_app_server_request_api.dart:28`

## Reference Codex: Where `AGENTS.md` Actually Enters the Conversation

### Discovery and merge

Reference Codex discovers `AGENTS.md` files from project root to current working directory, concatenates them, and merges them into `user_instructions`.

Source:

- `.reference/codex/codex-rs/core/src/project_doc.rs:1`
- `.reference/codex/codex-rs/core/src/project_doc.rs:79`
- `.reference/codex/codex-rs/core/src/project_doc_tests.rs:214`
- `.reference/codex/codex-rs/core/src/project_doc_tests.rs:245`

### Session initialization

When a Codex session is created, reference Codex computes `user_instructions` once and stores them in `session_configuration.user_instructions`.

Source:

- `.reference/codex/codex-rs/core/src/codex.rs:473`
- `.reference/codex/codex-rs/core/src/codex.rs:551`

### Serialization format

Reference Codex serializes these instructions as a contextual user message with this wrapper:

```text
# AGENTS.md instructions for <directory>

<INSTRUCTIONS>
...
</INSTRUCTIONS>
```

Source:

- `.reference/codex/codex-rs/core/src/instructions/user_instructions.rs:19`
- `.reference/codex/codex-rs/core/src/contextual_user_message.rs:6`

### When the reference injects that context

Reference Codex injects full initial context only when there is no `reference_context_item` baseline. After that, steady-state turns emit only settings diffs instead of replaying full initial context.

Source:

- `.reference/codex/codex-rs/core/src/codex.rs:3596`
- `.reference/codex/codex-rs/core/src/codex.rs:3604`

The reference also stores a `TurnContextItem` baseline so later turns can avoid reinjecting full context.

Source:

- `.reference/codex/codex-rs/core/src/codex.rs:3617`

## Reference App Server: Turn Semantics

On the app-server side, `turn/start` maps the provided input items into `Op::UserInput`. It does not accept or inject `base_instructions` or `developer_instructions` as per-turn fields in the Flutter path we inspected.

Source:

- `.reference/codex/codex-rs/app-server/src/codex_message_processor.rs:5844`

The fields `base_instructions` and `developer_instructions` exist on `thread/start`, `thread/resume`, and `thread/fork`, not on normal turn start in the Flutter flow.

Source:

- `.reference/codex/codex-rs/app-server/src/codex_message_processor.rs:1845`
- `.reference/codex/codex-rs/app-server/src/codex_message_processor.rs:3335`
- `.reference/codex/codex-rs/app-server/src/codex_message_processor.rs:3834`

The reference app-server also explicitly treats start/resume overrides as session/thread configuration, not steady-state running-thread turn input.

Source:

- `.reference/codex/codex-rs/app-server/src/codex_message_processor.rs:7409`

## Where Pocket Relay Diverges From Reference Behavior

### Reference client filters contextual user fragments

Reference Codex does not treat contextual `AGENTS.md` messages as normal user chat. It detects and skips contextual user fragments entirely when parsing visible turn items.

Source:

- `.reference/codex/codex-rs/core/src/event_mapping.rs:24`
- `.reference/codex/codex-rs/core/src/event_mapping.rs:28`
- `.reference/codex/codex-rs/core/src/event_mapping_tests.rs:139`

That filtering includes:

- `AGENTS.md` fragments
- environment context fragments
- skill fragments
- shell command fragments
- other internal contextual user wrappers

### Pocket Relay does not filter them

Pocket Relay currently infers user messages by checking whether the item type contains `user`.

Source:

- `lib/src/features/chat/application/runtime_event_mapper_support.dart:117`

Then it extracts text directly from the item snapshot or detail and turns it into a visible `CodexUserMessageBlock`.

Source:

- `lib/src/features/chat/application/transcript_item_policy.dart:87`
- `lib/src/features/chat/application/transcript_item_policy.dart:144`
- `lib/src/features/chat/application/transcript_item_block_factory.dart:17`

There is no equivalent filter for contextual user fragments like:

- `# AGENTS.md instructions for ...`
- `<INSTRUCTIONS>...</INSTRUCTIONS>`
- `<environment_context>...</environment_context>`
- `<skill>...</skill>`

Pocket Relay only suppresses a user item when it exactly duplicates the last visible local user bubble.

Source:

- `lib/src/features/chat/application/transcript_item_policy.dart:176`

That means a server-emitted contextual instruction item can show up in the transcript as if the user sent it.

## Assessment Of The Original Suspicion

### Suspicion: every new message resends the entire `AGENTS.md`

Based on the Dart transport code, that suspicion is not supported at the Flutter client layer.

The Flutter client does not attach repo instructions to each `turn/start`.

### What is more likely happening

There are two more plausible explanations:

1. The remote thread is being recreated or resumed repeatedly, causing initial context to be seeded again.
2. Pocket Relay is rendering internal contextual user-instruction items that the reference client would hide.

## When Repeated `AGENTS.md` Can Still Happen Legitimately

Repeated appearance is still possible if the app is not staying on one stable running thread.

Examples:

- `ephemeralSession` is enabled, so each prompt starts fresh
- the app disconnects and reconnects between prompts
- `sessionState.threadId` and `appServerClient.threadId` stop matching, so the controller starts or resumes again
- the remote session exits and the client has to recreate it

Relevant sources:

- `lib/src/core/models/connection_models.dart:15`
- `lib/src/features/chat/application/chat_session_controller.dart:337`
- `lib/src/features/chat/infrastructure/app_server/codex_app_server_connection.dart:238`

## Bottom Line

The underlying conversation model is not fundamentally different from the reference implementation.

Pocket Relay is already using the Codex app-server thread and turn protocol in the same general shape:

- `thread/start` or `thread/resume` for session/thread setup
- `turn/start` for per-message input

The main difference is client behavior after events arrive:

- reference Codex hides contextual instruction fragments from the visible conversation
- Pocket Relay currently renders them as normal user transcript content

That transcript mismatch can make it look like the app is resending `AGENTS.md` every time, even when the transport layer is not doing that.

## Most Defensible Root Cause Statement

The strongest current conclusion is:

Pocket Relay is not resending `AGENTS.md` on each `turn/start` request. Instead, it is likely showing server-generated contextual instruction items as ordinary user messages, and repeated thread creation or resume may cause those contextual items to appear again.

## Suggested Follow-Up

The next code change should be to bring Pocket Relay’s transcript parsing in line with reference Codex by suppressing contextual user fragments from the visible conversation.

That should include filters for at least:

- `# AGENTS.md instructions for ...`
- `<INSTRUCTIONS>...</INSTRUCTIONS>`
- `<environment_context>...</environment_context>`
- `<skill>...</skill>`

If that filter is added and `AGENTS.md` still appears on every prompt, then the next debugging target should be thread lifecycle and reconnection behavior rather than prompt assembly.
