import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

export 'dart:async';
export 'package:flutter/gestures.dart';
export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
export 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
export 'package:pocket_relay/src/core/theme/pocket_theme.dart';
export 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
export 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_overlay_delegate.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_presenter.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
export 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/widgets/empty_state.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

Widget buildAdapterApp({
  AgentAdapterClient? agentAdapterClient,
  @Deprecated('Use agentAdapterClient instead.')
  AgentAdapterClient? appServerClient,
  required ChatRootOverlayDelegate overlayDelegate,
  Future<void> Function(ChatConnectionSettingsLaunchContract payload)?
  onConnectionSettingsRequested,
  PocketPlatformPolicy? platformPolicy,
  PocketPlatformBehavior? platformBehavior,
  ConnectionLaneBinding? laneBinding,
  CodexProfileStore? profileStore,
  SavedProfile? savedProfile,
  ChatScreenPresenter? screenPresenter,
  ThemeData? theme,
  Widget? supplementalEmptyStateContent,
}) {
  final resolvedAgentAdapterClient = agentAdapterClient ?? appServerClient;
  assert(
    resolvedAgentAdapterClient != null,
    'An agent adapter client is required.',
  );
  final resolvedPlatformPolicy =
      platformPolicy ??
      PocketPlatformPolicy(
        behavior: platformBehavior ?? PocketPlatformBehavior.resolve(),
      );
  return MaterialApp(
    theme: theme ?? buildPocketTheme(Brightness.light),
    home: ChatRootAdapterHarness(
      laneBinding: laneBinding,
      agentAdapterClient: resolvedAgentAdapterClient!,
      profileStore: profileStore,
      savedProfile: savedProfile ?? testSavedProfile(),
      platformPolicy: resolvedPlatformPolicy,
      overlayDelegate: overlayDelegate,
      screenPresenter: screenPresenter ?? const ChatScreenPresenter(),
      onConnectionSettingsRequested:
          onConnectionSettingsRequested ?? (_) async {},
      supplementalEmptyStateContent: supplementalEmptyStateContent,
    ),
  );
}

ConnectionLaneBinding buildLaneBinding({
  AgentAdapterClient? agentAdapterClient,
  @Deprecated('Use agentAdapterClient instead.')
  AgentAdapterClient? appServerClient,
  required SavedProfile savedProfile,
  CodexProfileStore? profileStore,
  PocketPlatformPolicy? platformPolicy,
}) {
  final resolvedAgentAdapterClient = agentAdapterClient ?? appServerClient;
  assert(
    resolvedAgentAdapterClient != null,
    'An agent adapter client is required.',
  );
  final resolvedPlatformPolicy =
      platformPolicy ??
      PocketPlatformPolicy(behavior: PocketPlatformBehavior.resolve());
  return ConnectionLaneBinding(
    connectionId: 'conn_primary',
    profileStore:
        profileStore ?? MemoryCodexProfileStore(initialValue: savedProfile),
    agentAdapterClient: resolvedAgentAdapterClient!,
    initialSavedProfile: savedProfile,
    supportsLocalConnectionMode:
        resolvedPlatformPolicy.supportsLocalConnectionMode,
  );
}

Future<void> restoreConversationInLane(
  ConnectionLaneBinding laneBinding,
  String threadId,
) async {
  await laneBinding.sessionController.initialize();
  await laneBinding.sessionController.selectConversationForResume(threadId);
}

ConnectionProfile configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

SavedProfile testSavedProfile({
  ConnectionProfile? profile,
  ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret'),
}) {
  return SavedProfile(
    profile: profile ?? configuredProfile(),
    secrets: secrets,
  );
}

SavedProfile savedProfile({
  ConnectionProfile? profile,
  ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret'),
}) {
  return testSavedProfile(profile: profile, secrets: secrets);
}

CodexAppServerThreadHistory savedConversationThread({
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
      CodexAppServerHistoryTurn(
        id: 'turn_second',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user_second',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant_second',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_second',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory rewoundConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_before_restore_this',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_assistant_earlier',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_before_restore_this',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory partiallyRewoundConversationThread({
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

class FakeChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  FakeChatRootOverlayDelegate();
  final List<ChatConnectionSettingsLaunchContract> connectionSettingsPayloads =
      <ChatConnectionSettingsLaunchContract>[];
  final List<ChatChangedFileDiffContract> changedFileDiffs =
      <ChatChangedFileDiffContract>[];
  final List<ChatWorkLogTerminalContract> workLogTerminals =
      <ChatWorkLogTerminalContract>[];
  final List<String> transientFeedbackMessages = <String>[];

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required PocketPlatformBehavior platformBehavior,
  }) async {
    connectionSettingsPayloads.add(connectionSettings);
    return null;
  }

  @override
  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  }) async {
    changedFileDiffs.add(diff);
  }

  @override
  Future<void> openWorkLogTerminal({
    required BuildContext context,
    required ChatWorkLogTerminalContract terminal,
  }) async {
    workLogTerminals.add(terminal);
  }

  @override
  void showTransientFeedback({
    required BuildContext context,
    required String message,
  }) {
    transientFeedbackMessages.add(message);
  }
}

