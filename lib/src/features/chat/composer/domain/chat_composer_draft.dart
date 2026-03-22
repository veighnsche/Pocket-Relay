import 'dart:convert';

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
  bool get hasStructuredDraft => hasTextElements || hasLocalImageAttachments;
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

  ChatComposerDraft normalized() {
    if (localImageAttachments.isEmpty) {
      if (textElements.isEmpty) {
        return this;
      }
      return copyWith(textElements: const <ChatComposerTextElement>[]);
    }

    final locatedAttachments = _locatedLocalImageAttachments(
      text,
      localImageAttachments,
    );
    if (locatedAttachments.isEmpty) {
      return copyWith(
        textElements: const <ChatComposerTextElement>[],
        localImageAttachments: const <ChatComposerLocalImageAttachment>[],
      );
    }

    final nextAttachments = <ChatComposerLocalImageAttachment>[];
    final nextTextElementRanges =
        <({int start, int end, String placeholder})>[];
    final buffer = StringBuffer();
    var cursor = 0;
    for (var index = 0; index < locatedAttachments.length; index++) {
      final locatedAttachment = locatedAttachments[index];
      if (locatedAttachment.start > cursor) {
        buffer.write(text.substring(cursor, locatedAttachment.start));
      }

      final normalizedPlaceholder = localImagePlaceholder(index + 1);
      final placeholderStart = buffer.length;
      buffer.write(normalizedPlaceholder);
      final placeholderEnd = buffer.length;
      nextAttachments.add(
        locatedAttachment.attachment.copyWith(
          placeholder: normalizedPlaceholder,
        ),
      );
      nextTextElementRanges.add((
        start: placeholderStart,
        end: placeholderEnd,
        placeholder: normalizedPlaceholder,
      ));
      cursor = locatedAttachment.end;
    }
    if (cursor < text.length) {
      buffer.write(text.substring(cursor));
    }

    final nextText = buffer.toString();
    final nextTextElements = nextTextElementRanges
        .map(
          (range) => ChatComposerTextElement(
            start: _utf8ByteOffset(nextText, range.start),
            end: _utf8ByteOffset(nextText, range.end),
            placeholder: range.placeholder,
          ),
        )
        .toList(growable: false);

    if (nextText == text &&
        _listEquals(nextAttachments, localImageAttachments) &&
        _listEquals(nextTextElements, textElements)) {
      return this;
    }

    return copyWith(
      text: nextText,
      textElements: nextTextElements,
      localImageAttachments: nextAttachments,
    );
  }

  ChatComposerDraftInsertion insertLocalImage({
    required String path,
    required int selectionStart,
    required int selectionEnd,
  }) {
    final normalizedDraft = normalized();
    final safeStart = _clampOffset(selectionStart, normalizedDraft.text.length);
    final safeEnd = _clampOffset(selectionEnd, normalizedDraft.text.length);
    final rangeStart = safeStart <= safeEnd ? safeStart : safeEnd;
    final rangeEnd = safeStart <= safeEnd ? safeEnd : safeStart;
    final nextNumber = normalizedDraft.nextLocalImagePlaceholderNumber();
    final placeholder = localImagePlaceholder(nextNumber);
    final nextText = normalizedDraft.text.replaceRange(
      rangeStart,
      rangeEnd,
      placeholder,
    );
    final nextDraft = ChatComposerDraft(
      text: nextText,
      localImageAttachments: <ChatComposerLocalImageAttachment>[
        ...normalizedDraft.localImageAttachments,
        ChatComposerLocalImageAttachment(path: path, placeholder: placeholder),
      ],
    ).normalized();

    return ChatComposerDraftInsertion(
      draft: nextDraft,
      selectionOffset: rangeStart + placeholder.length,
    );
  }

  int nextLocalImagePlaceholderNumber() {
    var maxNumber = 0;
    for (final attachment in localImageAttachments) {
      final placeholderNumber = _placeholderNumber(attachment.placeholder);
      if (placeholderNumber > maxNumber) {
        maxNumber = placeholderNumber;
      }
    }
    return maxNumber + 1;
  }

  List<ChatComposerLocalImagePlaceholderSpan> placeholderSpans() {
    return _locatedLocalImageAttachments(text, localImageAttachments)
        .map(
          (locatedAttachment) => ChatComposerLocalImagePlaceholderSpan(
            start: locatedAttachment.start,
            end: locatedAttachment.end,
            attachment: locatedAttachment.attachment,
          ),
        )
        .toList(growable: false);
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

  ChatComposerLocalImageAttachment copyWith({
    String? path,
    String? placeholder,
  }) {
    return ChatComposerLocalImageAttachment(
      path: path ?? this.path,
      placeholder: placeholder ?? this.placeholder,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatComposerLocalImageAttachment &&
        other.path == path &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode => Object.hash(path, placeholder);
}

class ChatComposerDraftInsertion {
  const ChatComposerDraftInsertion({
    required this.draft,
    required this.selectionOffset,
  });

  final ChatComposerDraft draft;
  final int selectionOffset;
}

class ChatComposerLocalImagePlaceholderSpan {
  const ChatComposerLocalImagePlaceholderSpan({
    required this.start,
    required this.end,
    required this.attachment,
  });

  final int start;
  final int end;
  final ChatComposerLocalImageAttachment attachment;

  bool containsOffset(int offset) => start < offset && offset < end;
}

String localImagePlaceholder(int number) => '[Image #$number]';

int _utf8ByteOffset(String text, int codeUnitOffset) {
  final safeOffset = _clampOffset(codeUnitOffset, text.length);
  return utf8.encode(text.substring(0, safeOffset)).length;
}

int _clampOffset(int offset, int textLength) {
  if (offset < 0) {
    return 0;
  }
  if (offset > textLength) {
    return textLength;
  }
  return offset;
}

int _placeholderNumber(String? placeholder) {
  if (placeholder == null) {
    return 0;
  }

  final match = RegExp(r'^\[Image #(\d+)\]$').firstMatch(placeholder.trim());
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

List<_LocatedLocalImageAttachment> _locatedLocalImageAttachments(
  String text,
  List<ChatComposerLocalImageAttachment> attachments,
) {
  final located = <_LocatedLocalImageAttachment>[];
  final usedStarts = <int>{};
  for (final attachment in attachments) {
    final placeholder = attachment.placeholder?.trim();
    if (placeholder == null || placeholder.isEmpty) {
      continue;
    }

    final startOffset = text.indexOf(placeholder);
    if (startOffset < 0 || !usedStarts.add(startOffset)) {
      continue;
    }
    located.add(
      _LocatedLocalImageAttachment(
        start: startOffset,
        end: startOffset + placeholder.length,
        attachment: attachment,
      ),
    );
  }
  located.sort((left, right) => left.start.compareTo(right.start));
  return located;
}

class _LocatedLocalImageAttachment {
  const _LocatedLocalImageAttachment({
    required this.start,
    required this.end,
    required this.attachment,
  });

  final int start;
  final int end;
  final ChatComposerLocalImageAttachment attachment;
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
