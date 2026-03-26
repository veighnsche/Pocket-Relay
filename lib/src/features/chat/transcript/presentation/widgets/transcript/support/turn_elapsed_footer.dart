import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class TurnElapsedFooter extends StatefulWidget {
  const TurnElapsedFooter({
    super.key,
    this.turnTimer,
    this.accent,
    this.onStop,
    this.laneRestartAction,
    this.onRestart,
  });

  final CodexSessionTurnTimer? turnTimer;
  final Color? accent;
  final Future<void> Function()? onStop;
  final ChatLaneRestartActionContract? laneRestartAction;
  final Future<void> Function()? onRestart;

  @override
  State<TurnElapsedFooter> createState() => _TurnElapsedFooterState();
}

class _TurnElapsedFooterState extends State<TurnElapsedFooter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant TurnElapsedFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turnTimer?.isTicking != widget.turnTimer?.isTicking ||
        oldWidget.turnTimer?.isRunning != widget.turnTimer?.isRunning) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    final turnTimer = widget.turnTimer;
    if (turnTimer == null || !turnTimer.isTicking) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final turnTimer = widget.turnTimer;
    final laneRestartAction = widget.laneRestartAction;
    final onStop = widget.onStop;
    if (turnTimer == null && laneRestartAction == null) {
      return const SizedBox.shrink();
    }

    final cards = TranscriptPalette.of(context);
    final accent = widget.accent ?? tealAccent(Theme.of(context).brightness);
    final restartAccent = Theme.of(context).colorScheme.primary;
    final elapsed = turnTimer?.elapsedAt(
      DateTime.now(),
      monotonicNow: CodexMonotonicClock.now(),
    );
    final label = switch (turnTimer?.isRunning) {
      true => 'Elapsed',
      false when turnTimer != null => 'Completed in',
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (elapsed != null && label != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cards.tintedSurface(
                    accent,
                    lightAlpha: 0.08,
                    darkAlpha: 0.16,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cards.accentBorder(accent)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      '$label ${formatElapsedDuration(elapsed)}',
                      style: TextStyle(
                        color: cards.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (laneRestartAction != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cards.tintedSurface(
                    restartAccent,
                    lightAlpha: 0.08,
                    darkAlpha: 0.16,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cards.accentBorder(restartAccent)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restart_alt_rounded,
                      size: 13,
                      color: restartAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      laneRestartAction.badgeLabel,
                      style: TextStyle(
                        color: cards.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (turnTimer?.isRunning == true && onStop != null)
              OutlinedButton.icon(
                key: const ValueKey('stop_active_turn'),
                onPressed: () {
                  unawaited(onStop());
                },
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.3),
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                ),
              ),
            if (laneRestartAction case final onDeckRestart?)
              FilledButton.tonalIcon(
                key: const ValueKey('restart_lane'),
                onPressed:
                    onDeckRestart.isInProgress || widget.onRestart == null
                    ? null
                    : () {
                        unawaited(widget.onRestart!());
                      },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(onDeckRestart.label),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
