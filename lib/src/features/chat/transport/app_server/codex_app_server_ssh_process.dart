import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';

import 'codex_app_server_models.dart';

Future<CodexSshBootstrapClient> connectAuthenticatedSshBootstrapClient({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  CodexSshProcessBootstrap sshBootstrap = connectSshBootstrapClient,
}) async {
  final host = profile.host.trim();
  final username = profile.username.trim();
  var emittedHostKeyMismatch = false;
  var emittedUnpinnedHostKey = false;

  bool verifyHostKey(String keyType, String actualFingerprint) {
    final expectedFingerprint = profile.hostFingerprint.trim();

    if (expectedFingerprint.isEmpty) {
      emittedUnpinnedHostKey = true;
      emitEvent(
        CodexAppServerUnpinnedHostKeyEvent(
          host: host,
          port: profile.port,
          keyType: keyType,
          fingerprint: actualFingerprint,
        ),
      );
      return false;
    }

    if (normalizeFingerprint(expectedFingerprint) ==
        normalizeFingerprint(actualFingerprint)) {
      return true;
    }

    emittedHostKeyMismatch = true;
    emitEvent(
      CodexAppServerSshHostKeyMismatchEvent(
        host: host,
        port: profile.port,
        keyType: keyType,
        expectedFingerprint: expectedFingerprint,
        actualFingerprint: actualFingerprint,
      ),
    );
    return false;
  }

  CodexSshBootstrapClient client;
  try {
    client = await sshBootstrap(
      profile: profile,
      secrets: secrets,
      verifyHostKey: verifyHostKey,
    );
  } catch (error) {
    if (!_shouldSuppressHostKeyFailure(
      error,
      emittedHostKeyMismatch: emittedHostKeyMismatch,
      emittedUnpinnedHostKey: emittedUnpinnedHostKey,
    )) {
      emitEvent(
        CodexAppServerSshConnectFailedEvent(
          host: host,
          port: profile.port,
          message: _sshErrorMessage(error),
          detail: error,
        ),
      );
    }
    rethrow;
  }

  try {
    await client.authenticate();
  } catch (error) {
    client.close();
    if (_shouldSuppressHostKeyFailure(
      error,
      emittedHostKeyMismatch: emittedHostKeyMismatch,
      emittedUnpinnedHostKey: emittedUnpinnedHostKey,
    )) {
      rethrow;
    }
    if (error is SSHAuthFailError || error is SSHAuthAbortError) {
      emitEvent(
        CodexAppServerSshAuthenticationFailedEvent(
          host: host,
          port: profile.port,
          username: username,
          authMode: profile.authMode,
          message: _sshErrorMessage(error),
          detail: error,
        ),
      );
    } else if (error is SSHHandshakeError || error is SSHSocketError) {
      emitEvent(
        CodexAppServerSshConnectFailedEvent(
          host: host,
          port: profile.port,
          message: _sshErrorMessage(error),
          detail: error,
        ),
      );
    }
    rethrow;
  }

  emitEvent(
    CodexAppServerSshAuthenticatedEvent(
      host: host,
      port: profile.port,
      username: username,
      authMode: profile.authMode,
    ),
  );
  return client;
}

bool _shouldSuppressHostKeyFailure(
  Object error, {
  required bool emittedHostKeyMismatch,
  required bool emittedUnpinnedHostKey,
}) {
  return (emittedHostKeyMismatch || emittedUnpinnedHostKey) &&
      error is SSHHostkeyError;
}

String _sshErrorMessage(Object error) {
  return switch (error) {
    SSHAuthFailError(:final message) ||
    SSHAuthAbortError(:final message) ||
    SSHHandshakeError(:final message) ||
    SSHChannelRequestError(:final message) ||
    SSHHostkeyError(:final message) => message,
    SSHChannelOpenError(:final description) => description,
    SSHSocketError(:final error) => '$error',
    _ => '$error',
  };
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

Future<CodexSshBootstrapClient> connectSshBootstrapClient({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required bool Function(String keyType, String actualFingerprint)
  verifyHostKey,
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
      return verifyHostKey(type, formatFingerprint(fingerprint));
    },
    identities: _buildIdentities(profile, secrets),
    onPasswordRequest: profile.authMode == AuthMode.password
        ? () => secrets.password.trim().isEmpty ? null : secrets.password
        : null,
  );
  return _DartSshBootstrapClient(client);
}

final class _DartSshBootstrapClient implements CodexSshBootstrapClient {
  _DartSshBootstrapClient(this._client);

  final SSHClient _client;

  @override
  Future<void> authenticate() => _client.authenticated;

  @override
  Future<CodexAppServerProcess> launchProcess(String command) async {
    final session = await _client.execute(command);
    return _SshCodexAppServerProcess(client: _client, session: session);
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) async {
    final channel = await _client.forwardLocal(
      remoteHost,
      remotePort,
      localHost: localHost,
      localPort: localPort,
    );
    return _DartSshForwardChannel(channel);
  }

  @override
  void close() {
    _client.close();
  }
}

final class _DartSshForwardChannel implements CodexSshForwardChannel {
  _DartSshForwardChannel(this._channel);

  final SSHForwardChannel _channel;

  @override
  Stream<Uint8List> get stream => _channel.stream;

  @override
  StreamSink<List<int>> get sink => _channel.sink;

  @override
  Future<void> get done => _channel.done;

  @override
  Future<void> close() => _channel.close();

  @override
  void destroy() {
    _channel.destroy();
  }
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
