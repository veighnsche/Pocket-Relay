import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';

part 'workspace_desktop_shell_sidebar.dart';
part 'workspace_desktop_shell_sidebar_collapsed.dart';
part 'workspace_desktop_shell_sidebar_expanded.dart';

class ConnectionWorkspaceDesktopShell extends StatefulWidget {
  const ConnectionWorkspaceDesktopShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final CodexWorkspaceConversationHistoryRepository?
  conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<ConnectionWorkspaceDesktopShell> createState() =>
      _ConnectionWorkspaceDesktopShellState();
}

class _ConnectionWorkspaceDesktopShellState
    extends State<ConnectionWorkspaceDesktopShell> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final supportsCollapsedSidebar =
        widget.platformPolicy.behavior.supportsCollapsibleDesktopSidebar;

    return AnimatedBuilder(
      animation: widget.workspaceController,
      builder: (context, _) {
        final state = widget.workspaceController.state;
        final selectedLaneBinding =
            widget.workspaceController.selectedLaneBinding;
        final palette = context.pocketPalette;

        return Scaffold(
          backgroundColor: palette.backgroundTop,
          body: Row(
            children: [
              _MaterialDesktopSidebar(
                workspaceController: widget.workspaceController,
                state: state,
                isCollapsed: supportsCollapsedSidebar && _isSidebarCollapsed,
                onToggleCollapsed: supportsCollapsedSidebar
                    ? _toggleSidebarCollapsed
                    : null,
                connectionSubtitleBuilder: _connectionSubtitle,
              ),
              Expanded(
                child: switch ((
                  state.isShowingDormantRoster,
                  selectedLaneBinding,
                )) {
                  (true, _) => ConnectionWorkspaceDormantRosterContent(
                    workspaceController: widget.workspaceController,
                    description: ConnectionWorkspaceCopy
                        .desktopSavedConnectionsDescription,
                    platformBehavior: widget.platformPolicy.behavior,
                    settingsOverlayDelegate: widget.settingsOverlayDelegate,
                    useSafeArea: true,
                  ),
                  (false, final laneBinding?) =>
                    ConnectionWorkspaceLiveLaneSurface(
                      workspaceController: widget.workspaceController,
                      laneBinding: laneBinding,
                      platformPolicy: widget.platformPolicy,
                      conversationHistoryRepository:
                          widget.conversationHistoryRepository,
                      settingsOverlayDelegate: widget.settingsOverlayDelegate,
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleSidebarCollapsed() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  String _connectionSubtitle(ConnectionProfile profile) {
    return ConnectionWorkspaceCopy.connectionSubtitle(profile);
  }
}
