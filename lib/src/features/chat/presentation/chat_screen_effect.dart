import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

sealed class ChatScreenEffect {
  const ChatScreenEffect();
}

final class ChatShowSnackBarEffect extends ChatScreenEffect {
  const ChatShowSnackBarEffect({required this.message});

  final String message;
}

final class ChatOpenConnectionSettingsEffect extends ChatScreenEffect {
  const ChatOpenConnectionSettingsEffect({required this.payload});

  final ChatConnectionSettingsLaunchContract payload;
}
