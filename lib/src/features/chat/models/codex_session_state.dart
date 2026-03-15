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
    this.activeTurn,
    this.blocks = const <CodexUiBlock>[],
    this.latestUsageSummary,
  });

  factory CodexSessionState.initial() {
    return const CodexSessionState();
  }

  final CodexRuntimeSessionState connectionStatus;
  final String? threadId;
  final CodexActiveTurnState? activeTurn;
  final List<CodexUiBlock> blocks;
  final String? latestUsageSummary;

  Map<String, CodexSessionPendingRequest> get pendingApprovalRequests =>
      activeTurn?.pendingApprovalRequests ??
      const <String, CodexSessionPendingRequest>{};

  Map<String, CodexSessionPendingUserInputRequest>
  get pendingUserInputRequests =>
      activeTurn?.pendingUserInputRequests ??
      const <String, CodexSessionPendingUserInputRequest>{};

  Map<String, CodexSessionActiveItem> get activeItems =>
      activeTurn?.itemsById ?? const <String, CodexSessionActiveItem>{};

  bool get isBusy => connectionStatus == CodexRuntimeSessionState.running;

  List<CodexUiBlock> get transcriptBlocks =>
      _buildTranscriptBlocks(<CodexUiBlock>[
        ...blocks.where(_shouldAppearInTranscript),
        if (activeTurn != null)
          ...projectCodexTurnSegments(activeTurn!.segments),
      ]);

  CodexApprovalRequestBlock? get primaryPendingApprovalBlock =>
      _firstPendingBlock<CodexApprovalRequestBlock>(
        pendingApprovalRequests.values.map(_pendingApprovalBlock),
      );

  CodexUserInputRequestBlock? get primaryPendingUserInputBlock =>
      _firstPendingBlock<CodexUserInputRequestBlock>(
        pendingUserInputRequests.values.map(_pendingUserInputBlock),
      );

  CodexSessionState copyWith({
    CodexRuntimeSessionState? connectionStatus,
    String? threadId,
    bool clearThreadId = false,
    CodexActiveTurnState? activeTurn,
    bool clearActiveTurn = false,
    List<CodexUiBlock>? blocks,
    String? latestUsageSummary,
    bool clearLatestUsageSummary = false,
  }) {
    return CodexSessionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      threadId: clearThreadId ? null : (threadId ?? this.threadId),
      activeTurn: clearActiveTurn ? null : (activeTurn ?? this.activeTurn),
      blocks: blocks ?? this.blocks,
      latestUsageSummary: clearLatestUsageSummary
          ? null
          : (latestUsageSummary ?? this.latestUsageSummary),
    );
  }
}

