import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
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
      '# Widgetbook Coverage Expansion\n\n'
      '## Summary\n\n'
      'Expose the card family designers review during transcript QA.\n\n'
      '## Scope\n\n'
      '1. Add isolated stories for approval, plan, file-change, and work-log states.\n'
      '2. Use deterministic fixtures with realistic copy.\n'
      '3. Keep runtime ownership outside the catalog.\n\n'
      '## Acceptance Criteria\n\n'
      '- Designers can compare light and dark themes.\n'
      '- Long content demonstrates truncation and expansion behavior.\n'
      '- Stories are grouped by product language rather than raw class names.';

  static const String longProposedPlanMarkdown =
      '# Desktop Transcript Review Pass\n\n'
      '## Summary\n\n'
      'Normalize the card shell and expose the transcript states that cause design churn during implementation review.\n\n'
      '## Workstreams\n\n'
      '1. Foundations\n'
      '- Promote shared panel, badge, and meta-card primitives into core ownership.\n'
      '- Reuse a consistent radius and spacing scale across transcript surfaces.\n\n'
      '2. Transcript Cards\n'
      '- Add approval-request previews with resolved and unresolved states.\n'
      '- Add changed-file rows that show create, modify, and delete actions.\n'
      '- Add work-log previews with command, search, and git variants.\n'
      '- Add SSH trust states for first-connect host verification.\n\n'
      '3. Design Review\n'
      '- Provide long markdown to exercise collapse behavior.\n'
      '- Keep realistic labels, filenames, and summaries.\n'
      '- Avoid playground-only knobs that do not map to product decisions.\n\n'
      '## Notes\n\n'
      'The catalog should act as a review artifact, not just a developer sandbox. That means every granular story needs a stable narrative and fixture set that represents a real product state rather than arbitrary lorem ipsum.';

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
          'Codex wants to update the shared transcript card frame and add Widgetbook stories for granular designer review.',
      isResolved: isResolved,
      resolutionLabel: isResolved ? 'approved' : null,
    );
  }

  static CodexPlanUpdateBlock planUpdateBlock() {
    return CodexPlanUpdateBlock(
      id: 'plan_update',
      createdAt: timestamp,
      explanation:
          'Reordered the implementation around designer-visible surfaces so the next slice improves reviewability instead of only internal structure.',
      steps: <CodexRuntimePlanStep>[
        CodexRuntimePlanStep(
          step: 'Expand the fixture layer with deterministic product states',
          status: CodexRuntimePlanStepStatus.completed,
        ),
        CodexRuntimePlanStep(
          step: 'Add transcript card stories for designer-facing review states',
          status: CodexRuntimePlanStepStatus.inProgress,
        ),
        CodexRuntimePlanStep(
          step: 'Backfill visual regression coverage for key transcript cards',
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
}

class NoopDisplayWakeLockController implements DisplayWakeLockController {
  const NoopDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
