import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

class WorkspaceTurnBackgroundGraceHost extends StatefulWidget {
  const WorkspaceTurnBackgroundGraceHost({
    super.key,
    required this.workspaceController,
    required this.child,
    this.backgroundGraceController =
        const MethodChannelBackgroundGraceController(),
    this.supportsBackgroundGrace,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;
  final BackgroundGraceController backgroundGraceController;
  final bool? supportsBackgroundGrace;

  @override
  State<WorkspaceTurnBackgroundGraceHost> createState() =>
      _WorkspaceTurnBackgroundGraceHostState();
}

class _WorkspaceTurnBackgroundGraceHostState
    extends State<WorkspaceTurnBackgroundGraceHost> {
  final Set<ChatSessionController> _attachedSessionControllers =
      <ChatSessionController>{};

  @override
  void initState() {
    super.initState();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnBackgroundGraceHost oldWidget) {
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
    return BackgroundGraceHost(
      backgroundGraceController: widget.backgroundGraceController,
      supportsBackgroundGrace: widget.supportsBackgroundGrace,
      keepBackgroundGraceAlive: _hasTickingTurnAcrossLiveLanes(),
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
