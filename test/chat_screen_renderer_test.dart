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
  testWidgets('forwards toolbar, empty-state, and menu actions', (
    tester,
  ) async {
    final actions = <ChatScreenActionId>[];

    await tester.pumpWidget(
      _buildRendererApp(
        screen: _screenContract(
          isConfigured: false,
          emptyState: const ChatEmptyStateContract(isConfigured: false),
        ),
        onScreenAction: actions.add,
      ),
    );

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pump();

    final configureButton = find.widgetWithText(FilledButton, 'Configure remote');
    await tester.ensureVisible(configureButton);
    await tester.tap(configureButton);
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<ChatScreenActionId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New thread'));
    await tester.pumpAndSettle();

    expect(actions, <ChatScreenActionId>[
      ChatScreenActionId.openSettings,
      ChatScreenActionId.openSettings,
      ChatScreenActionId.newThread,
    ]);
  });

  testWidgets('forwards composer interactions through renderer callbacks', (
    tester,
  ) async {
    final draftValues = <String>[];
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildRendererApp(
        screen: _screenContract(),
        onComposerDraftChanged: draftValues.add,
        onSendPrompt: () async {
          sendCalls += 1;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Plan phase 6');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(draftValues, <String>['Plan phase 6']);
    expect(sendCalls, 1);
  });
}

Widget _buildRendererApp({
  required ChatScreenContract screen,
  ValueChanged<ChatScreenActionId>? onScreenAction,
  ValueChanged<String>? onComposerDraftChanged,
  Future<void> Function()? onSendPrompt,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: FlutterChatScreenRenderer(
      screen: screen,
      onScreenAction: onScreenAction ?? (_) {},
      onAutoFollowEligibilityChanged: (_) {},
      onComposerDraftChanged: onComposerDraftChanged ?? (_) {},
      onSendPrompt: onSendPrompt ?? () async {},
      onStopActiveTurn: () async {},
    ),
  );
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
      placeholder: 'Describe what you want Codex to do…',
      primaryAction: ChatComposerPrimaryAction.send,
    ),
    connectionSettings: ChatConnectionSettingsLaunchContract(
      initialProfile: ConnectionProfile.defaults(),
      initialSecrets: const ConnectionSecrets(),
    ),
  );
}
