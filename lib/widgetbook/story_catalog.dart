import 'package:flutter/material.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
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
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_auth_failed_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_connect_failed_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_host_key_mismatch_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_remote_launch_failed_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_unpinned_host_key_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/status_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/user_input_request_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/widgetbook/support/fake_codex_app_server_client.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

Widget _storyCard({
  required Widget child,
  double maxWidth = 860,
  AlignmentGeometry alignment = Alignment.centerLeft,
}) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

Widget _storyFill({required Widget child, double? maxWidth}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 48,
            maxWidth: maxWidth ?? constraints.maxWidth,
          ),
          child: child,
        ),
      );
    },
  );
}

List<WidgetbookNode> buildPocketRelayWidgetbookCatalog() {
  return <WidgetbookNode>[
    WidgetbookCategory(
      name: 'Chat',
      children: <WidgetbookNode>[
        WidgetbookFolder(
          name: 'Transcript',
          children: <WidgetbookNode>[
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
                  name: 'Completed',
                  builder: (_) => _storyCard(
                    child: ChangedFilesCard(
                      item: WidgetbookFixtures.changedFilesItem(),
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
                connectionConversationStateStore:
                    MemoryCodexConnectionConversationStateStore(),
                appServerClient: WidgetbookFakeCodexAppServerClient(),
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
                connectionConversationStateStore:
                    MemoryCodexConnectionConversationStateStore(),
                appServerClient: WidgetbookFakeCodexAppServerClient(),
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
