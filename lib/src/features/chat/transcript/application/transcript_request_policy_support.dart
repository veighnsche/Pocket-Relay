part of 'transcript_request_policy.dart';

CodexUiBlock _resolvedRequestBlock({
  required String id,
  required DateTime createdAt,
  required String requestId,
  required CodexCanonicalRequestType requestType,
  required String title,
  required String body,
  String? resolutionLabel,
}) {
  final isUserInput =
      requestType == CodexCanonicalRequestType.toolUserInput ||
      requestType == CodexCanonicalRequestType.mcpServerElicitation;
  if (isUserInput) {
    return CodexUserInputRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title,
      body: body,
      isResolved: true,
    );
  }

  return CodexApprovalRequestBlock(
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
    'decline' || 'declined' || 'deny' || 'denied' || 'reject' || 'rejected' =>
      'denied',
    _ => normalized,
  };
}

CodexActiveTurnState? _activeTurnForPendingApproval(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionPendingRequest pendingRequest,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
    return activeTurn;
  }

  return activeTurn.copyWith(
    timer: turnTimer,
    status: CodexActiveTurnStatus.blocked,
    pendingApprovalRequests: <String, CodexSessionPendingRequest>{
      ...activeTurn.pendingApprovalRequests,
      requestId: pendingRequest,
    },
  );
}

CodexActiveTurnState? _activeTurnForPendingInput(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionPendingUserInputRequest pendingRequest,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
    return activeTurn;
  }

  return activeTurn.copyWith(
    timer: turnTimer,
    status: CodexActiveTurnStatus.blocked,
    pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
      ...activeTurn.pendingUserInputRequests,
      requestId: pendingRequest,
    },
  );
}

CodexActiveTurnState? _activeTurnAfterRequestResolved(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null) {
    return null;
  }

  final nextApprovals = <String, CodexSessionPendingRequest>{
    ...activeTurn.pendingApprovalRequests,
  }..remove(requestId);
  final nextInputs = <String, CodexSessionPendingUserInputRequest>{
    ...activeTurn.pendingUserInputRequests,
  }..remove(requestId);

  return activeTurn.copyWith(
    timer: turnTimer,
    status: nextApprovals.isNotEmpty || nextInputs.isNotEmpty
        ? CodexActiveTurnStatus.blocked
        : CodexActiveTurnStatus.running,
    pendingApprovalRequests: nextApprovals,
    pendingUserInputRequests: nextInputs,
  );
}

CodexActiveTurnState? _activeTurnAfterUserInputResolved(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null) {
    return null;
  }

  final nextInputs = <String, CodexSessionPendingUserInputRequest>{
    ...activeTurn.pendingUserInputRequests,
  }..remove(requestId);

  return activeTurn.copyWith(
    timer: turnTimer,
    status:
        activeTurn.pendingApprovalRequests.isNotEmpty || nextInputs.isNotEmpty
        ? CodexActiveTurnStatus.blocked
        : CodexActiveTurnStatus.running,
    pendingUserInputRequests: nextInputs,
  );
}

CodexActiveTurnState? _ensureActiveTurn(
  CodexActiveTurnState? activeTurn, {
  required String? turnId,
  required String? threadId,
  required DateTime createdAt,
}) {
  if (activeTurn != null || turnId == null) {
    return activeTurn;
  }

  return CodexActiveTurnState(
    turnId: turnId,
    threadId: threadId,
    timer: CodexSessionTurnTimer(
      turnId: turnId,
      startedAt: createdAt,
      activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
    ),
  );
}

