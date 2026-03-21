part of 'codex_session_state.dart';

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
