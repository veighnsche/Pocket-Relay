import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_surface.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.platformBehavior,
    required this.contract,
    required this.onChanged,
    required this.onSend,
  });

  final PocketPlatformBehavior platformBehavior;
  final ChatComposerContract contract;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return ChatComposerSurface(
      platformBehavior: platformBehavior,
      contract: contract,
      onChanged: onChanged,
      onSend: onSend,
    );
  }
}
