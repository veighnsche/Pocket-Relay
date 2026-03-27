abstract final class PocketErrorDetailFormatter {
  static String? normalize(
    Object? error, {
    bool stripRemoteOwnerControlFailure = false,
  }) {
    if (error == null) {
      return null;
    }

    final detail = '$error'.trim();
    if (detail.isEmpty) {
      return null;
    }

    final normalized = switch (detail) {
      final value when value.startsWith('Exception:') => value.substring(
        'Exception:'.length,
      ),
      final value when value.startsWith('Bad state:') => value.substring(
        'Bad state:'.length,
      ),
      final value when value.startsWith('CodexAppServerException:') =>
        value.substring('CodexAppServerException:'.length),
      final value
          when value.startsWith('CodexAppServerException(') &&
              value.contains('): ') =>
        value.substring(value.indexOf('): ') + 3),
      final value when value.startsWith('CodexJsonRpcRemoteException:') =>
        value.substring('CodexJsonRpcRemoteException:'.length),
      final value
          when value.startsWith('CodexJsonRpcRemoteException(') &&
              value.contains('): ') =>
        value.substring(value.indexOf('): ') + 3),
      final value
          when stripRemoteOwnerControlFailure &&
              value.startsWith('Remote owner control command failed:') =>
        value.substring('Remote owner control command failed:'.length),
      _ => detail,
    };
    final trimmedNormalized = normalized.trim();
    return trimmedNormalized.isEmpty ? null : trimmedNormalized;
  }

  static String composeMessage({
    required String message,
    String? underlyingDetail,
  }) {
    final normalizedMessage = message.trim();
    final normalizedDetail = underlyingDetail?.trim();
    if (normalizedDetail == null ||
        normalizedDetail.isEmpty ||
        normalizedMessage.contains(normalizedDetail)) {
      return normalizedMessage;
    }
    if (normalizedMessage.isEmpty) {
      return 'Underlying error: $normalizedDetail';
    }
    return '$normalizedMessage Underlying error: $normalizedDetail';
  }

  static String resolvePrimaryMessage({
    String? preferredMessage,
    Object? error,
    required String fallbackMessage,
    bool stripRemoteOwnerControlFailure = false,
  }) {
    final normalizedPreferred = preferredMessage?.trim();
    if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
      return normalizedPreferred;
    }

    final detail = normalize(
      error,
      stripRemoteOwnerControlFailure: stripRemoteOwnerControlFailure,
    );
    if (detail != null) {
      return detail;
    }

    return fallbackMessage.trim();
  }

  static String? uniqueUnderlyingDetail({
    required String existingText,
    Object? error,
    bool stripRemoteOwnerControlFailure = false,
  }) {
    final detail = normalize(
      error,
      stripRemoteOwnerControlFailure: stripRemoteOwnerControlFailure,
    );
    if (detail == null || existingText.contains(detail)) {
      return null;
    }
    return detail;
  }
}
