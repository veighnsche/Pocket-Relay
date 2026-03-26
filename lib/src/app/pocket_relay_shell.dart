import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_mobile_shell.dart';

class PocketRelayShell extends StatelessWidget {
  const PocketRelayShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    required this.conversationHistoryRepository,
    required this.settingsOverlayDelegate,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final CodexWorkspaceConversationHistoryRepository?
  conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: workspaceController,
      builder: (context, _) {
        final workspaceState = workspaceController.state;
        if (workspaceState.isLoading) {
          return const PocketRelayBootstrapShell();
        }

        if (platformPolicy.behavior.isMobileExperience) {
          return ConnectionWorkspaceMobileShell(
            workspaceController: workspaceController,
            platformPolicy: platformPolicy,
            conversationHistoryRepository: conversationHistoryRepository,
            settingsOverlayDelegate: settingsOverlayDelegate,
          );
        }

        if (platformPolicy.behavior.isDesktopExperience) {
          return ConnectionWorkspaceDesktopShell(
            workspaceController: workspaceController,
            platformPolicy: platformPolicy,
            conversationHistoryRepository: conversationHistoryRepository,
            settingsOverlayDelegate: settingsOverlayDelegate,
          );
        }

        final selectedLaneBinding = workspaceController.selectedLaneBinding;
        if (selectedLaneBinding != null) {
          return ConnectionWorkspaceLiveLaneSurface(
            workspaceController: workspaceController,
            laneBinding: selectedLaneBinding,
            platformPolicy: platformPolicy,
            conversationHistoryRepository: conversationHistoryRepository,
            settingsOverlayDelegate: settingsOverlayDelegate,
          );
        }

        return const PocketRelayBootstrapShell();
      },
    );
  }
}

class PocketRelayBootstrapShell extends StatelessWidget {
  const PocketRelayBootstrapShell({
    super.key,
    this.message = 'Loading saved connections and workspace state.',
    this.isLoading = true,
    this.action,
  });

  final String message;
  final bool isLoading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _BootstrapBackground(
        child: _BootstrapSplash(
          message: message,
          progressIndicator: isLoading
              ? const CircularProgressIndicator(strokeWidth: 2.8)
              : null,
          action: action,
        ),
      ),
    );
  }
}

class _BootstrapBackground extends StatelessWidget {
  const _BootstrapBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
        ),
      ),
      child: child,
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash({
    required this.message,
    this.progressIndicator,
    this.action,
  });

  final String message;
  final Widget? progressIndicator;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final titleStyle = materialTheme.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.8,
    );
    final bodyStyle = materialTheme.textTheme.bodyLarge?.copyWith(
      height: 1.45,
      color: materialTheme.colorScheme.onSurface.withValues(alpha: 0.68),
    );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(38),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.07),
                        Colors.black.withValues(alpha: 0.22),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 36,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Image.asset(
                      'assets/icons/app_icon_master.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Pocket Relay',
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: bodyStyle,
                ),
                if (progressIndicator != null) ...[
                  const SizedBox(height: 26),
                  progressIndicator!,
                ],
                if (action != null) ...[const SizedBox(height: 22), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
