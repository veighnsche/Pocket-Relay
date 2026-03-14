import 'dart:async';
import 'dart:convert';

sealed class CodexJsonRpcMessage {
  const CodexJsonRpcMessage();

  Map<String, Object?> toJson();
}

class CodexJsonRpcId {
  const CodexJsonRpcId(this.value);

  final Object value;

  factory CodexJsonRpcId.fromRaw(Object? rawValue) {
    if (rawValue is int) {
      return CodexJsonRpcId(rawValue);
    }

    if (rawValue is String) {
      return CodexJsonRpcId(rawValue);
    }

    if (rawValue is num && rawValue.isFinite && rawValue == rawValue.toInt()) {
      return CodexJsonRpcId(rawValue.toInt());
    }

    throw const FormatException(
      'JSON-RPC id must be a string or integer value.',
    );
  }

  String get token => switch (value) {
    int rawValue => 'i:$rawValue',
    String rawValue => 's:$rawValue',
    _ => 'o:$value',
  };

  String get displayValue => value.toString();
}

class CodexJsonRpcNotification extends CodexJsonRpcMessage {
  const CodexJsonRpcNotification({required this.method, this.params});

  final String method;
  final Object? params;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'method': method,
      if (params != null) 'params': params,
    };
  }
}

class CodexJsonRpcRequest extends CodexJsonRpcMessage {
  const CodexJsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
  });

  final CodexJsonRpcId id;
  final String method;
  final Object? params;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id.value,
      'method': method,
      if (params != null) 'params': params,
    };
  }
}

class CodexJsonRpcError {
  const CodexJsonRpcError({required this.message, this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (code != null) 'code': code,
      'message': message,
      if (data != null) 'data': data,
    };
  }
}

class CodexJsonRpcResponse extends CodexJsonRpcMessage {
  const CodexJsonRpcResponse._({
    required this.id,
    this.result,
    this.error,
    required this.isError,
  });

  factory CodexJsonRpcResponse.success({
    required CodexJsonRpcId id,
    Object? result,
  }) {
    return CodexJsonRpcResponse._(id: id, result: result, isError: false);
  }

  factory CodexJsonRpcResponse.failure({
    required CodexJsonRpcId id,
    required CodexJsonRpcError error,
  }) {
    return CodexJsonRpcResponse._(id: id, error: error, isError: true);
  }

  final CodexJsonRpcId id;
  final Object? result;
  final CodexJsonRpcError? error;
  final bool isError;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id.value,
      if (isError) 'error': error?.toJson() else 'result': result,
    };
  }
}

class CodexJsonRpcRemoteException implements Exception {
  const CodexJsonRpcRemoteException(this.error);

  final CodexJsonRpcError error;

  @override
  String toString() {
    if (error.code == null) {
      return 'CodexJsonRpcRemoteException: ${error.message}';
    }
    return 'CodexJsonRpcRemoteException(${error.code}): ${error.message}';
  }
}

sealed class CodexJsonRpcDecodeResult {
  const CodexJsonRpcDecodeResult();
}

class CodexJsonRpcDecodedMessage extends CodexJsonRpcDecodeResult {
  const CodexJsonRpcDecodedMessage(this.message);

  final CodexJsonRpcMessage message;
}

class CodexJsonRpcMalformedMessage extends CodexJsonRpcDecodeResult {
  const CodexJsonRpcMalformedMessage({
    required this.line,
    required this.problem,
  });

  final String line;
  final String problem;
}

class CodexJsonRpcCodec {
  const CodexJsonRpcCodec();

  String encodeLine(CodexJsonRpcMessage message) {
    return '${jsonEncode(message.toJson())}\n';
  }

  CodexJsonRpcDecodeResult decodeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return const CodexJsonRpcMalformedMessage(
        line: '',
        problem: 'Message line was empty.',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return CodexJsonRpcMalformedMessage(
          line: trimmed,
          problem: 'Message was not a JSON object.',
        );
      }

      final object = Map<String, Object?>.from(decoded);
      final method = object['method'];
      final hasId = object.containsKey('id');
      final hasResult = object.containsKey('result');
      final hasError = object.containsKey('error');

