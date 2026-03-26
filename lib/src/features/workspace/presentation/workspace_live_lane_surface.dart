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
  bool _isDisconnectingLaneTransport = false;
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
    _isDisconnectingLaneTransport = false;
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
    unawaited(
      _laneAppServerEventSubscription?.cancel() ?? Future<void>.value(),
    );
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

  void _setDisconnectingLaneTransport(bool value) {
    setState(() {
      _isDisconnectingLaneTransport = value;
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
    final sessionState = widget.laneBinding.sessionController.sessionState;
    final isLaneBusy = sessionState.isBusy;
    final showsEmptyState =
        sessionState.transcriptBlocks.isEmpty &&
        sessionState.pendingApprovalRequests.isEmpty &&
        sessionState.pendingUserInputRequests.isEmpty;
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
        profile: profile,
        isLaneBusy: isLaneBusy,
      ),
      supplementalStatusRegion: showsEmptyState
          ? null
          : _buildLaneConnectionStrip(
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
      supplementalEmptyStateContent: _buildLaneEmptyStateContent(
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
    if (_isConnectingLaneTransport ||
        widget.laneBinding.appServerClient.isConnected) {
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
        remoteRuntime = workspaceController.state.remoteRuntimeFor(
          connectionId,
        );
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

  Future<void> _connectLane() async {
    if (_isRefreshingLaneRemoteRuntime ||
        _isConnectingLaneTransport ||
        _activeLaneRemoteServerAction != null) {
      return;
    }

    final profile = widget.laneBinding.sessionController.profile;
    if (!profile.isRemote || !profile.isReady) {
      return;
    }

    final connectionId = widget.laneBinding.connectionId;
    final reconnectRequirement = widget.workspaceController.state
        .reconnectRequirementFor(connectionId);
    if (reconnectRequirement != null) {
      await _restartLane();
      return;
    }

    final remoteRuntime = await _prepareLaneRemoteRuntimeForConnect();
    if (!mounted || remoteRuntime == null) {
      return;
    }
    if (!remoteRuntime.hostCapability.isSupported ||
        !remoteRuntime.server.isConnectable) {
      _showTransientMessage(
        ConnectionLifecycleErrors.connectLaneFailure(
          remoteRuntime: remoteRuntime,
        ).inlineMessage,
      );
      return;
    }

    await _connectLaneTransport();
  }

  Future<ConnectionRemoteRuntimeState?>
  _prepareLaneRemoteRuntimeForConnect() async {
    final connectionId = widget.laneBinding.connectionId;
    var remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
      connectionId,
    );

    if (_shouldRefreshLaneRemoteRuntime(remoteRuntime)) {
      await _refreshLaneRemoteRuntime();
      remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
        connectionId,
      );
    }

    final hostStatus =
        remoteRuntime?.hostCapability.status ??
        ConnectionRemoteHostCapabilityStatus.unknown;
    if (hostStatus == ConnectionRemoteHostCapabilityStatus.checking) {
      return null;
    }
    if (hostStatus != ConnectionRemoteHostCapabilityStatus.supported) {
      return remoteRuntime;
    }

    if (remoteRuntime?.server.status == ConnectionRemoteServerStatus.unknown) {
      await _refreshLaneRemoteRuntime();
      remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
        connectionId,
      );
    }

    switch (remoteRuntime?.server.status ??
        ConnectionRemoteServerStatus.unknown) {
      case ConnectionRemoteServerStatus.notRunning:
        await _runLaneRemoteServerAction(
          ConnectionSettingsRemoteServerActionId.start,
        );
        final nextRemoteRuntime = widget.workspaceController.state
            .remoteRuntimeFor(connectionId);
        return nextRemoteRuntime?.server.isConnectable == true
            ? nextRemoteRuntime
            : null;
      case ConnectionRemoteServerStatus.unhealthy:
        await _runLaneRemoteServerAction(
          ConnectionSettingsRemoteServerActionId.restart,
        );
        final nextRemoteRuntime = widget.workspaceController.state
            .remoteRuntimeFor(connectionId);
        return nextRemoteRuntime?.server.isConnectable == true
            ? nextRemoteRuntime
            : null;
      case ConnectionRemoteServerStatus.checking:
        return null;
      case ConnectionRemoteServerStatus.running:
      case ConnectionRemoteServerStatus.unknown:
        return remoteRuntime;
    }
  }

  bool _shouldRefreshLaneRemoteRuntime(
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (remoteRuntime == null) {
      return true;
    }

    final hostStatus = remoteRuntime.hostCapability.status;
    if (hostStatus == ConnectionRemoteHostCapabilityStatus.checking) {
      return false;
    }
    if (hostStatus == ConnectionRemoteHostCapabilityStatus.unknown ||
        hostStatus == ConnectionRemoteHostCapabilityStatus.probeFailed ||
        hostStatus == ConnectionRemoteHostCapabilityStatus.unsupported) {
      return true;
    }

    return remoteRuntime.server.status == ConnectionRemoteServerStatus.unknown;
  }

  Future<void> _disconnectLaneTransport() async {
    if (_isDisconnectingLaneTransport ||
        !widget.laneBinding.appServerClient.isConnected) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final connectionId = widget.laneBinding.connectionId;
    _setDisconnectingLaneTransport(true);
    try {
      await workspaceController.disconnectConnection(connectionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final detail = error.toString().trim();
      _showTransientMessage(
        detail.isEmpty
            ? 'Could not disconnect lane.'
            : 'Could not disconnect lane. $detail',
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setDisconnectingLaneTransport(false);
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
    final appServerConnected = widget.laneBinding.appServerClient.isConnected;
    final showSteadyStateStrip =
        !appServerConnected ||
        reconnectRequirement != null ||
        transportRecoveryPhase != null ||
        liveReattachPhase != null ||
        recoveryNotice != null ||
        _isConnectingLaneTransport;
    if (!showSteadyStateStrip) {
      return null;
    }

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
    final secondaryAction = _laneConversationHistoryActionFor(
      profile: profile,
      isLaneBusy: isLaneBusy,
    );
    return _WorkspaceLaneConnectionStrip(
      status: status,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
      notice: recoveryNotice,
    );
  }

  Widget? _buildLaneEmptyStateContent({
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required bool isLaneBusy,
    required bool isRestartInProgress,
    required Widget? recoveryNotice,
  }) {
    if (!profile.isRemote || !profile.isReady) {
      return null;
    }

    final workspacePath = profile.workspaceDir.trim();
    final showConnectionControls =
        !widget.laneBinding.appServerClient.isConnected ||
        reconnectRequirement != null ||
        transportRecoveryPhase != null ||
        liveReattachPhase != null ||
        recoveryNotice != null ||
        _isConnectingLaneTransport;
    final status = showConnectionControls
        ? _laneStatusContractFor(
            profile: profile,
            reconnectRequirement: reconnectRequirement,
            transportRecoveryPhase: transportRecoveryPhase,
            liveReattachPhase: liveReattachPhase,
            remoteRuntime: remoteRuntime,
          )
        : null;
    final primaryAction = _lanePrimaryActionFor(
      profile: profile,
      reconnectRequirement: reconnectRequirement,
      remoteRuntime: remoteRuntime,
      isLaneBusy: isLaneBusy,
      isRestartInProgress: isRestartInProgress,
    );
    final secondaryAction = showConnectionControls
        ? _laneConversationHistoryActionFor(
            profile: profile,
            isLaneBusy: isLaneBusy,
          )
        : null;
    if (workspacePath.isEmpty &&
        status == null &&
        primaryAction == null &&
        secondaryAction == null &&
        recoveryNotice == null) {
      return null;
    }

    return _WorkspaceLaneEmptyStateContent(
      workspacePath: workspacePath.isEmpty ? null : workspacePath,
      statusMessage: status == null
          ? null
          : _laneEmptyStateStatusTextFor(
              status: status,
              message: _laneEmptyStateStatusMessageFor(
                reconnectRequirement: reconnectRequirement,
                transportRecoveryPhase: transportRecoveryPhase,
                liveReattachPhase: liveReattachPhase,
                remoteRuntime: remoteRuntime,
              ),
            ),
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
      notice: recoveryNotice,
    );
  }

  String _laneEmptyStateStatusMessageFor({
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
  }) {
    if (_isConnectingLaneTransport) {
      return 'Pocket Relay is attaching this lane to Codex.';
    }

    if (liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.reconnecting ||
        transportRecoveryPhase ==
            ConnectionWorkspaceTransportRecoveryPhase.reconnecting) {
      return ConnectionWorkspaceCopy.reconnectingNoticeMessage;
    }

    if (reconnectRequirement != null) {
      return switch (reconnectRequirement) {
        ConnectionWorkspaceReconnectRequirement.savedSettings =>
          'Apply the saved connection edits before this lane can continue.',
        ConnectionWorkspaceReconnectRequirement.transport =>
          'Reconnect this lane to Codex to continue.',
        ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
          'Apply the saved connection edits and reconnect this lane to continue.',
      };
    }

    switch (remoteRuntime?.hostCapability.status ??
        ConnectionRemoteHostCapabilityStatus.unknown) {
      case ConnectionRemoteHostCapabilityStatus.unknown:
        return 'Connect checks the host, starts the managed remote app-server if needed, and attaches this lane.';
      case ConnectionRemoteHostCapabilityStatus.checking:
        return ConnectionWorkspaceCopy.laneHostCheckingDetail;
      case ConnectionRemoteHostCapabilityStatus.probeFailed:
        return remoteRuntime?.hostCapability.detail ??
            'Pocket Relay could not verify this host. Review the connection settings, then try again.';
      case ConnectionRemoteHostCapabilityStatus.unsupported:
        return remoteRuntime?.hostCapability.detail ??
            'This host does not currently satisfy Pocket Relay continuity requirements.';
      case ConnectionRemoteHostCapabilityStatus.supported:
        switch (remoteRuntime?.server.status ??
            ConnectionRemoteServerStatus.unknown) {
          case ConnectionRemoteServerStatus.unknown:
          case ConnectionRemoteServerStatus.checking:
            return ConnectionWorkspaceCopy.laneServerCheckingDetail;
          case ConnectionRemoteServerStatus.notRunning:
            return remoteRuntime?.server.detail ??
                'Connect will start the managed remote app-server for this lane.';
          case ConnectionRemoteServerStatus.unhealthy:
            return remoteRuntime?.server.detail ??
                'Connect will restart the managed remote app-server before attaching this lane.';
          case ConnectionRemoteServerStatus.running:
            return ConnectionWorkspaceCopy.laneDisconnectedDetail;
        }
    }
  }

  String _laneEmptyStateStatusTextFor({
    required _WorkspaceLaneStatusContract status,
    required String? message,
  }) {
    final trimmedMessage = message?.trim();
    if (trimmedMessage == null || trimmedMessage.isEmpty) {
      final trimmedDetail = status.detail.trim();
      if (trimmedDetail.isEmpty) {
        return status.label;
      }
      return '${status.label}. $trimmedDetail';
    }

    return '${status.label}. $trimmedMessage';
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
        detail: _laneStatusDetail(
          baseDetail,
          ConnectionWorkspaceCopy.laneConfigurationIncompleteDetail,
        ),
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
          detail: _laneStatusDetail(
            baseDetail,
            ConnectionWorkspaceCopy.laneBootstrapDetail,
          ),
          icon: Icons.help_outline_rounded,
          tone: _WorkspaceLaneStatusTone.neutral,
        ),
      ConnectionRemoteHostCapabilityStatus.checking =>
        _WorkspaceLaneStatusContract(
          label: ConnectionWorkspaceCopy.laneHostCheckingStatus,
          detail: _laneStatusDetail(
            baseDetail,
            ConnectionWorkspaceCopy.laneHostCheckingDetail,
          ),
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
          detail: _laneStatusDetail(
            baseDetail,
            ConnectionWorkspaceCopy.laneServerCheckingDetail,
          ),
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
    if (widget.laneBinding.appServerClient.isConnected &&
        reconnectRequirement == null) {
      return null;
    }

    final isBusy =
        isLaneBusy ||
        _isRefreshingLaneRemoteRuntime ||
        _isConnectingLaneTransport ||
        _isDisconnectingLaneTransport ||
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

    final progressLabel = switch (_activeLaneRemoteServerAction) {
      ConnectionSettingsRemoteServerActionId.start =>
        ConnectionWorkspaceCopy.startServerProgress,
      ConnectionSettingsRemoteServerActionId.restart =>
        ConnectionWorkspaceCopy.restartServerProgress,
      ConnectionSettingsRemoteServerActionId.stop || null => null,
    };
    final isCheckingRuntime =
        _isRefreshingLaneRemoteRuntime ||
        remoteRuntime?.hostCapability.status ==
            ConnectionRemoteHostCapabilityStatus.checking ||
        remoteRuntime?.server.status == ConnectionRemoteServerStatus.checking;

    return _WorkspaceLaneStatusActionContract(
      key: const ValueKey<String>('lane_connection_action_connect'),
      label:
          progressLabel ??
          (isCheckingRuntime
              ? ConnectionWorkspaceCopy.checkHostProgress
              : _isConnectingLaneTransport
              ? ConnectionWorkspaceCopy.connectProgress
              : ConnectionWorkspaceCopy.connectAction),
      onPressed: isBusy || isCheckingRuntime ? null : _connectLane,
    );
  }

  _WorkspaceLaneStatusActionContract _laneConversationHistoryActionFor({
    required ConnectionProfile profile,
    required bool isLaneBusy,
  }) {
    final hasWorkspaceHistoryScope = profile.workspaceDir.trim().isNotEmpty;
    return _WorkspaceLaneStatusActionContract(
      key: const ValueKey<String>('lane_connection_action_history'),
      label: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
      onPressed: hasWorkspaceHistoryScope && !isLaneBusy
          ? _showConversationHistory
          : null,
    );
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

class _WorkspaceLaneEmptyStateContent extends StatelessWidget {
  const _WorkspaceLaneEmptyStateContent({
    this.workspacePath,
    this.statusMessage,
    this.primaryAction,
    this.secondaryAction,
    this.notice,
  });

  final String? workspacePath;
  final String? statusMessage;
  final _WorkspaceLaneStatusActionContract? primaryAction;
  final _WorkspaceLaneStatusActionContract? secondaryAction;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryAction = this.primaryAction;
    final secondaryAction = this.secondaryAction;
    final workspacePath = this.workspacePath?.trim();
    final hasWorkspacePath = workspacePath != null && workspacePath.isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasWorkspacePath) ...[
            Text(
              workspacePath!,
              key: const ValueKey<String>('lane_empty_state_workspace_path'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          if (statusMessage case final message?
              when message.trim().isNotEmpty) ...[
            if (hasWorkspacePath) const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          if (primaryAction != null) ...[
            const SizedBox(height: 14),
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
          if (secondaryAction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: secondaryAction.key,
              onPressed: secondaryAction.onPressed == null
                  ? null
                  : () {
                      unawaited(secondaryAction.onPressed!());
                    },
              child: Text(secondaryAction.label),
            ),
          ],
          if (notice != null) ...[const SizedBox(height: 14), notice!],
        ],
      ),
    );
  }
}

class _WorkspaceLaneConnectionStrip extends StatelessWidget {
  const _WorkspaceLaneConnectionStrip({
    required this.status,
    this.primaryAction,
    this.secondaryAction,
    this.notice,
  });

  final _WorkspaceLaneStatusContract status;
  final _WorkspaceLaneStatusActionContract? primaryAction;
  final _WorkspaceLaneStatusActionContract? secondaryAction;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryAction = this.primaryAction;
    final secondaryAction = this.secondaryAction;
    final detail = switch (status.label) {
      ConnectionWorkspaceCopy.laneDisconnectedStatus =>
        '${status.detail.isEmpty ? '' : '${status.detail} · '}${ConnectionWorkspaceCopy.laneDisconnectedDetail}',
      _ => status.detail,
    };
    final detailText = detail.trim().isEmpty
        ? status.label
        : '${status.label}. $detail';
    final hasActions = primaryAction != null || secondaryAction != null;

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
            if (hasActions)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
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
                  if (secondaryAction != null)
                    OutlinedButton(
                      key: secondaryAction.key,
                      onPressed: secondaryAction.onPressed == null
                          ? null
                          : () {
                              unawaited(secondaryAction.onPressed!());
                            },
                      child: Text(secondaryAction.label),
                    ),
                ],
              ),
            if (hasActions) const SizedBox(height: 8),
            Text(
              detailText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (notice != null) ...[const SizedBox(height: 12), notice!],
          ],
        ),
      ),
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
