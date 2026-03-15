import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_surface_projector.dart';

void main() {
  group('ChatScreenPresenter', () {
    const presenter = ChatScreenPresenter();

    test('derives header, actions, composer, and settings payload from raw top-level state', () {
      final profile = _configuredProfile();
      final secrets = const ConnectionSecrets(password: 'secret');

      final contract = presenter.present(
        isLoading: false,
        profile: profile,
        secrets: secrets,
        sessionState: CodexSessionState.initial(),
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
      expect(contract.composer.primaryAction, ChatComposerPrimaryAction.send);
      expect(contract.connectionSettings.initialProfile, same(profile));
      expect(contract.connectionSettings.initialSecrets, same(secrets));
    });

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
      );

      expect(contract.composer.isBusy, isTrue);
      expect(contract.composer.isTextInputEnabled, isFalse);
      expect(contract.composer.primaryAction, ChatComposerPrimaryAction.stop);
      expect(contract.composer.isPrimaryActionEnabled, isTrue);
      expect(contract.turnIndicator?.timer, same(activeTurn.timer));
    });
  });

  group('ChatTranscriptSurfaceProjector', () {
    const projector = ChatTranscriptSurfaceProjector();

    test('projects transcript blocks into the main region and pending requests into the pinned region', () {
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
      expect(surface.mainItems.single.block, same(transcriptBlock));
      expect(surface.pinnedItems.length, 2);
      expect(
        surface.pinnedItems.map((item) => item.block.kind),
        <CodexUiBlockKind>[
          CodexUiBlockKind.approvalRequest,
          CodexUiBlockKind.userInputRequest,
        ],
      );
    });

    test('projects an empty state when no transcript or pending items are visible', () {
      final surface = projector.project(
        profile: ConnectionProfile.defaults(),
        sessionState: CodexSessionState.initial(),
      );

      expect(surface.showsEmptyState, isTrue);
      expect(surface.emptyState?.isConfigured, isFalse);
      expect(surface.mainItems, isEmpty);
      expect(surface.pinnedItems, isEmpty);
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
