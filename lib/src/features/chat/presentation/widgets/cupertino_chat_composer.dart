import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer_surface.dart';

class CupertinoChatComposerRegion extends StatelessWidget {
  const CupertinoChatComposerRegion({
    super.key,
    required this.conversationRecoveryNotice,
    required this.composer,
    required this.onComposerDraftChanged,
    required this.onSendPrompt,
    required this.onStopActiveTurn,
    required this.onConversationRecoveryAction,
  });

  final ChatConversationRecoveryNoticeContract? conversationRecoveryNotice;
  final ChatComposerContract composer;
  final ValueChanged<String> onComposerDraftChanged;
  final Future<void> Function() onSendPrompt;
  final Future<void> Function() onStopActiveTurn;
  final ValueChanged<ChatConversationRecoveryActionId>
  onConversationRecoveryAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conversationRecoveryNotice case final notice?) ...[
              _CupertinoConversationRecoveryNotice(
                notice: notice,
                onAction: onConversationRecoveryAction,
              ),
              const SizedBox(height: 10),
            ],
            CupertinoChatComposer(
              contract: composer,
              onChanged: onComposerDraftChanged,
              onSend: onSendPrompt,
              onStop: onStopActiveTurn,
            ),
          ],
        ),
      ),
    );
  }
}

class CupertinoChatComposer extends StatelessWidget {
  const CupertinoChatComposer({
    super.key,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
  });

  final ChatComposerContract contract;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return ChatComposerSurface(
      contract: contract,
      onChanged: onChanged,
      onSend: onSend,
      onStop: onStop,
      style: ChatComposerVisualStyle.cupertino,
    );
  }
}

class _CupertinoConversationRecoveryNotice extends StatelessWidget {
  const _CupertinoConversationRecoveryNotice({
    required this.notice,
    required this.onAction,
  });

  final ChatConversationRecoveryNoticeContract notice;
  final ValueChanged<ChatConversationRecoveryActionId> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notice.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              notice.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: notice.actions
                  .map<Widget>((action) {
                    final key = ValueKey<String>(
                      'conversation_recovery_${action.id.name}',
                    );
                    if (action.isPrimary) {
                      return CupertinoButton.filled(
                        key: key,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        onPressed: () => onAction(action.id),
                        child: Text(action.label),
                      );
                    }

                    return CupertinoButton(
                      key: key,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      onPressed: () => onAction(action.id),
                      child: Text(action.label),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
