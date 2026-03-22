part of 'chat_session_controller.dart';

extension _ChatSessionControllerInit on ChatSessionController {
  Future<void> _initializeOnce() async {
    if (!_isLoading) {
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
  }
}
