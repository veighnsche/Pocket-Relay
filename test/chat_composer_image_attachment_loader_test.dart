import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_loader.dart';

void main() {
  const loader = ChatComposerImageAttachmentLoader();

  test('builds a remote-safe image attachment from an XFile', () async {
    final attachment = await loader.loadFromXFile(
      XFile.fromData(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
        path: '/tmp/reference.png',
        mimeType: 'image/png',
      ),
    );

    expect(attachment.imageUrl, 'data:image/png;base64,AQIDBA==');
    expect(attachment.displayName, 'reference.png');
    expect(attachment.mimeType, 'image/png');
    expect(attachment.byteLength, 4);
  });

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