List<CodexUiBlock> projectCodexTurnSegments(
  Iterable<CodexTurnSegment> segments,
) {
  final projected = <CodexUiBlock>[];

  for (final segment in segments) {
    switch (segment) {
      case CodexTurnTextSegment():
        projected.add(
          CodexTextBlock(
            id: segment.id,
            kind: segment.kind,
            createdAt: segment.createdAt,
            title: segment.title,
            body: segment.body,
            isRunning: segment.isStreaming,
          ),
        );
      case CodexTurnWorkSegment():
        projected.addAll(
          segment.entries.map(
            (entry) => CodexWorkLogEntryBlock(
              id: entry.id,
              createdAt: entry.createdAt,
              entryKind: entry.entryKind,
              title: entry.title,
              turnId: entry.turnId,
              preview: entry.preview,
              isRunning: entry.isRunning,
              exitCode: entry.exitCode,
            ),
          ),
        );
      case CodexTurnPlanSegment():
        projected.add(
          CodexProposedPlanBlock(
            id: segment.id,
            createdAt: segment.createdAt,
            title: segment.title,
            markdown: segment.markdown,
            isStreaming: segment.isStreaming,
          ),
        );
      case CodexTurnChangedFilesSegment():
        projected.add(
          CodexChangedFilesBlock(
            id: segment.id,
            createdAt: segment.createdAt,
            title: segment.title,
            files: segment.files,
            unifiedDiff: segment.unifiedDiff,
            isRunning: segment.isStreaming,
          ),
        );
      case CodexTurnBlockSegment():
        projected.add(segment.block);
    }
  }

  return projected;
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

CodexApprovalRequestBlock _pendingApprovalBlock(
  CodexSessionPendingRequest request,
) {
  return CodexApprovalRequestBlock(
    id: 'request_${request.requestId}',
    createdAt: request.createdAt,
    requestId: request.requestId,
    requestType: request.requestType,
    title: _requestTitle(request.requestType),
    body: request.detail ?? 'Codex needs a decision before it can continue.',
  );
}

CodexUserInputRequestBlock _pendingUserInputBlock(
  CodexSessionPendingUserInputRequest request,
) {
  return CodexUserInputRequestBlock(
    id: 'request_${request.requestId}',
    createdAt: request.createdAt,
    requestId: request.requestId,
    requestType: request.requestType,
    title: _requestTitle(request.requestType),
    body: request.detail ?? _questionsSummary(request.questions),
    questions: request.questions,
  );
}

String _requestTitle(CodexCanonicalRequestType requestType) {
  return switch (requestType) {
    CodexCanonicalRequestType.commandExecutionApproval => 'Command approval',
    CodexCanonicalRequestType.fileReadApproval => 'File read approval',
    CodexCanonicalRequestType.fileChangeApproval => 'File change approval',
    CodexCanonicalRequestType.applyPatchApproval => 'Patch approval',
    CodexCanonicalRequestType.execCommandApproval => 'Command approval',
    CodexCanonicalRequestType.permissionsRequestApproval =>
      'Permissions request',
    CodexCanonicalRequestType.toolUserInput => 'Input required',
    CodexCanonicalRequestType.mcpServerElicitation => 'MCP input required',
    CodexCanonicalRequestType.dynamicToolCall => 'Tool call',
    CodexCanonicalRequestType.authTokensRefresh => 'Auth refresh',
    CodexCanonicalRequestType.unknown => 'Request',
  };
}

String _questionsSummary(List<CodexRuntimeUserInputQuestion> questions) {
  return questions
      .map((question) => '${question.header}: ${question.question}')
      .join('\n\n');
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

enum CodexActiveTurnStatus { running, blocked, completing }

sealed class CodexTurnSegment {
  const CodexTurnSegment({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

final class CodexTurnTextSegment extends CodexTurnSegment {
  const CodexTurnTextSegment({
    required super.id,
    required super.createdAt,
    required this.kind,
    required this.title,
    required this.body,
    this.itemId,
    this.isStreaming = false,
  });

  final CodexUiBlockKind kind;
  final String title;
  final String body;
  final String? itemId;
  final bool isStreaming;
}

final class CodexTurnWorkSegment extends CodexTurnSegment {
  const CodexTurnWorkSegment({
    required super.id,
    required super.createdAt,
    this.itemId,
    this.entries = const <CodexWorkLogEntry>[],
  });

  final String? itemId;
  final List<CodexWorkLogEntry> entries;
}

final class CodexTurnPlanSegment extends CodexTurnSegment {
  const CodexTurnPlanSegment({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.markdown,
    this.itemId,
    this.isStreaming = false,
  });

  final String title;
  final String markdown;
  final String? itemId;
  final bool isStreaming;
}

final class CodexTurnChangedFilesSegment extends CodexTurnSegment {
  const CodexTurnChangedFilesSegment({
    required super.id,
    required super.createdAt,
    required this.title,
    this.itemId,
    this.files = const <CodexChangedFile>[],
    this.unifiedDiff,
    this.isStreaming = false,
  });

  final String title;
  final String? itemId;
  final List<CodexChangedFile> files;
  final String? unifiedDiff;
  final bool isStreaming;
}

final class CodexTurnBlockSegment extends CodexTurnSegment {
  CodexTurnBlockSegment({required this.block})
    : super(id: block.id, createdAt: block.createdAt);

  final CodexUiBlock block;
}

class CodexActiveTurnState {
  const CodexActiveTurnState({
    required this.turnId,
    this.threadId,
    required this.timer,
    this.status = CodexActiveTurnStatus.running,
    this.segments = const <CodexTurnSegment>[],
    this.itemsById = const <String, CodexSessionActiveItem>{},
    this.itemSegmentIds = const <String, String>{},
    this.pendingApprovalRequests = const <String, CodexSessionPendingRequest>{},
    this.pendingUserInputRequests =
        const <String, CodexSessionPendingUserInputRequest>{},
    this.pendingThreadTokenUsageBlock,
    this.latestUsageSummary,
    this.hasWork = false,
    this.hasReasoning = false,
  });

  final String turnId;
  final String? threadId;
  final CodexSessionTurnTimer timer;
  final CodexActiveTurnStatus status;
  final List<CodexTurnSegment> segments;
  final Map<String, CodexSessionActiveItem> itemsById;
  final Map<String, String> itemSegmentIds;
  final Map<String, CodexSessionPendingRequest> pendingApprovalRequests;
  final Map<String, CodexSessionPendingUserInputRequest>
  pendingUserInputRequests;
  final CodexUsageBlock? pendingThreadTokenUsageBlock;
  final String? latestUsageSummary;
  final bool hasWork;
  final bool hasReasoning;

  bool get hasBlockingRequests =>
      pendingApprovalRequests.isNotEmpty || pendingUserInputRequests.isNotEmpty;

  CodexActiveTurnState copyWith({
    String? turnId,
    String? threadId,
    CodexSessionTurnTimer? timer,
    CodexActiveTurnStatus? status,
    List<CodexTurnSegment>? segments,
    Map<String, CodexSessionActiveItem>? itemsById,
    Map<String, String>? itemSegmentIds,
    Map<String, CodexSessionPendingRequest>? pendingApprovalRequests,
    Map<String, CodexSessionPendingUserInputRequest>? pendingUserInputRequests,
    CodexUsageBlock? pendingThreadTokenUsageBlock,
    bool clearPendingThreadTokenUsageBlock = false,
    String? latestUsageSummary,
    bool clearLatestUsageSummary = false,
    bool? hasWork,
    bool? hasReasoning,
  }) {
    return CodexActiveTurnState(
      turnId: turnId ?? this.turnId,
      threadId: threadId ?? this.threadId,
      timer: timer ?? this.timer,
      status: status ?? this.status,
      segments: segments ?? this.segments,
      itemsById: itemsById ?? this.itemsById,
      itemSegmentIds: itemSegmentIds ?? this.itemSegmentIds,
      pendingApprovalRequests:
          pendingApprovalRequests ?? this.pendingApprovalRequests,
      pendingUserInputRequests:
          pendingUserInputRequests ?? this.pendingUserInputRequests,
      pendingThreadTokenUsageBlock: clearPendingThreadTokenUsageBlock
          ? null
          : (pendingThreadTokenUsageBlock ?? this.pendingThreadTokenUsageBlock),
      latestUsageSummary: clearLatestUsageSummary
          ? null
          : (latestUsageSummary ?? this.latestUsageSummary),
      hasWork: hasWork ?? this.hasWork,
      hasReasoning: hasReasoning ?? this.hasReasoning,
    );
  }
}
