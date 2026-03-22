import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'support/fake_connection_settings_overlay_delegate.dart';

void main() {
  testWidgets('renders live and dormant sections in the desktop sidebar', (
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

    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Open lanes'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop_live_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_dormant_roster')),
      findsOneWidget,
    );
    expect(find.textContaining('Secondary Box'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop_sidebar_toggle')),
      findsOneWidget,
    );
    expect(find.byType(IconButton), findsWidgets);
  });

  testWidgets(
    'desktop shell keeps the live lane empty until history is explicitly picked',
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
    'desktop shell does not surface unavailable-history chrome on startup',
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
      await tester.pumpWidget(_buildShell(controller));
      await tester.pumpAndSettle();

      expect(find.text('Transcript history unavailable'), findsNothing);
      expect(find.text('Retry load'), findsNothing);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
    },
  );

  testWidgets(
    'macOS sidebar can collapse into a thin rail and still open saved connections',
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

      final expandedWidth = tester
          .getSize(find.byKey(const ValueKey('desktop_sidebar')))
          .width;

      await tester.tap(find.byKey(const ValueKey('desktop_sidebar_toggle')));
      await tester.pumpAndSettle();

      final collapsedWidth = tester
          .getSize(find.byKey(const ValueKey('desktop_sidebar')))
          .width;

      expect(collapsedWidth, lessThan(expandedWidth));
      expect(collapsedWidth, lessThanOrEqualTo(80));
      expect(find.text('Connections'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
      await tester.pumpAndSettle();

      expect(controller.state.isShowingDormantRoster, isTrue);
      expect(
        find.byKey(const ValueKey('dormant_connection_conn_secondary')),
        findsOneWidget,
      );
    },
  );

  testWidgets('dormant sidebar action shows the roster in the main pane', (
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

    await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets(
    'desktop overflow menu opens the workspace conversation history sheet',
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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation history'));
      await tester.pumpAndSettle();

      expect(find.text('Saved backend thread'), findsOneWidget);
    },
  );
  testWidgets(
    'desktop overflow disables non-roster actions when the active lane has no workspace',
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

  testWidgets('desktop conversation history shows an honest error for now', (
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

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversation history'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load conversations'), findsOneWidget);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets(
    'desktop conversation history row resumes the selected Codex thread',
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
                    promptCount: 3,
                    firstPromptAt: DateTime(2026, 3, 20, 9),
                    lastActivityAt: DateTime(2026, 3, 20, 11),
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
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_saved')),
      );
      await tester.pumpAndSettle();

      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(find.text('Restored answer'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
    },
  );

  testWidgets(
    'desktop conversation history row surfaces unavailable-history chrome when the selected transcript is empty',
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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_empty')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transcript history unavailable'), findsOneWidget);
      expect(find.text('Retry load'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop conversation history resume primes the lane so the next send stays on that conversation',
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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_saved')),
      );
      await tester.pumpAndSettle();

      expect(clientsById['conn_primary']!.startSessionCalls, 0);

      expect(
        await controller.selectedLaneBinding!.sessionController.sendPrompt(
          'Continue this thread',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(clientsById['conn_primary']!.startSessionCalls, 1);
      expect(
        clientsById['conn_primary']!.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(clientsById['conn_primary']!.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_saved',
          input: const CodexAppServerTurnInput.text('Continue this thread'),
          text: 'Continue this thread',
          model: null,
          effort: null,
        ),
      ]);
    },
  );

  testWidgets('selecting a live lane from the sidebar returns to the lane', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    controller.showDormantRoster();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop_live_conn_secondary')));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingLiveLane, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_live_conn_secondary')),
        matching: find.text('Secondary Box'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_live_conn_secondary')),
        matching: find.text('secondary.local · /workspace'),
      ),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('closing a live lane from the sidebar keeps other lanes intact', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(controller.state.dormantConnectionIds, <String>['conn_primary']);
    expect(
      find.byKey(const ValueKey('desktop_live_conn_primary')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_live_conn_secondary')),
        matching: find.text('Secondary Box'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_live_conn_secondary')),
        matching: find.text('secondary.local · /workspace'),
      ),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 1);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('closing the last live lane shows the dormant roster', (
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

    await tester.tap(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, isEmpty);
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

  testWidgets('empty workspace shows the first-connection CTA', (tester) async {
    final controller = _buildWorkspaceController(
      clientsById: <String, FakeCodexAppServerClient>{},
      repository: MemoryCodexConnectionRepository(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    expect(find.text('No saved connections yet.'), findsOneWidget);
    expect(find.text('Return to open lane'), findsNothing);
    expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);
  });

  testWidgets(
    'desktop live rows show a saved-changes badge when reconnect is pending',
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
      expect(find.text('Restart needed'), findsNWidgets(2));
      expect(find.text('Saved settings are pending'), findsNothing);
      expect(find.byKey(const ValueKey('restart_lane')), findsOneWidget);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  testWidgets('desktop dormant roster can add a saved connection', (
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

    await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
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
  });

  testWidgets('desktop dormant roster can delete a dormant connection', (
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

    await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
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
  });

  testWidgets(
    'desktop sidebar shows an explicit fallback for an unconfigured saved connection',
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
            profile: _profile('Secondary Box', '').copyWith(workspaceDir: ''),
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

      expect(
        find.text('Secondary Box · Remote connection not configured'),
        findsOneWidget,
      );
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
