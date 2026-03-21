import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';

class WidgetbookFixtures {
  static final DateTime timestamp = DateTime.utc(2026, 3, 21, 10, 30);

  static const String assistantMessageMarkdown =
      'Updated the workspace shell and tightened the lane selection flow.\n\n'
      '- Added deterministic fixtures for previews\n'
      '- Kept the app wiring separate from story state\n'
      '- Left transport ownership outside the visual surface';

  static const String reasoningMarkdown =
      'Comparing the new shell against the prior state.\n\n'
      '1. Verify lane selection is explicit.\n'
      '2. Keep storage and transport injected.\n'
      '3. Render only presentation-focused surfaces in isolation.';

  static const String proposedPlanMarkdown =
      '# Workspace Update Plan\n\n'
      '## Summary\n\n'
      'Stabilize the active workspace and improve the transcript interaction flow.\n\n'
      '## Scope\n\n'
      '1. Tighten lane selection and preserve the current active session.\n'
      '2. Reduce duplicate transcript chrome in execution-heavy states.\n'
      '3. Keep runtime ownership outside the presentation layer.\n\n'
      '## Acceptance Criteria\n\n'
      '- Active session context stays visible while work is running.\n'
      '- Execution details remain readable in dense turns.\n'
      '- Long content still supports truncation and expansion.';

