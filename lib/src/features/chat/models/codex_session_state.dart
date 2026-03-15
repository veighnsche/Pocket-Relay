import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class CodexSessionTurnTimer {
  const CodexSessionTurnTimer({
    required this.turnId,
    required this.startedAt,
    this.completedAt,
    this.accumulatedElapsed = Duration.zero,
    this.activeSegmentStartedMonotonicAt,
    this.completedElapsed,
    this.isPaused = false,
    DateTime? activeSegmentStartedAt,
  }) : activeSegmentStartedAt =
           activeSegmentStartedAt ?? (isPaused ? null : startedAt);

  final String turnId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration accumulatedElapsed;
  final DateTime? activeSegmentStartedAt;
  final Duration? activeSegmentStartedMonotonicAt;
  final Duration? completedElapsed;
  final bool isPaused;

  bool get isRunning => completedAt == null;

  bool get isTicking => isRunning && !isPaused;

  Duration elapsedNow() {
    return elapsedAt(DateTime.now(), monotonicNow: CodexMonotonicClock.now());
  }

  Duration elapsedAt(DateTime now, {Duration? monotonicNow}) {
    final frozenElapsed = completedElapsed;
    if (frozenElapsed != null) {
      return frozenElapsed;
    }

    final activeStartedAt = activeSegmentStartedAt;
    if (activeStartedAt == null) {
      if (completedAt != null && accumulatedElapsed == Duration.zero) {
        return _safeWallClockDifference(startedAt, completedAt!);
      }
      return accumulatedElapsed;
    }

    return accumulatedElapsed +
        _segmentElapsed(
          activeStartedAt: activeStartedAt,
          activeStartedMonotonicAt: activeSegmentStartedMonotonicAt,
          wallClockEnd: completedAt ?? now,
          monotonicEnd: monotonicNow,
        );
  }

  CodexSessionTurnTimer pause({
    required DateTime pausedAt,
    Duration? monotonicAt,
  }) {
    if (!isRunning || isPaused) {
      return this;
    }

    return copyWith(
      accumulatedElapsed: elapsedAt(pausedAt, monotonicNow: monotonicAt),
      clearActiveSegmentStartedAt: true,
      clearActiveSegmentStartedMonotonicAt: true,
      isPaused: true,
    );
  }

  CodexSessionTurnTimer resume({
    required DateTime resumedAt,
    Duration? monotonicAt,
  }) {
    if (!isRunning || !isPaused) {
      return this;
    }

    return copyWith(
      activeSegmentStartedAt: resumedAt,
      activeSegmentStartedMonotonicAt: monotonicAt,
      isPaused: false,
    );
  }

  CodexSessionTurnTimer complete({
    required DateTime completedAt,
    Duration? monotonicAt,
  }) {
    final frozenElapsed =
        completedElapsed ?? elapsedAt(completedAt, monotonicNow: monotonicAt);
    return copyWith(
      completedAt: this.completedAt ?? completedAt,
      accumulatedElapsed: frozenElapsed,
      completedElapsed: frozenElapsed,
      clearActiveSegmentStartedAt: true,
      clearActiveSegmentStartedMonotonicAt: true,
      isPaused: true,
    );
  }

  CodexSessionTurnTimer copyWith({
    DateTime? completedAt,
    Duration? accumulatedElapsed,
    DateTime? activeSegmentStartedAt,
    bool clearActiveSegmentStartedAt = false,
    Duration? activeSegmentStartedMonotonicAt,
    bool clearActiveSegmentStartedMonotonicAt = false,
    Duration? completedElapsed,
    bool clearCompletedElapsed = false,
    bool? isPaused,
  }) {
    return CodexSessionTurnTimer(
      turnId: turnId,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      accumulatedElapsed: accumulatedElapsed ?? this.accumulatedElapsed,
      activeSegmentStartedAt: clearActiveSegmentStartedAt
          ? null
          : (activeSegmentStartedAt ?? this.activeSegmentStartedAt),
      activeSegmentStartedMonotonicAt: clearActiveSegmentStartedMonotonicAt
          ? null
          : (activeSegmentStartedMonotonicAt ??
                this.activeSegmentStartedMonotonicAt),
      completedElapsed: clearCompletedElapsed
          ? null
          : (completedElapsed ?? this.completedElapsed),
      isPaused: isPaused ?? this.isPaused,
    );
  }

  Duration _segmentElapsed({
    required DateTime activeStartedAt,
    required Duration? activeStartedMonotonicAt,
    required DateTime wallClockEnd,
    required Duration? monotonicEnd,
  }) {
    if (activeStartedMonotonicAt != null && monotonicEnd != null) {
      final monotonicElapsed = monotonicEnd - activeStartedMonotonicAt;
      if (monotonicElapsed.isNegative) {
        return Duration.zero;
      }
      return monotonicElapsed;
    }

    return _safeWallClockDifference(activeStartedAt, wallClockEnd);
  }

  Duration _safeWallClockDifference(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      return Duration.zero;
    }
    return end.difference(start);
  }
}

