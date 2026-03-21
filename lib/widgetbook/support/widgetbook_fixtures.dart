import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

class WidgetbookFixtures {
  static final DateTime timestamp = DateTime.utc(2026, 3, 21, 10, 30);

  static const String assistantMessageMarkdown =
      'I checked the session and found two concrete follow-ups.\n\n'
      '- The SSH trust prompt is still blocking the first connection.\n'
      '- One command failed because the saved workspace path is missing.\n'
      '- The next step is to confirm the host key, then retry the launch.';

  static const String reasoningMarkdown =
      'Comparing the latest runtime events before choosing the next action.\n\n'
      '1. Check whether the failure is trust-related or authentication-related.\n'
      '2. Keep the blocked action visible while the user decides.\n'
      '3. Do not hide the consequence behind secondary detail.';

  static const String proposedPlanMarkdown =
      '# Connection Recovery Plan\n\n'
      '## Summary\n\n'
      'Recover the current session and keep the user-facing consequences visible.\n\n'
      '## Scope\n\n'
      '1. Re-check the saved connection settings and workspace path.\n'
      '2. Surface the SSH trust and auth states as distinct blockers.\n'
      '3. Retry the remote launch only after the blocking state is resolved.\n\n'
      '## Acceptance Criteria\n\n'
      '- The blocking state is obvious before any action is taken.\n'
      '- The user can see what host, path, and account are affected.\n'
      '- Long content still supports truncation and expansion.';

  static const String longProposedPlanMarkdown =
      '# Remote Session Recovery\n\n'
      '## Summary\n\n'
      'Recover a failing remote session without hiding the evidence that explains the failure.\n\n'
      '## Workstreams\n\n'
      '1. Transport\n'
      '- Re-check the saved host, port, and account details.\n'
      '- Verify whether the host key is already pinned or still pending trust.\n\n'
      '2. Transcript\n'
      '- Keep approval and input-required states visually distinct.\n'
      '- Keep file changes and command activity readable in dense turns.\n'
      '- Preserve SSH trust and failure context while recovery actions are available.\n\n'
      '3. Reliability\n'
      '- Keep long content expandable without losing the initial summary.\n'
      '- Avoid duplicate status signals for the same runtime meaning.\n'
      '- Keep action-required states visually consistent.\n\n'
      '## Notes\n\n'
      'This plan focuses on the runtime surfaces the user actually sees while the connection is blocked or recovering.';

  static const PocketPlatformBehavior mobileBehavior = PocketPlatformBehavior(
    experience: PocketPlatformExperience.mobile,
    supportsLocalConnectionMode: false,
    supportsWakeLock: true,
    usesDesktopKeyboardSubmit: false,
    supportsCollapsibleDesktopSidebar: false,
  );

  static const PocketPlatformBehavior desktopBehavior = PocketPlatformBehavior(
    experience: PocketPlatformExperience.desktop,
    supportsLocalConnectionMode: true,
    supportsWakeLock: false,
    usesDesktopKeyboardSubmit: true,
    supportsCollapsibleDesktopSidebar: true,
  );

  static const PocketPlatformPolicy mobilePolicy = PocketPlatformPolicy(
    behavior: mobileBehavior,
  );

  static const PocketPlatformPolicy desktopPolicy = PocketPlatformPolicy(
    behavior: desktopBehavior,
  );

  static final ConnectionProfile remoteProfile = ConnectionProfile.defaults()
      .copyWith(
        label: 'Developer Box',
        host: 'devbox.local',
        username: 'vince',
        workspaceDir: '/workspace/Pocket-Relay',
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.high,
      );

  static final ConnectionProfile localProfile = ConnectionProfile.defaults()
      .copyWith(
        label: 'Local Workspace',
        workspaceDir: '/Users/vince/Projects/Pocket-Relay',
        connectionMode: ConnectionMode.local,
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.medium,
      );

  static const ConnectionSecrets passwordSecrets = ConnectionSecrets(
    password: 'secret-password',
  );

