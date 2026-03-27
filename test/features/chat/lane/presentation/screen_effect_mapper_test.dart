import '../../support/screen_presentation_test_support.dart';

void main() {
  test('maps snackbar messages into screen effects', () {
    const mapper = ChatScreenEffectMapper();

    final effect = mapper.mapSnackBarMessage('Input failed');

    expect(effect, isA<ChatShowSnackBarEffect>());
    expect((effect as ChatShowSnackBarEffect).message, 'Input failed');
  });

  test('maps the settings action into a connection settings effect', () {
    const presenter = ChatScreenPresenter();
    const mapper = ChatScreenEffectMapper();
    final profile = configuredProfile();
    final secrets = const ConnectionSecrets(password: 'secret');
    final contract = presenter.present(
      isLoading: false,
      profile: profile,
      secrets: secrets,
      sessionState: CodexSessionState.initial(),
      conversationRecoveryState: null,
      composerDraft: const ChatComposerDraft(),
      transcriptFollow: defaultTranscriptFollowContract,
    );

    final effect = mapper.mapAction(
      action: ChatScreenActionId.openSettings,
      screen: contract,
    );

    expect(effect, isA<ChatOpenConnectionSettingsEffect>());
    expect(
      (effect as ChatOpenConnectionSettingsEffect).payload.initialProfile,
      same(profile),
    );
    expect(effect.payload.initialSecrets, same(secrets));
  });
}
