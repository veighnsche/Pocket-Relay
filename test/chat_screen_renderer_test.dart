import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';

void main() {
  testWidgets('renders the explicit shell regions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: FlutterChatScreenRenderer(
          screen: _screenContract(),
          appChrome: const _TestAppChrome(),
          transcriptRegion: const Center(child: Text('Transcript region')),
          composerRegion: const Text('Composer region'),
        ),
      ),
    );

    expect(find.text('Injected chrome'), findsOneWidget);
    expect(find.text('Transcript region'), findsOneWidget);
    expect(find.text('Composer region'), findsOneWidget);
  });

  testWidgets('forwards toolbar and menu actions through app chrome', (
    tester,
  ) async {
    final actions = <ChatScreenActionId>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          appBar: FlutterChatAppChrome(
            screen: _screenContract(),
            onScreenAction: actions.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<ChatScreenActionId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New thread'));
    await tester.pumpAndSettle();

    expect(actions, <ChatScreenActionId>[
      ChatScreenActionId.openSettings,
      ChatScreenActionId.newThread,
    ]);
  });

  testWidgets('forwards empty-state actions through transcript region', (
    tester,
  ) async {
    final actions = <ChatScreenActionId>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: FlutterChatTranscriptRegion(
            screen: _screenContract(
              isConfigured: false,
              emptyState: const ChatEmptyStateContract(isConfigured: false),
            ),
            onScreenAction: actions.add,
            onAutoFollowEligibilityChanged: (_) {},
          ),
        ),
      ),
    );

    final configureButton = find.widgetWithText(
      FilledButton,
      'Configure remote',
    );
    await tester.ensureVisible(configureButton);
    await tester.tap(configureButton);
    await tester.pump();

    expect(actions, <ChatScreenActionId>[ChatScreenActionId.openSettings]);
  });

  testWidgets('forwards composer interactions through composer region', (
    tester,
  ) async {
    final draftValues = <String>[];
    var sendCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: FlutterChatComposerRegion(
            composer: _screenContract().composer,
            onComposerDraftChanged: draftValues.add,
            onSendPrompt: () async {
              sendCalls += 1;
            },
            onStopActiveTurn: () async {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Plan phase 6');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(draftValues, <String>['Plan phase 6']);
    expect(sendCalls, 1);
  });
}

ChatScreenContract _screenContract({
  bool isConfigured = true,
  ChatEmptyStateContract? emptyState,
}) {
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
    ],
    transcriptSurface: ChatTranscriptSurfaceContract(
      isConfigured: isConfigured,
      mainItems: const <ChatTranscriptItemContract>[],
      pinnedItems: const <ChatTranscriptItemContract>[],
      pendingRequestPlacement: ChatPendingRequestPlacementContract(
        visibleApprovalRequest: null,
        visibleUserInputRequest: null,
      ),
      activePendingUserInputRequestIds: const <String>{},
      emptyState: emptyState,
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

class _TestAppChrome extends StatelessWidget implements PreferredSizeWidget {
  const _TestAppChrome();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Injected chrome'));
  }
}
