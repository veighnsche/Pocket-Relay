import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_errors.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';

class ChatComposerImageAttachmentLoader {
  const ChatComposerImageAttachmentLoader({
    this.maximumSourceImageBytes = maximumImageBytes,
    this.targetImageBytes = defaultTargetImageBytes,
    this.maximumImageDimension = defaultMaximumImageDimension,
    this.minimumImageDimension = defaultMinimumImageDimension,
  }) : assert(maximumSourceImageBytes > 0),
       assert(targetImageBytes > 0),
       assert(maximumImageDimension > 0),
       assert(minimumImageDimension > 0),
       assert(maximumImageDimension >= minimumImageDimension);

  static const int maximumImageBytes = 50 * 1024 * 1024;
  static const int defaultTargetImageBytes = 2 * 1024 * 1024;
  static const int defaultMaximumImageDimension = 2048;
  static const int defaultMinimumImageDimension = 768;
  static const List<int> _jpegQualitySteps = <int>[85, 75, 65, 55, 45, 35];

  final int maximumSourceImageBytes;
  final int targetImageBytes;
  final int maximumImageDimension;
  final int minimumImageDimension;

  Future<ChatComposerImageAttachment> loadFromXFile(XFile file) async {
    final sourceByteLength = await file.length();
    if (sourceByteLength == 0) {
      throw ChatComposerImageAttachmentLoadException(
        ChatComposerErrors.imageAttachmentEmpty(),
      );
    }
    if (sourceByteLength > maximumSourceImageBytes) {
      throw ChatComposerImageAttachmentLoadException(
        ChatComposerErrors.imageAttachmentTooLarge(),
      );
    }

    final sourceBytes = await file.readAsBytes();
    final displayName = _resolvedDisplayName(file);
    final mimeType = _resolvedMimeType(file, sourceBytes);
    if (mimeType == null) {
      throw ChatComposerImageAttachmentLoadException(
        ChatComposerErrors.imageAttachmentUnsupportedType(),
      );
    }
    final sourceImage = img.decodeNamedImage(displayName, sourceBytes);
    if (sourceImage == null) {
      throw ChatComposerImageAttachmentLoadException(
        ChatComposerErrors.imageAttachmentDecodeFailed(),
      );
    }

    final normalizedPayload = _normalizePayload(
      sourceBytes: sourceBytes,
      sourceMimeType: mimeType,
      sourceImage: sourceImage,
    );
    return ChatComposerImageAttachment(
      imageUrl:
          'data:${normalizedPayload.mimeType};base64,'
          '${base64Encode(normalizedPayload.bytes)}',
      displayName: displayName,
      mimeType: normalizedPayload.mimeType,
      byteLength: normalizedPayload.bytes.length,
    );
  }

