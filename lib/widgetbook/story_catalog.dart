import 'package:flutter/material.dart';
import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_meta_card.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/approval_request_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/assistant_message_card.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/error_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/plan_update_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/proposed_plan_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/reasoning_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_auth_failed_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_connect_failed_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_host_key_mismatch_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_remote_launch_failed_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/status_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/turn_boundary_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/usage_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/user_input_request_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/user_message_card.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_group_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

Widget _storyCard({
  required Widget child,
  double maxWidth = 860,
  AlignmentGeometry alignment = Alignment.centerLeft,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        child: SizedBox(
          width: constraints.maxWidth,
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

Widget _storyFill({required Widget child, double? maxWidth}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      final availableHeight = constraints.maxHeight;

      return SizedBox(
        width: availableWidth,
        height: availableHeight,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? availableWidth,
              maxHeight: availableHeight,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

List<WidgetbookNode> buildPocketRelayWidgetbookCatalog() {
  return <WidgetbookNode>[
    WidgetbookCategory(
      name: 'Core UI',
      children: <WidgetbookNode>[
        WidgetbookComponent(
          name: 'Panel Surface',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Default',
              builder: (context) {
                final theme = Theme.of(context);
                final palette = theme.extension<PocketPalette>()!;
                return _storyCard(
                  child: PocketPanelSurface(
                    padding: const EdgeInsets.all(PocketSpacing.md),
                    radius: PocketRadii.lg,
                    backgroundColor: palette.surface,
                    borderColor: palette.surfaceBorder,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: palette.shadowColor.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shared panel surface',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: PocketSpacing.xs),
                        Text(
                          'This container is reused for settings and support surfaces that need a consistent panel shell.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Transcript Frame',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Default',
              builder: (context) {
                final theme = Theme.of(context);
                final cards = ConversationCardPalette.of(context);
                final accent = blueAccent(theme.brightness);
                return _storyCard(
                  child: PocketTranscriptFrame(
                    backgroundColor: cards.tintedSurface(accent),
                    borderColor: cards.accentBorder(accent),
                    shadowColor: cards.shadow,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transcript frame primitive',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: PocketSpacing.xs),
                        Text(
                          'Transcript cards use this shared shell for width, radius, border, and elevation behavior.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cards.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Badges',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Variants',
              builder: (context) {
                final theme = Theme.of(context);
                return _storyCard(
                  child: Wrap(
                    spacing: PocketSpacing.sm,
                    runSpacing: PocketSpacing.sm,
                    children: [
                      PocketTintBadge(
                        label: 'Pending',
                        color: amberAccent(theme.brightness),
                      ),
                      PocketSolidBadge(
                        label: 'Running',
                        color: blueAccent(theme.brightness),
                      ),
                      const InlinePulseChip(label: 'Streaming'),
                      StateChip(
                        label: 'Saved',
                        color: tealAccent(theme.brightness),
                      ),
                      TranscriptBadge(
                        label: 'Approved',
                        color: tealAccent(theme.brightness),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Meta Card',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Default',
              builder: (context) => _storyCard(
                child: PocketMetaCard(
                  title: 'Session attached',
                  body:
                      'Pocket Relay resumed the existing Codex conversation without losing transcript context.',
                  accent: tealAccent(Theme.of(context).brightness),
                  icon: Icons.link_rounded,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'Chat',
      children: <WidgetbookNode>[
        WidgetbookFolder(
          name: 'Transcript',
          children: <WidgetbookNode>[
            WidgetbookComponent(
              name: 'Transcript Lane',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Desktop Filled Lane',
                  builder: (_) {
                    final screen = WidgetbookFixtures.denseTranscriptLaneScreen();
                    return FlutterChatScreenRenderer(
                      screen: screen,
                      appChrome: FlutterChatAppChrome(
                        screen: screen,
                        onScreenAction: (_) {},
                      ),
                      transcriptRegion: FlutterChatTranscriptRegion(
                        screen: screen,
                        platformBehavior: WidgetbookFixtures.desktopBehavior,
                        onScreenAction: (_) {},
                        onSelectTimeline: (_) {},
                        onSelectConnectionMode: (_) {},
                        onAutoFollowEligibilityChanged: (_) {},
                        onOpenChangedFileDiff: (_) {},
                        onApproveRequest: (_) async {},
                        onDenyRequest: (_) async {},
                        onSubmitUserInput: (_, answers) async {},
                        onSaveHostFingerprint: (_) async {},
                      ),
                      composerRegion: FlutterChatComposerRegion(
                        platformBehavior: WidgetbookFixtures.desktopBehavior,
                        conversationRecoveryNotice: null,
                        historicalConversationRestoreNotice: null,
                        composer: screen.composer,
                        onComposerDraftChanged: (_) {},
                        onSendPrompt: () async {},
                        onConversationRecoveryAction: (_) {},
                        onHistoricalConversationRestoreAction: (_) {},
                      ),
                      onStopActiveTurn: () async {},
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Assistant Message',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Final',
                  builder: (_) => _storyCard(
                    child: AssistantMessageCard(
                      block: WidgetbookFixtures.assistantMessage(),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Streaming',
                  builder: (_) => _storyCard(
                    child: AssistantMessageCard(
                      block: WidgetbookFixtures.assistantMessage(
                        isRunning: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Reasoning',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Running',
                  builder: (_) => _storyCard(
                    child: ReasoningCard(
                      block: WidgetbookFixtures.reasoningBlock(isRunning: true),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Complete',
                  builder: (_) => _storyCard(
                    child: ReasoningCard(
                      block: WidgetbookFixtures.reasoningBlock(
                        isRunning: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'User Message',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Sent',
                  builder: (_) => _storyCard(
                    alignment: Alignment.centerRight,
                    child: UserMessageCard(
                      block: WidgetbookFixtures.userMessage(),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Local Echo',
                  builder: (_) => _storyCard(
                    alignment: Alignment.centerRight,
                    child: UserMessageCard(
                      block: WidgetbookFixtures.userMessage(
                        deliveryState: CodexUserMessageDeliveryState.localEcho,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Status',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => _storyCard(
                    child: StatusCard(block: WidgetbookFixtures.statusBlock()),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Error',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => _storyCard(
                    child: ErrorCard(block: WidgetbookFixtures.errorBlock()),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Approval Request',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Pending',
                  builder: (_) => _storyCard(
                    child: ApprovalRequestCard(
                      request: WidgetbookFixtures.approvalRequest(),
                      onApprove: (_) async {},
                      onDeny: (_) async {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Resolved',
                  builder: (_) => _storyCard(
                    child: ApprovalRequestCard(
                      request: WidgetbookFixtures.approvalRequest(
                        isResolved: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Plan Update',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => _storyCard(
                    child: PlanUpdateCard(
                      block: WidgetbookFixtures.planUpdateBlock(),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Proposed Plan',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Final',
                  builder: (_) => _storyCard(
                    child: ProposedPlanCard(
                      block: WidgetbookFixtures.proposedPlanBlock(),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Streaming Long',
                  builder: (_) => _storyCard(
                    child: ProposedPlanCard(
                      block: WidgetbookFixtures.proposedPlanBlock(
                        isStreaming: true,
                        isLong: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Changed Files',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Mixed',
                  builder: (_) => _storyCard(
                    child: ChangedFilesCard(
                      item: WidgetbookFixtures.changedFilesItem(),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Created',
                  builder: (_) => _storyCard(
                    child: ChangedFilesCard(
                      item: WidgetbookFixtures.changedFilesItem(
                        variant: 'created',
                      ),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Deleted',
                  builder: (_) => _storyCard(
                    child: ChangedFilesCard(
                      item: WidgetbookFixtures.changedFilesItem(
                        variant: 'deleted',
                      ),
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Running',
                  builder: (_) => _storyCard(
                    child: ChangedFilesCard(
                      item: WidgetbookFixtures.changedFilesItem(
                        isRunning: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Work Log',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => _storyCard(
                    child: WorkLogGroupCard(
                      item: WidgetbookFixtures.workLogGroupItem(),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'User Input Request',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Pending',
                  builder: (_) => _storyCard(
                    child: UserInputRequestCard(
                      contract: WidgetbookFixtures.pendingUserInput(),
                      onFieldChanged: (_, value) {},
                      onSubmit: () async {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Resolved',
                  builder: (_) => _storyCard(
                    child: UserInputRequestCard(
                      contract: WidgetbookFixtures.pendingUserInput(
                        resolved: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Usage Summary',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => _storyCard(
                    child: UsageCard(block: WidgetbookFixtures.usageBlock()),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Turn Boundary',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (_) => _storyCard(
                    child: TurnBoundaryCard(
                      block: WidgetbookFixtures.turnBoundaryBlock(),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SSH Host Trust',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Unpinned',
                  builder: (_) => _storyCard(
                    child: SshUnpinnedHostKeyCard(
                      block: WidgetbookFixtures.sshUnpinnedHostKey(),
                      onSaveFingerprint: (_) async {},
                      onOpenConnectionSettings: () {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Saved',
                  builder: (_) => _storyCard(
                    child: SshUnpinnedHostKeyCard(
                      block: WidgetbookFixtures.sshUnpinnedHostKey(
                        isSaved: true,
                      ),
                      onOpenConnectionSettings: () {},
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SSH Errors',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Connect Failed',
                  builder: (_) => _storyCard(
                    child: SshConnectFailedCard(
                      block: WidgetbookFixtures.sshConnectFailedBlock(),
                      onOpenConnectionSettings: () {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Host Key Mismatch',
                  builder: (_) => _storyCard(
                    child: SshHostKeyMismatchCard(
                      block: WidgetbookFixtures.sshHostKeyMismatchBlock(),
                      onOpenConnectionSettings: () {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Authentication Failed',
                  builder: (_) => _storyCard(
                    child: SshAuthFailedCard(
                      block: WidgetbookFixtures.sshAuthenticationFailedBlock(),
                      onOpenConnectionSettings: () {},
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Remote Launch Failed',
                  builder: (_) => _storyCard(
                    child: SshRemoteLaunchFailedCard(
                      block: WidgetbookFixtures.sshRemoteLaunchFailedBlock(),
                      onOpenConnectionSettings: () {},
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Composer',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile',
              builder: (_) => _storyCard(
                maxWidth: 720,
                child: ChatComposer(
                  platformBehavior: WidgetbookFixtures.mobileBehavior,
                  contract: const ChatComposerContract(
                    draftText: 'Summarize the latest session output.',
                    isSendActionEnabled: true,
                    placeholder: 'Ask Codex to continue',
                  ),
                  onChanged: (_) {},
                  onSend: () async {},
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'Desktop',
              builder: (_) => _storyCard(
                maxWidth: 920,
                child: ChatComposer(
                  platformBehavior: WidgetbookFixtures.desktopBehavior,
                  contract: const ChatComposerContract(
                    draftText:
                        'Run the failing test file and explain the regression.',
                    isSendActionEnabled: true,
                    placeholder: 'Message Pocket Relay',
                  ),
                  onChanged: (_) {},
                  onSend: () async {},
                ),
              ),
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Empty State',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile First Run',
              builder: (_) => _storyFill(
                child: EmptyState(
                  isConfigured: false,
                  connectionMode: ConnectionMode.remote,
                  platformBehavior: WidgetbookFixtures.mobileBehavior,
                  onConfigure: () {},
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'Desktop Configured',
              builder: (_) => _storyFill(
                child: EmptyState(
                  isConfigured: true,
                  connectionMode: ConnectionMode.local,
                  platformBehavior: WidgetbookFixtures.desktopBehavior,
                  onConfigure: () {},
                  onSelectConnectionMode: (_) {},
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'Settings',
      children: <WidgetbookNode>[
        WidgetbookComponent(
          name: 'Connection Sheet',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Remote Password',
              builder: (_) => _storyFill(
                maxWidth: 920,
                child: ConnectionSettingsHost(
                  initialProfile: WidgetbookFixtures.remoteProfile,
                  initialSecrets: WidgetbookFixtures.passwordSecrets,
                  platformBehavior: WidgetbookFixtures.desktopBehavior,
                  onCancel: () {},
                  onSubmit: (_) {},
                  builder: (context, viewModel, actions) {
                    return ConnectionSheet(
                      viewModel: viewModel,
                      actions: actions,
                    );
                  },
                ),
              ),
            ),
            WidgetbookUseCase(
              name: 'Local Workspace',
              builder: (_) => _storyFill(
                maxWidth: 920,
                child: ConnectionSettingsHost(
                  initialProfile: WidgetbookFixtures.localProfile,
                  initialSecrets: const ConnectionSecrets(),
                  platformBehavior: WidgetbookFixtures.desktopBehavior,
                  onCancel: () {},
                  onSubmit: (_) {},
                  builder: (context, viewModel, actions) {
                    return ConnectionSheet(
                      viewModel: viewModel,
                      actions: actions,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'App',
      children: <WidgetbookNode>[
        WidgetbookComponent(
          name: 'Workspace',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile Workspace',
              builder: (_) => PocketRelayApp(
                connectionRepository: MemoryCodexConnectionRepository.single(
                  savedProfile: WidgetbookFixtures.savedProfile,
                ),
                appServerClient: FakeCodexAppServerClient(),
                displayWakeLockController:
                    const NoopDisplayWakeLockController(),
                platformPolicy: WidgetbookFixtures.mobilePolicy,
              ),
            ),
            WidgetbookUseCase(
              name: 'Desktop Workspace',
              builder: (_) => PocketRelayApp(
                connectionRepository: MemoryCodexConnectionRepository.single(
                  savedProfile: WidgetbookFixtures.savedProfile,
                ),
                appServerClient: FakeCodexAppServerClient(),
                displayWakeLockController:
                    const NoopDisplayWakeLockController(),
                platformPolicy: WidgetbookFixtures.desktopPolicy,
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}
