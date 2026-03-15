import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

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

    return MaterialApp(
      title: 'Pocket Relay',
      debugShowCheckedModeBanner: false,
      theme: buildPocketTheme(Brightness.light),
      darkTheme: buildPocketTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: savedProfile == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : ChatScreen(
              profileStore: _profileStore,
              appServerClient: _appServerClient,
              initialSavedProfile: savedProfile,
            ),
    );
  }
}
