import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

class TranscriptPolicySupport {
  const TranscriptPolicySupport();

  TranscriptActiveTurnState startActiveTurn({
    required String turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    return TranscriptActiveTurnState(
      turnId: turnId,
      threadId: threadId,
      timer: TranscriptSessionTurnTimer(
        turnId: turnId,
        startedAt: createdAt,
        activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
      ),
    );
  }

  TranscriptActiveTurnState? ensureActiveTurn(
    TranscriptActiveTurnState? activeTurn, {
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

  TranscriptActiveTurnState? activeTurnForStartedEvent(
    TranscriptActiveTurnState? activeTurn, {
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

  TranscriptSessionTurnTimer completeTurnTimer(
    TranscriptSessionTurnTimer? turnTimer,
    DateTime completedAt,
  ) {
    if (turnTimer == null) {
      return TranscriptSessionTurnTimer(
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

  TranscriptSessionTurnTimer? pauseTurnTimer(
    TranscriptSessionTurnTimer? turnTimer,
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

  TranscriptSessionTurnTimer? resumeTurnTimer(
    TranscriptSessionTurnTimer? turnTimer,
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

  TranscriptSessionState appendBlock(
    TranscriptSessionState state,
    TranscriptUiBlock block,
  ) {
    return state.copyWithProjectedTranscript(
      blocks: <TranscriptUiBlock>[...state.blocks, block],
    );
  }

  TranscriptStatusBlock statusEntry({
    required String prefix,
    required String title,
    required String body,
    required DateTime createdAt,
    TranscriptStatusBlockKind statusKind = TranscriptStatusBlockKind.info,
    bool isTranscriptSignal = false,
  }) {
    return TranscriptStatusBlock(
      id: eventEntryId(prefix, createdAt),
      createdAt: createdAt,
      title: title,
      body: body,
      statusKind: statusKind,
      isTranscriptSignal: isTranscriptSignal,
    );
  }

  bool isTranscriptStatusSignal(TranscriptRuntimeStatusEvent event) {
    return switch (event.rawMethod) {
      'account/chatgptAuthTokens/refresh' || 'item/tool/call' => true,
      _ => false,
    };
  }

  TranscriptStatusBlockKind statusKindForRuntimeStatus(
    TranscriptRuntimeStatusEvent event,
  ) {
    return switch (event.rawMethod) {
      'account/chatgptAuthTokens/refresh' => TranscriptStatusBlockKind.auth,
      _ => TranscriptStatusBlockKind.info,
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
