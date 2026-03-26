import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/turn_elapsed_footer.dart';

class ChatScreenGradientBackground extends StatelessWidget {
  const ChatScreenGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
        ),
      ),
      child: child,
    );
  }
}

class ChatScreenBody extends StatelessWidget {
  const ChatScreenBody({
    super.key,
    required this.platformBehavior,
    required this.screen,
    required this.transcriptRegion,
    required this.composerRegion,
    required this.loadingIndicator,
    required this.onStopActiveTurn,
    this.supplementalStatusRegion,
    this.laneRestartAction,
    this.onRestartLane,
  });

  static const double _desktopContentMaxWidth = 1120;

  final PocketPlatformBehavior platformBehavior;
  final ChatScreenContract screen;
  final Widget transcriptRegion;
  final Widget composerRegion;
  final Widget loadingIndicator;
  final Future<void> Function() onStopActiveTurn;
  final Widget? supplementalStatusRegion;
  final ChatLaneRestartActionContract? laneRestartAction;
  final Future<void> Function()? onRestartLane;

  @override
  Widget build(BuildContext context) {
    if (screen.isLoading) {
      return Center(child: loadingIndicator);
    }

    return Column(
      children: [
        if (supplementalStatusRegion != null)
          _wrapDesktopLaneSection(
            supplementalStatusRegion!,
            key: const ValueKey<String>('desktop_chat_status_region'),
          ),
        Expanded(
          child: _wrapDesktopLaneSection(
            transcriptRegion,
            key: const ValueKey<String>('desktop_chat_transcript_region'),
          ),
        ),
        if (screen.turnIndicator != null || laneRestartAction != null)
          _wrapDesktopLaneSection(
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: TurnElapsedFooter(
                turnTimer: screen.turnIndicator?.timer,
                onStop: onStopActiveTurn,
                laneRestartAction: laneRestartAction,
                onRestart: onRestartLane,
              ),
            ),
            key: const ValueKey<String>('desktop_chat_footer_region'),
          ),
        _wrapDesktopLaneSection(
          composerRegion,
          key: const ValueKey<String>('desktop_chat_composer_region'),
        ),
      ],
    );
  }

  Widget _wrapDesktopLaneSection(Widget child, {required Key key}) {
    if (!platformBehavior.isDesktopExperience) {
      return child;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: SizedBox(key: key, width: double.infinity, child: child),
        ),
      ),
    );
  }
}
