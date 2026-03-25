import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_local_process.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_stdio_transport.dart';

Future<CodexAppServerTransport> openCodexAppServerTransport({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  CodexAppServerProcessLauncher localLauncher = openLocalCodexAppServerProcess,
}) async {
  final process = await openCodexAppServerProcess(
    profile: profile,
    secrets: secrets,
    emitEvent: emitEvent,
    localLauncher: localLauncher,
  );
  return CodexAppServerStdioTransport(process);
}

Future<CodexAppServerProcess> openCodexAppServerProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  CodexAppServerProcessLauncher localLauncher = openLocalCodexAppServerProcess,
}) {
  if (profile.connectionMode == ConnectionMode.remote) {
    throw const CodexAppServerException(
      'Remote app-server connections require the managed-owner websocket transport path.',
    );
  }
  return localLauncher(
    profile: profile,
    secrets: secrets,
    emitEvent: emitEvent,
  );
}
