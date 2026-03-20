import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

import 'connection_workspace_conversation_history_sheet.dart';

class ConnectionWorkspaceLiveLaneSurface extends StatefulWidget {
  const ConnectionWorkspaceLiveLaneSurface({
    super.key,
    required this.workspaceController,
    required this.laneBinding,
    required this.platformPolicy,
    required this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final CodexWorkspaceConversationHistoryRepository
  conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<ConnectionWorkspaceLiveLaneSurface> createState() =>
      _ConnectionWorkspaceLiveLaneSurfaceState();
}

class _ConnectionWorkspaceLiveLaneSurfaceState
    extends State<ConnectionWorkspaceLiveLaneSurface> {
  bool _isOpeningConnectionSettings = false;
  bool _isApplyingSavedSettings = false;

  @override
  Widget build(BuildContext context) {
    final requiresReconnect = widget.workspaceController.state
        .requiresReconnect(widget.laneBinding.connectionId);
    final chatRoot = ChatRootAdapter(
      laneBinding: widget.laneBinding,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: _handleConnectionSettingsRequested,
      supplementalMenuActions: _supplementalMenuActionsFor(
        requiresReconnect: requiresReconnect,
      ),
    );
    if (!requiresReconnect) {
      return chatRoot;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _SavedSettingsNotice(
            isApplying: _isApplyingSavedSettings,
            onApply: _applySavedSettings,
          ),
        ),
        Expanded(child: chatRoot),
      ],
    );
  }

