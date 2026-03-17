import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_local_process.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_ssh_process.dart';

Future<CodexAppServerProcess> openCodexAppServerProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  CodexAppServerProcessLauncher remoteLauncher = openSshCodexAppServerProcess,
  CodexAppServerProcessLauncher localLauncher = openLocalCodexAppServerProcess,
}) {
  return switch (profile.connectionMode) {
    ConnectionMode.remote => remoteLauncher(
      profile: profile,
      secrets: secrets,
      emitEvent: emitEvent,
    ),
    ConnectionMode.local => localLauncher(
      profile: profile,
      secrets: secrets,
      emitEvent: emitEvent,
    ),
  };
}
