import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';

class PocketRelayApp extends StatefulWidget {
  const PocketRelayApp({super.key, this.profileStore, this.appServerClient});

  final CodexProfileStore? profileStore;
  final CodexAppServerClient? appServerClient;

  @override
  State<PocketRelayApp> createState() => _PocketRelayAppState();
}

class _PocketRelayAppState extends State<PocketRelayApp> {
  CodexProfileStore? _ownedProfileStore;
  CodexAppServerClient? _ownedAppServerClient;
  late CodexProfileStore _profileStore;
  late CodexAppServerClient _appServerClient;
  SavedProfile? _savedProfile;
  int _profileLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindDependencies();
    _loadSavedProfile();
  }

  @override
  void didUpdateWidget(covariant PocketRelayApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileStore == widget.profileStore &&
        oldWidget.appServerClient == widget.appServerClient) {
      return;
    }

    _bindDependencies();
    if (oldWidget.profileStore == widget.profileStore) {
      return;
    }

    setState(() {
      _savedProfile = null;
    });
    _loadSavedProfile();
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

  Future<void> _loadSavedProfile() async {
    final loadGeneration = ++_profileLoadGeneration;
    final profileStore = _profileStore;
    final savedProfile = await profileStore.load();
    if (!mounted ||
        loadGeneration != _profileLoadGeneration ||
        profileStore != _profileStore) {
      return;
    }

    setState(() {
      _savedProfile = savedProfile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedProfile = _savedProfile;
    const platformPolicy = ChatRootPlatformPolicy.cupertinoFoundation();

    return MaterialApp(
      title: 'Pocket Relay',
      debugShowCheckedModeBanner: false,
      theme: buildPocketTheme(Brightness.light),
      darkTheme: buildPocketTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: _PocketRelayHome(
        savedProfile: savedProfile,
        profileStore: _profileStore,
        appServerClient: _appServerClient,
        platformPolicy: platformPolicy,
      ),
    );
  }
}

class _PocketRelayHome extends StatelessWidget {
  const _PocketRelayHome({
    required this.savedProfile,
    required this.profileStore,
    required this.appServerClient,
    required this.platformPolicy,
  });

  final SavedProfile? savedProfile;
  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;
  final ChatRootPlatformPolicy platformPolicy;

  @override
  Widget build(BuildContext context) {
    if (savedProfile case final resolvedProfile?) {
      return ChatRootAdapter(
        profileStore: profileStore,
        appServerClient: appServerClient,
        initialSavedProfile: resolvedProfile,
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
