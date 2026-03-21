import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart';

import 'support/fake_codex_app_server_client.dart';
import 'support/fake_connection_settings_overlay_delegate.dart';

void main() {
  testWidgets('swiping past the live lane reveals the dormant roster', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved connections'), findsWidgets);
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_primary');
  });

  testWidgets('overflow menu opens the dormant roster page', (tester) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved connections'));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(find.byKey(const ValueKey('dormant_roster_page')), findsOneWidget);
  });

  testWidgets('overflow menu opens the workspace conversation history sheet', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
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
                  promptCount: 2,
                  firstPromptAt: DateTime(2026, 3, 20, 9),
                  lastActivityAt: DateTime(2026, 3, 20, 10),
                ),
              ],
            ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversation history'));
    await tester.pumpAndSettle();

    expect(find.text('Saved backend thread'), findsOneWidget);
    expect(find.textContaining('2 prompts'), findsOneWidget);
  });

  testWidgets(
    'overflow menu shows an honest error until Codex-backed history loading exists',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          conversationHistoryRepository:
              FakeCodexWorkspaceConversationHistoryRepository(
                error: StateError('history backend unavailable'),
              ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation history'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load conversations'), findsOneWidget);
    },
  );
  testWidgets(
    'overflow menu disables non-roster actions when the active lane has no workspace',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile(
              'Primary Box',
              'primary.local',
            ).copyWith(workspaceDir: ''),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: _profile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(_buildShell(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      final newThreadItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('New thread'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );
      final clearTranscriptItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Clear transcript'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );
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
      final savedConnectionsItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Saved connections'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );

      expect(newThreadItem.enabled, isFalse);
      expect(clearTranscriptItem.enabled, isFalse);
      expect(historyItem.enabled, isFalse);
      expect(closeLaneItem.enabled, isFalse);
      expect(savedConnectionsItem.enabled, isTrue);
    },
  );

  testWidgets('swiping offscreen does not dispose the live lane', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets('iPhone saved connections page uses material primitives', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      _buildShell(controller, platform: TargetPlatform.iOS),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved connections'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Add connection'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open lane'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsWidgets);
  });

  testWidgets('instantiating from the roster opens a new live lane', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('instantiate_conn_secondary')));
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(controller.state.isShowingLiveLane, isTrue);
    expect(find.text('Secondary Box'), findsOneWidget);
    expect(find.text('secondary.local'), findsOneWidget);
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('workspace_page_view')),
    );
    expect(pageView.childrenDelegate.estimatedChildCount, 3);
  });

  testWidgets('closing the only live lane from the overflow shows the roster', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close lane'));
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, isEmpty);
    expect(controller.state.dormantConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, isNull);
    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 1);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets(
    'empty workspace shows a first-connection CTA and can create the first saved connection',
    (tester) async {
      final controller = _buildWorkspaceController(
        clientsById: <String, FakeCodexAppServerClient>{},
        repository: MemoryCodexConnectionRepository(
          connectionIdGenerator: () => 'conn_created',
        ),
      );
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: _profile('Created Box', 'created.local'),
            secrets: const ConnectionSecrets(password: 'secret-3'),
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved connections yet.'), findsOneWidget);
      expect(find.text('Return to open lane'), findsNothing);
      expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add_connection')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dormant_connection_conn_created')),
        findsOneWidget,
      );
      expect(controller.state.catalog.orderedConnectionIds, <String>[
        'conn_created',
      ]);
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.isShowingDormantRoster, isTrue);
    },
  );

  testWidgets(
    'saving live settings stages reconnect-required state without disconnecting the lane',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: _profile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(find.text('Saved settings are pending'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('apply_saved_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live settings reopen with the staged saved definition while reconnect is pending',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: _profile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
          null,
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(2));
      expect(
        settingsOverlayDelegate.launchedSettings.last.$1.host,
        'primary.changed',
      );
      expect(
        settingsOverlayDelegate.launchedSettings.last.$2,
        const ConnectionSecrets(password: 'updated-secret'),
      );
    },
  );

  testWidgets(
    'applying saved settings reconnects the lane and clears reconnect-required state',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: _profile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apply_saved_settings')));
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(find.text('Saved settings are pending'), findsNothing);
      expect(find.text('Primary Renamed'), findsOneWidget);
      expect(find.text('primary.changed'), findsOneWidget);
    },
  );

  testWidgets(
    'closing the selected live lane keeps the remaining live lane active',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(_buildShell(controller));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('instantiate_conn_secondary')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close lane'));
      await tester.pumpAndSettle();

      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.isShowingLiveLane, isTrue);
      expect(find.text('Primary Box'), findsOneWidget);
      expect(find.text('primary.local'), findsOneWidget);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 1);
    },
  );

  testWidgets('adding a dormant connection appends a new roster card', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
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
      connectionIdGenerator: () => 'conn_created',
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
      results: <ConnectionSettingsSubmitPayload?>[
        ConnectionSettingsSubmitPayload(
          profile: _profile('Created Box', 'created.local'),
          secrets: const ConnectionSecrets(password: 'secret-3'),
        ),
      ],
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      _buildShell(controller, settingsOverlayDelegate: settingsOverlayDelegate),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add_connection')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dormant_connection_conn_created')),
      findsOneWidget,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.state.dormantConnectionIds, <String>[
      'conn_secondary',
      'conn_created',
    ]);
  });

  testWidgets('editing a dormant connection updates the roster card', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
      results: <ConnectionSettingsSubmitPayload?>[
        ConnectionSettingsSubmitPayload(
          profile: _profile('Secondary Renamed', 'secondary.changed'),
          secrets: const ConnectionSecrets(password: 'updated-secret'),
        ),
      ],
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      _buildShell(controller, settingsOverlayDelegate: settingsOverlayDelegate),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
    await tester.pumpAndSettle();

    expect(find.text('Secondary Renamed'), findsOneWidget);
    expect(find.text('Secondary Renamed'), findsOneWidget);
    expect(find.text('secondary.changed · /workspace'), findsOneWidget);
    expect(
      controller.state.catalog.connectionForId('conn_secondary')?.profile.host,
      'secondary.changed',
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets(
    'saved connection cards show a workspace fallback when the saved path is missing',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: _profile(
              'Secondary Box',
              'secondary.local',
            ).copyWith(workspaceDir: ''),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(_buildShell(controller));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Secondary Box'), findsOneWidget);
      expect(find.text('secondary.local · Workspace not set'), findsOneWidget);
    },
  );

  testWidgets('deleting a dormant connection removes it from the roster', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final conversationStateStore = MemoryCodexConnectionConversationStateStore(
      initialStates: <String, SavedConnectionConversationState>{
        'conn_secondary': const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
      },
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      conversationStateStore: conversationStateStore,
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete_conn_secondary')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsNothing,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(
      await conversationStateStore.loadState('conn_secondary'),
      const SavedConnectionConversationState(),
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });
}