class CodexSessionState {
  const CodexSessionState({
    this.connectionStatus = CodexRuntimeSessionState.stopped,
    this.threadId,
    this.turnId,
    this.turnTimers = const <String, CodexSessionTurnTimer>{},
    this.pendingApprovalRequests = const <String, CodexSessionPendingRequest>{},
    this.pendingUserInputRequests =
        const <String, CodexSessionPendingUserInputRequest>{},
    this.activeItems = const <String, CodexSessionActiveItem>{},
    this.blocks = const <CodexUiBlock>[],
    this.latestUsageSummary,
    this.pendingThreadTokenUsageBlock,
  });

  factory CodexSessionState.initial() {
    return const CodexSessionState();
  }

  final CodexRuntimeSessionState connectionStatus;
  final String? threadId;
  final String? turnId;
  final Map<String, CodexSessionTurnTimer> turnTimers;
  final Map<String, CodexSessionPendingRequest> pendingApprovalRequests;
  final Map<String, CodexSessionPendingUserInputRequest>
  pendingUserInputRequests;
  final Map<String, CodexSessionActiveItem> activeItems;
  final List<CodexUiBlock> blocks;
  final String? latestUsageSummary;
  final CodexUsageBlock? pendingThreadTokenUsageBlock;

  bool get isBusy => connectionStatus == CodexRuntimeSessionState.running;

  List<CodexUiBlock> get transcriptBlocks =>
      _buildTranscriptBlocks(blocks.where(_shouldAppearInTranscript));

  CodexApprovalRequestBlock? get primaryPendingApprovalBlock =>
      _firstPendingBlock<CodexApprovalRequestBlock>(
        blocks.whereType<CodexApprovalRequestBlock>().where(
          (block) =>
              !block.isResolved &&
              pendingApprovalRequests.containsKey(block.requestId),
        ),
      );

  CodexUserInputRequestBlock? get primaryPendingUserInputBlock =>
      _firstPendingBlock<CodexUserInputRequestBlock>(
        blocks.whereType<CodexUserInputRequestBlock>().where(
          (block) =>
              !block.isResolved &&
              pendingUserInputRequests.containsKey(block.requestId),
        ),
      );

  CodexSessionState copyWith({
    CodexRuntimeSessionState? connectionStatus,
    String? threadId,
    bool clearThreadId = false,
    String? turnId,
    bool clearTurnId = false,
    Map<String, CodexSessionTurnTimer>? turnTimers,
    Map<String, CodexSessionPendingRequest>? pendingApprovalRequests,
    Map<String, CodexSessionPendingUserInputRequest>? pendingUserInputRequests,
    Map<String, CodexSessionActiveItem>? activeItems,
    List<CodexUiBlock>? blocks,
    String? latestUsageSummary,
    bool clearLatestUsageSummary = false,
    CodexUsageBlock? pendingThreadTokenUsageBlock,
    bool clearPendingThreadTokenUsageBlock = false,
  }) {
    return CodexSessionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      threadId: clearThreadId ? null : (threadId ?? this.threadId),
      turnId: clearTurnId ? null : (turnId ?? this.turnId),
      turnTimers: turnTimers ?? this.turnTimers,
      pendingApprovalRequests:
          pendingApprovalRequests ?? this.pendingApprovalRequests,
      pendingUserInputRequests:
          pendingUserInputRequests ?? this.pendingUserInputRequests,
      activeItems: activeItems ?? this.activeItems,
      blocks: blocks ?? this.blocks,
      latestUsageSummary: clearLatestUsageSummary
          ? null
          : (latestUsageSummary ?? this.latestUsageSummary),
      pendingThreadTokenUsageBlock: clearPendingThreadTokenUsageBlock
          ? null
          : (pendingThreadTokenUsageBlock ?? this.pendingThreadTokenUsageBlock),
    );
  }
}

