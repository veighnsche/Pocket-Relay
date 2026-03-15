import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart';

class CupertinoChatScreenRenderer extends StatelessWidget {
  const CupertinoChatScreenRenderer({
    super.key,
    required this.screen,
    required this.appChrome,
    required this.transcriptRegion,
    required this.composerRegion,
  });

  final ChatScreenContract screen;
  final PreferredSizeWidget appChrome;
  final Widget transcriptRegion;
  final Widget composerRegion;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return CupertinoTheme(
      data: MaterialBasedCupertinoThemeData(materialTheme: Theme.of(context)),
      child: CupertinoPageScaffold(
        backgroundColor: palette.backgroundTop,
        child: Material(
          type: MaterialType.transparency,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appChrome,
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    palette.backgroundTop,
                    palette.backgroundBottom,
                  ],
                ),
              ),
              child: screen.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : Column(
                      children: [
                        Expanded(child: transcriptRegion),
                        if (screen.turnIndicator case final turnIndicator?)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                            child: TurnElapsedFooter(
                              turnTimer: turnIndicator.timer,
                            ),
                          ),
                        composerRegion,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