  static const String longProposedPlanMarkdown =
      '# Runtime Surface Cleanup\n\n'
      '## Summary\n\n'
      'Reduce visual duplication and keep runtime state visible while the assistant is still working.\n\n'
      '## Workstreams\n\n'
      '1. Navigation\n'
      '- Preserve the active lane while workspace state refreshes.\n'
      '- Keep saved connections distinct from currently running sessions.\n\n'
      '2. Transcript\n'
      '- Show approval and input-required states without obscuring consequence.\n'
      '- Keep file changes and work log output readable during long turns.\n'
      '- Preserve SSH trust and failure context while recovery actions are available.\n\n'
      '3. Reliability\n'
      '- Keep long content expandable without losing the initial summary.\n'
      '- Avoid duplicate status signals for the same runtime meaning.\n'
      '- Keep action-required states visually consistent.\n\n'
      '## Notes\n\n'
      'This plan focuses on the runtime surfaces users actually see during a dense session, not on internal implementation abstractions.';

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
      body: 'Pocket Relay is connected to the remote Codex session.',
    );
  }

  static CodexErrorBlock errorBlock() {
    return CodexErrorBlock(
      id: 'error_message',
      createdAt: timestamp,
      title: 'Remote launch failed',
      body:
          'The preview uses a fake client, so no real app-server process was started.',
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
          'Codex wants to update the workspace transcript shell and apply the pending file edits.',
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
          'Choose which transcript surface to inspect next and add any notes before continuing.',
      isResolved: resolved,
      isSubmitting: submitting,
      isSubmitEnabled: !resolved,
      statusBadgeLabel: resolved
          ? 'submitted'
          : (submitting ? 'submitting' : 'pending'),
      submitLabel: submitting ? 'Submitting…' : 'Submit review',
      submitPayload: const <String, List<String>>{
        'surface': <String>['Approval Request'],
      },
      fields: const <PendingUserInputFieldContract>[
        PendingUserInputFieldContract(
          id: 'surface',
          header: 'Surface',
          prompt: 'Pick the next transcript surface to inspect.',
          inputLabel: 'Surface',
          value: 'Approval Request',
          options: <PendingUserInputOptionContract>[
            PendingUserInputOptionContract(
              label: 'Approval Request',
              description: 'Inspect the blocked-action state',
            ),
            PendingUserInputOptionContract(
              label: 'Changed Files',
              description: 'Inspect file-change output',
            ),
            PendingUserInputOptionContract(
              label: 'Work Log',
              description: 'Inspect command activity output',
            ),
          ],
        ),
        PendingUserInputFieldContract(
          id: 'notes',
          header: 'Notes',
          prompt: 'Add any notes before continuing.',
          inputLabel: 'Notes',
          value:
              'Badge contrast is working well. The changed-file action chips still feel too visually competitive.',
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
          'Reordered the next steps so the active runtime surfaces are stabilized before expanding secondary states.',
      steps: <CodexRuntimePlanStep>[
        CodexRuntimePlanStep(
          step: 'Tighten active runtime transcript states',
          status: CodexRuntimePlanStepStatus.completed,
        ),
        CodexRuntimePlanStep(
          step: 'Normalize action-required transcript surfaces',
          status: CodexRuntimePlanStepStatus.inProgress,
        ),
        CodexRuntimePlanStep(
          step: 'Backfill visual regression coverage for key runtime states',
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
  }) {
    const designDiff = ChatChangedFileDiffContract(
      id: 'diff_transcript_frame',
      displayPathLabel: 'lib/src/core/ui/surfaces/pocket_transcript_frame.dart',
      statusLabel: 'modified',
      stats: ChatChangedFileStatsContract(additions: 42, deletions: 11),
      lines: <ChatChangedFileDiffLineContract>[
        ChatChangedFileDiffLineContract(
          text: '@@ -1,6 +1,17 @@',
          kind: ChatChangedFileDiffLineKind.hunk,
        ),
        ChatChangedFileDiffLineContract(
          text: '+class PocketTranscriptFrame extends StatelessWidget {',
          kind: ChatChangedFileDiffLineKind.addition,
        ),
        ChatChangedFileDiffLineContract(
          text:
              '+  const PocketTranscriptFrame({super.key, required this.child});',
          kind: ChatChangedFileDiffLineKind.addition,
        ),
        ChatChangedFileDiffLineContract(
          text: '-class TranscriptBadge extends StatelessWidget {',
          kind: ChatChangedFileDiffLineKind.deletion,
        ),
        ChatChangedFileDiffLineContract(
          text: ' child: PocketPanelSurface(...),',
          kind: ChatChangedFileDiffLineKind.context,
        ),
      ],
    );

    return ChatChangedFilesItemContract(
      id: 'changed_files',
      title: 'Changed files',
      isRunning: isRunning,
      headerStats: const ChatChangedFileStatsContract(
        additions: 108,
        deletions: 36,
      ),
      rows: <ChatChangedFileRowContract>[
        ChatChangedFileRowContract(
          id: 'changed_file_1',
          displayPathLabel: 'lib/widgetbook/story_catalog.dart',
          operationKind: ChatChangedFileOperationKind.modified,
          operationLabel: 'modified',
          stats: ChatChangedFileStatsContract(additions: 27, deletions: 5),
          actionLabel: 'Open diff',
          diff: designDiff,
        ),
        ChatChangedFileRowContract(
          id: 'changed_file_2',
          displayPathLabel: 'lib/widgetbook/support/widgetbook_fixtures.dart',
          operationKind: ChatChangedFileOperationKind.created,
          operationLabel: 'created',
          stats: ChatChangedFileStatsContract(additions: 54, deletions: 0),
          actionLabel: 'Open diff',
          diff: ChatChangedFileDiffContract(
            id: 'diff_widgetbook_fixtures',
            displayPathLabel: 'lib/widgetbook/support/widgetbook_fixtures.dart',
            statusLabel: 'new',
            stats: ChatChangedFileStatsContract(additions: 54, deletions: 0),
            lines: <ChatChangedFileDiffLineContract>[
              ChatChangedFileDiffLineContract(
                text:
                    '+static ChatApprovalRequestContract approvalRequest(...) {',
                kind: ChatChangedFileDiffLineKind.addition,
              ),
              ChatChangedFileDiffLineContract(
                text:
                    '+static ChatChangedFilesItemContract changedFilesItem(...) {',
                kind: ChatChangedFileDiffLineKind.addition,
              ),
            ],
          ),
        ),
        ChatChangedFileRowContract(
          id: 'changed_file_3',
          displayPathLabel:
              'lib/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart',
          operationKind: ChatChangedFileOperationKind.deleted,
          operationLabel: 'deleted',
          stats: ChatChangedFileStatsContract(additions: 0, deletions: 31),
          actionLabel: 'No diff',
        ),
      ],
    );
  }

  static ChatWorkLogGroupItemContract workLogGroupItem() {
    return ChatWorkLogGroupItemContract(
      id: 'work_log_group',
      entries: <ChatWorkLogEntryContract>[
        ChatRipgrepSearchWorkLogEntryContract(
          id: 'work_log_rg',
          commandText: 'rg "PocketPanelSurface|PocketMetaCard" lib/src',
          queryText: 'PocketPanelSurface|PocketMetaCard',
          scopeTargets: <String>['lib/src', 'lib/widgetbook'],
          exitCode: 0,
        ),
        ChatGitWorkLogEntryContract(
          id: 'work_log_git',
          commandText: 'git status --short',
          subcommandLabel: 'status',
          summaryLabel: 'Reviewing modified transcript cards',
          primaryLabel: 'git status --short',
          secondaryLabel: '6 files changed',
          exitCode: 0,
        ),
        ChatGenericWorkLogEntryContract(
          id: 'work_log_generic',
          entryKind: CodexWorkLogEntryKind.dynamicToolCall,
          title: 'Updated Widgetbook fixtures',
          preview:
              'Added approval, changed-files, and work-log preview states.',
        ),
        ChatGenericWorkLogEntryContract(
          id: 'work_log_running',
          entryKind: CodexWorkLogEntryKind.commandExecution,
          title: 'Analyzing transcript card library',
          preview:
              'flutter analyze lib/src/features/chat/presentation/widgets/transcript/cards',
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
}

class NoopDisplayWakeLockController implements DisplayWakeLockController {
  const NoopDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
