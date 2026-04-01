part of 'chat_session_controller.dart';

Future<ChatWorkLogTerminalContract> _hydrateChatWorkLogTerminal(
  ChatSessionController controller,
  ChatWorkLogTerminalContract terminal,
) async {
  final itemId = terminal.itemId?.trim();
  final threadId = terminal.threadId?.trim();
  final turnId = _trimmedTerminalIdentifier(terminal.turnId);
  if ((itemId?.isEmpty ?? true) || (threadId?.isEmpty ?? true)) {
    return terminal;
  }

  final timelineActiveTurn = controller._sessionState
      .timelineForThread(threadId!)
      ?.activeTurn;
  final sessionActiveTurn = controller._sessionState.activeTurn;
  final activeTurn =
      timelineActiveTurn ??
      (sessionActiveTurn?.threadId == threadId ? sessionActiveTurn : null);
  final activeItem = _matchingActiveTerminalItem(
    activeTurn,
    itemId: itemId!,
    threadId: threadId,
    turnId: turnId,
  );
  if (activeItem != null) {
    return _terminalFromActiveItem(terminal, activeItem);
  }

  try {
    final thread = await controller.agentAdapterClient.readThreadWithTurns(
      threadId: threadId,
    );
    final historyItem = _findWorkLogHistoryItem(thread, itemId, turnId: turnId);
    if (historyItem == null) {
      return terminal;
    }
    return _terminalFromHistoryItem(terminal, historyItem);
  } catch (_) {
    return terminal;
  }
}

TranscriptSessionActiveItem? _matchingActiveTerminalItem(
  TranscriptActiveTurnState? activeTurn, {
  required String itemId,
  required String threadId,
  required String? turnId,
}) {
  if (activeTurn == null ||
      !_matchesTerminalTurnId(activeTurn.turnId, turnId)) {
    return null;
  }

  final activeItem = activeTurn.itemsById[itemId];
  if (activeItem == null ||
      activeItem.threadId != threadId ||
      activeItem.itemType != TranscriptCanonicalItemType.commandExecution ||
      !_matchesTerminalTurnId(activeItem.turnId, turnId)) {
    return null;
  }
  return activeItem;
}

ChatWorkLogTerminalContract _terminalFromActiveItem(
  ChatWorkLogTerminalContract terminal,
  TranscriptSessionActiveItem item,
) {
  final snapshot = item.snapshot;
  final terminalInput =
      _nonBlankTerminalStringPreservingWhitespace(snapshot?['stdin']) ??
      terminal.terminalInput;
  return terminal.copyWith(
    commandText: _terminalString(item.title) ?? terminal.commandText,
    isRunning: item.isRunning,
    isFailed: !item.isRunning && item.exitCode != null && item.exitCode != 0,
    exitCode: item.exitCode ?? terminal.exitCode,
    processId: _terminalProcessId(snapshot) ?? terminal.processId,
    terminalInput: terminalInput,
    terminalOutput:
        _activeTerminalOutput(item.body, terminalInput) ??
        terminal.terminalOutput,
  );
}

AgentAdapterHistoryItem? _findWorkLogHistoryItem(
  AgentAdapterThreadHistory thread,
  String itemId, {
  required String? turnId,
}) {
  for (final turn in thread.turns.reversed) {
    if (!_matchesTerminalTurnId(turn.id, turnId)) {
      continue;
    }
    for (final item in turn.items.reversed) {
      if (item.id == itemId) {
        return item;
      }
    }
  }
  return null;
}

ChatWorkLogTerminalContract _terminalFromHistoryItem(
  ChatWorkLogTerminalContract terminal,
  AgentAdapterHistoryItem item,
) {
  final raw = item.raw;
  final normalizedStatus = _terminalString(raw['status'])?.toLowerCase();
  final exitCode = _terminalExitCode(raw) ?? terminal.exitCode;
  final result = _terminalObject(raw['result']);
  return terminal.copyWith(
    commandText:
        _terminalString(raw['command'] ?? result?['command']) ??
        terminal.commandText,
    isRunning: switch (normalizedStatus) {
      'inprogress' || 'in_progress' || 'running' || 'active' => true,
      _ => false,
    },
    isFailed: _isTerminalFailureStatus(normalizedStatus),
    exitCode: exitCode,
    processId: _terminalProcessId(raw) ?? terminal.processId,
    terminalInput:
        _nonBlankTerminalStringPreservingWhitespace(raw['stdin']) ??
        terminal.terminalInput,
    terminalOutput: _terminalOutputFromHistory(raw) ?? terminal.terminalOutput,
  );
}

String? _terminalProcessId(Map<String, dynamic>? value) {
  final result = _terminalObject(value?['result']);
  return _terminalString(
    value?['processId'] ??
        value?['process_id'] ??
        result?['processId'] ??
        result?['process_id'],
  );
}

int? _terminalExitCode(Map<String, dynamic> value) {
  final result = _terminalObject(value['result']);
  final raw =
      value['exitCode'] ??
      value['exit_code'] ??
      result?['exitCode'] ??
      result?['exit_code'];
  return raw is num ? raw.toInt() : null;
}

Map<String, dynamic>? _terminalObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _terminalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _nonBlankTerminalStringPreservingWhitespace(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value;
}

String? _terminalOutputFromHistory(Map<String, dynamic> raw) {
  final result = _terminalObject(raw['result']);
  return _nonBlankTerminalStringPreservingWhitespace(
    raw['aggregatedOutput'] ?? raw['aggregated_output'] ?? result?['output'],
  );
}

String? _trimmedTerminalIdentifier(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

bool _matchesTerminalTurnId(String candidateTurnId, String? requestedTurnId) {
  return requestedTurnId == null || requestedTurnId == candidateTurnId;
}

bool _isTerminalFailureStatus(String? status) {
  return switch (status) {
    'failed' ||
    'error' ||
    'errored' ||
    'declined' ||
    'cancelled' ||
    'canceled' ||
    'interrupted' ||
    'terminated' => true,
    _ => false,
  };
}

String? _activeTerminalOutput(String body, String? terminalInput) {
  final value = _nonBlankTerminalStringPreservingWhitespace(body);
  if (value == null) {
    return null;
  }
  if (terminalInput == null || !value.startsWith(terminalInput)) {
    return value;
  }

  final output = value.substring(terminalInput.length);
  return output.isEmpty ? null : output;
}
