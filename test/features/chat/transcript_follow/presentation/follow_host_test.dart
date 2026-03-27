import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatTranscriptFollowHost', () {
    test(
      'models follow requests and viewport eligibility above the widget',
      () {
        final host = ChatTranscriptFollowHost();

        expect(host.contract.isAutoFollowEnabled, isTrue);
        expect(host.contract.request, isNull);

        host.updateAutoFollowEligibility(isNearBottom: false);

        expect(host.contract.isAutoFollowEnabled, isFalse);
        expect(host.contract.request, isNull);

        host.requestFollow(
          source: ChatTranscriptFollowRequestSource.clearTranscript,
        );

        final firstRequest = host.contract.request;
        expect(host.contract.isAutoFollowEnabled, isTrue);
        expect(
          firstRequest?.source,
          ChatTranscriptFollowRequestSource.clearTranscript,
        );

        host.requestFollow(source: ChatTranscriptFollowRequestSource.newThread);

        expect(host.contract.request?.id, greaterThan(firstRequest!.id));
        expect(
          host.contract.request?.source,
          ChatTranscriptFollowRequestSource.newThread,
        );
      },
    );

    test('reset restores default follow state', () {
      final host = ChatTranscriptFollowHost();

      host.updateAutoFollowEligibility(isNearBottom: false);
      host.requestFollow(
        source: ChatTranscriptFollowRequestSource.clearTranscript,
      );

      host.reset();

      expect(host.contract.isAutoFollowEnabled, isTrue);
      expect(host.contract.request, isNull);
    });
  });
}
