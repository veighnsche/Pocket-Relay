import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';

class ChatComposerImageAttachmentLoader {
  const ChatComposerImageAttachmentLoader();

  static const int maximumImageBytes = 50 * 1024 * 1024;

  Future<ChatComposerImageAttachment> loadFromXFile(XFile file) async {
    final byteLength = await file.length();
    if (byteLength == 0) {
      throw const ChatComposerImageAttachmentLoadException(
        'The selected image was empty.',
      );
    }
    if (byteLength > maximumImageBytes) {
      throw const ChatComposerImageAttachmentLoadException(
        'Images larger than 50 MB are not supported.',
      );
    }

    final bytes = await file.readAsBytes();
    final mimeType = _resolvedMimeType(file);
    if (mimeType == null) {
      throw const ChatComposerImageAttachmentLoadException(
        'Unsupported image type.',
      );
    }

    final displayName = _resolvedDisplayName(file);
    return ChatComposerImageAttachment(
      imageUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
      displayName: displayName,
      mimeType: mimeType,
      byteLength: byteLength,
    );
  }

  String _resolvedDisplayName(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) {
      return name;
    }

    final path = file.path.trim();
    if (path.isEmpty) {
      return 'image';
    }

    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    for (var index = segments.length - 1; index >= 0; index -= 1) {
      final segment = segments[index].trim();
      if (segment.isNotEmpty) {
        return segment;
      }
    }
    return 'image';
  }

  String? _resolvedMimeType(XFile file) {
    final explicitMimeType = _normalizeMimeType(file.mimeType);
    if (explicitMimeType != null) {
      return explicitMimeType;
    }

    final lowerName = _resolvedDisplayName(file).toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    return null;
  }

  String? _normalizeMimeType(String? rawMimeType) {
    final mimeType = rawMimeType?.trim().toLowerCase();
    if (mimeType == null || mimeType.isEmpty) {
      return null;
    }

    return switch (mimeType) {
      'image/jpg' => 'image/jpeg',
      'image/jpeg' || 'image/png' || 'image/gif' || 'image/webp' => mimeType,
      _ => null,
    };
  }
}

class ChatComposerImageAttachmentLoadException implements Exception {
  const ChatComposerImageAttachmentLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
