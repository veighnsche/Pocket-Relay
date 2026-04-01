import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_saved_connections_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_saved_systems_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';

class ConnectionWorkspaceMobileShell extends StatefulWidget {
  const ConnectionWorkspaceMobileShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final WorkspaceConversationHistoryRepository? conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<ConnectionWorkspaceMobileShell> createState() =>
      _ConnectionWorkspaceMobileShellState();
}

class _ConnectionWorkspaceMobileShellState
    extends State<ConnectionWorkspaceMobileShell> {
  late PageController _pageController;
  late int _currentPageIndex;
  int? _scheduledTargetPage;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = _targetPageIndex(widget.workspaceController.state);
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void didUpdateWidget(covariant ConnectionWorkspaceMobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceController == widget.workspaceController) {
      return;
    }

    _pageController.dispose();
    _currentPageIndex = _targetPageIndex(widget.workspaceController.state);
    _pageController = PageController(initialPage: _currentPageIndex);
    _scheduledTargetPage = null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workspaceController,
      builder: (context, _) {
        final state = widget.workspaceController.state;
        final liveConnectionIds = state.liveConnectionIds;
        final targetPageIndex = _targetPageIndex(state);
        _syncPageController(targetPageIndex);

        return PageView(
          key: const ValueKey('workspace_page_view'),
          controller: _pageController,
          onPageChanged: (index) =>
              _handlePageChanged(index, liveConnectionIds: liveConnectionIds),
          children: <Widget>[
            for (final connectionId in liveConnectionIds)
              _ConnectionWorkspaceLanePageHost(
                key: ValueKey<String>('lane_page_$connectionId'),
                child: _buildLanePage(connectionId),
              ),
            _ConnectionWorkspaceSavedConnectionsPage(
              key: const ValueKey('saved_connections_page'),
              workspaceController: widget.workspaceController,
              platformPolicy: widget.platformPolicy,
              settingsOverlayDelegate: widget.settingsOverlayDelegate,
            ),
            _ConnectionWorkspaceSavedSystemsPage(
              key: const ValueKey('saved_systems_page'),
              workspaceController: widget.workspaceController,
              platformPolicy: widget.platformPolicy,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanePage(String connectionId) {
    final laneBinding = widget.workspaceController.bindingForConnectionId(
      connectionId,
    );
    if (laneBinding == null) {
      return const SizedBox.shrink();
    }

    return ConnectionWorkspaceLiveLaneSurface(
      workspaceController: widget.workspaceController,
      laneBinding: laneBinding,
      platformPolicy: widget.platformPolicy,
      conversationHistoryRepository: widget.conversationHistoryRepository,
      settingsOverlayDelegate: widget.settingsOverlayDelegate,
    );
  }

  void _handlePageChanged(
    int index, {
    required List<String> liveConnectionIds,
  }) {
    _currentPageIndex = index;
    _scheduledTargetPage = index;
    if (index == liveConnectionIds.length) {
      widget.workspaceController.showSavedConnections();
      return;
    }
    if (index > liveConnectionIds.length) {
      widget.workspaceController.showSavedSystems();
      return;
    }

    widget.workspaceController.selectConnection(liveConnectionIds[index]);
  }

  int _targetPageIndex(ConnectionWorkspaceState state) {
    if (state.isShowingSavedSystems) {
      return state.liveConnectionIds.length + 1;
    }
    if (state.isShowingSavedConnections || state.selectedConnectionId == null) {
      return state.liveConnectionIds.length;
    }

    final selectedIndex = state.liveConnectionIds.indexOf(
      state.selectedConnectionId!,
    );
    return selectedIndex == -1 ? state.liveConnectionIds.length : selectedIndex;
  }

  void _syncPageController(int targetPageIndex) {
    if (_scheduledTargetPage == targetPageIndex) {
      return;
    }
    _scheduledTargetPage = targetPageIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final currentPage = (_pageController.page ?? _currentPageIndex.toDouble())
          .round();
      if (currentPage == targetPageIndex) {
        _currentPageIndex = targetPageIndex;
        return;
      }

      _currentPageIndex = targetPageIndex;
      unawaited(
        _pageController.animateToPage(
          targetPageIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }
}

class _ConnectionWorkspaceLanePageHost extends StatefulWidget {
  const _ConnectionWorkspaceLanePageHost({super.key, required this.child});

  final Widget child;

  @override
  State<_ConnectionWorkspaceLanePageHost> createState() =>
      _ConnectionWorkspaceLanePageHostState();
}

class _ConnectionWorkspaceLanePageHostState
    extends State<_ConnectionWorkspaceLanePageHost>
    with AutomaticKeepAliveClientMixin<_ConnectionWorkspaceLanePageHost> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ConnectionWorkspaceSavedConnectionsPage extends StatefulWidget {
  const _ConnectionWorkspaceSavedConnectionsPage({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    required this.settingsOverlayDelegate,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<_ConnectionWorkspaceSavedConnectionsPage> createState() =>
      _ConnectionWorkspaceSavedConnectionsPageState();
}

class _ConnectionWorkspaceSavedConnectionsPageState
    extends State<_ConnectionWorkspaceSavedConnectionsPage> {
  @override
  Widget build(BuildContext context) {
    final content = ConnectionWorkspaceSavedConnectionsContent(
      workspaceController: widget.workspaceController,
      description: ConnectionWorkspaceCopy.mobileSavedConnectionsDescription,
      platformBehavior: widget.platformPolicy.behavior,
      settingsOverlayDelegate: widget.settingsOverlayDelegate,
    );

    return Scaffold(body: content);
  }
}

class _ConnectionWorkspaceSavedSystemsPage extends StatefulWidget {
  const _ConnectionWorkspaceSavedSystemsPage({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;

  @override
  State<_ConnectionWorkspaceSavedSystemsPage> createState() =>
      _ConnectionWorkspaceSavedSystemsPageState();
}

class _ConnectionWorkspaceSavedSystemsPageState
    extends State<_ConnectionWorkspaceSavedSystemsPage> {
  @override
  Widget build(BuildContext context) {
    final content = ConnectionWorkspaceSavedSystemsContent(
      workspaceController: widget.workspaceController,
      description: ConnectionWorkspaceCopy.mobileSavedSystemsDescription,
      platformBehavior: widget.platformPolicy.behavior,
    );

    return Scaffold(body: content);
  }
}
