import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_empty_state_body.dart';

enum ChatEmptyStateRenderer { flutter, cupertino }

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.isConfigured,
    required this.connectionMode,
    required this.onConfigure,
    this.onSelectConnectionMode,
  });

  final bool isConfigured;
  final ConnectionMode connectionMode;
  final VoidCallback onConfigure;
  final ValueChanged<ConnectionMode>? onSelectConnectionMode;

  @override
  Widget build(BuildContext context) {
    return ChatEmptyStateBody(
      isConfigured: isConfigured,
      connectionMode: connectionMode,
      onConfigure: onConfigure,
      onSelectConnectionMode: onSelectConnectionMode,
      style: ChatEmptyStateVisualStyle.material,
    );
  }
}