Widget _buildShell(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
  CodexWorkspaceConversationHistoryRepository? conversationHistoryRepository,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ConnectionWorkspaceMobileShell(
      workspaceController: controller,
      platformPolicy: PocketPlatformPolicy.resolve(platform: platform),
      conversationHistoryRepository: conversationHistoryRepository,
      settingsOverlayDelegate:
          settingsOverlayDelegate ?? FakeConnectionSettingsOverlayDelegate(),
    ),
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
  MemoryCodexConnectionConversationStateStore? conversationStateStore,
}) {
  final resolvedRepository =
      repository ??
      MemoryCodexConnectionRepository(
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
  final resolvedConversationStateStore =
      conversationStateStore ?? MemoryCodexConnectionConversationStateStore();

  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    connectionConversationStateStore: resolvedConversationStateStore,
    laneBindingFactory:
        ({
          required connectionId,
          required connection,
          required conversationState,
        }) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: resolvedRepository,
            ),
            conversationStateStore: ConnectionScopedConversationStateStore(
              connectionId: connectionId,
              conversationStateStore: resolvedConversationStateStore,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            initialConversationState: conversationState,
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

class FakeCodexWorkspaceConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  FakeCodexWorkspaceConversationHistoryRepository({
    this.conversations = const <CodexWorkspaceConversationSummary>[],
    this.error,
  });

  final List<CodexWorkspaceConversationSummary> conversations;
  final Object? error;

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    if (error != null) {
      throw error!;
    }
    return conversations;
  }
}
