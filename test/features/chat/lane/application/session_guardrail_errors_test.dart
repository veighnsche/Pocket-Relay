import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';

void main() {
  test('host fingerprint prompt unavailable maps to a stable code', () {
    final error = ChatSessionGuardrailErrors.hostFingerprintPromptUnavailable();

    expect(
      error.definition,
      PocketErrorCatalog.chatSessionHostFingerprintPromptUnavailable,
    );
    expect(
      error.inlineMessage,
      '[${PocketErrorCatalog.chatSessionHostFingerprintPromptUnavailable.code}] Host fingerprint unavailable. This host fingerprint prompt is no longer available.',
    );
  });

  test('host fingerprint save failures keep the stable code and detail', () {
    final error = ChatSessionGuardrailErrors.hostFingerprintSaveFailed(
      error: StateError('profile save failed'),
    );

    expect(
      error.definition,
      PocketErrorCatalog.chatSessionHostFingerprintSaveFailed,
    );
    expect(error.inlineMessage, contains('profile save failed'));
  });

  test('validation guardrails use distinct codes', () {
    expect(
      ChatSessionGuardrailErrors.remoteConnectionDetailsRequired().definition,
      PocketErrorCatalog.chatSessionRemoteConfigurationRequired,
    );
    expect(
      ChatSessionGuardrailErrors.localConfigurationRequired().definition,
      PocketErrorCatalog.chatSessionLocalConfigurationRequired,
    );
    expect(
      ChatSessionGuardrailErrors.sshPasswordRequired().definition,
      PocketErrorCatalog.chatSessionSshPasswordRequired,
    );
    expect(
      ChatSessionGuardrailErrors.privateKeyRequired().definition,
      PocketErrorCatalog.chatSessionPrivateKeyRequired,
    );
  });

  test('image input unsupported includes the effective model when present', () {
    final error = ChatSessionGuardrailErrors.imageInputUnsupported(
      model: 'gpt-text-only',
    );

    expect(
      error.definition,
      PocketErrorCatalog.chatSessionImageInputUnsupported,
    );
    expect(error.inlineMessage, contains('gpt-text-only'));
  });

  test('recovery guardrails use distinct continue and branch codes', () {
    expect(
      ChatSessionGuardrailErrors.continueBlockedByActiveTurn().definition,
      PocketErrorCatalog.chatSessionContinueBlockedByActiveTurn,
    );
    expect(
      ChatSessionGuardrailErrors.branchBlockedByActiveTurn().definition,
      PocketErrorCatalog.chatSessionBranchBlockedByActiveTurn,
    );
  });
}
