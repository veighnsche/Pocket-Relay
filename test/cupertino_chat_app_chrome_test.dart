import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_app_chrome.dart';

void main() {
  testWidgets(
    'cupertino app chrome forwards toolbar and menu actions through the shared popup menu',
    (tester) async {
      final actions = <ChatScreenActionId>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: Column(
              children: [
                CupertinoChatAppChrome(
                  screen: _screenContract(),
                  onScreenAction: actions.add,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pocket Relay'), findsOneWidget);
      expect(find.text('Dev Box · devbox.local'), findsOneWidget);

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('cupertino_menu_actions')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('New thread'), findsOneWidget);
      expect(find.text('Clear transcript'), findsOneWidget);

      await tester.tap(find.text('Clear transcript'));
      await tester.pumpAndSettle();

      expect(actions, <ChatScreenActionId>[
        ChatScreenActionId.openSettings,
        ChatScreenActionId.clearTranscript,
      ]);
    },
  );

  testWidgets(
    'cupertino app chrome keeps a stable native background configuration',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: Column(
              children: [
                CupertinoChatAppChrome(
                  screen: _screenContract(),
                  onScreenAction: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      final navBar = tester.widget<CupertinoNavigationBar>(
        find.byType(CupertinoNavigationBar),
      );

      expect(navBar.automaticBackgroundVisibility, isFalse);
      expect(navBar.backgroundColor, isNull);
      expect(navBar.brightness, isNull);
    },
  );

  testWidgets(
    'cupertino app chrome supports supplemental workspace menu actions',
    (tester) async {
      final laneActions = <ChatScreenActionId>[];
      var openedDormantConnections = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: Column(
              children: [
                CupertinoChatAppChrome(
                  screen: _screenContract(),
                  onScreenAction: laneActions.add,
                  supplementalMenuActions: <ChatChromeMenuAction>[
                    ChatChromeMenuAction(
                      label: 'Dormant connections',
                      onSelected: () {
                        openedDormantConnections = true;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('cupertino_menu_actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dormant connections'));
      await tester.pumpAndSettle();

      expect(openedDormantConnections, isTrue);
      expect(laneActions, isEmpty);
    },
  );
}

ChatScreenContract _screenContract() {
  return ChatScreenContract(
    isLoading: false,
    header: const ChatHeaderContract(
      title: 'Pocket Relay',
      subtitle: 'Dev Box · devbox.local',
    ),
    actions: const <ChatScreenActionContract>[
      ChatScreenActionContract(
        id: ChatScreenActionId.openSettings,
        label: 'Connection settings',
        placement: ChatScreenActionPlacement.toolbar,
        tooltip: 'Connection settings',
        icon: ChatScreenActionIcon.settings,
      ),
      ChatScreenActionContract(
        id: ChatScreenActionId.newThread,
        label: 'New thread',
        placement: ChatScreenActionPlacement.menu,
      ),
      ChatScreenActionContract(
        id: ChatScreenActionId.clearTranscript,
        label: 'Clear transcript',
        placement: ChatScreenActionPlacement.menu,
      ),
    ],
    transcriptSurface: ChatTranscriptSurfaceContract(
      isConfigured: true,
      mainItems: const <ChatTranscriptItemContract>[],
      pinnedItems: const <ChatTranscriptItemContract>[],
      pendingRequestPlacement: ChatPendingRequestPlacementContract(
        visibleApprovalRequest: null,
        visibleUserInputRequest: null,
      ),
      activePendingUserInputRequestIds: const <String>{},
    ),
    transcriptFollow: const ChatTranscriptFollowContract(
      isAutoFollowEnabled: true,
      resumeDistance: 80,
    ),
    composer: const ChatComposerContract(
      draftText: '',
      isSendActionEnabled: true,
      placeholder: 'Message Codex',
    ),
    connectionSettings: ChatConnectionSettingsLaunchContract(
      initialProfile: ConnectionProfile.defaults(),
      initialSecrets: const ConnectionSecrets(),
    ),
  );
}
