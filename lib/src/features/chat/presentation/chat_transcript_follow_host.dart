import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';

class ChatTranscriptFollowHost extends ChangeNotifier {
  static const double defaultResumeDistance = 72;

  bool _isAutoFollowEnabled = true;
  int _nextRequestId = 0;
  ChatTranscriptFollowRequestContract? _request;

  ChatTranscriptFollowContract get contract => ChatTranscriptFollowContract(
    isAutoFollowEnabled: _isAutoFollowEnabled,
    resumeDistance: defaultResumeDistance,
    request: _request,
  );

  void requestFollow({required ChatTranscriptFollowRequestSource source}) {
    _isAutoFollowEnabled = true;
    _request = ChatTranscriptFollowRequestContract(
      id: ++_nextRequestId,
      source: source,
    );
    notifyListeners();
  }

  void updateAutoFollowEligibility({required bool isNearBottom}) {
    if (_isAutoFollowEnabled == isNearBottom) {
      return;
    }

    _isAutoFollowEnabled = isNearBottom;
    notifyListeners();
  }
}
