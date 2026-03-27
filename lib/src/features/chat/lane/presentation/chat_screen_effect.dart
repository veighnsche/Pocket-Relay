import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

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

final class ChatOpenChangedFileDiffEffect extends ChatScreenEffect {
  const ChatOpenChangedFileDiffEffect({required this.payload});

  final ChatChangedFileDiffContract payload;
}

final class ChatOpenWorkLogTerminalEffect extends ChatScreenEffect {
  const ChatOpenWorkLogTerminalEffect({required this.payload});

  final ChatWorkLogTerminalContract payload;
}
