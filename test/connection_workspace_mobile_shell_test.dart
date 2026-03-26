import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_mobile_shell.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'support/fakes/connection_settings_overlay_delegate.dart';

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
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(controller.state.isShowingSavedConnections, isTrue);
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

    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(
      find.byKey(const ValueKey('saved_connections_page')),
      findsOneWidget,
    );
  });

  testWidgets('lane strip opens the workspace conversation history sheet', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    final repository = FakeCodexWorkspaceConversationHistoryRepository(
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
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      _buildShell(controller, conversationHistoryRepository: repository),
    );
    await tester.pumpAndSettle();

    await _openLaneConversationHistory(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Saved backend thread'), findsOneWidget);
    expect(find.textContaining('2 prompts'), findsOneWidget);
    expect(repository.loadOwnerIds, <String?>['conn_primary']);
  });

  testWidgets(
    'mobile shell keeps the live lane empty until history is explicitly picked',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(_buildShell(controller));
      await tester.pumpAndSettle();

      expect(find.text('Restored answer'), findsNothing);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
    },
  );

  testWidgets(
    'mobile conversation history row resumes the selected Codex thread',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadsById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
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

      await _openLaneConversationHistory(tester);
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_saved')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restored answer'), findsOneWidget);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
    },
  );

  testWidgets(
    'mobile conversation history row surfaces unavailable-history chrome when the selected transcript is empty',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_empty'] =
          const CodexAppServerThreadHistory(
            id: 'thread_empty',
            name: 'Empty conversation',
            sourceKind: 'app-server',
            turns: <CodexAppServerHistoryTurn>[],
          );
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
                    threadId: 'thread_empty',
                    preview: 'Empty backend thread',
                    cwd: '/workspace',
                    promptCount: 0,
                    firstPromptAt: null,
                    lastActivityAt: DateTime(2026, 3, 20, 11),
                  ),
                ],
              ),
        ),
      );
      await tester.pumpAndSettle();

      await _openLaneConversationHistory(tester);
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_empty')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transcript history unavailable'), findsOneWidget);
      expect(find.text('Retry load'), findsOneWidget);
    },
  );

  testWidgets('lane strip shows a generic conversation history backend error', (
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
              error: StateError('history backend unavailable'),
            ),
      ),
    );
    await tester.pumpAndSettle();

    await _openLaneConversationHistory(tester);

    expect(find.text('Could not load conversations'), findsOneWidget);
    expect(
      find.textContaining(
        '[${PocketErrorCatalog.connectionHistoryLoadFailed.code}]',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'when the active lane has no workspace, the lane strip disables history and the overflow keeps only roster actions',
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
      expect(
        find.byKey(const ValueKey('lane_connection_action_history')),
        findsNothing,
      );
      expect(closeLaneItem.enabled, isTrue);
      expect(savedConnectionsItem.enabled, isTrue);
      expect(
        find.ancestor(
          of: find.text('Conversation history'),
          matching: find.byType(PopupMenuItem<int>),
        ),
        findsNothing,
      );
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('open_connection_conn_secondary')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open_connection_conn_secondary')),
    );
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
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, isNull);
    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(
      find.byKey(const ValueKey('saved_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
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
        find.byKey(const ValueKey('saved_connection_conn_created')),
        findsOneWidget,
      );
      expect(controller.state.catalog.orderedConnectionIds, <String>[
        'conn_created',
      ]);
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.isShowingSavedConnections, isTrue);
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
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lane_connection_status_strip')),
          matching: find.text('Changes pending'),
        ),
        findsNothing,
      );
      expect(find.text('Apply changes'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'transport loss shows reconnect copy instead of saved-settings copy',
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

      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await tester.pump();

      await clientsById['conn_primary']!.disconnect();
      await tester.pump();

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Changes pending'), findsNothing);
      expect(find.text('Apply changes'), findsNothing);
      expect(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
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
      await tester.tap(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
      );
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(find.text('Changes pending'), findsNothing);
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
      await tester.ensureVisible(
        find.byKey(const ValueKey('open_connection_conn_secondary')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('open_connection_conn_secondary')),
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

  testWidgets('adding a dormant connection appends a new roster entry', (
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

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('saved_connection_conn_created')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('saved_connection_conn_created')),
      findsOneWidget,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_secondary',
      'conn_created',
    ]);
  });

  testWidgets('editing a dormant connection updates the roster entry', (
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit_conn_secondary')),
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('delete_conn_secondary')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_conn_secondary')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsNothing,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
    ]);
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

Future<void> _openLaneConversationHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conversation history'));
  await tester.pumpAndSettle();
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
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
  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    remoteAppServerHostProbe: const _FakeRemoteHostProbe(
      CodexRemoteAppServerHostCapabilities(),
    ),
    remoteAppServerOwnerInspector: const _StaticRemoteOwnerInspector(
      CodexRemoteAppServerOwnerSnapshot(
        ownerId: 'conn_primary',
        workspaceDir: '/workspace',
        status: CodexRemoteAppServerOwnerStatus.stopped,
        sessionName: 'pocket-relay-conn_primary',
      ),
    ),
    remoteAppServerOwnerControl: const _StaticRemoteOwnerControl(
      CodexRemoteAppServerOwnerSnapshot(
        ownerId: 'conn_primary',
        workspaceDir: '/workspace',
        status: CodexRemoteAppServerOwnerStatus.stopped,
        sessionName: 'pocket-relay-conn_primary',
      ),
    ),
    laneBindingFactory: ({required connectionId, required connection}) {
      final appServerClient = clientsById[connectionId]!;
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: resolvedRepository,
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

final class _FakeRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const _FakeRemoteHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class _StaticRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const _StaticRemoteOwnerInspector(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class _StaticRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const _StaticRemoteOwnerControl(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }
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

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

class FakeCodexWorkspaceConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  FakeCodexWorkspaceConversationHistoryRepository({
    this.conversations = const <CodexWorkspaceConversationSummary>[],
    this.error,
  });

  final List<CodexWorkspaceConversationSummary> conversations;
  final Object? error;
  final List<String?> loadOwnerIds = <String?>[];

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    loadOwnerIds.add(ownerId);
    if (error != null) {
      throw error!;
    }
    return conversations;
  }
}
