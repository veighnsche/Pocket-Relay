import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_models.dart';
import 'codex_app_server_ssh_process.dart';
import 'codex_app_server_websocket_transport.dart';

Future<CodexAppServerTransport> openSshForwardedCodexAppServerWebSocketTransport({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String remoteHost,
  required int remotePort,
  required void Function(CodexAppServerEvent event) emitEvent,
  @visibleForTesting
  CodexSshProcessBootstrap sshBootstrap = connectSshBootstrapClient,
  Duration connectTimeout = const Duration(seconds: 10),
}) async {
  final client = await connectAuthenticatedSshBootstrapClient(
    profile: profile,
    secrets: secrets,
    emitEvent: emitEvent,
    sshBootstrap: sshBootstrap,
  );
  CodexSshLocalPortForward? portForward;

  try {
    portForward = await openCodexSshLocalPortForward(
      profile: profile,
      client: client,
      remoteHost: remoteHost,
      remotePort: remotePort,
      emitEvent: emitEvent,
    );
    final websocketTransport = await openCodexAppServerWebSocketTransport(
      uri: portForward.websocketUri,
      connectTimeout: connectTimeout,
    );
    return _CodexAppServerSshForwardedWebSocketTransport(
      websocketTransport: websocketTransport,
      portForward: portForward,
    );
  } catch (_) {
    if (portForward != null) {
      await portForward.close();
    } else {
      client.close();
    }
    rethrow;
  }
}

Future<CodexSshLocalPortForward> openCodexSshLocalPortForward({
  required ConnectionProfile profile,
  required CodexSshBootstrapClient client,
  required String remoteHost,
  required int remotePort,
  required void Function(CodexAppServerEvent event) emitEvent,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final forward = CodexSshLocalPortForward._(
    profile: profile,
    client: client,
    remoteHost: remoteHost,
    remotePort: remotePort,
    server: server,
    emitEvent: emitEvent,
  );
  emitEvent(
    CodexAppServerSshPortForwardStartedEvent(
      host: profile.host.trim(),
      port: profile.port,
      username: profile.username.trim(),
      remoteHost: remoteHost,
      remotePort: remotePort,
      localPort: server.port,
    ),
  );
  return forward;
}

class CodexSshLocalPortForward {
  CodexSshLocalPortForward._({
    required ConnectionProfile profile,
    required CodexSshBootstrapClient client,
    required String remoteHost,
    required int remotePort,
    required ServerSocket server,
    required void Function(CodexAppServerEvent event) emitEvent,
  }) : _profile = profile,
       _client = client,
       _remoteHost = remoteHost,
       _remotePort = remotePort,
       _server = server,
       _emitEvent = emitEvent {
    _serverSubscription = _server.listen(_handleLocalConnection);
  }

  final ConnectionProfile _profile;
  final CodexSshBootstrapClient _client;
  final String _remoteHost;
  final int _remotePort;
  final ServerSocket _server;
  final void Function(CodexAppServerEvent event) _emitEvent;
  final Set<_CodexSshForwardBridge> _bridges = <_CodexSshForwardBridge>{};
  StreamSubscription<Socket>? _serverSubscription;
  bool _isClosed = false;

  Uri get websocketUri => Uri(
    scheme: 'ws',
    host: _server.address.address,
    port: _server.port,
  );

  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;

    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server.close();
    await Future.wait(<Future<void>>[
      for (final bridge in _bridges.toList(growable: false)) bridge.close(),
    ]);
    _bridges.clear();
    _client.close();
  }

  Future<void> _handleLocalConnection(Socket localSocket) async {
    if (_isClosed) {
      await localSocket.close();
      return;
    }

    try {
      final remoteChannel = await _client.forwardLocal(
        _remoteHost,
        _remotePort,
        localHost: localSocket.address.address,
        localPort: localSocket.port,
      );
      late final _CodexSshForwardBridge bridge;
      bridge = _CodexSshForwardBridge(
        localSocket: localSocket,
        remoteChannel: remoteChannel,
        onClosed: () {
          _bridges.removeWhere((candidate) => identical(candidate, bridge));
        },
      );
      _bridges.add(bridge);
    } catch (error) {
      _emitEvent(
        CodexAppServerSshPortForwardFailedEvent(
          host: _profile.host.trim(),
          port: _profile.port,
          username: _profile.username.trim(),
          remoteHost: _remoteHost,
          remotePort: _remotePort,
          message: '$error',
          detail: error,
        ),
      );
      localSocket.destroy();
    }
  }
}

final class _CodexSshForwardBridge {
  _CodexSshForwardBridge({
    required Socket localSocket,
    required CodexSshForwardChannel remoteChannel,
    required VoidCallback onClosed,
  }) : _localSocket = localSocket,
       _remoteChannel = remoteChannel,
       _onClosed = onClosed {
    _localSubscription = _localSocket.listen(
      _remoteChannel.sink.add,
      onError: (_, __) => _closeImmediately(),
      onDone: close,
      cancelOnError: true,
    );
    _remoteSubscription = _remoteChannel.stream.listen(
      _localSocket.add,
      onError: (_, __) => _closeImmediately(),
      onDone: close,
      cancelOnError: true,
    );
  }

  final Socket _localSocket;
  final CodexSshForwardChannel _remoteChannel;
  final VoidCallback _onClosed;
  StreamSubscription<Uint8List>? _remoteSubscription;
  StreamSubscription<Uint8List>? _localSubscription;
  bool _isClosed = false;

  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;

    await _localSubscription?.cancel();
    await _remoteSubscription?.cancel();
    _localSubscription = null;
    _remoteSubscription = null;

    try {
      await _localSocket.close();
    } catch (_) {
      _localSocket.destroy();
    }
    try {
      await _remoteChannel.close();
    } catch (_) {
      _remoteChannel.destroy();
    }

    _onClosed();
  }

  void _closeImmediately() {
    unawaited(close());
  }
}

final class _CodexAppServerSshForwardedWebSocketTransport
    implements CodexAppServerTransport {
  _CodexAppServerSshForwardedWebSocketTransport({
    required CodexAppServerTransport websocketTransport,
    required CodexSshLocalPortForward portForward,
  }) : _websocketTransport = websocketTransport,
       _portForward = portForward;

  final CodexAppServerTransport _websocketTransport;
  final CodexSshLocalPortForward _portForward;

  @override
  Stream<String> get protocolMessages => _websocketTransport.protocolMessages;

  @override
  Stream<String> get diagnostics => _websocketTransport.diagnostics;

  @override
  void sendLine(String line) => _websocketTransport.sendLine(line);

  @override
  Future<void> get done => _websocketTransport.done;

  @override
  CodexAppServerTransportTermination? get termination =>
      _websocketTransport.termination;

  @override
  Future<void> close() async {
    try {
      await _websocketTransport.close();
    } finally {
      await _portForward.close();
    }
  }
}
