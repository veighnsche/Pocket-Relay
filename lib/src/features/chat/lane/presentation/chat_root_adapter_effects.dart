part of 'chat_root_adapter.dart';

void _bindChatRootScreenEffects(_ChatRootAdapterState state) {
  state._screenEffectSubscription = state.widget.laneBinding.screenEffects
      .listen(state._handleScreenEffect);
}

void _handleChatScreenEffect(
  _ChatRootAdapterState state,
  ChatScreenEffect effect,
) {
  switch (effect) {
    case ChatShowSnackBarEffect(:final message):
      state._showTransientFeedback(message);
    case ChatOpenConnectionSettingsEffect(:final payload):
      unawaited(state._requestConnectionSettings(payload));
    case ChatOpenChangedFileDiffEffect(:final payload):
      unawaited(state._openChangedFileDiff(payload));
    case ChatOpenWorkLogTerminalEffect(:final payload):
      unawaited(state._openWorkLogTerminal(payload));
  }
}

void _showChatTransientFeedback(_ChatRootAdapterState state, String message) {
  if (!state.mounted) {
    return;
  }

  state.widget.overlayDelegate.showTransientFeedback(
    context: state.context,
    message: message,
  );
}
