import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart';

void main() {
  const loader = ChatComposerImageAttachmentLoader();

  test('builds a remote-safe image attachment from an XFile', () async {
    final sourceBytes = img.encodePng(img.Image(width: 1, height: 1));
    final attachment = await loader.loadFromXFile(
      XFile.fromData(
        sourceBytes,
        path: '/tmp/reference.png',
        mimeType: 'image/png',
      ),
    );

    expect(
      attachment.imageUrl,
      'data:image/png;base64,${base64Encode(sourceBytes)}',
    );
    expect(attachment.displayName, 'reference.png');
    expect(attachment.mimeType, 'image/png');
    expect(attachment.byteLength, sourceBytes.length);
  });

  test(
    'shrinks oversized opaque images before building the remote-safe data URL',
    () async {
      final loader = ChatComposerImageAttachmentLoader(
        targetImageBytes: 48 * 1024,
        maximumImageDimension: 512,
        minimumImageDimension: 256,
      );
      final sourceBytes = _encodeOpaqueNoisePng(width: 1200, height: 900);

      final attachment = await loader.loadFromXFile(
        XFile.fromData(
          sourceBytes,
          path: '/tmp/reference.png',
          mimeType: 'image/png',
        ),
      );

      final payload = _decodeDataUrl(attachment.imageUrl);
      final decoded = img.decodeImage(payload.bytes);

      expect(payload.mimeType, attachment.mimeType);
      expect(attachment.byteLength, lessThanOrEqualTo(48 * 1024));
      expect(attachment.byteLength, lessThan(sourceBytes.length));
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(512));
      expect(decoded.height, lessThanOrEqualTo(512));
    },
  );

  test(
    'rejects alpha images that still exceed the configured byte budget',
    () async {
      final loader = ChatComposerImageAttachmentLoader(
        targetImageBytes: 512,
        maximumImageDimension: 64,
        minimumImageDimension: 64,
      );
      final sourceBytes = _encodeTransparentNoisePng(width: 64, height: 64);

      await expectLater(
        loader.loadFromXFile(
          XFile.fromData(
            sourceBytes,
            path: '/tmp/reference.png',
            mimeType: 'image/png',
          ),
        ),
        throwsA(
          isA<ChatComposerImageAttachmentLoadException>().having(
            (error) => error.message,
            'message',
            contains('Could not shrink this image enough'),
          ),
        ),
      );
    },
  );

  test('rejects unsupported image types', () async {
    await expectLater(
      loader.loadFromXFile(
        XFile.fromData(
          Uint8List.fromList(<int>[1, 2, 3]),
          name: 'reference.bmp',
          mimeType: 'image/bmp',
        ),
      ),
      throwsA(isA<ChatComposerImageAttachmentLoadException>()),
    );
  });
}

Uint8List _encodeOpaqueNoisePng({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      image.setPixelRgb(
        x,
        y,
        (x * 17 + y * 13) % 256,
        (x * 29 + y * 19) % 256,
        (x * 37 + y * 23) % 256,
      );
    }
  }
  return img.encodePng(image, level: 9);
}

Uint8List _encodeTransparentNoisePng({
  required int width,
  required int height,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      image.setPixelRgba(
        x,
        y,
        (x * 11 + y * 5) % 256,
        (x * 7 + y * 17) % 256,
        (x * 19 + y * 3) % 256,
        (x * 13 + y * 29) % 256,
      );
    }
  }
  return img.encodePng(image, level: 9);
}

({String mimeType, Uint8List bytes}) _decodeDataUrl(String dataUrl) {
  final match = RegExp(r'^data:([^;]+);base64,(.+)$').firstMatch(dataUrl);
  expect(match, isNotNull);
  return (
    mimeType: match!.group(1)!,
    bytes: Uint8List.fromList(base64Decode(match.group(2)!)),
  );
}
