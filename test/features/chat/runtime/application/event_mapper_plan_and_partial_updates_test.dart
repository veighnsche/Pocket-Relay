import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';

void main() {
  test('maps turn plan notifications into runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final planUpdated = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/plan/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'explanation': 'Implement the migration in phases.',
          'plan': <Object>[
            <String, Object?>{
              'step': 'Wire the transport',
              'status': 'completed',
            },
            <String, Object?>{
              'step': 'Render proposed plans',
              'status': 'inProgress',
            },
          ],
        },
      ),
    );
    final planEvent =
        planUpdated.single as TranscriptRuntimeTurnPlanUpdatedEvent;

    expect(planEvent.explanation, 'Implement the migration in phases.');
    expect(planEvent.steps, hasLength(2));
    expect(
      planEvent.steps.first.status,
      TranscriptRuntimePlanStepStatus.completed,
    );
    expect(
      planEvent.steps.last.status,
      TranscriptRuntimePlanStepStatus.inProgress,
    );
  });

  test(
    'maps partial item update notifications without embedded item snapshots',
    () {
      final mapper = CodexRuntimeEventMapper();

      final reasoningUpdate = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'item/reasoning/summaryPartAdded',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_123',
            'summaryIndex': 2,
          },
        ),
      );
      final terminalInteraction = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_456',
            'processId': 'proc_1',
            'stdin': 'y\n',
          },
        ),
      );
      final terminalWait = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_789',
            'processId': 'proc_2',
            'stdin': '',
          },
        ),
      );

      final reasoningEvent =
          reasoningUpdate.single as TranscriptRuntimeItemUpdatedEvent;
      final terminalEvent =
          terminalInteraction.single as TranscriptRuntimeItemUpdatedEvent;
      final terminalWaitEvent =
          terminalWait.single as TranscriptRuntimeItemUpdatedEvent;

      expect(reasoningEvent.itemType, TranscriptCanonicalItemType.reasoning);
      expect(reasoningEvent.itemId, 'item_123');
      expect(reasoningEvent.detail, isNull);
      expect(
        terminalEvent.itemType,
        TranscriptCanonicalItemType.commandExecution,
      );
      expect(terminalEvent.itemId, 'item_456');
      expect(terminalEvent.detail, 'y\n');
      expect(
        terminalWaitEvent.itemType,
        TranscriptCanonicalItemType.commandExecution,
      );
      expect(terminalWaitEvent.itemId, 'item_789');
      expect(terminalWaitEvent.detail, '');
      expect(terminalWaitEvent.snapshot?['processId'], 'proc_2');
    },
  );

  test('clears stale pending requests after disconnect', () {
    final mapper = CodexRuntimeEventMapper();

    mapper.mapEvent(
      const CodexAppServerRequestEvent(
        requestId: 'i:99',
        method: 'item/fileChange/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'reason': 'Write files',
        },
      ),
    );
    mapper.mapEvent(const CodexAppServerDisconnectedEvent(exitCode: 1));

    final resolved = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'serverRequest/resolved',
        params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
      ),
    );

    final resolvedEvent =
        resolved.single as TranscriptRuntimeRequestResolvedEvent;
    expect(resolvedEvent.requestType, TranscriptCanonicalRequestType.unknown);
  });
}
