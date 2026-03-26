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
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
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
  bool _isRefreshingLaneRemoteRuntime = false;
  bool _isConnectingLaneTransport = false;
  ConnectionSettingsRemoteServerActionId? _activeLaneRemoteServerAction;
  StreamSubscription<CodexAppServerEvent>? _laneAppServerEventSubscription;

  @override
  void initState() {
    super.initState();
    _attachLaneBindingListeners(widget.laneBinding);
  }

  @override
  void didUpdateWidget(covariant ConnectionWorkspaceLiveLaneSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.laneBinding == widget.laneBinding) {
      return;
    }

    _detachLaneBindingListeners(oldWidget.laneBinding);
    _isOpeningConnectionSettings = false;
    _isRestartingLane = false;
    _isRefreshingLaneRemoteRuntime = false;
    _isConnectingLaneTransport = false;
    _activeLaneRemoteServerAction = null;
    _attachLaneBindingListeners(widget.laneBinding);
  }

  @override
  void dispose() {
    _detachLaneBindingListeners(widget.laneBinding);
    super.dispose();
  }

  void _attachLaneBindingListeners(ConnectionLaneBinding laneBinding) {
    laneBinding.sessionController.addListener(_handleLaneBindingChange);
    _laneAppServerEventSubscription = laneBinding.appServerClient.events.listen(
      (_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
    );
  }

  void _detachLaneBindingListeners(ConnectionLaneBinding laneBinding) {
    laneBinding.sessionController.removeListener(_handleLaneBindingChange);
    unawaited(_laneAppServerEventSubscription?.cancel() ?? Future<void>.value());
    _laneAppServerEventSubscription = null;
  }

  void _handleLaneBindingChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

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

  void _setRefreshingLaneRemoteRuntime(bool value) {
    setState(() {
      _isRefreshingLaneRemoteRuntime = value;
    });
  }

  void _setConnectingLaneTransport(bool value) {
    setState(() {
      _isConnectingLaneTransport = value;
    });
  }

  void _setActiveLaneRemoteServerAction(
    ConnectionSettingsRemoteServerActionId? value,
  ) {
    setState(() {
      _activeLaneRemoteServerAction = value;
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
    final liveReattachPhase = workspaceState.liveReattachPhaseFor(
      widget.laneBinding.connectionId,
    );
    final remoteRuntime = workspaceState.remoteRuntimeFor(
      widget.laneBinding.connectionId,
    );
    final profile = widget.laneBinding.sessionController.profile;
    final isLaneBusy = widget.laneBinding.sessionController.sessionState.isBusy;
    final isTransportReconnectInProgress =
        transportRecoveryPhase ==
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting;
    final isRestartInProgress =
        _isRestartingLane || isTransportReconnectInProgress;
    final recoveryNotice = _transportRecoveryNoticeFor(
      liveReattachPhase: liveReattachPhase,
      phase: transportRecoveryPhase,
      remoteRuntime: remoteRuntime,
    );
    final chatRoot = ChatRootAdapter(
      laneBinding: widget.laneBinding,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: _handleConnectionSettingsRequested,
      supplementalMenuActions: _supplementalMenuActionsFor(
        isLaneBusy: isLaneBusy,
      ),
      supplementalStatusRegion: _buildLaneConnectionStrip(
        context,
        profile: profile,
        reconnectRequirement: reconnectRequirement,
        transportRecoveryPhase: transportRecoveryPhase,
        liveReattachPhase: liveReattachPhase,
        remoteRuntime: remoteRuntime,
        isLaneBusy: isLaneBusy,
        isRestartInProgress: isRestartInProgress,
        recoveryNotice: recoveryNotice,
      ),
    );
    return chatRoot;
  }

  Future<void> _refreshLaneRemoteRuntime() async {
    if (_isRefreshingLaneRemoteRuntime) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final connectionId = widget.laneBinding.connectionId;
    _setRefreshingLaneRemoteRuntime(true);
    try {
      await workspaceController.refreshRemoteRuntime(
        connectionId: connectionId,
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setRefreshingLaneRemoteRuntime(false);
      }
    }
  }

  Future<void> _runLaneRemoteServerAction(
    ConnectionSettingsRemoteServerActionId actionId,
  ) async {
    if (_activeLaneRemoteServerAction != null) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final connectionId = widget.laneBinding.connectionId;
    _setActiveLaneRemoteServerAction(actionId);
    try {
      final remoteRuntime = await switch (actionId) {
        ConnectionSettingsRemoteServerActionId.start =>
          workspaceController.startRemoteServer(connectionId: connectionId),
        ConnectionSettingsRemoteServerActionId.stop =>
          workspaceController.stopRemoteServer(connectionId: connectionId),
        ConnectionSettingsRemoteServerActionId.restart =>
          workspaceController.restartRemoteServer(connectionId: connectionId),
      };
      if (!mounted) {
        return;
      }

      if (!_didRemoteServerActionSucceed(actionId, remoteRuntime)) {
        _showTransientMessage(
          ConnectionLifecycleErrors.remoteServerActionFailure(
            actionId,
            remoteRuntime: remoteRuntime,
          ).inlineMessage,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showTransientMessage(
        ConnectionLifecycleErrors.remoteServerActionFailure(
          actionId,
          remoteRuntime: widget.workspaceController.state.remoteRuntimeFor(
            connectionId,
          ),
          error: error,
        ).inlineMessage,
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setActiveLaneRemoteServerAction(null);
      }
    }
  }

  Future<void> _connectLaneTransport() async {
    if (_isConnectingLaneTransport || widget.laneBinding.appServerClient.isConnected) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final laneBinding = widget.laneBinding;
    final connectionId = laneBinding.connectionId;
    _setConnectingLaneTransport(true);
    try {
      await laneBinding.appServerClient.connect(
        profile: laneBinding.sessionController.profile,
        secrets: laneBinding.sessionController.secrets,
      );
    } catch (error) {
      ConnectionRemoteRuntimeState? remoteRuntime;
      try {
        remoteRuntime = await workspaceController.refreshRemoteRuntime(
          connectionId: connectionId,
        );
      } catch (_) {
        remoteRuntime = workspaceController.state.remoteRuntimeFor(connectionId);
      }
      if (!mounted) {
        return;
      }
      _showTransientMessage(
        ConnectionLifecycleErrors.connectLaneFailure(
          remoteRuntime: remoteRuntime,
          error: error,
        ).inlineMessage,
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding == laneBinding) {
        _setConnectingLaneTransport(false);
      }
    }
  }

  bool _didRemoteServerActionSucceed(
    ConnectionSettingsRemoteServerActionId actionId,
    ConnectionRemoteRuntimeState remoteRuntime,
  ) {
    if (!remoteRuntime.hostCapability.isSupported) {
      return false;
    }

    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start =>
        remoteRuntime.server.status == ConnectionRemoteServerStatus.running,
      ConnectionSettingsRemoteServerActionId.stop =>
        remoteRuntime.server.status == ConnectionRemoteServerStatus.notRunning,
      ConnectionSettingsRemoteServerActionId.restart =>
        remoteRuntime.server.status == ConnectionRemoteServerStatus.running,
    };
  }

  void _showTransientMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget? _transportRecoveryNoticeFor({
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionWorkspaceTransportRecoveryPhase? phase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
  }) {
    final sessionController = widget.laneBinding.sessionController;
    if ((phase == null && liveReattachPhase == null) ||
        sessionController.historicalConversationRestoreState != null ||
        sessionController.conversationRecoveryState != null) {
      return null;
    }

    if (liveReattachPhase ==
        ConnectionWorkspaceLiveReattachPhase.liveReattached) {
      return null;
    }

    if (liveReattachPhase ==
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore) {
      return const _WorkspaceLaneTransportNotice(
        title: ConnectionWorkspaceCopy.restoringConversationNoticeTitle,
        message: ConnectionWorkspaceCopy.restoringConversationNoticeMessage,
        isLoading: true,
      );
    }

    final transportLostError = ConnectionLifecycleErrors.transportLostNotice();
    final unavailableError =
        ConnectionLifecycleErrors.transportUnavailableNotice(remoteRuntime);
    final unavailableNotice = (
      unavailableError.title,
      unavailableError.bodyWithCode,
      false,
    );
    final (title, message, isLoading) = switch (liveReattachPhase ?? phase) {
      ConnectionWorkspaceLiveReattachPhase.transportLost => (
        transportLostError.title,
        transportLostError.bodyWithCode,
        false,
      ),
      ConnectionWorkspaceLiveReattachPhase.reconnecting => (
        ConnectionWorkspaceCopy.reconnectingNoticeTitle,
        ConnectionWorkspaceCopy.reconnectingNoticeMessage,
        true,
      ),
      ConnectionWorkspaceLiveReattachPhase.ownerMissing ||
      ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy => unavailableNotice,
      ConnectionWorkspaceTransportRecoveryPhase.lost => (
        transportLostError.title,
        transportLostError.bodyWithCode,
        false,
      ),
      ConnectionWorkspaceTransportRecoveryPhase.reconnecting => (
        ConnectionWorkspaceCopy.reconnectingNoticeTitle,
        ConnectionWorkspaceCopy.reconnectingNoticeMessage,
        true,
      ),
      ConnectionWorkspaceTransportRecoveryPhase.unavailable =>
        unavailableNotice,
      _ => unavailableNotice,
    };
    return _WorkspaceLaneTransportNotice(
      title: title,
      message: message,
      isLoading: isLoading,
    );
  }

  Widget? _buildLaneConnectionStrip(
    BuildContext context, {
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required bool isLaneBusy,
    required bool isRestartInProgress,
    required Widget? recoveryNotice,
  }) {
    final status = _laneStatusContractFor(
      profile: profile,
      reconnectRequirement: reconnectRequirement,
      transportRecoveryPhase: transportRecoveryPhase,
      liveReattachPhase: liveReattachPhase,
      remoteRuntime: remoteRuntime,
    );
    final primaryAction = _lanePrimaryActionFor(
      profile: profile,
      reconnectRequirement: reconnectRequirement,
      remoteRuntime: remoteRuntime,
      isLaneBusy: isLaneBusy,
      isRestartInProgress: isRestartInProgress,
    );
    return _WorkspaceLaneConnectionStrip(
      status: status,
      primaryAction: primaryAction,
      notice: recoveryNotice,
    );
  }

  _WorkspaceLaneStatusContract _laneStatusContractFor({
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
  }) {
    final baseDetail = ConnectionWorkspaceCopy.connectionSubtitle(profile);
    final appServerConnected = widget.laneBinding.appServerClient.isConnected;

    if (!profile.isReady) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneConfigurationIncompleteStatus,
        detail: baseDetail,
        icon: Icons.settings_outlined,
        tone: _WorkspaceLaneStatusTone.warning,
      );
    }

    if (_isConnectingLaneTransport) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneConnectingStatus,
        detail: '$baseDetail · Connect this lane to Codex to continue.',
        icon: Icons.sync_rounded,
        tone: _WorkspaceLaneStatusTone.loading,
      );
    }

    if (liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.reconnecting ||
        transportRecoveryPhase ==
            ConnectionWorkspaceTransportRecoveryPhase.reconnecting) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneReconnectingStatus,
        detail:
            '$baseDetail · ${ConnectionWorkspaceCopy.reconnectingNoticeMessage}',
        icon: Icons.sync_rounded,
        tone: _WorkspaceLaneStatusTone.loading,
      );
    }

    if (reconnectRequirement ==
        ConnectionWorkspaceReconnectRequirement.savedSettings) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneChangesPendingStatus,
        detail:
            '$baseDetail · Apply the saved connection edits before this lane can continue.',
        icon: Icons.edit_note_rounded,
        tone: _WorkspaceLaneStatusTone.warning,
      );
    }

    if (liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.ownerMissing ||
        (remoteRuntime?.hostCapability.isSupported == true &&
            remoteRuntime?.server.status ==
                ConnectionRemoteServerStatus.notRunning)) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneServerStoppedStatus,
        detail: _laneStatusDetail(baseDetail, remoteRuntime?.server.detail),
        icon: Icons.stop_circle_outlined,
        tone: _WorkspaceLaneStatusTone.warning,
      );
    }

    if (liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy ||
        (remoteRuntime?.hostCapability.isSupported == true &&
            remoteRuntime?.server.status ==
                ConnectionRemoteServerStatus.unhealthy)) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneServerUnhealthyStatus,
        detail: _laneStatusDetail(baseDetail, remoteRuntime?.server.detail),
        icon: Icons.warning_amber_rounded,
        tone: _WorkspaceLaneStatusTone.warning,
      );
    }

    if (reconnectRequirement != null ||
        liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.transportLost ||
        transportRecoveryPhase ==
            ConnectionWorkspaceTransportRecoveryPhase.lost ||
        transportRecoveryPhase ==
            ConnectionWorkspaceTransportRecoveryPhase.unavailable) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneReconnectNeededStatus,
        detail:
            '$baseDetail · ${ConnectionWorkspaceCopy.reconnectingNoticeMessage}',
        icon: Icons.link_off_rounded,
        tone: _WorkspaceLaneStatusTone.warning,
      );
    }

    if (profile.isLocal) {
      return _WorkspaceLaneStatusContract(
        label: appServerConnected
            ? ConnectionWorkspaceCopy.laneConnectedStatus
            : ConnectionWorkspaceCopy.laneLocalReadyStatus,
        detail: baseDetail,
        icon: appServerConnected
            ? Icons.check_circle_outline_rounded
            : Icons.laptop_mac_rounded,
        tone: _WorkspaceLaneStatusTone.good,
      );
    }

    if (appServerConnected) {
      return _WorkspaceLaneStatusContract(
        label: ConnectionWorkspaceCopy.laneConnectedStatus,
        detail: _laneStatusDetail(baseDetail, remoteRuntime?.server.detail),
        icon: Icons.check_circle_outline_rounded,
        tone: _WorkspaceLaneStatusTone.good,
      );
    }

    return switch (remoteRuntime?.hostCapability.status ??
        ConnectionRemoteHostCapabilityStatus.unknown) {
      ConnectionRemoteHostCapabilityStatus.unknown =>
        _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneHostUnknownStatus,
          detail: baseDetail,
          icon: Icons.help_outline_rounded,
          tone: _WorkspaceLaneStatusTone.neutral,
        ),
      ConnectionRemoteHostCapabilityStatus.checking =>
        _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneHostCheckingStatus,
          detail: baseDetail,
          icon: Icons.sync_rounded,
          tone: _WorkspaceLaneStatusTone.loading,
        ),
      ConnectionRemoteHostCapabilityStatus.probeFailed =>
        _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneHostCheckFailedStatus,
          detail: _laneStatusDetail(
            baseDetail,
            remoteRuntime?.hostCapability.detail,
          ),
          icon: Icons.portable_wifi_off_rounded,
          tone: _WorkspaceLaneStatusTone.danger,
        ),
      ConnectionRemoteHostCapabilityStatus.unsupported =>
        _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneContinuityUnavailableStatus,
          detail: _laneStatusDetail(
            baseDetail,
            remoteRuntime?.hostCapability.detail,
          ),
          icon: Icons.error_outline_rounded,
          tone: _WorkspaceLaneStatusTone.warning,
        ),
      ConnectionRemoteHostCapabilityStatus.supported => switch (remoteRuntime
              ?.server
              .status ??
          ConnectionRemoteServerStatus.unknown) {
        ConnectionRemoteServerStatus.unknown ||
        ConnectionRemoteServerStatus.checking => _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneServerCheckingStatus,
          detail: baseDetail,
          icon: Icons.sync_rounded,
          tone: _WorkspaceLaneStatusTone.loading,
        ),
        ConnectionRemoteServerStatus.notRunning => _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneServerStoppedStatus,
          detail: _laneStatusDetail(baseDetail, remoteRuntime?.server.detail),
          icon: Icons.stop_circle_outlined,
          tone: _WorkspaceLaneStatusTone.warning,
        ),
        ConnectionRemoteServerStatus.unhealthy => _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneServerUnhealthyStatus,
          detail: _laneStatusDetail(baseDetail, remoteRuntime?.server.detail),
          icon: Icons.warning_amber_rounded,
          tone: _WorkspaceLaneStatusTone.warning,
        ),
        ConnectionRemoteServerStatus.running => _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneDisconnectedStatus,
          detail: baseDetail,
          icon: Icons.link_off_rounded,
          tone: _WorkspaceLaneStatusTone.neutral,
        ),
      },
    };
  }

  String _laneStatusDetail(String baseDetail, String? runtimeDetail) {
    final normalizedRuntimeDetail = runtimeDetail?.trim();
    if (normalizedRuntimeDetail == null || normalizedRuntimeDetail.isEmpty) {
      return baseDetail;
    }
    return '$baseDetail · $normalizedRuntimeDetail';
  }

  _WorkspaceLaneStatusActionContract? _lanePrimaryActionFor({
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required bool isLaneBusy,
    required bool isRestartInProgress,
  }) {
    if (!profile.isRemote || !profile.isReady) {
      return null;
    }

    final isBusy =
        isLaneBusy ||
        _isRefreshingLaneRemoteRuntime ||
        _isConnectingLaneTransport ||
        _activeLaneRemoteServerAction != null ||
        isRestartInProgress;
    if (reconnectRequirement case final requirement?) {
      return _WorkspaceLaneStatusActionContract(
        key: const ValueKey<String>('lane_connection_action_reconnect'),
        label: isRestartInProgress
            ? ConnectionWorkspaceCopy.reconnectProgressFor(requirement)
            : ConnectionWorkspaceCopy.reconnectActionFor(requirement),
        onPressed: isBusy ? null : _restartLane,
      );
    }

    switch (remoteRuntime?.hostCapability.status ??
        ConnectionRemoteHostCapabilityStatus.unknown) {
      case ConnectionRemoteHostCapabilityStatus.unknown:
      case ConnectionRemoteHostCapabilityStatus.probeFailed:
      case ConnectionRemoteHostCapabilityStatus.unsupported:
        return _WorkspaceLaneStatusActionContract(
          key: const ValueKey<String>('lane_connection_action_check_host'),
          label: _isRefreshingLaneRemoteRuntime
              ? ConnectionWorkspaceCopy.checkHostProgress
              : ConnectionWorkspaceCopy.checkHostAction,
          onPressed: isBusy ? null : _refreshLaneRemoteRuntime,
        );
      case ConnectionRemoteHostCapabilityStatus.checking:
        return null;
      case ConnectionRemoteHostCapabilityStatus.supported:
        switch (remoteRuntime?.server.status ??
            ConnectionRemoteServerStatus.unknown) {
          case ConnectionRemoteServerStatus.notRunning:
            return _WorkspaceLaneStatusActionContract(
              key: const ValueKey<String>(
                'lane_connection_action_start_server',
              ),
              label:
                  _activeLaneRemoteServerAction ==
                      ConnectionSettingsRemoteServerActionId.start
                  ? ConnectionWorkspaceCopy.startServerProgress
                  : ConnectionWorkspaceCopy.startServerAction,
              onPressed: isBusy
                  ? null
                  : () => _runLaneRemoteServerAction(
                      ConnectionSettingsRemoteServerActionId.start,
                    ),
            );
          case ConnectionRemoteServerStatus.unhealthy:
            return _WorkspaceLaneStatusActionContract(
              key: const ValueKey<String>(
                'lane_connection_action_restart_server',
              ),
              label:
                  _activeLaneRemoteServerAction ==
                      ConnectionSettingsRemoteServerActionId.restart
                  ? ConnectionWorkspaceCopy.restartServerProgress
                  : ConnectionWorkspaceCopy.restartServerAction,
              onPressed: isBusy
                  ? null
                  : () => _runLaneRemoteServerAction(
                      ConnectionSettingsRemoteServerActionId.restart,
                    ),
            );
          case ConnectionRemoteServerStatus.running:
            return _WorkspaceLaneStatusActionContract(
              key: const ValueKey<String>('lane_connection_action_connect'),
              label: _isConnectingLaneTransport
                  ? ConnectionWorkspaceCopy.connectProgress
                  : ConnectionWorkspaceCopy.connectAction,
              onPressed: isBusy ? null : _connectLaneTransport,
            );
          case ConnectionRemoteServerStatus.unknown:
          case ConnectionRemoteServerStatus.checking:
            return null;
        }
    }
  }
}

