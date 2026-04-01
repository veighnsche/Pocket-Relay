import 'dart:convert';

import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

class TranscriptItemSupport {
  const TranscriptItemSupport({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;
  static final RegExp _imagePlaceholderPattern = RegExp(r'^\[Image #\d+\]$');

  TranscriptCanonicalItemType itemTypeFromStreamKind(
    TranscriptRuntimeContentStreamKind streamKind,
  ) {
    return switch (streamKind) {
      TranscriptRuntimeContentStreamKind.assistantText =>
        TranscriptCanonicalItemType.assistantMessage,
      TranscriptRuntimeContentStreamKind.reasoningText ||
      TranscriptRuntimeContentStreamKind.reasoningSummaryText =>
        TranscriptCanonicalItemType.reasoning,
      TranscriptRuntimeContentStreamKind.planText =>
        TranscriptCanonicalItemType.plan,
      TranscriptRuntimeContentStreamKind.commandOutput =>
        TranscriptCanonicalItemType.commandExecution,
      TranscriptRuntimeContentStreamKind.fileChangeOutput =>
        TranscriptCanonicalItemType.fileChange,
      _ => TranscriptCanonicalItemType.unknown,
    };
  }

  String? extractTextFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    final result = snapshot['result'];
    final nestedResult = result is Map<String, dynamic> ? result : null;
    return _support.stringFromCandidates(<Object?>[
      snapshot['aggregatedOutput'],
      snapshot['aggregated_output'],
      snapshot['text'],
      _textFromStructuredEntries(snapshot['summary']),
      _textFromStructuredEntries(snapshot['content']),
      snapshot['summary'],
      snapshot['review'],
      snapshot['revisedPrompt'],
      snapshot['patch'],
      snapshot['result'],
      nestedResult?['output'],
      nestedResult?['text'],
      nestedResult?['path'],
      _textFromStructuredEntries(nestedResult?['content']),
    ]);
  }

  ChatComposerDraft? extractStructuredUserMessageDraft(
    Map<String, dynamic>? snapshot,
  ) {
    final contentItems = _contentItemsFromSnapshot(snapshot);
    if (contentItems == null || contentItems.isEmpty) {
      return null;
    }

    final parsedText = _firstStructuredTextEntry(contentItems);
    final imageUrls = _remoteImageUrls(contentItems);
    if (imageUrls.isEmpty) {
      return null;
    }

    final baseText = parsedText?.text ?? '';
    final baseTextElements =
        parsedText?.textElements ?? const <ChatComposerTextElement>[];
    final imagePlaceholders = parsedText?.imagePlaceholders ?? const <String>[];
    final synthesizedPlaceholders = imageUrls.length > imagePlaceholders.length
        ? _synthesizedImagePlaceholders(
            baseText,
            imageUrls.length - imagePlaceholders.length,
          )
        : const <String>[];
    final allPlaceholders = <String>[
      ...imagePlaceholders.take(imageUrls.length),
      ...synthesizedPlaceholders,
    ];
    final effectiveTextAndElements =
        imagePlaceholders.length >= imageUrls.length
        ? (text: baseText, textElements: baseTextElements)
        : _textAndElementsWithTrailingImagePlaceholders(
            baseText: baseText,
            existingTextElements: baseTextElements,
            trailingPlaceholders: synthesizedPlaceholders,
          );
    final imageAttachments = <ChatComposerImageAttachment>[
      for (var index = 0; index < imageUrls.length; index += 1)
        ChatComposerImageAttachment(
          imageUrl: imageUrls[index],
          placeholder: allPlaceholders[index],
        ),
    ];

    final draft = ChatComposerDraft(
      text: effectiveTextAndElements.text,
      textElements: effectiveTextAndElements.textElements,
      imageAttachments: imageAttachments,
    ).normalized();
    return draft.hasStructuredDraft ? draft : null;
  }

  String? defaultLifecycleBody(TranscriptCanonicalItemType itemType) {
    return switch (itemType) {
      TranscriptCanonicalItemType.reviewEntered => 'Codex entered review mode.',
      TranscriptCanonicalItemType.reviewExited => 'Codex exited review mode.',
      TranscriptCanonicalItemType.contextCompaction =>
        'Codex compacted the current thread context.',
      _ => null,
    };
  }

  List<dynamic>? _contentItemsFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    return _listFromCandidate(snapshot['content']);
  }

  List<dynamic>? _listFromCandidate(Object? value) {
    return value is List ? List<dynamic>.from(value) : null;
  }

  _StructuredUserTextEntry? _firstStructuredTextEntry(List<dynamic> content) {
    for (final entry in content) {
      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final type = _support.stringFromCandidates(<Object?>[object['type']]);
      final text = _stringFromCandidatesPreservingWhitespace(<Object?>[
        object['text'],
        (object['content'] as Map?)?['text'],
      ]);
      final textElements = _imageTextElements(object['text_elements']);
      if (type == 'text' ||
          (type == null && (text != null || textElements.isNotEmpty))) {
        return _StructuredUserTextEntry(
          text: text ?? '',
          textElements: textElements,
        );
      }
    }

    return null;
  }

