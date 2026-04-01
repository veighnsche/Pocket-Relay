part of 'transcript_request_policy.dart';

TranscriptUiBlock _resolvedRequestBlock({
  required String id,
  required DateTime createdAt,
  required String requestId,
  required TranscriptCanonicalRequestType requestType,
  required String title,
  required String body,
  String? resolutionLabel,
}) {
  final isUserInput =
      requestType == TranscriptCanonicalRequestType.toolUserInput ||
      requestType == TranscriptCanonicalRequestType.mcpServerElicitation;
  if (isUserInput) {
    return TranscriptUserInputRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title,
      body: body,
      isResolved: true,
    );
  }

  return TranscriptApprovalRequestBlock(
    id: id,
    createdAt: createdAt,
    requestId: requestId,
    requestType: requestType,
    title: title,
    body: body,
    isResolved: true,
    resolutionLabel: resolutionLabel,
  );
}

String _resolvedApprovalBody({
  required String? pendingDetail,
  required String decisionLabel,
}) {
  final decisionSentence = switch (decisionLabel) {
    'approved' => 'Codex received approval for this request.',
    'denied' => 'Codex was denied approval for this request.',
    _ => 'Codex received a response for this request.',
  };
  final detail = pendingDetail?.trim();
  if (detail == null || detail.isEmpty) {
    return decisionSentence;
  }
  return '$detail\n\n$decisionSentence';
}

String _resolutionLabel(
  TranscriptPolicySupport support,
  Object? resolution, {
  required String fallback,
}) {
  if (resolution is bool) {
    return resolution ? 'approved' : 'denied';
  }
  if (resolution is String && resolution.trim().isNotEmpty) {
    return _normalizeResolutionLabel(resolution);
  }
  if (resolution is Map) {
    final raw = support.stringFromCandidates(<Object?>[
      resolution['result'],
      resolution['status'],
      resolution['resolution'],
      resolution['decision'],
      resolution['outcome'],
      resolution['action'],
    ]);
    if (raw != null && raw.trim().isNotEmpty) {
      return _normalizeResolutionLabel(raw);
    }
    final approved = resolution['approved'];
    if (approved is bool) {
      return approved ? 'approved' : 'denied';
    }
  }
  return fallback;
}

String _normalizeResolutionLabel(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'accept' || 'accepted' || 'approve' || 'approved' => 'approved',
    'decline' ||
    'declined' ||
    'deny' ||
    'denied' ||
    'reject' ||
    'rejected' => 'denied',
    _ => normalized,
  };
}

TranscriptSessionState _stateWithResolvedTranscriptBlock(
  TranscriptSessionState state,
  TranscriptUiBlock block, {
  required String? turnId,
  required String? threadId,
}) {
  final activeTurn = _ensureActiveTurn(
    state.activeTurn,
    turnId: turnId,
    threadId: threadId,
    createdAt: block.createdAt,
  );
  if (activeTurn == null) {
    if (state.blocks.any((existing) => existing.id == block.id)) {
      return state;
    }
    return const TranscriptPolicySupport().appendBlock(state, block);
  }

  final existingIndex = activeTurn.artifacts.indexWhere(
    (artifact) => artifact.id == block.id,
  );
  if (existingIndex == -1) {
    return state.copyWithProjectedTranscript(
      activeTurn: _appendTurnBlock(activeTurn, block),
    );
  }
  if (existingIndex != activeTurn.artifacts.length - 1) {
    return state;
  }

  final existingArtifact = activeTurn.artifacts[existingIndex];
  final nextBlock = _mergeResolvedRequestBlocks(
    switch (existingArtifact) {
      TranscriptTurnBlockArtifact(:final block) => block,
      _ => null,
    },
    _resolvedRequestBlockWithCreatedAt(
      block,
      createdAt: existingArtifact.createdAt,
    ),
  );

  return state.copyWithProjectedTranscript(
    activeTurn: _replaceTailTurnBlock(activeTurn, nextBlock),
  );
}

TranscriptUiBlock _resolvedRequestBlockWithCreatedAt(
  TranscriptUiBlock block, {
  required DateTime createdAt,
}) {
  return switch (block) {
    TranscriptApprovalRequestBlock() => TranscriptApprovalRequestBlock(
      id: block.id,
      createdAt: createdAt,
      requestId: block.requestId,
      requestType: block.requestType,
      title: block.title,
      body: block.body,
      isResolved: block.isResolved,
      resolutionLabel: block.resolutionLabel,
    ),
    TranscriptUserInputRequestBlock() => TranscriptUserInputRequestBlock(
      id: block.id,
      createdAt: createdAt,
      requestId: block.requestId,
      requestType: block.requestType,
      title: block.title,
      body: block.body,
      isResolved: block.isResolved,
      questions: block.questions,
      answers: block.answers,
    ),
    _ => block,
  };
}

TranscriptUiBlock _mergeResolvedRequestBlocks(
  TranscriptUiBlock? existingBlock,
  TranscriptUiBlock incomingBlock,
) {
  if (existingBlock == null) {
    return incomingBlock;
  }

  return switch ((existingBlock, incomingBlock)) {
    (
      TranscriptUserInputRequestBlock existing,
      TranscriptUserInputRequestBlock incoming,
    ) =>
      _mergeUserInputResolvedBlocks(existing, incoming),
    (
      TranscriptApprovalRequestBlock existing,
      TranscriptApprovalRequestBlock incoming,
    ) =>
      _mergeApprovalResolvedBlocks(existing, incoming),
    (
      TranscriptUserInputRequestBlock existing,
      TranscriptApprovalRequestBlock incoming,
    ) =>
      incoming.requestType == TranscriptCanonicalRequestType.unknown
          ? existing
          : incoming,
    (
      TranscriptApprovalRequestBlock existing,
      TranscriptUserInputRequestBlock incoming,
    ) =>
      _isRichUserInputResolution(incoming) ||
              existing.requestType == TranscriptCanonicalRequestType.unknown
          ? incoming
          : incoming,
    _ => incomingBlock,
  };
}

TranscriptUserInputRequestBlock _mergeUserInputResolvedBlocks(
  TranscriptUserInputRequestBlock existing,
  TranscriptUserInputRequestBlock incoming,
) {
  final incomingIsRich = _isRichUserInputResolution(incoming);
  final existingIsRich = _isRichUserInputResolution(existing);
  if (existingIsRich && !incomingIsRich) {
    return existing;
  }

  return incoming.copyWith(
    questions: incoming.questions.isNotEmpty
        ? incoming.questions
        : existing.questions,
    answers: incoming.answers.isNotEmpty ? incoming.answers : existing.answers,
    body: incoming.body.isNotEmpty ? incoming.body : existing.body,
  );
}

TranscriptApprovalRequestBlock _mergeApprovalResolvedBlocks(
  TranscriptApprovalRequestBlock existing,
  TranscriptApprovalRequestBlock incoming,
) {
  final existingIsSpecific =
      existing.requestType != TranscriptCanonicalRequestType.unknown;
  final incomingIsSpecific =
      incoming.requestType != TranscriptCanonicalRequestType.unknown;
  if (existingIsSpecific && !incomingIsSpecific) {
    return existing;
  }

  return incoming;
}

bool _isRichUserInputResolution(TranscriptUserInputRequestBlock block) {
  return block.answers.isNotEmpty || block.title == 'Input submitted';
}