enum _WorkspaceLaneStatusTone { neutral, good, warning, danger, loading }

class _WorkspaceLaneStatusContract {
  const _WorkspaceLaneStatusContract({
    required this.label,
    required this.detail,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String detail;
  final IconData icon;
  final _WorkspaceLaneStatusTone tone;
}

class _WorkspaceLaneStatusActionContract {
  const _WorkspaceLaneStatusActionContract({
    required this.key,
    required this.label,
    required this.onPressed,
  });

  final Key key;
  final String label;
  final Future<void> Function()? onPressed;
}

class _WorkspaceLaneConnectionStrip extends StatelessWidget {
  const _WorkspaceLaneConnectionStrip({
    required this.status,
    this.primaryAction,
    this.notice,
  });

  final _WorkspaceLaneStatusContract status;
  final _WorkspaceLaneStatusActionContract? primaryAction;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colorsFor(theme, status.tone);
    final primaryAction = this.primaryAction;
    final detail = switch (status.label) {
      ConnectionWorkspaceCopy.laneDisconnectedStatus =>
        '${status.detail.isEmpty ? '' : '${status.detail} · '}Connect this lane to Codex to continue.',
      _ => status.detail,
    };

    return DecoratedBox(
      key: const ValueKey<String>('lane_connection_status_strip'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.$1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status.tone == _WorkspaceLaneStatusTone.loading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.$2,
                            ),
                          )
                        else
                          Icon(status.icon, size: 16, color: colors.$2),
                        const SizedBox(width: 8),
                        Text(
                          status.label,
                          key: const ValueKey<String>(
                            'lane_connection_status_label',
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.$2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (primaryAction != null)
                  FilledButton.tonal(
                    key: primaryAction.key,
                    onPressed: primaryAction.onPressed == null
                        ? null
                        : () {
                            unawaited(primaryAction.onPressed!());
                          },
                    child: Text(primaryAction.label),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (notice != null) ...[
              const SizedBox(height: 12),
              notice!,
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(ThemeData theme, _WorkspaceLaneStatusTone tone) {
    return switch (tone) {
      _WorkspaceLaneStatusTone.good => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      _WorkspaceLaneStatusTone.warning => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      _WorkspaceLaneStatusTone.danger => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _WorkspaceLaneStatusTone.loading || _WorkspaceLaneStatusTone.neutral => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
    };
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
