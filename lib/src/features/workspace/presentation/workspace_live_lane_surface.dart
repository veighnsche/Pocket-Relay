import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

import 'workspace_conversation_history_sheet.dart';

part 'workspace_live_lane_surface_menu.dart';
part 'workspace_live_lane_surface_settings.dart';

class ConnectionWorkspaceLiveLaneSurface extends StatefulWidget {
  const ConnectionWorkspaceLiveLaneSurface({
    super.key,
    required this.workspaceController,
    required this.laneBinding,
    required this.platformPolicy,
    this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final CodexWorkspaceConversationHistoryRepository?
  conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<ConnectionWorkspaceLiveLaneSurface> createState() =>
      _ConnectionWorkspaceLiveLaneSurfaceState();
}

class _ConnectionWorkspaceLiveLaneSurfaceState
    extends State<ConnectionWorkspaceLiveLaneSurface> {
  bool _isOpeningConnectionSettings = false;
  bool _isRestartingLane = false;

  void _setOpeningConnectionSettings(bool value) {
    setState(() {
      _isOpeningConnectionSettings = value;
    });
  }

  void _setRestartingLane(bool value) {
    setState(() {
      _isRestartingLane = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = widget.workspaceController.state;
    final reconnectRequirement = workspaceState.reconnectRequirementFor(
      widget.laneBinding.connectionId,
    );
    final transportRecoveryPhase = workspaceState.transportRecoveryPhaseFor(
      widget.laneBinding.connectionId,
    );
    final isLaneBusy = widget.laneBinding.sessionController.sessionState.isBusy;
    final isTransportReconnectInProgress =
        transportRecoveryPhase ==
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting;
    final isRestartInProgress =
        _isRestartingLane || isTransportReconnectInProgress;
    final chatRoot = ChatRootAdapter(
      laneBinding: widget.laneBinding,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: _handleConnectionSettingsRequested,
      supplementalMenuActions: _supplementalMenuActionsFor(
        reconnectRequirement: reconnectRequirement,
        isLaneBusy: isLaneBusy,
        isRestartInProgress: isRestartInProgress,
      ),
      supplementalComposerNotice: _transportRecoveryNoticeFor(
        transportRecoveryPhase,
      ),
      laneRestartAction: reconnectRequirement != null
          ? ChatLaneRestartActionContract(
              badgeLabel: ConnectionWorkspaceCopy.reconnectBadgeFor(
                reconnectRequirement,
              ),
              label: isRestartInProgress
                  ? ConnectionWorkspaceCopy.reconnectProgressFor(
                      reconnectRequirement,
                    )
                  : ConnectionWorkspaceCopy.reconnectActionFor(
                      reconnectRequirement,
                    ),
              isInProgress: isRestartInProgress,
            )
          : null,
      onRestartLane:
          reconnectRequirement != null && !isLaneBusy && !isRestartInProgress
          ? _restartLane
          : null,
    );
    return chatRoot;
  }

  Widget? _transportRecoveryNoticeFor(
    ConnectionWorkspaceTransportRecoveryPhase? phase,
  ) {
    final sessionController = widget.laneBinding.sessionController;
    if (phase == null ||
        sessionController.historicalConversationRestoreState != null ||
        sessionController.conversationRecoveryState != null) {
      return null;
    }

    final (title, message, isLoading) = switch (phase) {
      ConnectionWorkspaceTransportRecoveryPhase.lost => (
        ConnectionWorkspaceCopy.transportLostNoticeTitle,
        ConnectionWorkspaceCopy.transportLostNoticeMessage,
        false,
      ),
      ConnectionWorkspaceTransportRecoveryPhase.reconnecting => (
        ConnectionWorkspaceCopy.reconnectingNoticeTitle,
        ConnectionWorkspaceCopy.reconnectingNoticeMessage,
        true,
      ),
      ConnectionWorkspaceTransportRecoveryPhase.unavailable => (
        ConnectionWorkspaceCopy.transportUnavailableNoticeTitle,
        ConnectionWorkspaceCopy.transportUnavailableNoticeMessage,
        false,
      ),
    };
    return _WorkspaceLaneTransportNotice(
      title: title,
      message: message,
      isLoading: isLoading,
    );
  }
}

class _WorkspaceLaneTransportNotice extends StatelessWidget {
  const _WorkspaceLaneTransportNotice({
    required this.title,
    required this.message,
    required this.isLoading,
  });

  final String title;
  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = theme.colorScheme.onSecondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(Icons.portable_wifi_off_rounded, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.88),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
