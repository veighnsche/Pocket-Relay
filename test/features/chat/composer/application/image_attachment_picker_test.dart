import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/composer/application/chat_composer_image_attachment_picker.dart';

void main() {
  test(
    'pickImageFile requests image filters for every supported platform',
    () async {
      List<XTypeGroup>? capturedAcceptedTypeGroups;
      final picker = ChatComposerImageAttachmentPicker(
        openImageFile:
            ({
              List<XTypeGroup>? acceptedTypeGroups,
              String? initialDirectory,
              String? confirmButtonText,
            }) async {
              capturedAcceptedTypeGroups = acceptedTypeGroups;
              return null;
            },
      );

      await picker.pickImageFile();

      expect(capturedAcceptedTypeGroups, hasLength(1));
      expect(
        capturedAcceptedTypeGroups!.single,
        ChatComposerImageAttachmentPicker.imageTypeGroup,
      );
      expect(capturedAcceptedTypeGroups!.single.extensions, const <String>[
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
      ]);
      expect(capturedAcceptedTypeGroups!.single.mimeTypes, const <String>[
        'image/png',
        'image/jpeg',
        'image/gif',
        'image/webp',
      ]);
      expect(
        capturedAcceptedTypeGroups!.single.uniformTypeIdentifiers,
        const <String>['public.image'],
      );
      expect(capturedAcceptedTypeGroups!.single.webWildCards, const <String>[
        'image/*',
      ]);
    },
  );

  test('pickImageFile returns the selected file', () async {
    final selectedFile = XFile.fromData(
      Uint8List.fromList(const <int>[1, 2, 3]),
      name: 'reference.png',
      mimeType: 'image/png',
    );
    final picker = ChatComposerImageAttachmentPicker(
      openImageFile:
          ({
            List<XTypeGroup>? acceptedTypeGroups,
            String? initialDirectory,
            String? confirmButtonText,
          }) async => selectedFile,
    );

    expect(await picker.pickImageFile(), same(selectedFile));
  });
}
