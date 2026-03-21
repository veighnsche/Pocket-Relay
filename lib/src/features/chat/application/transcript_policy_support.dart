import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptPolicySupport {
  const TranscriptPolicySupport();

  CodexActiveTurnState startActiveTurn({
    required String turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    return CodexActiveTurnState(
      turnId: turnId,
      threadId: threadId,
      timer: CodexSessionTurnTimer(
        turnId: turnId,
        startedAt: createdAt,
        activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
      ),
    );
  }

  CodexActiveTurnState? ensureActiveTurn(
    CodexActiveTurnState? activeTurn, {
    required String? turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    if (activeTurn != null || turnId == null) {
      return activeTurn;
    }

    return startActiveTurn(
      turnId: turnId,
      threadId: threadId,
      createdAt: createdAt,
    );
  }

  CodexActiveTurnState? activeTurnForStartedEvent(
    CodexActiveTurnState? activeTurn, {
    required String? turnId,
    required String? threadId,
    required String? fallbackThreadId,
    required DateTime createdAt,
  }) {
    if (turnId == null) {
      return activeTurn;
    }

    if (activeTurn != null && activeTurn.turnId == turnId) {
      return activeTurn.copyWith(
        threadId: threadId ?? activeTurn.threadId ?? fallbackThreadId,
      );
    }

    return startActiveTurn(
      turnId: turnId,
      threadId: threadId ?? fallbackThreadId,
      createdAt: createdAt,
    );
  }

  CodexSessionTurnTimer completeTurnTimer(
    CodexSessionTurnTimer? turnTimer,
    DateTime completedAt,
  ) {
    if (turnTimer == null) {
      return CodexSessionTurnTimer(
        turnId: 'completed-${completedAt.microsecondsSinceEpoch}',
        startedAt: completedAt,
        completedAt: completedAt,
        completedElapsed: Duration.zero,
      );
    }
    return turnTimer.complete(
      completedAt: completedAt,
      monotonicAt: CodexMonotonicClock.now(),
    );
  }

  CodexSessionTurnTimer? pauseTurnTimer(
    CodexSessionTurnTimer? turnTimer,
    DateTime pausedAt,
  ) {
    if (turnTimer == null) {
      return null;
    }
    return turnTimer.pause(
      pausedAt: pausedAt,
      monotonicAt: CodexMonotonicClock.now(),
    );
  }

  CodexSessionTurnTimer? resumeTurnTimer(
    CodexSessionTurnTimer? turnTimer,
    DateTime resumedAt,
  ) {
    if (turnTimer == null) {
      return null;
    }
    return turnTimer.resume(
      resumedAt: resumedAt,
      monotonicAt: CodexMonotonicClock.now(),
    );
  }

  CodexSessionState appendBlock(CodexSessionState state, CodexUiBlock block) {
    return state.copyWithProjectedTranscript(
      blocks: <CodexUiBlock>[...state.blocks, block],
    );
  }

  CodexStatusBlock statusEntry({
    required String prefix,
    required String title,
    required String body,
    required DateTime createdAt,
    CodexStatusBlockKind statusKind = CodexStatusBlockKind.info,
    bool isTranscriptSignal = false,
  }) {
    return CodexStatusBlock(
      id: eventEntryId(prefix, createdAt),
      createdAt: createdAt,
      title: title,
      body: body,
      statusKind: statusKind,
      isTranscriptSignal: isTranscriptSignal,
    );
  }

  bool isTranscriptStatusSignal(CodexRuntimeStatusEvent event) {
    return switch (event.rawMethod) {
      'account/chatgptAuthTokens/refresh' ||
      'item/tool/call' => true,
      _ => false,
    };
  }

  CodexStatusBlockKind statusKindForRuntimeStatus(
    CodexRuntimeStatusEvent event,
  ) {
    return switch (event.rawMethod) {
      'account/chatgptAuthTokens/refresh' => CodexStatusBlockKind.auth,
      _ => CodexStatusBlockKind.info,
    };
  }

  String eventEntryId(String prefix, DateTime createdAt) {
    return '$prefix-${createdAt.microsecondsSinceEpoch}';
  }

  String? stringFromCandidates(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }
}
