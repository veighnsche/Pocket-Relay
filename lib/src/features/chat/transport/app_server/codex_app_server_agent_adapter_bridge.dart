import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

import 'codex_app_server_models.dart';

CodexAppServerTurnInput? codexTurnInputFromAgentAdapter(
  AgentAdapterTurnInput? input,
) {
  if (input == null) {
    return null;
  }
  if (input is CodexAppServerTurnInput) {
    return input;
  }
  return CodexAppServerTurnInput(
    text: input.text,
    textElements: input.textElements
        .map(
          (element) => element is CodexAppServerTextElement
              ? element
              : CodexAppServerTextElement(
                  start: element.start,
                  end: element.end,
                  placeholder: element.placeholder,
                ),
        )
        .toList(growable: false),
    images: input.images
        .map(
          (image) => image is CodexAppServerImageInput
              ? image
              : CodexAppServerImageInput(url: image.url),
        )
        .toList(growable: false),
  );
}

CodexAppServerElicitationAction codexElicitationActionFromAgentAdapter(
  AgentAdapterElicitationAction action,
) {
  return switch (action) {
    AgentAdapterElicitationAction.accept =>
      CodexAppServerElicitationAction.accept,
    AgentAdapterElicitationAction.decline =>
      CodexAppServerElicitationAction.decline,
    AgentAdapterElicitationAction.cancel =>
      CodexAppServerElicitationAction.cancel,
  };
}
