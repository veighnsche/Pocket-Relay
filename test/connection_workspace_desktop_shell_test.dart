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
import 'support/fakes/connection_settings_overlay_delegate.dart';

void main() {
  testWidgets('renders a unified connection inventory in the desktop sidebar', (
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
    expect(find.text('Inventory'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_saved_connections')),
      findsOneWidget,
    );
    expect(find.text('Manage connections'), findsOneWidget);
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

      await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
      await tester.pumpAndSettle();

      expect(controller.state.isShowingSavedConnections, isTrue);
      expect(
        find.byKey(const ValueKey('saved_connection_conn_secondary')),
        findsOneWidget,
      );
    },
  );

  testWidgets('manage connections action shows the roster in the main pane', (
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

    await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets(
    'dormant inventory rows open a lane directly from the desktop sidebar',
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

      await tester.tap(
        find.byKey(const ValueKey('desktop_connection_conn_secondary')),
      );
      await tester.pumpAndSettle();

      expect(controller.state.isShowingLiveLane, isTrue);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(controller.state.liveConnectionIds, <String>[
        'conn_primary',
        'conn_secondary',
      ]);
    },
  );

  testWidgets(
    'desktop sidebar surfaces lane open failures instead of leaking async errors',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final repository = _FailingLoadConnectionRepository(
        delegate: MemoryCodexConnectionRepository(
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
        ),
        failingConnectionId: 'conn_secondary',
        error: StateError('saved definition unavailable'),
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

      await tester.tap(
        find.byKey(const ValueKey('desktop_connection_conn_secondary')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open lane'), findsOneWidget);
      expect(
        find.textContaining('saved definition unavailable'),
        findsOneWidget,
      );
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    },
  );

  testWidgets(
    'desktop lane strip opens the workspace conversation history sheet',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final repository = FakeCodexWorkspaceConversationHistoryRepository(
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

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('desktop_conversation_history_surface'),
        ),
        findsOneWidget,
      );
      expect(find.text('Saved backend thread'), findsOneWidget);
      expect(repository.loadCalls, hasLength(1));
      expect(repository.loadCalls.single.$3, 'conn_primary');
    },
  );

  testWidgets(
    'desktop conversation history does not reload while the dialog rebuilds on resize',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final repository = FakeCodexWorkspaceConversationHistoryRepository(
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
      );
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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

      expect(repository.loadCalls, hasLength(1));

      tester.view.physicalSize = const Size(1440, 960);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('desktop_conversation_history_surface'),
        ),
        findsOneWidget,
      );
      expect(repository.loadCalls, hasLength(1));
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

  testWidgets('desktop conversation history shows a generic backend error', (
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
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets(
    'desktop conversation history surfaces remote server health and opens connection settings',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
          conversationHistoryRepository:
              FakeCodexWorkspaceConversationHistoryRepository(
                error: const CodexRemoteAppServerAttachException(
                  snapshot: CodexRemoteAppServerOwnerSnapshot(
                    ownerId: 'conn_primary',
                    workspaceDir: '/workspace',
                    status: CodexRemoteAppServerOwnerStatus.unhealthy,
                    sessionName: 'pocket-relay-conn_primary',
                    endpoint: CodexRemoteAppServerEndpoint(
                      host: '127.0.0.1',
                      port: 4100,
                    ),
                    detail: 'readyz failed',
                  ),
                  message: 'readyz failed',
                ),
              ),
        ),
      );
      await tester.pumpAndSettle();

      await _openLaneConversationHistory(tester);

      expect(find.text('Remote server unhealthy'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionHistoryServerUnhealthy.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('readyz failed'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_history_open_connection_settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(1));
      expect(
        settingsOverlayDelegate.launchedSettings.single.$1.host,
        'primary.local',
      );
    },
  );

  testWidgets(
    'desktop conversation history can open connection settings for an unpinned host key',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
          conversationHistoryRepository:
              FakeCodexWorkspaceConversationHistoryRepository(
                error:
                    const CodexWorkspaceConversationHistoryUnpinnedHostKeyException(
                      host: 'example.com',
                      port: 22,
                      keyType: 'ssh-ed25519',
                      fingerprint: '7a:9f:d7:dc:2e:f2',
                    ),
              ),
        ),
      );
      await tester.pumpAndSettle();

      await _openLaneConversationHistory(tester);

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionHistoryHostKeyUnpinned.code}]',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_history_open_connection_settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(1));
      expect(
        settingsOverlayDelegate.launchedSettings.single.$1.host,
        'primary.local',
      );
      expect(
        settingsOverlayDelegate.launchedSettings.single.$2.password,
        'secret-1',
      );
    },
  );

  testWidgets(
    'desktop conversation history retries with saved connection edits when reconnect is required',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final repository = FakeCodexWorkspaceConversationHistoryRepository();
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile(
          'Primary Box',
          'saved.primary.local',
        ).copyWith(hostFingerprint: 'SHA256:saved'),
        secrets: const ConnectionSecrets(password: 'saved-secret'),
      );

      await tester.pumpWidget(
        _buildShell(controller, conversationHistoryRepository: repository),
      );
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);

      await _openLaneConversationHistory(tester);

      expect(repository.loadCalls, hasLength(1));
      expect(repository.loadCalls.single.$1.host, 'saved.primary.local');
      expect(repository.loadCalls.single.$1.hostFingerprint, 'SHA256:saved');
      expect(repository.loadCalls.single.$2.password, 'saved-secret');
    },
  );

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

      await _openLaneConversationHistory(tester);
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

      await _openLaneConversationHistory(tester);
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

      await _openLaneConversationHistory(tester);
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
      await tester.pump(const Duration(milliseconds: 300));

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

    controller.showSavedConnections();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_connection_conn_secondary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.isShowingLiveLane, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
        matching: find.text('Secondary Box'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
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
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(
      find.byKey(const ValueKey('desktop_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
        matching: find.text('Secondary Box'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
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

    await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
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

    await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
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
        find.descendant(
          of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
          matching: find.text('Secondary Box'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
          matching: find.text('Remote connection not configured'),
        ),
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

Future<void> _openLaneConversationHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conversation history'));
  await tester.pumpAndSettle();
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
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

final class _FailingLoadConnectionRepository
    implements CodexConnectionRepository {
  _FailingLoadConnectionRepository({
    required this.delegate,
    required this.failingConnectionId,
    required this.error,
  });

  final CodexConnectionRepository delegate;
  final String failingConnectionId;
  final Object error;

  @override
  Future<ConnectionCatalogState> loadCatalog() => delegate.loadCatalog();

  @override
  Future<SavedConnection> loadConnection(String connectionId) {
    if (connectionId == failingConnectionId) {
      throw error;
    }
    return delegate.loadConnection(connectionId);
  }

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) => delegate.createConnection(profile: profile, secrets: secrets);

  @override
  Future<void> saveConnection(SavedConnection connection) =>
      delegate.saveConnection(connection);

  @override
  Future<void> deleteConnection(String connectionId) =>
      delegate.deleteConnection(connectionId);
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
  final List<(ConnectionProfile, ConnectionSecrets, String?)> loadCalls =
      <(ConnectionProfile, ConnectionSecrets, String?)>[];

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    loadCalls.add((profile, secrets, ownerId));
    if (error != null) {
      throw error!;
    }
    return conversations;
  }
}
