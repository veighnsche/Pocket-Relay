import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatComposerDraftHost', () {
    test('models draft updates and clear behavior above the renderer', () {
      final host = ChatComposerDraftHost();

      expect(host.draft.text, isEmpty);

      host.updateText('  draft text  ');
      expect(host.draft.text, '  draft text  ');

      host.clear();
      expect(host.draft.text, isEmpty);
    });

    test('reset clears draft state above the renderer', () {
      final host = ChatComposerDraftHost();

      host.updateText('draft to reset');
      host.reset();

      expect(host.draft.text, isEmpty);
    });
  });
}
