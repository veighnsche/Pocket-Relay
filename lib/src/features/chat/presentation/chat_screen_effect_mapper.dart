import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';

class ChatScreenEffectMapper {
  const ChatScreenEffectMapper();

  ChatScreenEffect mapSnackBarMessage(String message) {
    return ChatShowSnackBarEffect(message: message);
  }

  ChatScreenEffect? mapAction({
    required ChatScreenActionId action,
    required ChatScreenContract screen,
  }) {
    return switch (action) {
      ChatScreenActionId.openSettings => ChatOpenConnectionSettingsEffect(
        payload: screen.connectionSettings,
      ),
      ChatScreenActionId.newThread || ChatScreenActionId.clearTranscript => null,
    };
  }
}
