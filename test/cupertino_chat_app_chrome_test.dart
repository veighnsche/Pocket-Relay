import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
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
      isTextInputEnabled: true,
      isPrimaryActionEnabled: true,
      isBusy: false,
      placeholder: 'Message Codex',
      primaryAction: ChatComposerPrimaryAction.send,
    ),
    connectionSettings: ChatConnectionSettingsLaunchContract(
      initialProfile: ConnectionProfile.defaults(),
      initialSecrets: const ConnectionSecrets(),
    ),
  );
}