  List<String> _remoteImageUrls(List<dynamic> content) {
    final urls = <String>[];
    for (final entry in content) {
      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final type = _support.stringFromCandidates(<Object?>[object['type']]);
      if (type != 'image') {
        continue;
      }

      final url = _stringFromCandidatesPreservingWhitespace(<Object?>[
        object['image_url'],
        object['url'],
      ]);
      if (url == null || url.trim().isEmpty) {
        continue;
      }
      urls.add(url.trim());
    }
    return urls;
  }

  List<ChatComposerTextElement> _imageTextElements(Object? raw) {
    if (raw is! List) {
      return const <ChatComposerTextElement>[];
    }

    final elements = <ChatComposerTextElement>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final placeholder = _support.stringFromCandidates(<Object?>[
        object['placeholder'],
      ]);
      if (placeholder == null ||
          !_imagePlaceholderPattern.hasMatch(placeholder.trim())) {
        continue;
      }

      final byteRange = object['byteRange'] is Map
          ? Map<String, dynamic>.from(object['byteRange'] as Map)
          : object['byte_range'] is Map
          ? Map<String, dynamic>.from(object['byte_range'] as Map)
          : null;
      final start = byteRange?['start'];
      final end = byteRange?['end'];
      if (start is! num || end is! num) {
        continue;
      }

      elements.add(
        ChatComposerTextElement(
          start: start.toInt(),
          end: end.toInt(),
          placeholder: placeholder.trim(),
        ),
      );
    }

    return elements;
  }

  List<String> _synthesizedImagePlaceholders(String text, int imageCount) {
    final reservedNumbers = _placeholderNumbersInText(text);
    final placeholders = <String>[];
    var candidate = 1;
    while (placeholders.length < imageCount) {
      if (reservedNumbers.contains(candidate)) {
        candidate += 1;
        continue;
      }
      placeholders.add(imagePlaceholder(candidate));
      reservedNumbers.add(candidate);
      candidate += 1;
    }
    return placeholders;
  }

  ({String text, List<ChatComposerTextElement> textElements})
  _textAndElementsWithTrailingImagePlaceholders({
    required String baseText,
    required List<ChatComposerTextElement> existingTextElements,
    required List<String> trailingPlaceholders,
  }) {
    if (trailingPlaceholders.isEmpty) {
      return (text: baseText, textElements: existingTextElements);
    }

    final separator = baseText.isEmpty || _endsWithWhitespace(baseText)
        ? ''
        : '\n';
    final placeholderText = trailingPlaceholders.join(' ');
    final effectiveText = '$baseText$separator$placeholderText';
    final placeholderStartOffset = baseText.length + separator.length;
    final trailingElements = <ChatComposerTextElement>[];
    var cursor = placeholderStartOffset;
    for (var index = 0; index < trailingPlaceholders.length; index += 1) {
      if (index > 0) {
        cursor += 1;
      }
      final placeholder = trailingPlaceholders[index];
      final startOffset = cursor;
      cursor += placeholder.length;
      trailingElements.add(
        ChatComposerTextElement(
          start: _utf8ByteOffset(effectiveText, startOffset),
          end: _utf8ByteOffset(effectiveText, cursor),
          placeholder: placeholder,
        ),
      );
    }

    return (
      text: effectiveText,
      textElements: <ChatComposerTextElement>[
        ...existingTextElements,
        ...trailingElements,
      ],
    );
  }

  Set<int> _placeholderNumbersInText(String text) {
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

  bool _endsWithWhitespace(String text) {
    if (text.isEmpty) {
      return false;
    }
    return RegExp(r'\s$').hasMatch(text);
  }

  int _utf8ByteOffset(String text, int codeUnitOffset) {
    final safeOffset = codeUnitOffset.clamp(0, text.length).toInt();
    return utf8.encode(text.substring(0, safeOffset)).length;
  }

  String? _stringFromCandidatesPreservingWhitespace(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? _textFromStructuredEntries(Object? value) {
    if (value is! List) {
      return null;
    }

    final textParts = <String>[];
    for (final entry in value) {
      if (entry is String && entry.isNotEmpty) {
        textParts.add(entry);
        continue;
      }

      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final text = _support.stringFromCandidates(<Object?>[
        object['text'],
        (object['content'] as Map?)?['text'],
      ]);
      if (text != null && text.isNotEmpty) {
        textParts.add(text);
      }
    }

    if (textParts.isEmpty) {
      return null;
    }
    return textParts.join('\n');
  }
}

class _StructuredUserTextEntry {
  const _StructuredUserTextEntry({
    required this.text,
    required this.textElements,
  });

  final String text;
  final List<ChatComposerTextElement> textElements;

  List<String> get imagePlaceholders => textElements
      .map((element) => element.placeholder?.trim())
      .whereType<String>()
      .where((placeholder) => placeholder.isNotEmpty)
      .toList(growable: false);
}
