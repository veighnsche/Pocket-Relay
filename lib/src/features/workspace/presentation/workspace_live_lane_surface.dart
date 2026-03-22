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
  bool _isApplyingSavedSettings = false;

  void _setOpeningConnectionSettings(bool value) {
    setState(() {
      _isOpeningConnectionSettings = value;
    });
  }

  void _setApplyingSavedSettings(bool value) {
    setState(() {
      _isApplyingSavedSettings = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requiresReconnect = widget.workspaceController.state
        .requiresReconnect(widget.laneBinding.connectionId);
    final isLaneBusy = widget.laneBinding.sessionController.sessionState.isBusy;
    final chatRoot = ChatRootAdapter(
      laneBinding: widget.laneBinding,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: _handleConnectionSettingsRequested,
      supplementalMenuActions: _supplementalMenuActionsFor(
        requiresReconnect: requiresReconnect,
        isLaneBusy: isLaneBusy,
      ),
      laneRestartAction: requiresReconnect
          ? ChatLaneRestartActionContract(
              badgeLabel: ConnectionWorkspaceCopy.reconnectBadge,
              label: _isApplyingSavedSettings
                  ? ConnectionWorkspaceCopy.reconnectProgress
                  : ConnectionWorkspaceCopy.reconnectAction,
              isInProgress: _isApplyingSavedSettings,
            )
          : null,
      onRestartLane: requiresReconnect && !isLaneBusy
          ? _applySavedSettings
          : null,
    );
    return chatRoot;
  }
}
