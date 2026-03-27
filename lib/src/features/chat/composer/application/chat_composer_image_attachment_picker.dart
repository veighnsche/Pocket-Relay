import 'package:file_selector/file_selector.dart' as file_selector;

typedef ChatComposerOpenImageFile =
    Future<file_selector.XFile?> Function({
      List<file_selector.XTypeGroup>? acceptedTypeGroups,
      String? initialDirectory,
      String? confirmButtonText,
    });

class ChatComposerImageAttachmentPicker {
  const ChatComposerImageAttachmentPicker({
    this.openImageFile = _openImageFile,
  });

  static const file_selector.XTypeGroup imageTypeGroup =
      file_selector.XTypeGroup(
        label: 'images',
        extensions: <String>['png', 'jpg', 'jpeg', 'gif', 'webp'],
        mimeTypes: <String>[
          'image/png',
          'image/jpeg',
          'image/gif',
          'image/webp',
        ],
        uniformTypeIdentifiers: <String>['public.image'],
        webWildCards: <String>['image/*'],
      );

  final ChatComposerOpenImageFile openImageFile;

  Future<file_selector.XFile?> pickImageFile() {
    return openImageFile(
      acceptedTypeGroups: const <file_selector.XTypeGroup>[imageTypeGroup],
    );
  }
}

Future<file_selector.XFile?> _openImageFile({
  List<file_selector.XTypeGroup>? acceptedTypeGroups,
  String? initialDirectory,
  String? confirmButtonText,
}) {
  return file_selector.openFile(
    acceptedTypeGroups:
        acceptedTypeGroups ?? const <file_selector.XTypeGroup>[],
    initialDirectory: initialDirectory,
    confirmButtonText: confirmButtonText,
  );
}
