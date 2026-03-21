import 'package:flutter/material.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_meta_card.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/error_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/status_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/widgetbook/support/fake_codex_app_server_client.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_story_frame.dart';
import 'package:widgetbook/widgetbook.dart';

List<WidgetbookNode> buildPocketRelayWidgetbookCatalog() {
  return <WidgetbookNode>[
    WidgetbookCategory(
      name: 'Foundations',
      children: <WidgetbookNode>[
        WidgetbookFolder(
          name: 'Primitives',
          children: <WidgetbookNode>[
            WidgetbookComponent(
              name: 'Badges',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Status Set',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      maxWidth: 720,
                      child: Wrap(
                        spacing: PocketSpacing.sm,
                        runSpacing: PocketSpacing.sm,
                        children: <Widget>[
                          PocketTintBadge(
                            label: 'designer review',
                            color: blueAccent(Brightness.light),
                          ),
                          PocketTintBadge(
                            label: 'running',
                            color: tealAccent(Brightness.light),
                          ),
                          PocketTintBadge(
                            label: 'warning',
                            color: amberAccent(Brightness.light),
                          ),
                          const PocketSolidBadge(
                            label: 'ready',
                            color: Color(0xFF1D4ED8),
                          ),
                          const PocketSolidBadge(
                            label: 'blocked',
                            color: Color(0xFFB91C1C),
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
                  name: 'Informational',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: PocketMetaCard(
                        title: 'Review checkpoint',
                        body:
                            'The transcript surface now shares one visual shell across designer-facing card states.',
                        accent: blueAccent(Brightness.light),
                        icon: Icons.info_outline,
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Panel Surface',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Default Panel',
                  builder: (context) {
                    final cards = ConversationCardPalette.of(context);
                    final accent = blueAccent(Theme.of(context).brightness);
                    return WidgetbookStoryFrame.card(
                      maxWidth: 760,
                      child: PocketPanelSurface(
                        padding: const EdgeInsets.all(PocketSpacing.md),
                        radius: PocketRadii.lg,
                        backgroundColor: cards.surface,
                        borderColor: cards.accentBorder(accent),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Shared panel shell',
                              style: TextStyle(
                                color: cards.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: PocketSpacing.xs),
                            Text(
                              'Use this surface for reusable transcript and settings panels before introducing feature-local container recipes.',
                              style: TextStyle(color: cards.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'Chat',
      children: <WidgetbookNode>[
        WidgetbookFolder(
          name: 'Transcript Cards',
          children: <WidgetbookNode>[
            WidgetbookComponent(
              name: 'Assistant Message',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    final body = context.knobs.string(
                      label: 'Body',
                      initialValue: WidgetbookFixtures.assistantMessageMarkdown,
                    );
                    final isRunning = context.knobs.boolean(
                      label: 'Streaming',
                      initialValue: false,
                    );
                    return WidgetbookStoryFrame.card(
                      child: AssistantMessageCard(
                        block: WidgetbookFixtures.assistantMessage(
                          body: body,
                          isRunning: isRunning,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Reasoning',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    final isRunning = context.knobs.boolean(
                      label: 'Running',
                      initialValue: true,
                    );
                    return WidgetbookStoryFrame.card(
                      child: ReasoningCard(
                        block: WidgetbookFixtures.reasoningBlock(
                          isRunning: isRunning,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'User Message',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    final localEcho = context.knobs.boolean(
                      label: 'Local echo',
                      initialValue: false,
                    );
                    return WidgetbookStoryFrame.card(
                      alignment: Alignment.centerRight,
                      child: UserMessageCard(
                        block: WidgetbookFixtures.userMessage(
                          deliveryState: localEcho
                              ? CodexUserMessageDeliveryState.localEcho
                              : CodexUserMessageDeliveryState.sent,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Status',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    return WidgetbookStoryFrame.card(
                      child: StatusCard(
                        block: WidgetbookFixtures.statusBlock(),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Error',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: (context) {
                    return WidgetbookStoryFrame.card(
                      child: ErrorCard(block: WidgetbookFixtures.errorBlock()),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Approval Request',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Needs Approval',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: ApprovalRequestCard(
                        request: WidgetbookFixtures.approvalRequest(),
                        onApprove: (_) async {},
                        onDeny: (_) async {},
                      ),
                    );
                  },
                ),
                WidgetbookUseCase(
                  name: 'Resolved',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: ApprovalRequestCard(
                        request: WidgetbookFixtures.approvalRequest(
                          isResolved: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Plan Update',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Execution Status',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: PlanUpdateCard(
                        block: WidgetbookFixtures.planUpdateBlock(),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Proposed Plan',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Collapsed Draft',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: ProposedPlanCard(
                        block: WidgetbookFixtures.proposedPlanBlock(
                          isStreaming: true,
                          isLong: true,
                        ),
                      ),
                    );
                  },
                ),
                WidgetbookUseCase(
                  name: 'Settled Summary',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: ProposedPlanCard(
                        block: WidgetbookFixtures.proposedPlanBlock(),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Changed Files',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Settled Review',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: ChangedFilesCard(
                        item: WidgetbookFixtures.changedFilesItem(),
                      ),
                    );
                  },
                ),
                WidgetbookUseCase(
                  name: 'Running Update',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: ChangedFilesCard(
                        item: WidgetbookFixtures.changedFilesItem(
                          isRunning: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Work Log',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Mixed Activity',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: WorkLogGroupCard(
                        item: WidgetbookFixtures.workLogGroupItem(),
                      ),
                    );
                  },
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SSH Host Trust',
              useCases: <WidgetbookUseCase>[
                WidgetbookUseCase(
                  name: 'Unpinned',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: SshUnpinnedHostKeyCard(
                        block: WidgetbookFixtures.sshUnpinnedHostKey(),
                        onSaveFingerprint: (_) async {},
                        onOpenConnectionSettings: () {},
                      ),
                    );
                  },
                ),
                WidgetbookUseCase(
                  name: 'Saved',
                  builder: (_) {
                    return WidgetbookStoryFrame.card(
                      child: SshUnpinnedHostKeyCard(
                        block: WidgetbookFixtures.sshUnpinnedHostKey(
                          isSaved: true,
                        ),
                        onOpenConnectionSettings: () {},
                      ),
                    );
                  },
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
              builder: (context) {
                final draftText = context.knobs.string(
                  label: 'Draft',
                  initialValue: 'Summarize the latest transcript changes.',
                );
                return WidgetbookStoryFrame.card(
                  maxWidth: 720,
                  child: ChatComposer(
                    platformBehavior: WidgetbookFixtures.mobileBehavior,
                    contract: ChatComposerContract(
                      draftText: draftText,
                      isSendActionEnabled: draftText.trim().isNotEmpty,
                      placeholder: 'Ask Codex to continue',
                    ),
                    onChanged: (_) {},
                    onSend: () async {},
                  ),
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Desktop',
              builder: (context) {
                final draftText = context.knobs.string(
                  label: 'Draft',
                  initialValue:
                      'Run the failing test file and explain the regression.',
                );
                return WidgetbookStoryFrame.card(
                  maxWidth: 920,
                  child: ChatComposer(
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    contract: ChatComposerContract(
                      draftText: draftText,
                      isSendActionEnabled: draftText.trim().isNotEmpty,
                      placeholder: 'Message Pocket Relay',
                    ),
                    onChanged: (_) {},
                    onSend: () async {},
                  ),
                );
              },
            ),
          ],
        ),
        WidgetbookComponent(
          name: 'Empty State',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile First Run',
              builder: (context) {
                return WidgetbookStoryFrame.fill(
                  child: EmptyState(
                    isConfigured: false,
                    connectionMode: ConnectionMode.remote,
                    platformBehavior: WidgetbookFixtures.mobileBehavior,
                    onConfigure: () {},
                  ),
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Desktop Configured',
              builder: (context) {
                return WidgetbookStoryFrame.fill(
                  child: EmptyState(
                    isConfigured: true,
                    connectionMode: ConnectionMode.local,
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    onConfigure: () {},
                    onSelectConnectionMode: (_) {},
                  ),
                );
              },
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
              builder: (_) {
                return WidgetbookStoryFrame.fill(
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
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Local Workspace',
              builder: (_) {
                return WidgetbookStoryFrame.fill(
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
                );
              },
            ),
          ],
        ),
      ],
    ),
    WidgetbookCategory(
      name: 'Shells',
      children: <WidgetbookNode>[
        WidgetbookComponent(
          name: 'Pocket Relay App',
          useCases: <WidgetbookUseCase>[
            WidgetbookUseCase(
              name: 'Mobile Active Lane',
              builder: (_) {
                return PocketRelayApp(
                  connectionRepository: MemoryCodexConnectionRepository.single(
                    savedProfile: WidgetbookFixtures.savedProfile,
                  ),
                  connectionConversationStateStore:
                      MemoryCodexConnectionConversationHistoryStore(),
                  appServerClient: WidgetbookFakeCodexAppServerClient(),
                  displayWakeLockController:
                      const NoopDisplayWakeLockController(),
                  platformPolicy: WidgetbookFixtures.mobilePolicy,
                );
              },
            ),
            WidgetbookUseCase(
              name: 'Desktop Active Lane',
              builder: (_) {
                return PocketRelayApp(
                  connectionRepository: MemoryCodexConnectionRepository.single(
                    savedProfile: WidgetbookFixtures.savedProfile,
                  ),
                  connectionConversationStateStore:
                      MemoryCodexConnectionConversationHistoryStore(),
                  appServerClient: WidgetbookFakeCodexAppServerClient(),
                  displayWakeLockController:
                      const NoopDisplayWakeLockController(),
                  platformPolicy: WidgetbookFixtures.desktopPolicy,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ];
}
