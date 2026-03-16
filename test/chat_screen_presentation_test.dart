import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_composer_draft_host.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_host.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_surface_projector.dart';

const _defaultTranscriptFollowContract = ChatTranscriptFollowContract(
  isAutoFollowEnabled: true,
  resumeDistance: ChatTranscriptFollowHost.defaultResumeDistance,
);

void main() {
  group('ChatScreenPresenter', () {
    const presenter = ChatScreenPresenter();

    test(
      'derives header, actions, composer, and settings payload from raw top-level state',
      () {
        final profile = _configuredProfile();
        final secrets = const ConnectionSecrets(password: 'secret');

        final contract = presenter.present(
          isLoading: false,
          profile: profile,
          secrets: secrets,
          sessionState: CodexSessionState.initial(),
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: _defaultTranscriptFollowContract,
        );

        expect(contract.header.title, 'Pocket Relay');
        expect(contract.header.subtitle, 'Dev Box · devbox.local');
        expect(
          contract.toolbarActions.map((action) => action.id),
          <ChatScreenActionId>[ChatScreenActionId.openSettings],
        );
        expect(
          contract.menuActions.map((action) => action.id),
          <ChatScreenActionId>[
            ChatScreenActionId.newThread,
            ChatScreenActionId.clearTranscript,
          ],
        );
        expect(contract.composer.isTextInputEnabled, isTrue);
        expect(contract.composer.draftText, isEmpty);
        expect(contract.composer.primaryAction, ChatComposerPrimaryAction.send);
        expect(contract.connectionSettings.initialProfile, same(profile));
        expect(contract.connectionSettings.initialSecrets, same(secrets));
        expect(
          contract.transcriptFollow,
          same(_defaultTranscriptFollowContract),
        );
      },
    );

    test('derives stop action and turn indicator when the session is busy', () {
      final activeTurn = CodexActiveTurnState(
        turnId: 'turn_1',
        timer: CodexSessionTurnTimer(
          turnId: 'turn_1',
          startedAt: DateTime(2026, 3, 15, 12),
        ),
      );
      final sessionState = CodexSessionState.initial().copyWith(
        connectionStatus: CodexRuntimeSessionState.running,
        activeTurn: activeTurn,
      );

      final contract = presenter.present(
        isLoading: false,
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: sessionState,
        composerDraft: const ChatComposerDraft(text: 'Keep draft'),
        transcriptFollow: _defaultTranscriptFollowContract,
      );

      expect(contract.composer.draftText, 'Keep draft');
      expect(contract.composer.isBusy, isTrue);
      expect(contract.composer.isTextInputEnabled, isFalse);
      expect(contract.composer.primaryAction, ChatComposerPrimaryAction.stop);
      expect(contract.composer.isPrimaryActionEnabled, isTrue);
      expect(contract.turnIndicator?.timer, same(activeTurn.timer));
    });

    test(
      'uses a preferred empty-state connection mode without treating the profile as configured',
      () {
        final profile = ConnectionProfile.defaults();

        final contract = presenter.present(
          isLoading: false,
          profile: profile,
          secrets: const ConnectionSecrets(),
          sessionState: CodexSessionState.initial(),
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: _defaultTranscriptFollowContract,
          preferredConnectionMode: ConnectionMode.local,
        );

        expect(
          contract.transcriptSurface.emptyState?.connectionMode,
          ConnectionMode.local,
        );
        expect(
          contract.connectionSettings.initialProfile.connectionMode,
          ConnectionMode.local,
        );
        expect(contract.transcriptSurface.isConfigured, isFalse);
        expect(contract.composer.isTextInputEnabled, isFalse);
      },
    );
  });

  group('ChatTranscriptSurfaceProjector', () {
    const projector = ChatTranscriptSurfaceProjector();

    test(
      'projects transcript blocks into the main region and pending requests into the pinned region',
      () {
        final transcriptBlock = CodexTextBlock(
          id: 'assistant_1',
          kind: CodexUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Codex',
          body: 'Hello',
        );
        final activeTurn = CodexActiveTurnState(
          turnId: 'turn_1',
          timer: CodexSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
          pendingApprovalRequests: <String, CodexSessionPendingRequest>{
            'request_1': CodexSessionPendingRequest(
              requestId: 'request_1',
              requestType: CodexCanonicalRequestType.fileChangeApproval,
              createdAt: DateTime(2026, 3, 15, 12, 0, 1),
              detail: 'Approve file change',
            ),
          },
          pendingUserInputRequests:
              <String, CodexSessionPendingUserInputRequest>{
                'request_2': CodexSessionPendingUserInputRequest(
                  requestId: 'request_2',
                  requestType: CodexCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                  detail: 'Need extra info',
                ),
              },
        );
        final sessionState = CodexSessionState.initial().copyWith(
          activeTurn: activeTurn,
          blocks: <CodexUiBlock>[transcriptBlock],
        );

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        expect(surface.emptyState, isNull);
        expect(
          surface.mainItems.single,
          isA<ChatAssistantMessageItemContract>(),
        );
        expect(
          (surface.mainItems.single as ChatAssistantMessageItemContract).block,
          same(transcriptBlock),
        );
        expect(surface.pinnedItems.length, 2);
        expect(
          surface.pinnedItems.first,
          isA<ChatApprovalRequestItemContract>(),
        );
        expect(
          (surface.pinnedItems.first as ChatApprovalRequestItemContract)
              .request
              .title,
          'File change approval',
        );
        expect(
          surface.pinnedItems.last,
          isA<ChatUserInputRequestItemContract>(),
        );
        expect(
          (surface.pinnedItems.last as ChatUserInputRequestItemContract)
              .request
              .body,
          'Need extra info',
        );
        expect(
          surface.pendingRequestPlacement.visibleApprovalRequest?.requestId,
          'request_1',
        );
        expect(
          surface.pendingRequestPlacement.visibleUserInputRequest?.requestId,
          'request_2',
        );
        expect(surface.activePendingUserInputRequestIds, <String>{'request_2'});
      },
    );

    test(
      'keeps active pending user-input ids limited to the visible request when multiple pending inputs exist',
      () {
        final activeTurn = CodexActiveTurnState(
          turnId: 'turn_1',
          timer: CodexSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
          pendingUserInputRequests:
              <String, CodexSessionPendingUserInputRequest>{
                'request_newer': CodexSessionPendingUserInputRequest(
                  requestId: 'request_newer',
                  requestType: CodexCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                  detail: 'Newer input',
                ),
                'request_older': CodexSessionPendingUserInputRequest(
                  requestId: 'request_older',
                  requestType: CodexCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 1),
                  detail: 'Older input',
                ),
              },
        );
        final sessionState = CodexSessionState.initial().copyWith(
          activeTurn: activeTurn,
        );

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        expect(surface.pinnedItems, hasLength(1));
        expect(
          (surface.pinnedItems.single as ChatUserInputRequestItemContract)
              .request
              .requestId,
          'request_older',
        );
        expect(surface.activePendingUserInputRequestIds, <String>{
          'request_older',
        });
      },
    );

    test(
      'projects an empty state when no transcript or pending items are visible',
      () {
        final surface = projector.project(
          profile: ConnectionProfile.defaults(),
          sessionState: CodexSessionState.initial(),
        );

        expect(surface.showsEmptyState, isTrue);
        expect(surface.emptyState?.isConfigured, isFalse);
        expect(surface.mainItems, isEmpty);
        expect(surface.pinnedItems, isEmpty);
        expect(surface.pendingRequestPlacement.hasVisibleRequests, isFalse);
        expect(surface.activePendingUserInputRequestIds, isEmpty);
      },
    );

    test(
      'uses the injected placement projector instead of runtime convenience getters',
      () {
        final projector = ChatTranscriptSurfaceProjector(
          pendingRequestPlacementProjector:
              _FakePendingRequestPlacementProjector(
                placement: ChatPendingRequestPlacementContract(
                  visibleApprovalRequest: ChatApprovalRequestContract(
                    id: 'request_override_approval',
                    createdAt: DateTime(2026, 3, 15, 12, 0, 9),
                    requestId: 'request_override_approval',
                    requestType:
                        CodexCanonicalRequestType.commandExecutionApproval,
                    title: 'Injected approval',
                    body: 'Injected approval body',
                    isResolved: false,
                  ),
                  visibleUserInputRequest: ChatUserInputRequestContract(
                    id: 'request_override_input',
                    createdAt: DateTime(2026, 3, 15, 12, 0, 10),
                    requestId: 'request_override_input',
                    requestType: CodexCanonicalRequestType.toolUserInput,
                    title: 'Injected input',
                    body: 'Injected input body',
                    isResolved: false,
                  ),
                ),
              ),
        );
        final sessionState = CodexSessionState.initial().copyWith(
          activeTurn: CodexActiveTurnState(
            turnId: 'turn_1',
            timer: CodexSessionTurnTimer(
              turnId: 'turn_1',
              startedAt: DateTime(2026, 3, 15, 12),
            ),
            pendingApprovalRequests: <String, CodexSessionPendingRequest>{
              'runtime_approval': CodexSessionPendingRequest(
                requestId: 'runtime_approval',
                requestType: CodexCanonicalRequestType.fileChangeApproval,
                createdAt: DateTime(2026, 3, 15, 12, 0, 1),
                detail: 'Runtime approval body',
              ),
            },
            pendingUserInputRequests:
                <String, CodexSessionPendingUserInputRequest>{
                  'runtime_input': CodexSessionPendingUserInputRequest(
                    requestId: 'runtime_input',
                    requestType: CodexCanonicalRequestType.toolUserInput,
                    createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                    detail: 'Runtime input body',
                  ),
                },
          ),
        );

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        expect(surface.pinnedItems, hasLength(2));
        expect(
          (surface.pinnedItems.first as ChatApprovalRequestItemContract)
              .request
              .title,
          'Injected approval',
        );
        expect(
          (surface.pinnedItems.last as ChatUserInputRequestItemContract)
              .request
              .title,
          'Injected input',
        );
        expect(
          surface.pendingRequestPlacement.visibleApprovalRequest?.requestId,
          'request_override_approval',
        );
        expect(
          surface.pendingRequestPlacement.visibleUserInputRequest?.requestId,
          'request_override_input',
        );
        expect(surface.activePendingUserInputRequestIds, <String>{
          'request_override_input',
        });
      },
    );
  });

  group('ChatRequestProjector', () {
    const projector = ChatRequestProjector();

    test('projects pending approval requests into presentation contracts', () {
      final request = CodexSessionPendingRequest(
        requestId: 'request_approval',
        requestType: CodexCanonicalRequestType.execCommandApproval,
        createdAt: DateTime(2026, 3, 15, 12, 0, 1),
      );

      final contract = projector.projectPendingApprovalRequest(request);

      expect(contract.id, 'request_request_approval');
      expect(contract.requestId, request.requestId);
      expect(contract.title, 'Command approval');
      expect(contract.body, 'Codex needs a decision before it can continue.');
      expect(contract.isResolved, isFalse);
    });

    test(
      'projects pending user-input requests into presentation contracts',
      () {
        final request = CodexSessionPendingUserInputRequest(
          requestId: 'request_input',
          requestType: CodexCanonicalRequestType.toolUserInput,
          createdAt: DateTime(2026, 3, 15, 12, 0, 2),
          questions: const <CodexRuntimeUserInputQuestion>[
            CodexRuntimeUserInputQuestion(
              id: 'project',
              header: 'Project',
              question: 'Which project should I use?',
            ),
          ],
        );

        final contract = projector.projectPendingUserInputRequest(request);

        expect(contract.id, 'request_request_input');
        expect(contract.requestId, request.requestId);
        expect(contract.title, 'Input required');
        expect(contract.body, 'Project: Which project should I use?');
        expect(contract.questions, request.questions);
        expect(contract.isResolved, isFalse);
      },
    );
  });

  group('ChatPendingRequestPlacementProjector', () {
    const projector = ChatPendingRequestPlacementProjector();

    test('selects the oldest pending approval request as visible', () {
      final placement = projector.project(
        pendingApprovalRequests: <String, CodexSessionPendingRequest>{
          'request_newer': CodexSessionPendingRequest(
            requestId: 'request_newer',
            requestType: CodexCanonicalRequestType.fileChangeApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 2),
            detail: 'Newer approval',
          ),
          'request_older': CodexSessionPendingRequest(
            requestId: 'request_older',
            requestType: CodexCanonicalRequestType.fileChangeApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older approval',
          ),
        },
        pendingUserInputRequests:
            const <String, CodexSessionPendingUserInputRequest>{},
      );

      expect(placement.visibleApprovalRequest?.requestId, 'request_older');
      expect(placement.visibleApprovalRequest?.title, 'File change approval');
      expect(placement.visibleUserInputRequest, isNull);
      expect(placement.orderedVisibleRequests, hasLength(1));
    });

    test('selects the oldest pending user-input request as visible', () {
      final placement = projector.project(
        pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          'request_newer': CodexSessionPendingUserInputRequest(
            requestId: 'request_newer',
            requestType: CodexCanonicalRequestType.toolUserInput,
            createdAt: DateTime(2026, 3, 15, 12, 0, 2),
            detail: 'Newer input',
          ),
          'request_older': CodexSessionPendingUserInputRequest(
            requestId: 'request_older',
            requestType: CodexCanonicalRequestType.mcpServerElicitation,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older input',
          ),
        },
      );

      expect(placement.visibleApprovalRequest, isNull);
      expect(placement.visibleUserInputRequest?.requestId, 'request_older');
      expect(placement.visibleUserInputRequest?.title, 'MCP input required');
      expect(placement.orderedVisibleRequests, hasLength(1));
    });

    test('orders visible requests as approval first then user-input', () {
      final placement = projector.project(
        pendingApprovalRequests: <String, CodexSessionPendingRequest>{
          'approval_request': CodexSessionPendingRequest(
            requestId: 'approval_request',
            requestType: CodexCanonicalRequestType.execCommandApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 5),
            detail: 'Approval request',
          ),
        },
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          'input_request_newer': CodexSessionPendingUserInputRequest(
            requestId: 'input_request_newer',
            requestType: CodexCanonicalRequestType.toolUserInput,
            createdAt: DateTime(2026, 3, 15, 12, 0, 6),
            detail: 'Newer input request',
          ),
          'input_request_older': CodexSessionPendingUserInputRequest(
            requestId: 'input_request_older',
            requestType: CodexCanonicalRequestType.toolUserInput,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older input request',
          ),
        },
      );

      expect(placement.orderedVisibleRequests, hasLength(2));
      expect(
        placement.orderedVisibleRequests.first.requestId,
        'approval_request',
      );
      expect(
        placement.orderedVisibleRequests.first,
        isA<ChatApprovalRequestContract>(),
      );
      expect(
        placement.orderedVisibleRequests.last.requestId,
        'input_request_older',
      );
      expect(
        placement.orderedVisibleRequests.last,
        isA<ChatUserInputRequestContract>(),
      );
    });

    test(
      'keeps insertion order when requests share the same createdAt timestamp',
      () {
        final createdAt = DateTime(2026, 3, 15, 12, 0, 1);
        final placement = projector.project(
          pendingApprovalRequests: <String, CodexSessionPendingRequest>{
            'request_first': CodexSessionPendingRequest(
              requestId: 'request_first',
              requestType: CodexCanonicalRequestType.fileChangeApproval,
              createdAt: createdAt,
              detail: 'First approval',
            ),
            'request_second': CodexSessionPendingRequest(
              requestId: 'request_second',
              requestType: CodexCanonicalRequestType.fileChangeApproval,
              createdAt: createdAt,
              detail: 'Second approval',
            ),
          },
          pendingUserInputRequests:
              const <String, CodexSessionPendingUserInputRequest>{},
        );

        expect(placement.visibleApprovalRequest?.requestId, 'request_first');
      },
    );
  });

  group('ChatTranscriptItemProjector', () {
    const projector = ChatTranscriptItemProjector();

    test('projects work-log groups into work-log group item contracts', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_1',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_1',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'Read docs',
            turnId: 'turn_1',
            preview: 'Found the CLI docs',
            isRunning: true,
            exitCode: 0,
          ),
        ],
      );

      final item = projector.project(groupBlock);

      expect(item, isA<ChatWorkLogGroupItemContract>());
      final groupItem = item as ChatWorkLogGroupItemContract;
      expect(groupItem.block, same(groupBlock));
      expect(groupItem.block.entries, hasLength(1));
      expect(groupItem.block.entries.single.title, 'Read docs');
      expect(groupItem.block.entries.single.turnId, 'turn_1');
      expect(groupItem.block.entries.single.preview, 'Found the CLI docs');
      expect(groupItem.block.entries.single.isRunning, isTrue);
      expect(groupItem.block.entries.single.exitCode, 0);
    });

    test(
      'projects changed-files blocks into structured changed-files item contracts',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/app.dart', additions: 1),
          ],
          unifiedDiff:
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        );

        final item = projector.project(block);

        expect(item, isA<ChatChangedFilesItemContract>());
        final changedFilesItem = item as ChatChangedFilesItemContract;
        expect(changedFilesItem.id, block.id);
        expect(changedFilesItem.title, block.title);
        expect(changedFilesItem.fileCount, 1);
        expect(changedFilesItem.headerStats.additions, 1);
        expect(changedFilesItem.headerStats.deletions, 1);
        expect(changedFilesItem.rows.single.displayPathLabel, 'lib/app.dart');
        expect(changedFilesItem.rows.single.stats.deletions, 1);
        expect(changedFilesItem.rows.single.diff, isNotNull);
        expect(
          changedFilesItem.rows.single.diff?.lines.first.text,
          'diff --git a/lib/app.dart b/lib/app.dart',
        );
      },
    );

    test('projects SSH transcript blocks into SSH item contracts', () {
      final block = CodexSshConnectFailedBlock(
        id: 'ssh_connect_failed_1',
        createdAt: DateTime(2026, 3, 15, 12),
        host: 'example.com',
        port: 22,
        message: 'Connection refused',
      );

      final item = projector.project(block);

      expect(item, isA<ChatSshItemContract>());
      final sshItem = item as ChatSshItemContract;
      expect(sshItem.block, same(block));
    });

    test(
      'derives changed-files header totals from resolved row stats when file payloads are partial',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_mixed_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'README.md', additions: 1),
            CodexChangedFile(path: 'lib/app.dart'),
          ],
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              '--- a/README.md\n'
              '+++ b/README.md\n'
              '@@ -1 +1 @@\n'
              '-old readme\n'
              '+new readme\n'
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1,2 @@\n'
              '-old app\n'
              '+new app\n'
              '+second line\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;

        expect(item.headerStats.additions, 3);
        expect(item.headerStats.deletions, 2);
        expect(item.rows[1].stats.additions, 2);
        expect(item.rows[1].stats.deletions, 1);
      },
    );
  });

  group('ChatTranscriptFollowHost', () {
    test(
      'models follow requests and viewport eligibility above the widget',
      () {
        final host = ChatTranscriptFollowHost();

        expect(host.contract.isAutoFollowEnabled, isTrue);
        expect(host.contract.request, isNull);

        host.updateAutoFollowEligibility(isNearBottom: false);

        expect(host.contract.isAutoFollowEnabled, isFalse);
        expect(host.contract.request, isNull);

        host.requestFollow(
          source: ChatTranscriptFollowRequestSource.clearTranscript,
        );

        final firstRequest = host.contract.request;
        expect(host.contract.isAutoFollowEnabled, isTrue);
        expect(
          firstRequest?.source,
          ChatTranscriptFollowRequestSource.clearTranscript,
        );

        host.requestFollow(source: ChatTranscriptFollowRequestSource.newThread);

        expect(host.contract.request?.id, greaterThan(firstRequest!.id));
        expect(
          host.contract.request?.source,
          ChatTranscriptFollowRequestSource.newThread,
        );
      },
    );

    test('reset restores default follow state', () {
      final host = ChatTranscriptFollowHost();

      host.updateAutoFollowEligibility(isNearBottom: false);
      host.requestFollow(
        source: ChatTranscriptFollowRequestSource.clearTranscript,
      );

      host.reset();

      expect(host.contract.isAutoFollowEnabled, isTrue);
      expect(host.contract.request, isNull);
    });
  });

  group('ChatComposerDraftHost', () {
    test('models draft updates and clear behavior above the renderer', () {
      final host = ChatComposerDraftHost();

      expect(host.draft.text, isEmpty);

      host.updateText('  draft text  ');
      expect(host.draft.text, '  draft text  ');

      host.clear();
      expect(host.draft.text, isEmpty);
    });

    test('reset clears draft state above the renderer', () {
      final host = ChatComposerDraftHost();

      host.updateText('draft to reset');
      host.reset();

      expect(host.draft.text, isEmpty);
    });
  });

  test('maps snackbar messages into screen effects', () {
    const mapper = ChatScreenEffectMapper();

    final effect = mapper.mapSnackBarMessage('Input failed');

    expect(effect, isA<ChatShowSnackBarEffect>());
    expect((effect as ChatShowSnackBarEffect).message, 'Input failed');
  });

  test('maps the settings action into a connection settings effect', () {
    const presenter = ChatScreenPresenter();
    const mapper = ChatScreenEffectMapper();
    final profile = _configuredProfile();
    final secrets = const ConnectionSecrets(password: 'secret');
    final contract = presenter.present(
      isLoading: false,
      profile: profile,
      secrets: secrets,
      sessionState: CodexSessionState.initial(),
      composerDraft: const ChatComposerDraft(),
      transcriptFollow: _defaultTranscriptFollowContract,
    );

    final effect = mapper.mapAction(
      action: ChatScreenActionId.openSettings,
      screen: contract,
    );

    expect(effect, isA<ChatOpenConnectionSettingsEffect>());
    expect(
      (effect as ChatOpenConnectionSettingsEffect).payload.initialProfile,
      same(profile),
    );
    expect(effect.payload.initialSecrets, same(secrets));
  });
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}

class _FakePendingRequestPlacementProjector
    extends ChatPendingRequestPlacementProjector {
  const _FakePendingRequestPlacementProjector({required this.placement});

  final ChatPendingRequestPlacementContract placement;

  @override
  ChatPendingRequestPlacementContract project({
    required Map<String, CodexSessionPendingRequest> pendingApprovalRequests,
    required Map<String, CodexSessionPendingUserInputRequest>
    pendingUserInputRequests,
  }) {
    return placement;
  }
}
