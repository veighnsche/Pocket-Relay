part of 'chat_session_controller.dart';

extension _ChatSessionControllerInit on ChatSessionController {
  Future<void> _initializeOnce() async {
    if (!_isLoading) {
      await _conversationSelection.hydratePersistedSelection();
      await _restoreInitialConversationIfNeeded();
      return;
    }

    final savedProfile = await profileStore.load();
    if (_isDisposed) {
      return;
    }

    _profile = savedProfile.profile;
    _secrets = savedProfile.secrets;
    _isLoading = false;
    _notifyListenersIfMounted();
    await _conversationSelection.hydratePersistedSelection();
    await _restoreInitialConversationIfNeeded();
  }
}
