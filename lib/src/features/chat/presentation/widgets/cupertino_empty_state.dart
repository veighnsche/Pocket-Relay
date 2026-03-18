import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_empty_state_body.dart';

class CupertinoEmptyState extends StatelessWidget {
  const CupertinoEmptyState({
    super.key,
    required this.isConfigured,
    required this.connectionMode,
    required this.platformBehavior,
    required this.onConfigure,
    this.onSelectConnectionMode,
  });

  final bool isConfigured;
  final ConnectionMode connectionMode;
  final PocketPlatformBehavior platformBehavior;
  final VoidCallback onConfigure;
  final ValueChanged<ConnectionMode>? onSelectConnectionMode;

  @override
  Widget build(BuildContext context) {
    return ChatEmptyStateBody(
      isConfigured: isConfigured,
      connectionMode: connectionMode,
      platformBehavior: platformBehavior,
      onConfigure: onConfigure,
      onSelectConnectionMode: onSelectConnectionMode,
      style: ChatEmptyStateVisualStyle.cupertino,
    );
  }
}
