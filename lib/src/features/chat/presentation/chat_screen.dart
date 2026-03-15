import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.profileStore,
    required this.appServerClient,
    this.initialSavedProfile,
  });

  final CodexProfileStore profileStore;
  final CodexAppServerClient appServerClient;
  final SavedProfile? initialSavedProfile;

  @override
  Widget build(BuildContext context) {
    return ChatRootAdapter(
      profileStore: profileStore,
      appServerClient: appServerClient,
      initialSavedProfile: initialSavedProfile,
    );
  }
}