  _NormalizedImagePayload _normalizePayload({
    required Uint8List sourceBytes,
    required String sourceMimeType,
    required img.Image sourceImage,
  }) {
    if (sourceBytes.length <= targetImageBytes &&
        !_exceedsDimensionBudget(sourceImage)) {
      return _NormalizedImagePayload(
        bytes: sourceBytes,
        mimeType: sourceMimeType,
      );
    }

    var workingImage = _bakeOrientationIfNeeded(sourceImage);
    if (_exceedsDimensionBudget(workingImage)) {
      workingImage = _resizeToLongestEdge(workingImage, maximumImageDimension);
    }

    while (true) {
      final candidate = _bestCandidateForBudget(
        workingImage,
        preferredMimeType: sourceMimeType,
      );
      if (candidate.bytes.length <= targetImageBytes) {
        return candidate;
      }

      final currentLongestEdge = _longestEdge(workingImage);
      if (currentLongestEdge <= minimumImageDimension) {
        break;
      }

      final nextLongestEdge = _nextLongestEdge(
        currentLongestEdge: currentLongestEdge,
        currentByteLength: candidate.bytes.length,
      );
      if (nextLongestEdge >= currentLongestEdge) {
        break;
      }
      workingImage = _resizeToLongestEdge(workingImage, nextLongestEdge);
    }

    throw ChatComposerImageAttachmentLoadException(
      ChatComposerErrors.imageAttachmentTooLargeForRemote(),
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

  String? _resolvedMimeType(XFile file, List<int> bytes) {
    final detectedMimeType = _mimeTypeForDetectedFormat(bytes);
    if (detectedMimeType != null) {
      return detectedMimeType;
    }
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

  String? _mimeTypeForDetectedFormat(List<int> bytes) {
    try {
      return switch (img.findFormatForData(bytes)) {
        img.ImageFormat.jpg => 'image/jpeg',
        img.ImageFormat.png => 'image/png',
        img.ImageFormat.gif => 'image/gif',
        img.ImageFormat.webp => 'image/webp',
        _ => null,
      };
    } catch (_) {
      return null;
    }
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

  bool _exceedsDimensionBudget(img.Image image) {
    return _longestEdge(image) > maximumImageDimension;
  }

  int _longestEdge(img.Image image) => math.max(image.width, image.height);

  img.Image _bakeOrientationIfNeeded(img.Image image) {
    final orientation = image.exif.imageIfd.orientation;
    if (!image.exif.imageIfd.hasOrientation || orientation == 1) {
      return image;
    }
    return img.bakeOrientation(image);
  }

  img.Image _resizeToLongestEdge(img.Image image, int longestEdge) {
    final currentLongestEdge = _longestEdge(image);
    if (currentLongestEdge <= longestEdge) {
      return image;
    }

    final scale = longestEdge / currentLongestEdge;
    final width = math.max(1, (image.width * scale).round());
    final height = math.max(1, (image.height * scale).round());
    return img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
  }

  _NormalizedImagePayload _bestCandidateForBudget(
    img.Image image, {
    required String preferredMimeType,
  }) {
    _NormalizedImagePayload? smallestCandidate;
    for (final candidate in _payloadCandidates(
      image,
      preferredMimeType: preferredMimeType,
    )) {
      if (smallestCandidate == null ||
          candidate.bytes.length < smallestCandidate.bytes.length) {
        smallestCandidate = candidate;
      }
      if (candidate.bytes.length <= targetImageBytes) {
        return candidate;
      }
    }

    if (smallestCandidate != null) {
      return smallestCandidate;
    }
    throw ChatComposerImageAttachmentLoadException(
      ChatComposerErrors.imageAttachmentUnsupportedType(),
    );
  }

  Iterable<_NormalizedImagePayload> _payloadCandidates(
    img.Image image, {
    required String preferredMimeType,
  }) sync* {
    final canEncodeAsJpeg = _canEncodeAsJpeg(image);
    switch (preferredMimeType) {
      case 'image/jpeg':
        yield* _jpegCandidates(image);
        return;
      case 'image/png':
        yield _pngCandidate(image);
        if (canEncodeAsJpeg) {
          yield* _jpegCandidates(image);
        }
        return;
      case 'image/webp':
        if (canEncodeAsJpeg) {
          yield* _jpegCandidates(image);
        } else {
          yield _pngCandidate(image);
        }
        return;
      case 'image/gif':
        if (image.hasAnimation) {
          yield _gifCandidate(image);
        } else if (canEncodeAsJpeg) {
          yield* _jpegCandidates(image);
          yield _pngCandidate(image);
        } else {
          yield _pngCandidate(image);
        }
        return;
    }
  }

  Iterable<_NormalizedImagePayload> _jpegCandidates(img.Image image) sync* {
    for (final quality in _jpegQualitySteps) {
      yield _NormalizedImagePayload(
        bytes: img.encodeJpg(
          image,
          quality: quality,
          chroma: img.JpegChroma.yuv420,
        ),
        mimeType: 'image/jpeg',
      );
    }
  }

  _NormalizedImagePayload _pngCandidate(img.Image image) {
    return _NormalizedImagePayload(
      bytes: img.encodePng(image, level: 9),
      mimeType: 'image/png',
    );
  }

  _NormalizedImagePayload _gifCandidate(img.Image image) {
    return _NormalizedImagePayload(
      bytes: img.encodeGif(image),
      mimeType: 'image/gif',
    );
  }

  bool _canEncodeAsJpeg(img.Image image) {
    if (image.hasAnimation) {
      return false;
    }
    if (!image.hasAlpha) {
      return true;
    }

    for (final frame in image.frames) {
      final maxAlpha = frame.maxChannelValue;
      for (final pixel in frame) {
        if (pixel.a < maxAlpha) {
          return false;
        }
      }
    }
    return true;
  }

  int _nextLongestEdge({
    required int currentLongestEdge,
    required int currentByteLength,
  }) {
    final byteRatio = targetImageBytes / currentByteLength;
    final scale = (math.sqrt(byteRatio) * 0.95).clamp(0.5, 0.85).toDouble();
    final proposedLongestEdge = (currentLongestEdge * scale).round();
    return math.max(
      minimumImageDimension,
      math.min(currentLongestEdge - 1, proposedLongestEdge),
    );
  }
}

class ChatComposerImageAttachmentLoadException implements Exception {
  const ChatComposerImageAttachmentLoadException(this.userFacingError);

  final PocketUserFacingError userFacingError;

  String get message => userFacingError.message;

  @override
  String toString() => userFacingError.inlineMessage;
}

class _NormalizedImagePayload {
  const _NormalizedImagePayload({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}
