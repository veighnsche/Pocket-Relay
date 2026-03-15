import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptPolicySupport {
  const TranscriptPolicySupport();

  Map<String, CodexSessionTurnTimer> completeTurnTimer(
    Map<String, CodexSessionTurnTimer> turnTimers,
    String? turnId,
    DateTime completedAt,
  ) {
    if (turnId == null || turnId.isEmpty) {
      return turnTimers;
    }

    final existing = turnTimers[turnId];
    return <String, CodexSessionTurnTimer>{
      ...turnTimers,
      turnId:
          existing?.complete(
            completedAt: completedAt,
            monotonicAt: CodexMonotonicClock.now(),
          ) ??
          CodexSessionTurnTimer(
            turnId: turnId,
            startedAt: completedAt,
            completedAt: completedAt,
            completedElapsed: Duration.zero,
          ),
    };
  }

  Map<String, CodexSessionTurnTimer> pauseTurnTimer(
    Map<String, CodexSessionTurnTimer> turnTimers,
    String? turnId,
    DateTime pausedAt,
  ) {
    if (turnId == null || turnId.isEmpty) {
      return turnTimers;
    }

    final existing = turnTimers[turnId];
    if (existing == null) {
      return turnTimers;
    }

    return <String, CodexSessionTurnTimer>{
      ...turnTimers,
      turnId: existing.pause(
        pausedAt: pausedAt,
        monotonicAt: CodexMonotonicClock.now(),
      ),
    };
  }

  Map<String, CodexSessionTurnTimer> resumeTurnTimer(
    Map<String, CodexSessionTurnTimer> turnTimers,
    String? turnId,
    DateTime resumedAt,
  ) {
    if (turnId == null || turnId.isEmpty) {
      return turnTimers;
    }

    final existing = turnTimers[turnId];
    if (existing == null) {
      return turnTimers;
    }

    return <String, CodexSessionTurnTimer>{
      ...turnTimers,
      turnId: existing.resume(
        resumedAt: resumedAt,
        monotonicAt: CodexMonotonicClock.now(),
      ),
    };
  }

  bool hasBlockingRequest(CodexSessionState state) {
    return state.pendingApprovalRequests.isNotEmpty ||
        state.pendingUserInputRequests.isNotEmpty;
  }

  CodexSessionState upsertBlock(CodexSessionState state, CodexUiBlock block) {
    final nextBlocks = List<CodexUiBlock>.from(state.blocks);
    final index = nextBlocks.indexWhere((existing) => existing.id == block.id);
    if (index == -1) {
      nextBlocks.add(block);
    } else {
      nextBlocks[index] = block;
    }

    return state.copyWith(blocks: nextBlocks);
  }

  CodexStatusBlock statusEntry({
    required String prefix,
    required String title,
    required String body,
    required DateTime createdAt,
    bool isTranscriptSignal = false,
  }) {
    return CodexStatusBlock(
      id: eventEntryId(prefix, createdAt),
      createdAt: createdAt,
      title: title,
      body: body,
      isTranscriptSignal: isTranscriptSignal,
    );
  }

  bool isTranscriptStatusSignal(CodexRuntimeStatusEvent event) {
    return switch (event.rawMethod) {
      'account/chatgptAuthTokens/refresh' ||
      'item/tool/call' ||
      'item/fileRead/requestApproval' => true,
      _ => false,
    };
  }

  String buildRuntimeUsageSummary(CodexRuntimeTurnCompletedEvent event) {
    final parts = <String>[];
    final usage = event.usage;

    if (usage?.inputTokens != null) {
      parts.add('input ${usage!.inputTokens}');
    }
    if ((usage?.cachedInputTokens ?? 0) > 0) {
      parts.add('cached ${usage!.cachedInputTokens}');
    }
    if (usage?.outputTokens != null) {
      parts.add('output ${usage!.outputTokens}');
    }
    if (event.totalCostUsd != null) {
      parts.add('cost \$${event.totalCostUsd!.toStringAsFixed(4)}');
    }
    if (event.stopReason != null && event.stopReason!.trim().isNotEmpty) {
      parts.add(event.stopReason!);
    }
    if (event.errorMessage != null && event.errorMessage!.trim().isNotEmpty) {
      parts.add(event.errorMessage!);
    }

    if (parts.isEmpty) {
      return 'The active Codex turn finished.';
    }

    return parts.join(' · ');
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