bool _shouldAppearInTranscript(CodexUiBlock block) {
  return switch (block) {
    CodexApprovalRequestBlock(:final isResolved) => isResolved,
    CodexUserInputRequestBlock(:final isResolved) => isResolved,
    CodexStatusBlock(:final isTranscriptSignal) => isTranscriptSignal,
    _ => true,
  };
}

List<CodexUiBlock> _buildTranscriptBlocks(Iterable<CodexUiBlock> blocks) {
  final transcript = <CodexUiBlock>[];
  final pendingWorkEntries = <CodexWorkLogEntryBlock>[];

  void flushWorkEntries() {
    if (pendingWorkEntries.isEmpty) {
      return;
    }

    final first = pendingWorkEntries.first;
    final last = pendingWorkEntries.last;
    transcript.add(
      CodexWorkLogGroupBlock(
        id: 'worklog_${first.id}_${last.id}',
        createdAt: first.createdAt,
        entries: pendingWorkEntries
            .map(
              (entry) => CodexWorkLogEntry(
                id: entry.id,
                createdAt: entry.createdAt,
                entryKind: entry.entryKind,
                title: entry.title,
                turnId: entry.turnId,
                preview: entry.preview,
                isRunning: entry.isRunning,
                exitCode: entry.exitCode,
              ),
            )
            .toList(growable: false),
      ),
    );
    pendingWorkEntries.clear();
  }

  for (final block in blocks) {
    if (block is CodexWorkLogEntryBlock) {
      pendingWorkEntries.add(block);
      continue;
    }

    flushWorkEntries();
    transcript.add(block);
  }

  flushWorkEntries();
  return transcript;
}

T? _firstPendingBlock<T extends CodexUiBlock>(Iterable<T> blocks) {
  final sorted = blocks.toList(growable: false)
    ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  return sorted.isEmpty ? null : sorted.first;
}

class CodexSessionPendingRequest {
  const CodexSessionPendingRequest({
    required this.requestId,
    required this.requestType,
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.detail,
    this.args,
  });

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? detail;
  final Object? args;
}

class CodexSessionPendingUserInputRequest {
  const CodexSessionPendingUserInputRequest({
    required this.requestId,
    required this.requestType,
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.detail,
    this.questions = const <CodexRuntimeUserInputQuestion>[],
    this.args,
  });

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? detail;
  final List<CodexRuntimeUserInputQuestion> questions;
  final Object? args;
}

class CodexSessionActiveItem {
  const CodexSessionActiveItem({
    required this.itemId,
    required this.threadId,
    required this.turnId,
    required this.itemType,
    required this.entryId,
    required this.blockKind,
    required this.createdAt,
    this.title,
    this.body = '',
    this.isRunning = false,
    this.exitCode,
    this.snapshot,
  });

  final String itemId;
  final String threadId;
  final String turnId;
  final CodexCanonicalItemType itemType;
  final String entryId;
  final CodexUiBlockKind blockKind;
  final DateTime createdAt;
  final String? title;
  final String body;
  final bool isRunning;
  final int? exitCode;
  final Map<String, dynamic>? snapshot;

  CodexSessionActiveItem copyWith({
    String? title,
    String? body,
    bool? isRunning,
    int? exitCode,
    Map<String, dynamic>? snapshot,
  }) {
    return CodexSessionActiveItem(
      itemId: itemId,
      threadId: threadId,
      turnId: turnId,
      itemType: itemType,
      entryId: entryId,
      blockKind: blockKind,
      createdAt: createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}
