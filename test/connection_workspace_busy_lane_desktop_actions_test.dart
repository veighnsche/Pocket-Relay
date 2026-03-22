import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';

import 'support/fake_connection_settings_overlay_delegate.dart';

void main() {
  testWidgets(
    'desktop live-lane destructive actions are disabled while the lane is busy',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await _startBusyTurn(
        controller.bindingForConnectionId('conn_primary')!,
        clientsById['conn_primary']!,
      );
      await tester.pumpWidget(
        _buildShell(
          controller,
          conversationHistoryRepository:
              FakeCodexWorkspaceConversationHistoryRepository(
                conversations: <CodexWorkspaceConversationSummary>[
                  CodexWorkspaceConversationSummary(
                    threadId: 'thread_saved',
                    preview: 'Saved backend thread',
                    cwd: '/workspace',
                    promptCount: 3,
                    firstPromptAt: DateTime(2026, 3, 20, 9),
                    lastActivityAt: DateTime(2026, 3, 20, 11),
                  ),
                ],
              ),
        ),
      );
      await tester.pumpAndSettle();

      final closeButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
      );
      expect(closeButton.onPressed, isNull);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      final historyItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Conversation history'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );
      final closeLaneItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Close lane'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );

      expect(historyItem.enabled, isFalse);
      expect(closeLaneItem.enabled, isFalse);
    },
  );
}

Widget _buildShell(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
  CodexWorkspaceConversationHistoryRepository? conversationHistoryRepository,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ConnectionWorkspaceDesktopShell(
      workspaceController: controller,
      platformPolicy: PocketPlatformPolicy.resolve(
        platform: TargetPlatform.macOS,
      ),
      conversationHistoryRepository: conversationHistoryRepository,
      settingsOverlayDelegate:
          settingsOverlayDelegate ?? FakeConnectionSettingsOverlayDelegate(),
    ),
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
}) {
  final repository = MemoryCodexConnectionRepository(
    initialConnections: <SavedConnection>[
      SavedConnection(
        id: 'conn_primary',
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      ),
      SavedConnection(
        id: 'conn_secondary',
        profile: _profile('Secondary Box', 'secondary.local'),
        secrets: const ConnectionSecrets(password: 'secret-2'),
      ),
    ],
  );
  return ConnectionWorkspaceController(
    connectionRepository: repository,
    laneBindingFactory: ({required connectionId, required connection}) {
      final appServerClient = clientsById[connectionId]!;
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: repository,
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: connection.profile,
          secrets: connection.secrets,
        ),
        ownsAppServerClient: false,
      );
    },
  );
}

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById(
  String firstConnectionId,
  String secondConnectionId,
) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    secondConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

Future<void> _startBusyTurn(
  ConnectionLaneBinding binding,
  FakeCodexAppServerClient appServerClient,
) async {
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'thread/started',
      params: <String, Object?>{
        'thread': <String, Object?>{'id': 'thread_123'},
      },
    ),
  );
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'turn/started',
      params: <String, Object?>{
        'threadId': 'thread_123',
        'turn': <String, Object?>{
          'id': 'turn_running',
          'status': 'running',
          'model': 'gpt-5.4',
          'effort': 'high',
        },
      },
    ),
  );
  await Future<void>.delayed(Duration.zero);
  expect(binding.sessionController.sessionState.isBusy, isTrue);
}

class FakeCodexWorkspaceConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  FakeCodexWorkspaceConversationHistoryRepository({
    this.conversations = const <CodexWorkspaceConversationSummary>[],
  });

  final List<CodexWorkspaceConversationSummary> conversations;

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return conversations;
  }
}
