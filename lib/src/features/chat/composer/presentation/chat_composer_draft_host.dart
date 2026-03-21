import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';

class ChatComposerDraftHost extends ChangeNotifier {
  ChatComposerDraft _draft = const ChatComposerDraft();

  ChatComposerDraft get draft => _draft;

  void updateText(String text) {
    if (_draft.text == text) {
      return;
    }

    _draft = ChatComposerDraft(text: text);
    notifyListeners();
  }

  void clear() {
    updateText('');
  }

  void reset() {
    clear();
  }
}