class ChatRootAdapterHarness extends StatefulWidget {
  const ChatRootAdapterHarness({
    required this.agentAdapterClient,
    required this.savedProfile,
    required this.platformPolicy,
    required this.overlayDelegate,
    required this.screenPresenter,
    required this.onConnectionSettingsRequested,
    this.supplementalEmptyStateContent,
    this.laneBinding,
    this.profileStore,
  });

  final AgentAdapterClient agentAdapterClient;
  final SavedProfile savedProfile;
  final PocketPlatformPolicy platformPolicy;
  final ChatRootOverlayDelegate overlayDelegate;
  final ChatScreenPresenter screenPresenter;
  final Future<void> Function(ChatConnectionSettingsLaunchContract payload)
  onConnectionSettingsRequested;
  final Widget? supplementalEmptyStateContent;
  final ConnectionLaneBinding? laneBinding;
  final CodexProfileStore? profileStore;

  bool get _usesExternalBinding => laneBinding != null;

  @override
  State<ChatRootAdapterHarness> createState() => ChatRootAdapterHarnessState();
}

class ChatRootAdapterHarnessState extends State<ChatRootAdapterHarness> {
  ConnectionLaneBinding? _ownedLaneBinding;

  @override
  void initState() {
    super.initState();
    _rebindOwnedLaneBindingIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant ChatRootAdapterHarness oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebindOwnedLaneBindingIfNeeded(
      force:
          oldWidget.laneBinding != widget.laneBinding ||
          oldWidget.agentAdapterClient != widget.agentAdapterClient ||
          oldWidget.profileStore != widget.profileStore ||
          oldWidget.savedProfile != widget.savedProfile ||
          oldWidget.platformPolicy != widget.platformPolicy,
    );
  }

  @override
  void dispose() {
    _ownedLaneBinding?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChatRootAdapter(
      laneBinding: widget.laneBinding ?? _ownedLaneBinding!,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: widget.onConnectionSettingsRequested,
      screenPresenter: widget.screenPresenter,
      overlayDelegate: widget.overlayDelegate,
      supplementalEmptyStateContent: widget.supplementalEmptyStateContent,
    );
  }

  void _rebindOwnedLaneBindingIfNeeded({required bool force}) {
    if (!force) {
      return;
    }

    if (widget._usesExternalBinding) {
      final previousLaneBinding = _ownedLaneBinding;
      _ownedLaneBinding = null;
      previousLaneBinding?.dispose();
      return;
    }

    final nextLaneBinding = buildLaneBinding(
      agentAdapterClient: widget.agentAdapterClient,
      profileStore: widget.profileStore,
      savedProfile: widget.savedProfile,
      platformPolicy: widget.platformPolicy,
    );
    final previousLaneBinding = _ownedLaneBinding;
    _ownedLaneBinding = nextLaneBinding;
    previousLaneBinding?.dispose();
  }
}

class CountingChatScreenPresenter extends ChatScreenPresenter {
  CountingChatScreenPresenter();

  int presentSessionCalls = 0;

  @override
  ChatScreenSessionContract presentSession({
    required bool isLoading,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required TranscriptSessionState sessionState,
    required ChatConversationRecoveryState? conversationRecoveryState,
    ChatHistoricalConversationRestoreState? historicalConversationRestoreState,
    bool effectiveModelSupportsImages = true,
    AgentAdapterCapabilities? agentAdapterCapabilities,
    ConnectionMode? preferredConnectionMode,
  }) {
    presentSessionCalls += 1;
    return super.presentSession(
      isLoading: isLoading,
      profile: profile,
      secrets: secrets,
      sessionState: sessionState,
      conversationRecoveryState: conversationRecoveryState,
      historicalConversationRestoreState: historicalConversationRestoreState,
      effectiveModelSupportsImages: effectiveModelSupportsImages,
      agentAdapterCapabilities: agentAdapterCapabilities,
      preferredConnectionMode: preferredConnectionMode,
    );
  }
}

void completeActiveTurn(
  FakeCodexAppServerClient appServerClient, {
  String turnId = 'turn_1',
}) {
  appServerClient.emit(
    CodexAppServerNotificationEvent(
      method: 'turn/completed',
      params: <String, Object?>{
        'threadId': 'thread_123',
        'turn': <String, Object?>{'id': turnId, 'status': 'completed'},
      },
    ),
  );
}