  static final SavedProfile savedProfile = SavedProfile(
    profile: remoteProfile,
    secrets: passwordSecrets,
  );

  static CodexTextBlock assistantMessage({
    String body = assistantMessageMarkdown,
    bool isRunning = false,
  }) {
    return CodexTextBlock(
      id: 'assistant_message',
      kind: CodexUiBlockKind.assistantMessage,
      createdAt: timestamp,
      title: 'Assistant',
      body: body,
      isRunning: isRunning,
    );
  }

  static CodexTextBlock reasoningBlock({bool isRunning = true}) {
    return CodexTextBlock(
      id: 'reasoning_message',
      kind: CodexUiBlockKind.reasoning,
      createdAt: timestamp,
      title: 'Reasoning',
      body: reasoningMarkdown,
      isRunning: isRunning,
    );
  }

  static CodexUserMessageBlock userMessage({
    CodexUserMessageDeliveryState deliveryState =
        CodexUserMessageDeliveryState.sent,
  }) {
    return CodexUserMessageBlock(
      id: 'user_message',
      createdAt: timestamp,
      text:
          'Open the Widgetbook implementation plan and start the first slice.',
      deliveryState: deliveryState,
    );
  }

  static CodexStatusBlock statusBlock() {
    return CodexStatusBlock(
      id: 'status_message',
      createdAt: timestamp,
      title: 'Session attached',
      body:
          'Pocket Relay is connected to the remote session and ready to continue.',
    );
  }

  static CodexErrorBlock errorBlock() {
    return CodexErrorBlock(
      id: 'error_message',
      createdAt: timestamp,
      title: 'Remote launch failed',
      body: 'The remote workspace could not be opened with the saved settings.',
    );
  }

  static ChatApprovalRequestContract approvalRequest({
    bool isResolved = false,
  }) {
    return ChatApprovalRequestContract(
      id: 'approval_request',
      createdAt: timestamp,
      requestId: 'req_apply_patch',
      requestType: CodexCanonicalRequestType.applyPatchApproval,
      title: 'Approve file edits',
      body:
          'Codex wants to update the connection settings and retry the remote launch.',
      isResolved: isResolved,
      resolutionLabel: isResolved ? 'approved' : null,
    );
  }

