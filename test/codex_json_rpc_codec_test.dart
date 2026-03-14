import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/services/codex_json_rpc_codec.dart';

void main() {
  const codec = CodexJsonRpcCodec();

  test('decodes request, notification, and response messages', () async {
    final requestResult = codec.decodeLine(
      '{"id":1,"method":"thread/start","params":{"cwd":"/workspace"}}',
    );
    final notificationResult = codec.decodeLine(
      '{"method":"thread/started","params":{"thread":{"id":"thread_1"}}}',
    );
    final responseResult = codec.decodeLine(
      '{"id":1,"result":{"thread":{"id":"thread_1"}}}',
    );

    expect(requestResult, isA<CodexJsonRpcDecodedMessage>());
    expect(notificationResult, isA<CodexJsonRpcDecodedMessage>());
    expect(responseResult, isA<CodexJsonRpcDecodedMessage>());

    final request =
        (requestResult as CodexJsonRpcDecodedMessage).message
            as CodexJsonRpcRequest;
    final notification =
        (notificationResult as CodexJsonRpcDecodedMessage).message
            as CodexJsonRpcNotification;
    final response =
        (responseResult as CodexJsonRpcDecodedMessage).message
            as CodexJsonRpcResponse;

    expect(request.id.token, 'i:1');
    expect(request.method, 'thread/start');
    expect(notification.method, 'thread/started');
    expect(response.id.token, 'i:1');
    expect(response.isError, isFalse);
  });

  test('reports malformed messages with a reason', () {
    final invalidJson = codec.decodeLine('{not-json');
    final invalidShape = codec.decodeLine(
      '{"id":1,"method":"foo","result":{}}',
    );

    expect(invalidJson, isA<CodexJsonRpcMalformedMessage>());
    expect(invalidShape, isA<CodexJsonRpcMalformedMessage>());

    expect(
      (invalidJson as CodexJsonRpcMalformedMessage).problem,
      contains('Invalid JSON-RPC payload'),
    );
    expect(
      (invalidShape as CodexJsonRpcMalformedMessage).problem,
      'Message cannot have both method and result/error fields.',
    );
  });

  test(
    'request tracker resolves matching success and error responses',
    () async {
      final tracker = CodexJsonRpcRequestTracker();

      final success = tracker.createRequest(
        'thread/start',
        params: const <String, Object?>{'cwd': '/workspace'},
      );
      final failure = tracker.createRequest('turn/start');

      expect(
        tracker.completeResponse(
          CodexJsonRpcResponse.success(
            id: success.request.id,
            result: const <String, Object?>{'ok': true},
          ),
        ),
        isTrue,
      );

      expect(
        tracker.completeResponse(
          CodexJsonRpcResponse.failure(
            id: failure.request.id,
            error: const CodexJsonRpcError(message: 'boom', code: -32000),
          ),
        ),
        isTrue,
      );

      await expectLater(
        success.response,
        completion(const <String, Object?>{'ok': true}),
      );
      await expectLater(
        failure.response,
        throwsA(
          isA<CodexJsonRpcRemoteException>().having(
            (error) => error.error.message,
            'message',
            'boom',
          ),
        ),
      );
    },
  );

  test('inbound request store keys requests by stable token', () {
    final store = CodexJsonRpcInboundRequestStore();
    const request = CodexJsonRpcRequest(
      id: CodexJsonRpcId('approval-1'),
      method: 'item/fileChange/requestApproval',
    );

    store.remember(request);

    expect(store.lookup('s:approval-1'), same(request));
    expect(store.take('s:approval-1'), same(request));
    expect(store.lookup('s:approval-1'), isNull);
  });
}
