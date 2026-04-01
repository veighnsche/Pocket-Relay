import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';

void main() {
  test('maps progress and token-usage notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final progress = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/mcpToolCall/progress',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_mcp',
          'message': 'Fetching repository metadata',
        },
      ),
    );
    final tokenUsage = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'thread/tokenUsage/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'tokenUsage': <String, Object?>{
            'last': <String, Object?>{
              'inputTokens': 10,
              'cachedInputTokens': 2,
              'outputTokens': 4,
              'reasoningOutputTokens': 1,
              'totalTokens': 17,
            },
            'total': <String, Object?>{
              'inputTokens': 20,
              'cachedInputTokens': 3,
              'outputTokens': 8,
              'reasoningOutputTokens': 1,
              'totalTokens': 32,
            },
            'modelContextWindow': 200000,
          },
        },
      ),
    );

    final progressEvent = progress.single as TranscriptRuntimeItemUpdatedEvent;
    final usageEvent = tokenUsage.single as TranscriptRuntimeStatusEvent;

    expect(progressEvent.itemType, TranscriptCanonicalItemType.mcpToolCall);
    expect(progressEvent.detail, 'Fetching repository metadata');
    expect(usageEvent.title, 'Thread token usage');
    expect(usageEvent.message, contains('Context window: 200000'));
  });

  test('maps warnings and drops unknown notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final warning = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'configWarning',
        params: <String, Object?>{
          'summary': 'Config warning',
          'details': 'Bad config value',
        },
      ),
    );
    final unknown = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'unknown/method',
        params: <String, Object?>{'x': 1},
      ),
    );

    expect(warning.single, isA<TranscriptRuntimeWarningEvent>());
    expect(
      (warning.single as TranscriptRuntimeWarningEvent).summary,
      'Config warning',
    );
    expect(unknown, isEmpty);
  });

  test('maps unpinned host key transport events into runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final events = mapper.mapEvent(
      const CodexAppServerUnpinnedHostKeyEvent(
        host: '192.168.1.10',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: '7a:9f:d7:dc:2e:f2',
      ),
    );

    expect(events.single, isA<TranscriptRuntimeUnpinnedHostKeyEvent>());
    final event = events.single as TranscriptRuntimeUnpinnedHostKeyEvent;
    expect(event.host, '192.168.1.10');
    expect(event.port, 22);
    expect(event.keyType, 'ssh-ed25519');
    expect(event.fingerprint, '7a:9f:d7:dc:2e:f2');
  });

  test('maps SSH connect failures into typed runtime events only', () {
    final mapper = CodexRuntimeEventMapper();

    final events = mapper.mapEvent(
      const CodexAppServerSshConnectFailedEvent(
        host: '192.168.1.10',
        port: 22,
        message: 'Connection refused',
      ),
    );

    expect(events.single, isA<TranscriptRuntimeSshConnectFailedEvent>());
    final specific = events.single as TranscriptRuntimeSshConnectFailedEvent;
    expect(specific.host, '192.168.1.10');
    expect(specific.message, 'Connection refused');
  });

  test('maps SSH port-forward events into runtime diagnostics', () {
    final mapper = CodexRuntimeEventMapper();

    final started = mapper.mapEvent(
      const CodexAppServerSshPortForwardStartedEvent(
        host: '192.168.1.10',
        port: 22,
        username: 'vince',
        remoteHost: '127.0.0.1',
        remotePort: 4100,
        localPort: 54123,
      ),
    );
    final failed = mapper.mapEvent(
      const CodexAppServerSshPortForwardFailedEvent(
        host: '192.168.1.10',
        port: 22,
        username: 'vince',
        remoteHost: '127.0.0.1',
        remotePort: 4100,
        message: 'open failed',
        detail: 'administratively prohibited',
      ),
    );

    expect(started.single, isA<TranscriptRuntimeWarningEvent>());
    expect(
      (started.single as TranscriptRuntimeWarningEvent).summary,
      contains('localhost:54123'),
    );

    expect(failed.single, isA<TranscriptRuntimeErrorEvent>());
    final failedEvent = failed.single as TranscriptRuntimeErrorEvent;
    expect(failedEvent.message, contains('open failed'));
    expect(failedEvent.detail, 'administratively prohibited');
    expect(failedEvent.errorClass, TranscriptRuntimeErrorClass.transportError);
  });

  test(
    'maps SSH host-key mismatches and auth failures into typed runtime events only',
    () {
      final mapper = CodexRuntimeEventMapper();

      final mismatchEvents = mapper.mapEvent(
        const CodexAppServerSshHostKeyMismatchEvent(
          host: '192.168.1.10',
          port: 22,
          keyType: 'ssh-ed25519',
          expectedFingerprint: 'aa:bb:cc',
          actualFingerprint: '11:22:33',
        ),
      );
      final authFailedEvents = mapper.mapEvent(
        const CodexAppServerSshAuthenticationFailedEvent(
          host: '192.168.1.10',
          port: 22,
          username: 'vince',
          authMode: AuthMode.privateKey,
          message: 'Permission denied',
        ),
      );

      expect(
        mismatchEvents.single,
        isA<TranscriptRuntimeSshHostKeyMismatchEvent>(),
      );
      final mismatch =
          mismatchEvents.single as TranscriptRuntimeSshHostKeyMismatchEvent;
      expect(mismatch.expectedFingerprint, 'aa:bb:cc');
      expect(mismatch.actualFingerprint, '11:22:33');

      expect(
        authFailedEvents.single,
        isA<TranscriptRuntimeSshAuthenticationFailedEvent>(),
      );
      final authFailed =
          authFailedEvents.single
              as TranscriptRuntimeSshAuthenticationFailedEvent;
      expect(authFailed.username, 'vince');
      expect(authFailed.authMode, AuthMode.privateKey);
    },
  );

  test('maps SSH authenticated events into typed runtime events only', () {
    final mapper = CodexRuntimeEventMapper();

    final authenticated = mapper.mapEvent(
      const CodexAppServerSshAuthenticatedEvent(
        host: '192.168.1.10',
        port: 22,
        username: 'vince',
        authMode: AuthMode.password,
      ),
    );

    expect(authenticated.single, isA<TranscriptRuntimeSshAuthenticatedEvent>());
  });
}