      if (method is String) {
        if (hasResult || hasError) {
          return CodexJsonRpcMalformedMessage(
            line: trimmed,
            problem: 'Message cannot have both method and result/error fields.',
          );
        }

        if (hasId) {
          final id = _parseId(object['id'], trimmed);
          if (id is CodexJsonRpcMalformedMessage) {
            return id;
          }
          return CodexJsonRpcDecodedMessage(
            CodexJsonRpcRequest(
              id: id as CodexJsonRpcId,
              method: method,
              params: object['params'],
            ),
          );
        }

        return CodexJsonRpcDecodedMessage(
          CodexJsonRpcNotification(method: method, params: object['params']),
        );
      }

      if (hasId) {
        if (hasResult == hasError) {
          return CodexJsonRpcMalformedMessage(
            line: trimmed,
            problem: 'Response must contain exactly one of result or error.',
          );
        }

        final id = _parseId(object['id'], trimmed);
        if (id is CodexJsonRpcMalformedMessage) {
          return id;
        }

        if (hasError) {
          final errorObject = object['error'];
          if (errorObject is! Map) {
            return CodexJsonRpcMalformedMessage(
              line: trimmed,
              problem: 'Response error payload was not an object.',
            );
          }

          final error = Map<String, Object?>.from(errorObject);
          final message = error['message'];
          if (message is! String || message.trim().isEmpty) {
            return CodexJsonRpcMalformedMessage(
              line: trimmed,
              problem: 'Response error payload was missing a message.',
            );
          }

          return CodexJsonRpcDecodedMessage(
            CodexJsonRpcResponse.failure(
              id: id as CodexJsonRpcId,
              error: CodexJsonRpcError(
                message: message,
                code: (error['code'] as num?)?.toInt(),
                data: error['data'],
              ),
            ),
          );
        }

        return CodexJsonRpcDecodedMessage(
          CodexJsonRpcResponse.success(
            id: id as CodexJsonRpcId,
            result: object['result'],
          ),
        );
      }

      return CodexJsonRpcMalformedMessage(
        line: trimmed,
        problem:
            'Message did not match request, notification, or response shape.',
      );
    } on FormatException catch (error) {
      return CodexJsonRpcMalformedMessage(
        line: trimmed,
        problem: 'Invalid JSON-RPC payload: ${error.message}',
      );
    } on Object catch (error) {
      return CodexJsonRpcMalformedMessage(
        line: trimmed,
        problem: 'Invalid JSON-RPC payload: $error',
      );
    }
  }

  Object _parseId(Object? rawValue, String line) {
    try {
      return CodexJsonRpcId.fromRaw(rawValue);
    } on FormatException catch (error) {
      return CodexJsonRpcMalformedMessage(
        line: line,
        problem: 'Invalid JSON-RPC payload: ${error.message}',
      );
    }
  }
}

class CodexJsonRpcTrackedRequest {
  const CodexJsonRpcTrackedRequest({
    required this.request,
    required this.response,
  });

  final CodexJsonRpcRequest request;
  final Future<Object?> response;
}

class CodexJsonRpcRequestTracker {
  CodexJsonRpcRequestTracker({int startingRequestId = 1})
    : _nextRequestId = startingRequestId;

  int _nextRequestId;
  final _pendingResponses = <String, Completer<Object?>>{};

  CodexJsonRpcTrackedRequest createRequest(String method, {Object? params}) {
    final request = CodexJsonRpcRequest(
      id: CodexJsonRpcId(_nextRequestId++),
      method: method,
      params: params,
    );
    final completer = Completer<Object?>();
    _pendingResponses[request.id.token] = completer;

    return CodexJsonRpcTrackedRequest(
      request: request,
      response: completer.future,
    );
  }

  bool completeResponse(CodexJsonRpcResponse response) {
    final completer = _pendingResponses.remove(response.id.token);
    if (completer == null) {
      return false;
    }

    if (response.isError) {
      completer.completeError(CodexJsonRpcRemoteException(response.error!));
    } else {
      completer.complete(response.result);
    }
    return true;
  }

  void failPending(Object error) {
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingResponses.clear();
  }
}

class CodexJsonRpcInboundRequestStore {
  final _requests = <String, CodexJsonRpcRequest>{};

  void remember(CodexJsonRpcRequest request) {
    _requests[request.id.token] = request;
  }

  CodexJsonRpcRequest? lookup(String requestId) {
    return _requests[requestId];
  }

  CodexJsonRpcRequest? take(String requestId) {
    return _requests.remove(requestId);
  }

  void clear() {
    _requests.clear();
  }
}
