import 'dart:convert';

import 'package:flutter/foundation.dart';

class ChatComposerDraft {
  const ChatComposerDraft({
    this.text = '',
    this.textElements = const <ChatComposerTextElement>[],
    this.imageAttachments = const <ChatComposerImageAttachment>[],
  });

  final String text;
  final List<ChatComposerTextElement> textElements;
  final List<ChatComposerImageAttachment> imageAttachments;

  bool get hasTextElements => textElements.isNotEmpty;
  bool get hasImageAttachments => imageAttachments.isNotEmpty;
  bool get hasStructuredDraft => hasTextElements || hasImageAttachments;
  bool get isEmpty => text.trim().isEmpty && !hasImageAttachments;

  ChatComposerDraft copyWith({
    String? text,
    List<ChatComposerTextElement>? textElements,
    List<ChatComposerImageAttachment>? imageAttachments,
  }) {
    return ChatComposerDraft(
      text: text ?? this.text,
      textElements: textElements ?? this.textElements,
      imageAttachments: imageAttachments ?? this.imageAttachments,
    );
  }

  ChatComposerDraft normalized() {
    if (imageAttachments.isEmpty) {
      if (textElements.isEmpty) {
        return this;
      }
      return copyWith(textElements: const <ChatComposerTextElement>[]);
    }

    final locatedAttachments = _locatedImageAttachments(text, imageAttachments);
    if (locatedAttachments.isEmpty) {
      return copyWith(
        textElements: const <ChatComposerTextElement>[],
        imageAttachments: const <ChatComposerImageAttachment>[],
      );
    }

    final nextAttachments = <ChatComposerImageAttachment>[];
    final nextTextElementRanges =
        <({int start, int end, String placeholder})>[];
    final reservedPlaceholderNumbers = _reservedPlaceholderNumbers(
      text,
      locatedAttachments,
    );
    final assignedPlaceholderNumbers = <int>{};
    final buffer = StringBuffer();
    var cursor = 0;
    for (var index = 0; index < locatedAttachments.length; index++) {
      final locatedAttachment = locatedAttachments[index];
      if (locatedAttachment.start > cursor) {
        buffer.write(text.substring(cursor, locatedAttachment.start));
      }

      final normalizedPlaceholderNumber = _nextAvailablePlaceholderNumber(
        reservedNumbers: reservedPlaceholderNumbers,
        assignedNumbers: assignedPlaceholderNumbers,
      );
      assignedPlaceholderNumbers.add(normalizedPlaceholderNumber);
      final normalizedPlaceholder = imagePlaceholder(
        normalizedPlaceholderNumber,
      );
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
        listEquals(nextAttachments, imageAttachments) &&
        listEquals(nextTextElements, textElements)) {
      return this;
    }

    return copyWith(
      text: nextText,
      textElements: nextTextElements,
      imageAttachments: nextAttachments,
    );
  }

  ChatComposerDraftInsertion insertImageAttachment({
    required ChatComposerImageAttachment attachment,
    required int selectionStart,
    required int selectionEnd,
  }) {
    final normalizedDraft = normalized();
    final safeStart = _clampOffset(selectionStart, normalizedDraft.text.length);
    final safeEnd = _clampOffset(selectionEnd, normalizedDraft.text.length);
    final rangeStart = safeStart <= safeEnd ? safeStart : safeEnd;
    final rangeEnd = safeStart <= safeEnd ? safeEnd : safeStart;
    final nextNumber = normalizedDraft.nextImagePlaceholderNumber();
    final placeholder = imagePlaceholder(nextNumber);
    final nextText = normalizedDraft.text.replaceRange(
      rangeStart,
      rangeEnd,
      placeholder,
    );
    final nextDraft = ChatComposerDraft(
      text: nextText,
      imageAttachments: <ChatComposerImageAttachment>[
        ...normalizedDraft.imageAttachments,
        attachment.copyWith(placeholder: placeholder),
      ],
    ).normalized();

    return ChatComposerDraftInsertion(
      draft: nextDraft,
      selectionOffset: rangeStart + placeholder.length,
    );
  }

  int nextImagePlaceholderNumber() {
    var maxNumber = _maxPlaceholderNumberInText(text);
    for (final attachment in imageAttachments) {
      final placeholderNumber = _placeholderNumber(attachment.placeholder);
      if (placeholderNumber > maxNumber) {
        maxNumber = placeholderNumber;
      }
    }
    return maxNumber + 1;
  }

