import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_recovery_errors.dart';

void main() {
  test(
    'recovery state load failures keep a stable bootstrap code and detail',
    () {
      final error = ConnectionWorkspaceRecoveryErrors.recoveryStateLoadFailed(
        error: Exception(
          'Persisted workspace recovery metadata is malformed JSON.',
        ),
      );

      expect(
        error.definition,
        PocketErrorCatalog.appBootstrapRecoveryStateLoadFailed,
      );
      expect(error.inlineMessage, contains('malformed JSON'));
    },
  );
}
