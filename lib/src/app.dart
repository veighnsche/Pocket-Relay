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
  late final CodexProfileStore _profileStore;
  SavedProfile? _savedProfile;

  @override
  void initState() {
    super.initState();
    _profileStore = widget.profileStore ?? SecureCodexProfileStore();
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final savedProfile = await _profileStore.load();
    if (!mounted) {
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
              appServerClient: widget.appServerClient ?? CodexAppServerClient(),
              initialSavedProfile: savedProfile,
            ),
    );
  }
}
