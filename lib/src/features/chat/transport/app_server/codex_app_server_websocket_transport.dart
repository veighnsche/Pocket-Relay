import 'dart:async';
import 'dart:io';

import 'codex_app_server_models.dart';

Future<CodexAppServerTransport> openCodexAppServerWebSocketTransport({
  required Uri uri,
  Duration connectTimeout = const Duration(seconds: 10),
  HttpClient? customHttpClient,
}) async {
  final socket = await WebSocket.connect(
    uri.toString(),
    customClient: customHttpClient,
  ).timeout(connectTimeout);
  return CodexAppServerWebSocketTransport(socket);
}

class CodexAppServerWebSocketTransport implements CodexAppServerTransport {
  CodexAppServerWebSocketTransport(this._socket) {
    _subscription = _socket.listen(
      (message) {
        if (_protocolMessagesController.isClosed ||
            _diagnosticsController.isClosed) {
          return;
        }

        if (message is String) {
          _protocolMessagesController.add(message);
          return;
        }

        _diagnosticsController.add(
          'Unexpected non-text websocket frame from app-server.',
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_diagnosticsController.isClosed) {
          _diagnosticsController.add(
            'Failed to read app-server websocket messages: $error',
          );
        }
      },
      onDone: () {
        if (!_protocolMessagesController.isClosed) {
          _protocolMessagesController.close();
        }
        if (!_diagnosticsController.isClosed) {
          _diagnosticsController.close();
        }
      },
    );
  }

  final WebSocket _socket;
  final StreamController<String> _protocolMessagesController =
      StreamController<String>.broadcast();
  final StreamController<String> _diagnosticsController =
      StreamController<String>.broadcast();
  StreamSubscription<Object?>? _subscription;
  bool _isClosing = false;

  @override
  Stream<String> get protocolMessages => _protocolMessagesController.stream;

  @override
  Stream<String> get diagnostics => _diagnosticsController.stream;

  @override
  void sendLine(String line) {
    _socket.add(line);
  }

  @override
  Future<void> get done => _socket.done;

  @override
  CodexAppServerTransportTermination? get termination {
    final closeCode = _socket.closeCode;
    final closeReason = _socket.closeReason;
    if (closeCode == null && (closeReason == null || closeReason.isEmpty)) {
      return null;
    }

    final reasonBuffer = StringBuffer();
    if (closeCode != null) {
      reasonBuffer.write('websocket close $closeCode');
    }
    if (closeReason != null && closeReason.isNotEmpty) {
      if (reasonBuffer.isNotEmpty) {
        reasonBuffer.write(': ');
      }
      reasonBuffer.write(closeReason);
    }

    return CodexAppServerTransportTermination(
      reason: reasonBuffer.isEmpty ? null : reasonBuffer.toString(),
    );
  }

  @override
  Future<void> close() async {
    if (_isClosing) {
      await done;
      return;
    }
    _isClosing = true;

    try {
      await _socket.close();
      await done;
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      if (!_protocolMessagesController.isClosed) {
        await _protocolMessagesController.close();
      }
      if (!_diagnosticsController.isClosed) {
        await _diagnosticsController.close();
      }
    }
  }
}