  static PendingUserInputContract pendingUserInput({
    bool resolved = false,
    bool submitting = false,
  }) {
    return PendingUserInputContract(
      requestId: 'user_input_review_scope',
      title: 'Need user input',
      body:
          'Choose how to continue this session before the next tool call starts.',
      isResolved: resolved,
      isSubmitting: submitting,
      isSubmitEnabled: !resolved,
      statusBadgeLabel: resolved
          ? 'submitted'
          : (submitting ? 'submitting' : 'pending'),
      submitLabel: submitting ? 'Submitting…' : 'Submit review',
      submitPayload: const <String, List<String>>{
        'mode': <String>['Retry now'],
      },
      fields: const <PendingUserInputFieldContract>[
        PendingUserInputFieldContract(
          id: 'mode',
          header: 'Action',
          prompt: 'Pick how the session should continue.',
          inputLabel: 'Action',
          value: 'Retry now',
          options: <PendingUserInputOptionContract>[
            PendingUserInputOptionContract(
              label: 'Retry now',
              description: 'Retry the remote launch immediately',
            ),
            PendingUserInputOptionContract(
              label: 'Open settings',
              description: 'Review the saved host and workspace path first',
            ),
            PendingUserInputOptionContract(
              label: 'Stop session',
              description: 'Leave the connection blocked for now',
            ),
          ],
        ),
        PendingUserInputFieldContract(
          id: 'notes',
          header: 'Notes',
          prompt: 'Add any extra context before continuing.',
          inputLabel: 'Notes',
          value:
              'The workspace path changed on the remote host after the last deploy.',
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }

  static CodexPlanUpdateBlock planUpdateBlock() {
    return CodexPlanUpdateBlock(
      id: 'plan_update',
      createdAt: timestamp,
      explanation:
          'Updated the recovery steps after the remote launch failed a second time.',
      steps: <CodexRuntimePlanStep>[
        CodexRuntimePlanStep(
          step: 'Confirm the saved host fingerprint',
          status: CodexRuntimePlanStepStatus.completed,
        ),
        CodexRuntimePlanStep(
          step: 'Review the saved workspace path',
          status: CodexRuntimePlanStepStatus.inProgress,
        ),
        CodexRuntimePlanStep(
          step: 'Retry the remote launch',
          status: CodexRuntimePlanStepStatus.pending,
        ),
      ],
    );
  }

  static CodexProposedPlanBlock proposedPlanBlock({
    bool isStreaming = false,
    bool isLong = false,
  }) {
    return CodexProposedPlanBlock(
      id: isLong ? 'proposed_plan_long' : 'proposed_plan',
      createdAt: timestamp,
      title: 'Proposed plan',
      markdown: isLong ? longProposedPlanMarkdown : proposedPlanMarkdown,
      isStreaming: isStreaming,
    );
  }

  static ChatChangedFilesItemContract changedFilesItem({
    bool isRunning = false,
    String variant = 'mixed',
  }) {
    ChatChangedFilePresentationContract filePresentation(
      String path, {
      String? movePath,
    }) {
      return ChatChangedFilePresentationContract.fromPaths(
        path: path,
        movePath: movePath,
      );
    }

    const designDiff = ChatChangedFileDiffContract(
      id: 'diff_transcript_frame',
      file: ChatChangedFilePresentationContract(
        currentPath:
            'lib/src/features/chat/transcript/presentation/widgets/transcript/cards/approval_request_card.dart',
        fileName: 'approval_request_card.dart',
        directoryLabel:
            'lib/src/features/chat/transcript/presentation/widgets/transcript/cards',
        languageLabel: 'Dart',
        syntaxLanguage: 'dart',
      ),
      operationKind: ChatChangedFileOperationKind.modified,
      operationLabel: 'Edited',
      statusLabel: 'modified',
      stats: ChatChangedFileStatsContract(additions: 42, deletions: 11),
      lines: <ChatChangedFileDiffLineContract>[
        ChatChangedFileDiffLineContract(
          text: '@@ -1,6 +1,17 @@',
          kind: ChatChangedFileDiffLineKind.hunk,
        ),
        ChatChangedFileDiffLineContract(
          text: '+  final String blockingReason;',
          kind: ChatChangedFileDiffLineKind.addition,
        ),
        ChatChangedFileDiffLineContract(
          text: '+  final bool isDangerous;',
          kind: ChatChangedFileDiffLineKind.addition,
        ),
        ChatChangedFileDiffLineContract(
          text: '-  final String summary;',
          kind: ChatChangedFileDiffLineKind.deletion,
        ),
        ChatChangedFileDiffLineContract(
          text: '   child: PocketTranscriptFrame(...),',
          kind: ChatChangedFileDiffLineKind.context,
        ),
      ],
    );

    final createdRow = ChatChangedFileRowContract(
      id: 'changed_file_created',
      file: filePresentation('lib/src/core/ui/primitives/pocket_badge.dart'),
      operationKind: ChatChangedFileOperationKind.created,
      operationLabel: 'Created',
      stats: const ChatChangedFileStatsContract(additions: 36, deletions: 0),
      diff: const ChatChangedFileDiffContract(
        id: 'diff_created_badge',
        file: ChatChangedFilePresentationContract(
          currentPath: 'lib/src/core/ui/primitives/pocket_badge.dart',
          fileName: 'pocket_badge.dart',
          directoryLabel: 'lib/src/core/ui/primitives',
          languageLabel: 'Dart',
          syntaxLanguage: 'dart',
        ),
        operationKind: ChatChangedFileOperationKind.created,
        operationLabel: 'Created',
        statusLabel: 'created',
        stats: ChatChangedFileStatsContract(additions: 36, deletions: 0),
        lines: <ChatChangedFileDiffLineContract>[
          ChatChangedFileDiffLineContract(
            text: '+++ b/lib/src/core/ui/primitives/pocket_badge.dart',
            kind: ChatChangedFileDiffLineKind.meta,
          ),
          ChatChangedFileDiffLineContract(
            text: '+class PocketTintBadge extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.addition,
          ),
          ChatChangedFileDiffLineContract(
            text: '+class PocketSolidBadge extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.addition,
          ),
        ],
      ),
    );

    final modifiedRows = <ChatChangedFileRowContract>[
      ChatChangedFileRowContract(
        id: 'changed_file_1',
        file: filePresentation(
          'lib/src/features/chat/transcript/presentation/widgets/transcript/cards/approval_request_card.dart',
        ),
        operationKind: ChatChangedFileOperationKind.modified,
        operationLabel: 'Edited',
        stats: const ChatChangedFileStatsContract(additions: 27, deletions: 5),
        diff: designDiff,
      ),
      ChatChangedFileRowContract(
        id: 'changed_file_2',
        file: filePresentation(
          'lib/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart',
        ),
        operationKind: ChatChangedFileOperationKind.modified,
        operationLabel: 'Edited',
        stats: const ChatChangedFileStatsContract(additions: 54, deletions: 9),
        diff: ChatChangedFileDiffContract(
          id: 'diff_widgetbook_fixtures',
          file: filePresentation(
            'lib/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart',
          ),
          operationKind: ChatChangedFileOperationKind.modified,
          operationLabel: 'Edited',
          statusLabel: 'modified',
          stats: ChatChangedFileStatsContract(additions: 54, deletions: 9),
          lines: <ChatChangedFileDiffLineContract>[
            ChatChangedFileDiffLineContract(
              text: '+  final bool canSaveFingerprint;',
              kind: ChatChangedFileDiffLineKind.addition,
            ),
            ChatChangedFileDiffLineContract(
              text: '+  final String fingerprintStatus;',
              kind: ChatChangedFileDiffLineKind.addition,
            ),
          ],
        ),
      ),
      ChatChangedFileRowContract(
        id: 'changed_file_3',
        file: filePresentation(
          'lib/src/features/settings/presentation/connection_sheet.dart',
        ),
        operationKind: ChatChangedFileOperationKind.modified,
        operationLabel: 'Edited',
        stats: const ChatChangedFileStatsContract(additions: 18, deletions: 4),
      ),
    ];

    final deletedRow = ChatChangedFileRowContract(
      id: 'changed_file_deleted',
      file: filePresentation(
        'lib/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_chips.dart',
      ),
      operationKind: ChatChangedFileOperationKind.deleted,
      operationLabel: 'Deleted',
      stats: const ChatChangedFileStatsContract(additions: 0, deletions: 29),
      diff: const ChatChangedFileDiffContract(
        id: 'diff_deleted_chips',
        file: ChatChangedFilePresentationContract(
          currentPath:
              'lib/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_chips.dart',
          fileName: 'transcript_chips.dart',
          directoryLabel:
              'lib/src/features/chat/transcript/presentation/widgets/transcript/support',
          languageLabel: 'Dart',
          syntaxLanguage: 'dart',
        ),
        operationKind: ChatChangedFileOperationKind.deleted,
        operationLabel: 'Deleted',
        statusLabel: 'deleted',
        stats: ChatChangedFileStatsContract(additions: 0, deletions: 29),
        lines: <ChatChangedFileDiffLineContract>[
          ChatChangedFileDiffLineContract(
            text:
                '--- a/lib/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_chips.dart',
            kind: ChatChangedFileDiffLineKind.meta,
          ),
          ChatChangedFileDiffLineContract(
            text: '-class TranscriptBadge extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.deletion,
          ),
          ChatChangedFileDiffLineContract(
            text: '-class InlinePulseChip extends StatelessWidget {',
            kind: ChatChangedFileDiffLineKind.deletion,
          ),
        ],
      ),
    );

    final rows = switch (variant) {
      'created' => <ChatChangedFileRowContract>[createdRow],
      'deleted' => <ChatChangedFileRowContract>[deletedRow],
      'modified' => modifiedRows,
      _ => <ChatChangedFileRowContract>[
        createdRow,
        ...modifiedRows,
        deletedRow,
      ],
    };

    return ChatChangedFilesItemContract(
      id: 'changed_files',
      title: 'Changed files',
      isRunning: isRunning,
      headerStats: ChatChangedFileStatsContract(
        additions: rows.fold<int>(0, (sum, row) => sum + row.stats.additions),
        deletions: rows.fold<int>(0, (sum, row) => sum + row.stats.deletions),
      ),
      rows: rows,
    );
  }

  static ChatWorkLogGroupItemContract workLogGroupItem() {
    return ChatWorkLogGroupItemContract(
      id: 'work_log_group',
      entries: <ChatWorkLogEntryContract>[
        ChatRipgrepSearchWorkLogEntryContract(
          id: 'work_log_rg',
          commandText: 'rg "workspaceDir|hostKey|authMode" lib/src',
          queryText: 'workspaceDir|hostKey|authMode',
          scopeTargets: <String>['lib/src'],
          exitCode: 0,
        ),
        ChatGitWorkLogEntryContract(
          id: 'work_log_git',
          commandText: 'git diff --stat',
          subcommandLabel: 'diff --stat',
          summaryLabel: 'Reviewing the latest connection-recovery edits',
          primaryLabel: 'git diff --stat',
          secondaryLabel: '3 files changed',
          exitCode: 0,
        ),
        ChatGenericWorkLogEntryContract(
          id: 'work_log_generic',
          entryKind: CodexWorkLogEntryKind.dynamicToolCall,
          title: 'Read saved connection details',
          preview: 'Loaded the current host, auth mode, and workspace path.',
        ),
        ChatGenericWorkLogEntryContract(
          id: 'work_log_running',
          entryKind: CodexWorkLogEntryKind.commandExecution,
          title: 'Retrying the remote launch',
          preview:
              'ssh relay-dev.internal "cd /workspace/Pocket-Relay && pocket-relay app-server --stdio"',
          isRunning: true,
        ),
      ],
    );
  }

  static CodexUsageBlock usageBlock() {
    return CodexUsageBlock(
      id: 'usage_block',
      createdAt: timestamp,
      title: 'Usage',
      body:
          'Last: input 2.1k, cached 0.8k, output 0.9k, reasoning 0.3k, total 4.1k\n'
          'Total: input 18.4k, cached 6.1k, output 8.2k, reasoning 1.4k, total 34.1k\n'
          'Context window: 34.1k / 200k',
    );
  }

  static CodexTurnBoundaryBlock turnBoundaryBlock() {
    return CodexTurnBoundaryBlock(
      id: 'turn_boundary',
      createdAt: timestamp,
      label: 'turn completed',
      elapsed: const Duration(minutes: 2, seconds: 18),
      usage: usageBlock(),
    );
  }

  static CodexSshUnpinnedHostKeyBlock sshUnpinnedHostKey({
    bool isSaved = false,
  }) {
    return CodexSshUnpinnedHostKeyBlock(
      id: 'ssh_unpinned_host_key',
      createdAt: timestamp,
      host: 'relay-dev.internal',
      port: 22,
      keyType: 'ed25519',
      fingerprint: 'SHA256:Kx4q1R3p0z2+9gQmQ4l0o0dXx2nM0Y5M7Fq7zQ8wR0s',
      isSaved: isSaved,
    );
  }

  static CodexSshConnectFailedBlock sshConnectFailedBlock() {
    return CodexSshConnectFailedBlock(
      id: 'ssh_connect_failed',
      createdAt: timestamp,
      host: 'relay-dev.internal',
      port: 22,
      message:
          'Connection timed out while opening the SSH session. Verify the host, port, and network reachability.',
    );
  }

  static CodexSshHostKeyMismatchBlock sshHostKeyMismatchBlock() {
    return CodexSshHostKeyMismatchBlock(
      id: 'ssh_host_key_mismatch',
      createdAt: timestamp,
      host: 'relay-dev.internal',
      port: 22,
      keyType: 'ed25519',
      expectedFingerprint: 'SHA256:0g1gQ2o1T6fK8Yw3oQ6zP2i4lP0d3qf7Jr1nM4xS7iA',
      actualFingerprint: 'SHA256:Yq7fA9nL2kP0rM8uB3cW6zT1hV4jD9pQ1sN6eR2xC5d',
    );
  }

  static CodexSshAuthenticationFailedBlock sshAuthenticationFailedBlock() {
    return CodexSshAuthenticationFailedBlock(
      id: 'ssh_auth_failed',
      createdAt: timestamp,
      host: 'relay-dev.internal',
      port: 22,
      username: 'vince',
      authMode: AuthMode.privateKey,
      message:
          'The server rejected the configured private key. Confirm the selected key and the server account permissions.',
    );
  }

  static CodexSshRemoteLaunchFailedBlock sshRemoteLaunchFailedBlock() {
    return CodexSshRemoteLaunchFailedBlock(
      id: 'ssh_remote_launch_failed',
      createdAt: timestamp,
      host: 'relay-dev.internal',
      port: 22,
      username: 'vince',
      command: 'cd /workspace/Pocket-Relay && pocket-relay app-server --stdio',
      message:
          'The workspace directory could not be found on the remote host. Review the saved workspace path.',
    );
  }

  static ChatTranscriptSurfaceContract denseTranscriptSurface() {
    return ChatTranscriptSurfaceContract(
      isConfigured: true,
      mainItems: <ChatTranscriptItemContract>[
        ChatUserMessageItemContract(block: userMessage()),
        ChatReasoningItemContract(block: reasoningBlock(isRunning: true)),
        ChatPlanUpdateItemContract(block: planUpdateBlock()),
        ChatWorkLogGroupItemContract(
          id: 'lane_work_log',
          entries: workLogGroupItem().entries,
        ),
        ChatChangedFilesItemContract(
          id: 'lane_changed_files',
          title: changedFilesItem().title,
          isRunning: false,
          headerStats: changedFilesItem().headerStats,
          rows: changedFilesItem().rows,
        ),
        ChatAssistantMessageItemContract(
          block: assistantMessage(
            body:
                'I found the regression in the preview wrappers and removed the extra story-owned framing from the lane surfaces.',
          ),
        ),
        ChatSshItemContract(block: sshRemoteLaunchFailedBlock()),
        ChatStatusItemContract(block: statusBlock()),
        ChatUsageItemContract(block: usageBlock()),
        ChatTurnBoundaryItemContract(block: turnBoundaryBlock()),
      ],
      pinnedItems: const <ChatTranscriptItemContract>[],
      pendingRequestPlacement: ChatPendingRequestPlacementContract(
        visibleApprovalRequest: null,
        visibleUserInputRequest: null,
      ),
      activePendingUserInputRequestIds: const <String>{},
    );
  }

  static ChatScreenContract denseTranscriptLaneScreen({
    PocketPlatformBehavior platformBehavior = desktopBehavior,
  }) {
    return ChatScreenContract(
      isLoading: false,
      header: const ChatHeaderContract(
        title: 'Pocket Relay',
        subtitle: 'Developer Box · relay-dev.internal',
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
      transcriptSurface: denseTranscriptSurface(),
      transcriptFollow: const ChatTranscriptFollowContract(
        isAutoFollowEnabled: true,
        resumeDistance: 72,
      ),
      composer: ChatComposerContract(
        draftText: platformBehavior.usesDesktopKeyboardSubmit
            ? 'Summarize the lane and call out the highest-risk state.'
            : '',
        isSendActionEnabled: true,
        placeholder: 'Message Pocket Relay',
      ),
      connectionSettings: ChatConnectionSettingsLaunchContract(
        initialProfile: remoteProfile,
        initialSecrets: passwordSecrets,
      ),
    );
  }
}

class NoopDisplayWakeLockController implements DisplayWakeLockController {
  const NoopDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
