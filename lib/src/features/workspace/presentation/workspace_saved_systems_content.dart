import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_sheet.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_widgets.dart';

const double _savedSystemsPanelRadius = 12;

class ConnectionWorkspaceSavedSystemsContent extends StatefulWidget {
  const ConnectionWorkspaceSavedSystemsContent({
    super.key,
    required this.workspaceController,
    required this.description,
    this.platformBehavior = const PocketPlatformBehavior(
      experience: PocketPlatformExperience.mobile,
      supportsLocalConnectionMode: false,
      supportsWakeLock: true,
      supportsFiniteBackgroundGrace: false,
      supportsActiveTurnForegroundService: false,
      usesDesktopKeyboardSubmit: false,
      supportsCollapsibleDesktopSidebar: false,
    ),
    this.useSafeArea = true,
  });

  final ConnectionWorkspaceController workspaceController;
  final String description;
  final PocketPlatformBehavior platformBehavior;
  final bool useSafeArea;

  @override
  State<ConnectionWorkspaceSavedSystemsContent> createState() =>
      _ConnectionWorkspaceSavedSystemsContentState();
}

class _ConnectionWorkspaceSavedSystemsContentState
    extends State<ConnectionWorkspaceSavedSystemsContent> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _editingSystemIds = <String>{};
  final Set<String> _deletingSystemIds = <String>{};
  bool _isCreatingSystem = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    final wrappedContent = widget.useSafeArea
        ? SafeArea(bottom: false, child: content)
        : content;
    return Material(
      type: MaterialType.transparency,
      child: ChatScreenGradientBackground(child: wrappedContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    final systems =
        widget.workspaceController.state.systemCatalog.orderedSystems;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          ConnectionWorkspaceCopy.systemsTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('add_system'),
            onPressed: _isCreatingSystem ? null : _createSystem,
            icon: const Icon(Icons.add),
            label: Text(
              _isCreatingSystem
                  ? ConnectionWorkspaceCopy.addSystemProgress
                  : ConnectionWorkspaceCopy.addSystemAction,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (systems.isEmpty)
          const _SavedSystemsEmptyState()
        else
          ...systems.indexed.map((entry) {
            final index = entry.$1;
            final system = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == systems.length - 1 ? 0 : 12,
              ),
              child: ConnectionLifecycleRow(
                rowKey: ValueKey<String>('saved_system_${system.id}'),
                title: system.profile.displayLabel,
                subtitle: ConnectionWorkspaceCopy.systemSubtitle(
                  system.profile,
                ),
                facts: const [],
                secondaryActions: <ConnectionLifecycleButtonAction>[
                  ConnectionLifecycleButtonAction(
                    key: ValueKey<String>('edit_system_${system.id}'),
                    label: _editingSystemIds.contains(system.id)
                        ? ConnectionWorkspaceCopy.saveProgress
                        : ConnectionWorkspaceCopy.editAction,
                    onPressed:
                        _editingSystemIds.contains(system.id) ||
                            _deletingSystemIds.contains(system.id)
                        ? null
                        : () => _editSystem(system.id),
                  ),
                  ConnectionLifecycleButtonAction(
                    key: ValueKey<String>('delete_system_${system.id}'),
                    label: _deletingSystemIds.contains(system.id)
                        ? ConnectionWorkspaceCopy.deleteProgress
                        : ConnectionWorkspaceCopy.deleteAction,
                    onPressed:
                        _editingSystemIds.contains(system.id) ||
                            _deletingSystemIds.contains(system.id)
                        ? null
                        : () => _deleteSystem(system.id),
                    isDestructive: true,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Future<void> _createSystem() async {
    if (_isCreatingSystem) {
      return;
    }

    setState(() {
      _isCreatingSystem = true;
    });

    try {
      final payload = await _openSystemSettings();
      if (!mounted || payload == null) {
        return;
      }
      await widget.workspaceController.createSystem(
        profile: systemProfileFromConnectionProfile(payload.profile),
        secrets: payload.secrets,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingSystem = false;
        });
      }
    }
  }

  Future<void> _editSystem(String systemId) async {
    if (_editingSystemIds.contains(systemId)) {
      return;
    }

    setState(() {
      _editingSystemIds.add(systemId);
    });

    try {
      final system = await widget.workspaceController.loadSavedSystem(systemId);
      if (!mounted) {
        return;
      }
      final payload = await _openSystemSettings(system: system);
      if (!mounted || payload == null) {
        return;
      }
      await widget.workspaceController.saveSavedSystem(
        systemId: systemId,
        profile: systemProfileFromConnectionProfile(payload.profile),
        secrets: payload.secrets,
      );
    } finally {
      if (mounted) {
        setState(() {
          _editingSystemIds.remove(systemId);
        });
      }
    }
  }

  Future<void> _deleteSystem(String systemId) async {
    if (_deletingSystemIds.contains(systemId)) {
      return;
    }

    setState(() {
      _deletingSystemIds.add(systemId);
    });

    try {
      await widget.workspaceController.deleteSavedSystem(systemId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final detail = PocketErrorDetailFormatter.normalize(error);
      _showTransientMessage(
        detail == null || detail.isEmpty
            ? 'Could not delete system.'
            : 'Could not delete system. $detail',
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingSystemIds.remove(systemId);
        });
      }
    }
  }

  Future<ConnectionSettingsSubmitPayload?> _openSystemSettings({
    SavedSystem? system,
  }) {
    final initialProfile = connectionProfileFromWorkspace(
      workspace: WorkspaceProfile(
        label: 'Workspace',
        connectionMode: ConnectionMode.remote,
        systemId: null,
        workspaceDir: '',
        codexPath: 'codex',
        dangerouslyBypassSandbox: false,
        ephemeralSession: false,
      ),
      system: system,
    );
    final initialSecrets = system?.secrets ?? const ConnectionSecrets();

    if (widget.platformBehavior.isDesktopExperience) {
      return showDialog<ConnectionSettingsSubmitPayload>(
        context: context,
        builder: (dialogContext) {
          return ConnectionSettingsHost(
            initialProfile: initialProfile,
            initialSecrets: initialSecrets,
            isSystemSettings: true,
            platformBehavior: widget.platformBehavior,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSubmit: (payload) => Navigator.of(dialogContext).pop(payload),
            onTestSystem: (profile, secrets) {
              return testConnectionSettingsRemoteSystem(
                profile: profile,
                secrets: secrets,
              );
            },
            builder: (context, viewModel, actions) {
              return ConnectionSheet(
                platformBehavior: widget.platformBehavior,
                viewModel: viewModel,
                actions: actions,
                surfaceMode: ConnectionSettingsSurfaceMode.system,
              );
            },
          );
        },
      );
    }

    return showModalBottomSheet<ConnectionSettingsSubmitPayload>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ConnectionSettingsHost(
          initialProfile: initialProfile,
          initialSecrets: initialSecrets,
          isSystemSettings: true,
          platformBehavior: widget.platformBehavior,
          onCancel: () => Navigator.of(sheetContext).pop(),
          onSubmit: (payload) => Navigator.of(sheetContext).pop(payload),
          onTestSystem: (profile, secrets) {
            return testConnectionSettingsRemoteSystem(
              profile: profile,
              secrets: secrets,
            );
          },
          builder: (context, viewModel, actions) {
            return ConnectionSheet(
              platformBehavior: widget.platformBehavior,
              viewModel: viewModel,
              actions: actions,
              surfaceMode: ConnectionSettingsSurfaceMode.system,
            );
          },
        );
      },
    );
  }

  void _showTransientMessage(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SavedSystemsEmptyState extends StatelessWidget {
  const _SavedSystemsEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return PocketPanelSurface(
      backgroundColor: palette.surface.withValues(alpha: 0.86),
      borderColor: palette.surfaceBorder,
      padding: const EdgeInsets.all(PocketSpacing.xxl),
      radius: _savedSystemsPanelRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: palette.shadowColor,
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConnectionWorkspaceCopy.emptySystemsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PocketSpacing.xs),
          Text(
            ConnectionWorkspaceCopy.emptySystemsMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