  List<ChatComposerImagePlaceholderSpan> placeholderSpans() {
    return _locatedImageAttachments(text, imageAttachments)
        .map(
          (locatedAttachment) => ChatComposerImagePlaceholderSpan(
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
        listEquals(other.textElements, textElements) &&
        listEquals(other.imageAttachments, imageAttachments);
  }

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAll(textElements),
    Object.hashAll(imageAttachments),
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

class ChatComposerImageAttachment {
  const ChatComposerImageAttachment({
    required this.imageUrl,
    this.displayName,
    this.mimeType,
    this.byteLength,
    this.placeholder,
  });

  final String imageUrl;
  final String? displayName;
  final String? mimeType;
  final int? byteLength;
  final String? placeholder;

  String get summaryLabel {
    final normalizedPlaceholder = placeholder?.trim();
    final normalizedDisplayName = displayName?.trim();
    if (normalizedPlaceholder != null && normalizedPlaceholder.isNotEmpty) {
      if (normalizedDisplayName == null || normalizedDisplayName.isEmpty) {
        return normalizedPlaceholder;
      }
      return '$normalizedPlaceholder $normalizedDisplayName';
    }
    if (normalizedDisplayName == null || normalizedDisplayName.isEmpty) {
      return 'Image';
    }
    return normalizedDisplayName;
  }

  ChatComposerImageAttachment copyWith({
    String? imageUrl,
    String? displayName,
    String? mimeType,
    int? byteLength,
    String? placeholder,
  }) {
    return ChatComposerImageAttachment(
      imageUrl: imageUrl ?? this.imageUrl,
      displayName: displayName ?? this.displayName,
      mimeType: mimeType ?? this.mimeType,
      byteLength: byteLength ?? this.byteLength,
      placeholder: placeholder ?? this.placeholder,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatComposerImageAttachment &&
        other.imageUrl == imageUrl &&
        other.displayName == displayName &&
        other.mimeType == mimeType &&
        other.byteLength == byteLength &&
        other.placeholder == placeholder;
  }

  @override
  int get hashCode =>
      Object.hash(imageUrl, displayName, mimeType, byteLength, placeholder);
}

class ChatComposerDraftInsertion {
  const ChatComposerDraftInsertion({
    required this.draft,
    required this.selectionOffset,
  });

  final ChatComposerDraft draft;
  final int selectionOffset;
}

class ChatComposerImagePlaceholderSpan {
  const ChatComposerImagePlaceholderSpan({
    required this.start,
    required this.end,
    required this.attachment,
  });

  final int start;
  final int end;
  final ChatComposerImageAttachment attachment;

  bool containsOffset(int offset) => start < offset && offset < end;
}

String imagePlaceholder(int number) => '[Image #$number]';

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

int _maxPlaceholderNumberInText(String text) {
  var maxNumber = 0;
  final matches = RegExp(r'\[Image #(\d+)\]').allMatches(text);
  for (final match in matches) {
    final placeholderNumber = int.tryParse(match.group(1) ?? '') ?? 0;
    if (placeholderNumber > maxNumber) {
      maxNumber = placeholderNumber;
    }
  }
  return maxNumber;
}

Set<int> _reservedPlaceholderNumbers(
  String text,
  List<_LocatedImageAttachment> locatedAttachments,
) {
  final reservedNumbers = <int>{};
  var cursor = 0;
  for (final locatedAttachment in locatedAttachments) {
    if (locatedAttachment.start > cursor) {
      reservedNumbers.addAll(
        _placeholderNumbersInTextSegment(
          text.substring(cursor, locatedAttachment.start),
        ),
      );
    }
    cursor = locatedAttachment.end;
  }
  if (cursor < text.length) {
    reservedNumbers.addAll(
      _placeholderNumbersInTextSegment(text.substring(cursor)),
    );
  }
  return reservedNumbers;
}

Set<int> _placeholderNumbersInTextSegment(String text) {
  final numbers = <int>{};
  final matches = RegExp(r'\[Image #(\d+)\]').allMatches(text);
  for (final match in matches) {
    final placeholderNumber = int.tryParse(match.group(1) ?? '') ?? 0;
    if (placeholderNumber > 0) {
      numbers.add(placeholderNumber);
    }
  }
  return numbers;
}

int _nextAvailablePlaceholderNumber({
  required Set<int> reservedNumbers,
  required Set<int> assignedNumbers,
}) {
  var candidate = 1;
  while (reservedNumbers.contains(candidate) ||
      assignedNumbers.contains(candidate)) {
    candidate += 1;
  }
  return candidate;
}

List<_LocatedImageAttachment> _locatedImageAttachments(
  String text,
  List<ChatComposerImageAttachment> attachments,
) {
  final located = <_LocatedImageAttachment>[];
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
      _LocatedImageAttachment(
        start: startOffset,
        end: startOffset + placeholder.length,
        attachment: attachment,
      ),
    );
  }
  located.sort((left, right) => left.start.compareTo(right.start));
  return located;
}

class _LocatedImageAttachment {
  const _LocatedImageAttachment({
    required this.start,
    required this.end,
    required this.attachment,
  });

  final int start;
  final int end;
  final ChatComposerImageAttachment attachment;
}