CodexSessionState _stateWithResolvedTranscriptBlock(
  CodexSessionState state,
  CodexUiBlock block, {
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
      CodexTurnBlockArtifact(:final block) => block,
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

CodexActiveTurnState _appendTurnBlock(
  CodexActiveTurnState activeTurn,
  CodexUiBlock block,
) {
  return activeTurn.copyWith(
    artifacts: appendCodexTurnArtifact(
      activeTurn.artifacts,
      CodexTurnBlockArtifact(block: block),
    ),
  );
}

CodexActiveTurnState? _freezeTailArtifact(CodexActiveTurnState? activeTurn) {
  if (activeTurn == null || activeTurn.artifacts.isEmpty) {
    return activeTurn;
  }

  final frozenTail = freezeCodexTurnArtifact(activeTurn.artifacts.last);
  if (identical(frozenTail, activeTurn.artifacts.last)) {
    return activeTurn;
  }

  final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[nextArtifacts.length - 1] = frozenTail;
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

CodexActiveTurnState? _freezeArtifactsForRequest(
  CodexActiveTurnState? activeTurn, {
  required String? itemId,
}) {
  return _freezeCommandArtifact(
    _freezeTailArtifact(activeTurn),
    itemId: itemId,
  );
}

CodexActiveTurnState? _freezeCommandArtifact(
  CodexActiveTurnState? activeTurn, {
  required String? itemId,
}) {
  if (activeTurn == null || itemId == null) {
    return activeTurn;
  }

  final item = activeTurn.itemsById[itemId];
  if (item?.itemType != CodexCanonicalItemType.commandExecution) {
    return activeTurn;
  }

  final artifactId = activeTurn.itemArtifactIds[itemId];
  if (artifactId == null) {
    return activeTurn;
  }

  final index = activeTurn.artifacts.indexWhere(
    (artifact) => artifact.id == artifactId,
  );
  if (index == -1) {
    return activeTurn;
  }

  final artifact = activeTurn.artifacts[index];
  final frozenArtifact = freezeCodexTurnArtifact(artifact);
  if (identical(frozenArtifact, artifact)) {
    return activeTurn;
  }

  final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[index] = frozenArtifact;
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

CodexActiveTurnState _replaceTailTurnBlock(
  CodexActiveTurnState activeTurn,
  CodexUiBlock block,
) {
  final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[nextArtifacts.length - 1] = CodexTurnBlockArtifact(
    block: block,
  );
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

CodexUiBlock _resolvedRequestBlockWithCreatedAt(
  CodexUiBlock block, {
  required DateTime createdAt,
}) {
  return switch (block) {
    CodexApprovalRequestBlock() => CodexApprovalRequestBlock(
      id: block.id,
      createdAt: createdAt,
      requestId: block.requestId,
      requestType: block.requestType,
      title: block.title,
      body: block.body,
      isResolved: block.isResolved,
      resolutionLabel: block.resolutionLabel,
    ),
    CodexUserInputRequestBlock() => CodexUserInputRequestBlock(
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

CodexUiBlock _mergeResolvedRequestBlocks(
  CodexUiBlock? existingBlock,
  CodexUiBlock incomingBlock,
) {
  if (existingBlock == null) {
    return incomingBlock;
  }

  return switch ((existingBlock, incomingBlock)) {
    (
      CodexUserInputRequestBlock existing,
      CodexUserInputRequestBlock incoming,
    ) =>
      _mergeUserInputResolvedBlocks(existing, incoming),
    (
      CodexApprovalRequestBlock existing,
      CodexApprovalRequestBlock incoming,
    ) =>
      _mergeApprovalResolvedBlocks(existing, incoming),
    (
      CodexUserInputRequestBlock existing,
      CodexApprovalRequestBlock incoming,
    ) =>
      incoming.requestType == CodexCanonicalRequestType.unknown
          ? existing
          : incoming,
    (
      CodexApprovalRequestBlock existing,
      CodexUserInputRequestBlock incoming,
    ) =>
      _isRichUserInputResolution(incoming) ||
              existing.requestType == CodexCanonicalRequestType.unknown
          ? incoming
          : incoming,
    _ => incomingBlock,
  };
}

CodexUserInputRequestBlock _mergeUserInputResolvedBlocks(
  CodexUserInputRequestBlock existing,
  CodexUserInputRequestBlock incoming,
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

CodexApprovalRequestBlock _mergeApprovalResolvedBlocks(
  CodexApprovalRequestBlock existing,
  CodexApprovalRequestBlock incoming,
) {
  final existingIsSpecific =
      existing.requestType != CodexCanonicalRequestType.unknown;
  final incomingIsSpecific =
      incoming.requestType != CodexCanonicalRequestType.unknown;
  if (existingIsSpecific && !incomingIsSpecific) {
    return existing;
  }

  return incoming;
}

bool _isRichUserInputResolution(CodexUserInputRequestBlock block) {
  return block.answers.isNotEmpty || block.title == 'Input submitted';
}
