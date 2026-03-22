import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';

class ChatComposerDraftHost extends ChangeNotifier {
  ChatComposerDraft _draft = const ChatComposerDraft();

  ChatComposerDraft get draft => _draft;

  void updateDraft(ChatComposerDraft draft) {
    if (_draft == draft) {
      return;
    }

    _draft = draft;
    notifyListeners();
  }

  void updateText(String text) {
    updateDraft(_draft.copyWith(text: text));
  }

  void clear() {
    updateDraft(const ChatComposerDraft());
  }

  void reset() {
    clear();
  }
}
