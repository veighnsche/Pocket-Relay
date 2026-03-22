import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

void main() {
  test('fromJson normalizes blank selectedThreadId to null', () {
    final state = ConnectionWorkspaceRecoveryState.fromJson(
      <String, dynamic>{
        'connectionId': 'conn_primary',
        'draftText': 'Draft',
        'selectedThreadId': '   ',
        'backgroundedAt': '2026-03-22T10:00:00.000Z',
      },
    );

    expect(state.connectionId, 'conn_primary');
    expect(state.draftText, 'Draft');
    expect(state.selectedThreadId, isNull);
    expect(state.backgroundedAt, isNotNull);
  });
}
