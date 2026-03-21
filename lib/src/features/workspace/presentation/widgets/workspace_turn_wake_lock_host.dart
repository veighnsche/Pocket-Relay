import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';

class WorkspaceTurnWakeLockHost extends StatefulWidget {
  const WorkspaceTurnWakeLockHost({
    super.key,
    required this.workspaceController,
    required this.child,
    this.displayWakeLockController =
        const WakelockPlusDisplayWakeLockController(),
    this.supportsWakeLock,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;
  final DisplayWakeLockController displayWakeLockController;
  final bool? supportsWakeLock;

  @override
  State<WorkspaceTurnWakeLockHost> createState() =>
      _WorkspaceTurnWakeLockHostState();
}

class _WorkspaceTurnWakeLockHostState extends State<WorkspaceTurnWakeLockHost> {
  final Set<ChatSessionController> _attachedSessionControllers =
      <ChatSessionController>{};

  @override
  void initState() {
    super.initState();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnWakeLockHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceController == widget.workspaceController) {
      return;
    }

    oldWidget.workspaceController.removeListener(_handleWorkspaceChanged);
    _detachAllSessionListeners();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void dispose() {
    widget.workspaceController.removeListener(_handleWorkspaceChanged);
    _detachAllSessionListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DisplayWakeLockHost(
      displayWakeLockController: widget.displayWakeLockController,
      supportsWakeLock: widget.supportsWakeLock,
      keepDisplayAwake: _hasTickingTurnAcrossLiveLanes(),
      child: widget.child,
    );
  }

  void _handleWorkspaceChanged() {
    _syncSessionListeners();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _syncSessionListeners() {
    final nextControllers = _liveSessionControllers().toSet();

    for (final controller in _attachedSessionControllers.difference(
      nextControllers,
    )) {
      controller.removeListener(_handleSessionChanged);
    }

    for (final controller in nextControllers.difference(
      _attachedSessionControllers,
    )) {
      controller.addListener(_handleSessionChanged);
    }

    _attachedSessionControllers
      ..clear()
      ..addAll(nextControllers);
  }

  void _detachAllSessionListeners() {
    for (final controller in _attachedSessionControllers) {
      controller.removeListener(_handleSessionChanged);
    }
    _attachedSessionControllers.clear();
  }

  Iterable<ChatSessionController> _liveSessionControllers() sync* {
    final workspaceController = widget.workspaceController;
    for (final connectionId in workspaceController.state.liveConnectionIds) {
      final binding = workspaceController.bindingForConnectionId(connectionId);
      if (binding != null) {
        yield binding.sessionController;
      }
    }
  }

  bool _hasTickingTurnAcrossLiveLanes() {
    for (final controller in _liveSessionControllers()) {
      if (_sessionHasTickingTurn(controller.sessionState)) {
        return true;
      }
    }

    return false;
  }

  bool _sessionHasTickingTurn(CodexSessionState sessionState) {
    if (sessionState.sessionActiveTurn?.timer.isTicking == true) {
      return true;
    }

    for (final timeline in sessionState.timelinesByThreadId.values) {
      if (timeline.activeTurn?.timer.isTicking == true) {
        return true;
      }
    }

    return false;
  }
}
