import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';

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
    final navigationBar = switch (appChrome) {
      final ObstructingPreferredSizeWidget chrome => chrome,
      _ => null,
    };
    final body = Material(
      type: MaterialType.transparency,
      child: ChatScreenBody(
        screen: screen,
        transcriptRegion: transcriptRegion,
        composerRegion: composerRegion,
        loadingIndicator: const CupertinoActivityIndicator(),
      ),
    );

    return CupertinoTheme(
      data: buildPocketCupertinoTheme(Theme.of(context)),
      child: CupertinoPageScaffold(
        navigationBar: navigationBar,
        child: ChatScreenGradientBackground(
          child: navigationBar == null
              ? SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      appChrome,
                      Expanded(child: body),
                    ],
                  ),
                )
              : body,
        ),
      ),
    );
  }
}