  List<ChatChromeMenuAction> _supplementalMenuActionsFor({
    required bool requiresReconnect,
  }) {
    final hasWorkspaceHistoryScope = widget
        .laneBinding
        .sessionController
        .profile
        .workspaceDir
        .trim()
        .isNotEmpty;
    return <ChatChromeMenuAction>[
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
        onSelected: () {
          unawaited(_showConversationHistory());
        },
        isEnabled: hasWorkspaceHistoryScope,
      ),
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.savedConnectionsMenuLabel,
        onSelected: widget.workspaceController.showDormantRoster,
      ),
      if (requiresReconnect)
        ChatChromeMenuAction(
          label: _isApplyingSavedSettings
              ? ConnectionWorkspaceCopy.reconnectMenuProgress
              : ConnectionWorkspaceCopy.reconnectMenuAction,
          onSelected: () {
            unawaited(_applySavedSettings());
          },
          isEnabled: hasWorkspaceHistoryScope,
        ),
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.closeLaneAction,
        onSelected: () => widget.workspaceController.terminateConnection(
          widget.laneBinding.connectionId,
        ),
        isDestructive: true,
        isEnabled: hasWorkspaceHistoryScope,
      ),
    ];
  }

  Future<void> _handleConnectionSettingsRequested(
    ChatConnectionSettingsLaunchContract request,
  ) async {
    if (_isOpeningConnectionSettings) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final laneBinding = widget.laneBinding;
    final settingsOverlayDelegate = widget.settingsOverlayDelegate;
    final platformPolicy = widget.platformPolicy;
    final connectionId = laneBinding.connectionId;

    setState(() {
      _isOpeningConnectionSettings = true;
    });

    try {
      final initialSettings = await _resolveInitialSettings(
        request: request,
        workspaceController: workspaceController,
        connectionId: connectionId,
      );
      if (!_matchesLiveRequestContext(
        workspaceController: workspaceController,
        laneBinding: laneBinding,
        settingsOverlayDelegate: settingsOverlayDelegate,
        platformPolicy: platformPolicy,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }

      final result = await settingsOverlayDelegate.openConnectionSettings(
        context: context,
        initialProfile: initialSettings.$1,
        initialSecrets: initialSettings.$2,
        platformBehavior: platformPolicy.behavior,
      );
      if (!_matchesLiveRequestContext(
            workspaceController: workspaceController,
            laneBinding: laneBinding,
            settingsOverlayDelegate: settingsOverlayDelegate,
            platformPolicy: platformPolicy,
          ) ||
          result == null) {
        return;
      }

      if (result.profile == initialSettings.$1 &&
          result.secrets == initialSettings.$2) {
        return;
      }

      await workspaceController.saveLiveConnectionEdits(
        connectionId: connectionId,
        profile: result.profile,
        secrets: result.secrets,
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        setState(() {
          _isOpeningConnectionSettings = false;
        });
      }
    }
  }

  Future<void> _applySavedSettings() async {
    if (_isApplyingSavedSettings) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final laneBinding = widget.laneBinding;
    final connectionId = laneBinding.connectionId;
    if (!workspaceController.state.requiresReconnect(connectionId)) {
      return;
    }

    setState(() {
      _isApplyingSavedSettings = true;
    });

    try {
      await workspaceController.reconnectConnection(connectionId);
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        setState(() {
          _isApplyingSavedSettings = false;
        });
      }
    }
  }

  Future<void> _showConversationHistory() {
    final sessionController = widget.laneBinding.sessionController;
    final profile = sessionController.profile;
    final secrets = sessionController.secrets;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: ConnectionWorkspaceConversationHistorySheet(
            title: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
            future: _loadConversationHistory(
              profile: profile,
              secrets: secrets,
            ),
            onConversationSelected: (conversation) async {
              Navigator.of(sheetContext).pop();
              await widget.workspaceController.resumeConversation(
                connectionId: widget.laneBinding.connectionId,
                threadId: conversation.sessionId,
              );
            },
          ),
        );
      },
    );
  }

  Future<List<CodexWorkspaceConversationSummary>> _loadConversationHistory({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final savedStateFuture = widget.laneBinding.conversationStateStore
        .loadState();
    List<CodexWorkspaceConversationSummary> workspaceConversations;
    Object? workspaceLoadError;
    StackTrace? workspaceLoadStackTrace;

    try {
      workspaceConversations = await widget.conversationHistoryRepository
          .loadWorkspaceConversations(profile: profile, secrets: secrets);
    } catch (error, stackTrace) {
      workspaceConversations = const <CodexWorkspaceConversationSummary>[];
      workspaceLoadError = error;
      workspaceLoadStackTrace = stackTrace;
    }

    final savedState = await savedStateFuture;
    final mergedConversations = _mergeConversationSummaries(
      workspaceConversations: workspaceConversations,
      savedState: savedState,
      workspaceDir: profile.workspaceDir.trim(),
    );
    if (mergedConversations.isNotEmpty || workspaceLoadError == null) {
      return mergedConversations;
    }

    Error.throwWithStackTrace(
      workspaceLoadError,
      workspaceLoadStackTrace ?? StackTrace.current,
    );
  }

  List<CodexWorkspaceConversationSummary> _mergeConversationSummaries({
    required List<CodexWorkspaceConversationSummary> workspaceConversations,
    required SavedConnectionConversationState savedState,
    required String workspaceDir,
  }) {
    final conversationsById = <String, CodexWorkspaceConversationSummary>{};
    final orderedConversationIds = <String>[];

    void addConversation(CodexWorkspaceConversationSummary conversation) {
      final normalizedSessionId = conversation.sessionId.trim();
      if (normalizedSessionId.isEmpty) {
        return;
      }

      final normalizedConversation = CodexWorkspaceConversationSummary(
        sessionId: normalizedSessionId,
        preview: conversation.preview,
        cwd: conversation.cwd,
        messageCount: conversation.messageCount,
        firstPromptAt: conversation.firstPromptAt,
        lastActivityAt: conversation.lastActivityAt,
      );
      final existingConversation = conversationsById[normalizedSessionId];
      if (existingConversation == null) {
        conversationsById[normalizedSessionId] = normalizedConversation;
        orderedConversationIds.add(normalizedSessionId);
        return;
      }

      conversationsById[normalizedSessionId] = _preferRicherConversation(
        existingConversation,
        normalizedConversation,
      );
    }

    for (final conversation in workspaceConversations) {
      addConversation(conversation);
    }

    for (final conversation in savedState.conversations) {
      addConversation(
        _summaryFromSavedConversation(
          conversation: conversation,
          workspaceDir: workspaceDir,
        ),
      );
    }

    final selectedThreadId = savedState.normalizedSelectedThreadId;
    if (selectedThreadId != null) {
      addConversation(
        CodexWorkspaceConversationSummary(
          sessionId: selectedThreadId,
          preview: '',
          cwd: workspaceDir,
          messageCount: 1,
          firstPromptAt: null,
          lastActivityAt: null,
        ),
      );
    }

    return <CodexWorkspaceConversationSummary>[
      for (final conversationId in orderedConversationIds)
        conversationsById[conversationId]!,
    ];
  }

  CodexWorkspaceConversationSummary _summaryFromSavedConversation({
    required SavedResumableConversation conversation,
    required String workspaceDir,
  }) {
    return CodexWorkspaceConversationSummary(
      sessionId: conversation.normalizedThreadId,
      preview: conversation.preview,
      cwd: workspaceDir,
      messageCount: conversation.messageCount,
      firstPromptAt: conversation.firstPromptAt,
      lastActivityAt: conversation.lastActivityAt,
    );
  }

  CodexWorkspaceConversationSummary _preferRicherConversation(
    CodexWorkspaceConversationSummary existingConversation,
    CodexWorkspaceConversationSummary candidateConversation,
  ) {
    final existingScore = _conversationScore(existingConversation);
    final candidateScore = _conversationScore(candidateConversation);
    return candidateScore > existingScore
        ? candidateConversation
        : existingConversation;
  }

  int _conversationScore(CodexWorkspaceConversationSummary conversation) {
    var score = 0;
    if (conversation.trimmedPreview.isNotEmpty) {
      score += 4;
    }
    if (conversation.messageCount > 0) {
      score += 2;
    }
    if (conversation.lastActivityAt != null) {
      score += 1;
    }
    if (conversation.cwd.trim().isNotEmpty) {
      score += 1;
    }
    return score;
  }

  Future<(ConnectionProfile, ConnectionSecrets)> _resolveInitialSettings({
    required ChatConnectionSettingsLaunchContract request,
    required ConnectionWorkspaceController workspaceController,
    required String connectionId,
  }) async {
    if (!workspaceController.state.requiresReconnect(connectionId)) {
      return (request.initialProfile, request.initialSecrets);
    }

    final savedConnection = await workspaceController.loadSavedConnection(
      connectionId,
    );
    return (savedConnection.profile, savedConnection.secrets);
  }

  bool _matchesLiveRequestContext({
    required ConnectionWorkspaceController workspaceController,
    required ConnectionLaneBinding laneBinding,
    required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
    required PocketPlatformPolicy platformPolicy,
  }) {
    return mounted &&
        widget.workspaceController == workspaceController &&
        widget.laneBinding == laneBinding &&
        widget.settingsOverlayDelegate == settingsOverlayDelegate &&
        widget.platformPolicy == platformPolicy &&
        widget.workspaceController.state.isConnectionLive(
          laneBinding.connectionId,
        );
  }
}

class _SavedSettingsNotice extends StatelessWidget {
  const _SavedSettingsNotice({required this.isApplying, required this.onApply});

  final bool isApplying;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.sync, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ConnectionWorkspaceCopy.reconnectNoticeTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ConnectionWorkspaceCopy.reconnectNoticeBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const ValueKey('apply_saved_settings'),
              onPressed: isApplying
                  ? null
                  : () {
                      unawaited(onApply());
                    },
              child: Text(
                isApplying
                    ? ConnectionWorkspaceCopy.reconnectProgress
                    : ConnectionWorkspaceCopy.reconnectAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
