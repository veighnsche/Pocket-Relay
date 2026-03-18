import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_app_chrome.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';

abstract interface class ChatRootRendererDelegate {
  Widget buildScreenShell({
    required ChatRootScreenShellRenderer renderer,
    required ChatScreenContract screen,
    required PreferredSizeWidget appChrome,
    required Widget transcriptRegion,
    required Widget composerRegion,
  });

  PreferredSizeWidget buildAppChrome({
    required ChatRootRegionRenderer renderer,
    required ChatScreenContract screen,
    required ValueChanged<ChatScreenActionId> onScreenAction,
  });

  Widget buildTranscriptRegion({
    required ChatRootRegionRenderer renderer,
    required ChatEmptyStateRenderer emptyStateRenderer,
    required PocketPlatformBehavior platformBehavior,
    required ChatScreenContract screen,
    required Object? surfaceChangeToken,
    required ValueChanged<ChatScreenActionId> onScreenAction,
    required ValueChanged<String> onSelectTimeline,
    required ValueChanged<ConnectionMode> onSelectConnectionMode,
    required ValueChanged<bool> onAutoFollowEligibilityChanged,
    void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff,
    Future<void> Function(String requestId)? onApproveRequest,
    Future<void> Function(String requestId)? onDenyRequest,
    Future<void> Function(String requestId, Map<String, List<String>> answers)?
    onSubmitUserInput,
    Future<void> Function(String blockId)? onSaveHostFingerprint,
  });

  Widget buildComposerRegion({
    required ChatRootRegionRenderer renderer,
    required PocketPlatformBehavior platformBehavior,
    required ChatConversationRecoveryNoticeContract? conversationRecoveryNotice,
    required ChatComposerContract composer,
    required ValueChanged<String> onComposerDraftChanged,
    required Future<void> Function() onSendPrompt,
    required Future<void> Function() onStopActiveTurn,
    required ValueChanged<ChatConversationRecoveryActionId>
    onConversationRecoveryAction,
  });
}

class FlutterChatRootRendererDelegate implements ChatRootRendererDelegate {
  const FlutterChatRootRendererDelegate();

  @override
  Widget buildScreenShell({
    required ChatRootScreenShellRenderer renderer,
    required ChatScreenContract screen,
    required PreferredSizeWidget appChrome,
    required Widget transcriptRegion,
    required Widget composerRegion,
  }) {
    return switch (renderer) {
      ChatRootScreenShellRenderer.flutter => FlutterChatScreenRenderer(
        screen: screen,
        appChrome: appChrome,
        transcriptRegion: transcriptRegion,
        composerRegion: composerRegion,
      ),
      ChatRootScreenShellRenderer.cupertino => CupertinoChatScreenRenderer(
        screen: screen,
        appChrome: appChrome,
        transcriptRegion: transcriptRegion,
        composerRegion: composerRegion,
      ),
    };
  }

  @override
  PreferredSizeWidget buildAppChrome({
    required ChatRootRegionRenderer renderer,
    required ChatScreenContract screen,
    required ValueChanged<ChatScreenActionId> onScreenAction,
  }) {
    return switch (renderer) {
      ChatRootRegionRenderer.cupertino => CupertinoChatAppChrome(
        screen: screen,
        onScreenAction: onScreenAction,
      ),
      ChatRootRegionRenderer.flutter => FlutterChatAppChrome(
        screen: screen,
        onScreenAction: onScreenAction,
      ),
    };
  }

  @override
  Widget buildTranscriptRegion({
    required ChatRootRegionRenderer renderer,
    required ChatEmptyStateRenderer emptyStateRenderer,
    required PocketPlatformBehavior platformBehavior,
    required ChatScreenContract screen,
    required Object? surfaceChangeToken,
    required ValueChanged<ChatScreenActionId> onScreenAction,
    required ValueChanged<String> onSelectTimeline,
    required ValueChanged<ConnectionMode> onSelectConnectionMode,
    required ValueChanged<bool> onAutoFollowEligibilityChanged,
    void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff,
    Future<void> Function(String requestId)? onApproveRequest,
    Future<void> Function(String requestId)? onDenyRequest,
    Future<void> Function(String requestId, Map<String, List<String>> answers)?
    onSubmitUserInput,
    Future<void> Function(String blockId)? onSaveHostFingerprint,
  }) {
    return switch (renderer) {
      ChatRootRegionRenderer.cupertino ||
      ChatRootRegionRenderer.flutter => FlutterChatTranscriptRegion(
        screen: screen,
        emptyStateRenderer: emptyStateRenderer,
        platformBehavior: platformBehavior,
        surfaceChangeToken: surfaceChangeToken,
        onScreenAction: onScreenAction,
        onSelectTimeline: onSelectTimeline,
        onSelectConnectionMode: onSelectConnectionMode,
        onAutoFollowEligibilityChanged: onAutoFollowEligibilityChanged,
        onApproveRequest: onApproveRequest,
        onDenyRequest: onDenyRequest,
        onOpenChangedFileDiff: onOpenChangedFileDiff,
        onSubmitUserInput: onSubmitUserInput,
        onSaveHostFingerprint: onSaveHostFingerprint,
      ),
    };
  }

  @override
  Widget buildComposerRegion({
    required ChatRootRegionRenderer renderer,
    required PocketPlatformBehavior platformBehavior,
    required ChatConversationRecoveryNoticeContract? conversationRecoveryNotice,
    required ChatComposerContract composer,
    required ValueChanged<String> onComposerDraftChanged,
    required Future<void> Function() onSendPrompt,
    required Future<void> Function() onStopActiveTurn,
    required ValueChanged<ChatConversationRecoveryActionId>
    onConversationRecoveryAction,
  }) {
    return switch (renderer) {
      ChatRootRegionRenderer.cupertino => CupertinoChatComposerRegion(
        platformBehavior: platformBehavior,
        conversationRecoveryNotice: conversationRecoveryNotice,
        composer: composer,
        onComposerDraftChanged: onComposerDraftChanged,
        onSendPrompt: onSendPrompt,
        onStopActiveTurn: onStopActiveTurn,
        onConversationRecoveryAction: onConversationRecoveryAction,
      ),
      ChatRootRegionRenderer.flutter => FlutterChatComposerRegion(
        platformBehavior: platformBehavior,
        conversationRecoveryNotice: conversationRecoveryNotice,
        composer: composer,
        onComposerDraftChanged: onComposerDraftChanged,
        onSendPrompt: onSendPrompt,
        onStopActiveTurn: onStopActiveTurn,
        onConversationRecoveryAction: onConversationRecoveryAction,
      ),
    };
  }
}
