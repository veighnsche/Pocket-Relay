class PendingUserInputOptionContract {
  const PendingUserInputOptionContract({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;
}

class PendingUserInputFieldContract {
  const PendingUserInputFieldContract({
    required this.id,
    required this.inputLabel,
    required this.value,
    this.header,
    this.prompt,
    this.options = const <PendingUserInputOptionContract>[],
    this.isSecret = false,
    this.isReadOnly = false,
    this.minLines = 1,
    this.maxLines = 2,
  });

  final String id;
  final String inputLabel;
  final String value;
  final String? header;
  final String? prompt;
  final List<PendingUserInputOptionContract> options;
  final bool isSecret;
  final bool isReadOnly;
  final int minLines;
  final int maxLines;
}

class PendingUserInputContract {
  const PendingUserInputContract({
    required this.requestId,
    required this.title,
    required this.body,
    required this.fields,
    required this.isResolved,
    required this.isSubmitting,
    required this.isSubmitEnabled,
    required this.submitPayload,
    this.statusBadgeLabel,
    this.submitLabel = 'Submit response',
  });

  final String requestId;
  final String title;
  final String body;
  final List<PendingUserInputFieldContract> fields;
  final bool isResolved;
  final bool isSubmitting;
  final bool isSubmitEnabled;
  final Map<String, List<String>> submitPayload;
  final String? statusBadgeLabel;
  final String submitLabel;
}
