class ChatComposerDraft {
  const ChatComposerDraft({
    this.text = '',
    this.textElements = const <ChatComposerTextElement>[],
    this.localImageAttachments = const <ChatComposerLocalImageAttachment>[],
  });

  final String text;
  final List<ChatComposerTextElement> textElements;
  final List<ChatComposerLocalImageAttachment> localImageAttachments;

  bool get hasTextElements => textElements.isNotEmpty;
  bool get hasLocalImageAttachments => localImageAttachments.isNotEmpty;
  bool get isEmpty => text.isEmpty && !hasLocalImageAttachments;

  ChatComposerDraft copyWith({
    String? text,
    List<ChatComposerTextElement>? textElements,
    List<ChatComposerLocalImageAttachment>? localImageAttachments,
  }) {
    return ChatComposerDraft(
      text: text ?? this.text,
      textElements: textElements ?? this.textElements,
      localImageAttachments:
          localImageAttachments ?? this.localImageAttachments,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatComposerDraft &&
        other.text == text &&
        _listEquals(other.textElements, textElements) &&
        _listEquals(other.localImageAttachments, localImageAttachments);
  }

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAll(textElements),
    Object.hashAll(localImageAttachments),
  );
}

class ChatComposerTextElement {
  const ChatComposerTextElement({
    required this.start,
    required this.end,
    this.placeholder,
  });

  final int start;
  final int end;
  final String? placeholder;

  @override
  bool operator ==(Object other) {
    return other is ChatComposerTextElement &&
        other.start == start &&
        other.end == end &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(start, end, placeholder);
}

class ChatComposerLocalImageAttachment {
  const ChatComposerLocalImageAttachment({
    required this.path,
    this.placeholder,
  });

  final String path;
  final String? placeholder;

  @override
  bool operator ==(Object other) {
    return other is ChatComposerLocalImageAttachment &&
        other.path == path &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(path, placeholder);
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
