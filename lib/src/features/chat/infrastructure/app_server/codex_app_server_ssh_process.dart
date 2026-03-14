import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';

import 'codex_app_server_models.dart';

Future<CodexAppServerProcess> openSshCodexAppServerProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
}) async {
  final socket = await SSHSocket.connect(
    profile.host.trim(),
    profile.port,
    timeout: const Duration(seconds: 10),
  );

  final client = SSHClient(
    socket,
    username: profile.username.trim(),
    onVerifyHostKey: (type, fingerprint) {
      final actual = formatFingerprint(fingerprint);
      final expected = profile.hostFingerprint.trim();

      if (expected.isEmpty) {
        emitEvent(
          CodexAppServerDiagnosticEvent(
            message:
                'Accepted $type host key fingerprint $actual. Pin it later if you want stricter verification.',
            isError: false,
          ),
        );
        return true;
      }

      if (normalizeFingerprint(expected) == normalizeFingerprint(actual)) {
        return true;
      }

      emitEvent(
        CodexAppServerDiagnosticEvent(
          message:
              'Host key mismatch. Expected ${profile.hostFingerprint}, got $actual.',
          isError: true,
        ),
      );
      return false;
    },
    identities: _buildIdentities(profile, secrets),
    onPasswordRequest: profile.authMode == AuthMode.password
        ? () => secrets.password.trim().isEmpty ? null : secrets.password
        : null,
  );

  await client.authenticated;
  emitEvent(
    CodexAppServerDiagnosticEvent(
      message:
          'Connected to ${profile.host}:${profile.port} as ${profile.username}.',
      isError: false,
    ),
  );

  final session = await client.execute(_buildRemoteCommand(profile: profile));
  return _SshCodexAppServerProcess(client: client, session: session);
}

List<SSHKeyPair>? _buildIdentities(
  ConnectionProfile profile,
  ConnectionSecrets secrets,
) {
  if (profile.authMode != AuthMode.privateKey) {
    return null;
  }

  final privateKey = secrets.privateKeyPem.trim();
  if (privateKey.isEmpty) {
    throw StateError('A private key is required for key-based SSH auth.');
  }

  final passphrase = secrets.privateKeyPassphrase.trim();
  return SSHKeyPair.fromPem(privateKey, passphrase.isEmpty ? null : passphrase);
}

String _buildRemoteCommand({required ConnectionProfile profile}) {
  final codexArgs = <String>[
    profile.codexPath.trim(),
    'app-server',
    '--listen',
    'stdio://',
  ];
  final codexCommand = codexArgs.map(shellEscape).join(' ');
  final command =
      'cd ${shellEscape(profile.workspaceDir.trim())} && $codexCommand';
  return 'bash -lc ${shellEscape(command)}';
}

class _SshCodexAppServerProcess implements CodexAppServerProcess {
  _SshCodexAppServerProcess({required this.client, required this.session});

  final SSHClient client;
  final SSHSession session;

  @override
  Stream<Uint8List> get stdout => session.stdout;

  @override
  Stream<Uint8List> get stderr => session.stderr;

  @override
  StreamSink<Uint8List> get stdin => session.stdin;

  @override
  Future<void> get done => session.done;

  @override
  int? get exitCode => session.exitCode;

  @override
  Future<void> close() async {
    try {
      session.close();
    } catch (_) {
      // Ignore close errors when the remote process has already ended.
    }
    client.close();
  }
}
