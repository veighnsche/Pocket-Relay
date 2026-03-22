import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

typedef WorkspaceTurnActivityWidgetBuilder =
    Widget Function(BuildContext context, bool hasActiveTurn);

class WorkspaceTurnActivityBuilder extends StatefulWidget {
  const WorkspaceTurnActivityBuilder({
    super.key,
    required this.workspaceController,
    required this.builder,
  });

  final ConnectionWorkspaceController workspaceController;
  final WorkspaceTurnActivityWidgetBuilder builder;

  @override
  State<WorkspaceTurnActivityBuilder> createState() =>
      _WorkspaceTurnActivityBuilderState();
}

class _WorkspaceTurnActivityBuilderState
    extends State<WorkspaceTurnActivityBuilder> {
  final Set<ChatSessionController> _attachedSessionControllers =
      <ChatSessionController>{};

  @override
  void initState() {
    super.initState();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnActivityBuilder oldWidget) {
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
    return widget.builder(context, _hasActiveTurnAcrossLiveLanes());
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

  bool _hasActiveTurnAcrossLiveLanes() {
    for (final controller in _liveSessionControllers()) {
      if (_sessionHasActiveTurn(controller.sessionState)) {
        return true;
      }
    }

    return false;
  }

  bool _sessionHasActiveTurn(CodexSessionState sessionState) {
    if (_turnKeepsWorkspaceActivity(sessionState.sessionActiveTurn)) {
      return true;
    }

    for (final timeline in sessionState.timelinesByThreadId.values) {
      if (_turnKeepsWorkspaceActivity(timeline.activeTurn)) {
        return true;
      }
    }

    return false;
  }

  bool _turnKeepsWorkspaceActivity(CodexActiveTurnState? activeTurn) {
    return activeTurn?.timer.isRunning == true;
  }
}
