import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class TurnElapsedFooter extends StatefulWidget {
  const TurnElapsedFooter({super.key, required this.turnTimer, this.accent});

  final CodexSessionTurnTimer turnTimer;
  final Color? accent;

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
    if (oldWidget.turnTimer.isTicking != widget.turnTimer.isTicking ||
        oldWidget.turnTimer.isRunning != widget.turnTimer.isRunning) {
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
    if (!widget.turnTimer.isTicking) {
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
    final cards = ConversationCardPalette.of(context);
    final accent = widget.accent ?? tealAccent(Theme.of(context).brightness);
    final elapsed = widget.turnTimer.elapsedAt(
      DateTime.now(),
      monotonicNow: CodexMonotonicClock.now(),
    );
    final label = widget.turnTimer.isRunning ? 'Elapsed' : 'Completed in';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ],
      ),
    );
  }
}
