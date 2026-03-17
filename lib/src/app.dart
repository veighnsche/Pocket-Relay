import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';

class PocketRelayApp extends StatefulWidget {
  const PocketRelayApp({
    super.key,
    this.profileStore,
    this.conversationHandoffStore,
    this.appServerClient,
    this.displayWakeLockController,
  });

  final CodexProfileStore? profileStore;
  final CodexConversationHandoffStore? conversationHandoffStore;
  final CodexAppServerClient? appServerClient;
  final DisplayWakeLockController? displayWakeLockController;

  @override
  State<PocketRelayApp> createState() => _PocketRelayAppState();
}

class _PocketRelayAppState extends State<PocketRelayApp> {
  CodexProfileStore? _ownedProfileStore;
  CodexConversationHandoffStore? _ownedConversationHandoffStore;
  CodexAppServerClient? _ownedAppServerClient;
  late CodexProfileStore _profileStore;
  late CodexConversationHandoffStore _conversationHandoffStore;
  late CodexAppServerClient _appServerClient;
  SavedProfile? _savedProfile;
  SavedConversationHandoff? _savedConversationHandoff;
  int _bootstrapLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindDependencies();
    _loadBootstrapState();
  }

  @override
  void didUpdateWidget(covariant PocketRelayApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileStore == widget.profileStore &&
        oldWidget.conversationHandoffStore == widget.conversationHandoffStore &&
        oldWidget.appServerClient == widget.appServerClient) {
      return;
    }

    _bindDependencies();
    if (oldWidget.profileStore == widget.profileStore &&
        oldWidget.conversationHandoffStore == widget.conversationHandoffStore) {
      return;
    }

    setState(() {
      _savedProfile = null;
      _savedConversationHandoff = null;
    });
    _loadBootstrapState();
  }

  @override
  void dispose() {
    final ownedClient = _ownedAppServerClient;
    if (ownedClient != null) {
      unawaited(ownedClient.dispose());
    }
    super.dispose();
  }

  void _bindDependencies() {
    _profileStore =
        widget.profileStore ??
        (_ownedProfileStore ??= SecureCodexProfileStore());
    _conversationHandoffStore =
        widget.conversationHandoffStore ??
        (_ownedConversationHandoffStore ??=
            SecureCodexConversationHandoffStore());

    if (widget.appServerClient case final injectedClient?) {
      final ownedClient = _ownedAppServerClient;
      _ownedAppServerClient = null;
      if (ownedClient != null) {
        unawaited(ownedClient.dispose());
      }
      _appServerClient = injectedClient;
      return;
    }

    _appServerClient = _ownedAppServerClient ??= CodexAppServerClient();
  }

  Future<void> _loadBootstrapState() async {
    final loadGeneration = ++_bootstrapLoadGeneration;
    final profileStore = _profileStore;
    final conversationHandoffStore = _conversationHandoffStore;
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      profileStore.load(),
      conversationHandoffStore.load(),
    ]);
    if (!mounted ||
        loadGeneration != _bootstrapLoadGeneration ||
        profileStore != _profileStore ||
        conversationHandoffStore != _conversationHandoffStore) {
      return;
    }

    setState(() {
      _savedProfile = results[0] as SavedProfile;
      _savedConversationHandoff = results[1] as SavedConversationHandoff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedProfile = _savedProfile;
    final savedConversationHandoff = _savedConversationHandoff;
    const platformPolicy = ChatRootPlatformPolicy.cupertinoFoundation();

    return MaterialApp(
      title: 'Pocket Relay',
      debugShowCheckedModeBanner: false,
      theme: buildPocketTheme(Brightness.light),
      darkTheme: buildPocketTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: DisplayWakeLockHost(
        displayWakeLockController:
            widget.displayWakeLockController ??
            const WakelockPlusDisplayWakeLockController(),
        child: _PocketRelayHome(
          savedProfile: savedProfile,
          savedConversationHandoff: savedConversationHandoff,
          profileStore: _profileStore,
          conversationHandoffStore: _conversationHandoffStore,
          appServerClient: _appServerClient,
          platformPolicy: platformPolicy,
        ),
      ),
    );
  }
}

class _PocketRelayHome extends StatelessWidget {
  const _PocketRelayHome({
    required this.savedProfile,
    required this.savedConversationHandoff,
    required this.profileStore,
    required this.conversationHandoffStore,
    required this.appServerClient,
    required this.platformPolicy,
  });

  final SavedProfile? savedProfile;
  final SavedConversationHandoff? savedConversationHandoff;
  final CodexProfileStore profileStore;
  final CodexConversationHandoffStore conversationHandoffStore;
  final CodexAppServerClient appServerClient;
  final ChatRootPlatformPolicy platformPolicy;

  @override
  Widget build(BuildContext context) {
    final resolvedProfile = savedProfile;
    final resolvedConversationHandoff = savedConversationHandoff;
    if (resolvedProfile != null && resolvedConversationHandoff != null) {
      return ChatRootAdapter(
        profileStore: profileStore,
        conversationHandoffStore: conversationHandoffStore,
        appServerClient: appServerClient,
        initialSavedProfile: resolvedProfile,
        initialSavedConversationHandoff: resolvedConversationHandoff,
        platformPolicy: platformPolicy,
      );
    }

    final screenShell = platformPolicy
        .policyFor(Theme.of(context).platform)
        .screenShell;

    return _PocketRelayBootstrapShell(screenShell: screenShell);
  }
}

class _PocketRelayBootstrapShell extends StatelessWidget {
  const _PocketRelayBootstrapShell({required this.screenShell});

  final ChatRootScreenShellRenderer screenShell;

  @override
  Widget build(BuildContext context) {
    return switch (screenShell) {
      ChatRootScreenShellRenderer.flutter => const _FlutterBootstrapShell(),
      ChatRootScreenShellRenderer.cupertino => const _CupertinoBootstrapShell(),
    };
  }
}

class _FlutterBootstrapShell extends StatelessWidget {
  const _FlutterBootstrapShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _BootstrapBackground(
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CupertinoBootstrapShell extends StatelessWidget {
  const _CupertinoBootstrapShell();

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return CupertinoTheme(
      data: buildPocketCupertinoTheme(Theme.of(context)),
      child: CupertinoPageScaffold(
        backgroundColor: palette.backgroundTop,
        child: const _BootstrapBackground(
          child: Center(child: CupertinoActivityIndicator()),
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
