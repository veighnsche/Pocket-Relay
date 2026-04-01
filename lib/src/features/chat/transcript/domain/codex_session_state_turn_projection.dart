part of 'transcript_session_state.dart';

List<TranscriptUiBlock> projectTranscriptTurnArtifacts(
  Iterable<TranscriptTurnArtifact> artifacts,
) {
  final projected = <TranscriptUiBlock>[];

  for (final artifact in artifacts) {
    switch (artifact) {
      case TranscriptTurnTextArtifact():
        projected.add(
          TranscriptTextBlock(
            id: artifact.id,
            kind: artifact.kind,
            createdAt: artifact.createdAt,
            title: artifact.title,
            body: artifact.body,
            isRunning: artifact.isStreaming,
          ),
        );
      case TranscriptTurnWorkArtifact():
        projected.add(
          TranscriptWorkLogGroupBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            entries: artifact.entries,
          ),
        );
      case TranscriptTurnPlanArtifact():
        projected.add(
          TranscriptProposedPlanBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            title: artifact.title,
            markdown: artifact.markdown,
            isStreaming: artifact.isStreaming,
          ),
        );
      case TranscriptTurnChangedFilesArtifact():
        projected.add(
          TranscriptChangedFilesBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            title: artifact.title,
            files: artifact.files,
            unifiedDiff: artifact.unifiedDiff,
            isRunning: artifact.isStreaming,
          ),
        );
      case TranscriptTurnBlockArtifact():
        projected.add(artifact.block);
    }
  }

  return projected;
}

List<TranscriptTurnArtifact> appendTranscriptTurnArtifact(
  List<TranscriptTurnArtifact> artifacts,
  TranscriptTurnArtifact nextArtifact,
) {
  final nextArtifacts = List<TranscriptTurnArtifact>.from(artifacts);
  if (nextArtifacts.isNotEmpty) {
    nextArtifacts[nextArtifacts.length - 1] = freezeTranscriptTurnArtifact(
      nextArtifacts.last,
    );
  }
  nextArtifacts.add(nextArtifact);
  return nextArtifacts;
}

TranscriptTurnArtifact freezeTranscriptTurnArtifact(
  TranscriptTurnArtifact artifact,
) {
  return switch (artifact) {
    TranscriptTurnTextArtifact(:final isStreaming) when isStreaming =>
      TranscriptTurnTextArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        kind: artifact.kind,
        title: artifact.title,
        body: artifact.body,
        itemId: artifact.itemId,
        isStreaming: false,
      ),
    TranscriptTurnWorkArtifact() => TranscriptTurnWorkArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      entries: artifact.entries
          .map((entry) => entry.copyWith(isRunning: false))
          .toList(growable: false),
    ),
    TranscriptTurnPlanArtifact(:final isStreaming) when isStreaming =>
      TranscriptTurnPlanArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        title: artifact.title,
        markdown: artifact.markdown,
        itemId: artifact.itemId,
        isStreaming: false,
      ),
    TranscriptTurnChangedFilesArtifact(:final isStreaming) when isStreaming =>
      TranscriptTurnChangedFilesArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        title: artifact.title,
        itemId: artifact.itemId,
        files: artifact.files,
        unifiedDiff: artifact.unifiedDiff,
        entries: artifact.entries
            .map((entry) => entry.copyWith(isRunning: false))
            .toList(growable: false),
        isStreaming: false,
      ),
    TranscriptTurnBlockArtifact(:final block) => TranscriptTurnBlockArtifact(
      block: _freezeTranscriptUiBlock(block),
    ),
    _ => artifact,
  };
}

TranscriptUiBlock _freezeTranscriptUiBlock(TranscriptUiBlock block) {
  return switch (block) {
    TranscriptTextBlock(:final isRunning) when isRunning => block.copyWith(
      isRunning: false,
    ),
    TranscriptProposedPlanBlock(:final isStreaming) when isStreaming =>
      block.copyWith(isStreaming: false),
    TranscriptChangedFilesBlock(:final isRunning) when isRunning =>
      block.copyWith(isRunning: false),
    _ => block,
  };
}

bool _shouldAppearInTranscript(TranscriptUiBlock block) {
  return switch (block) {
    TranscriptApprovalRequestBlock(:final isResolved) => isResolved,
    TranscriptUserInputRequestBlock(:final isResolved) => isResolved,
    TranscriptStatusBlock(:final isTranscriptSignal) => isTranscriptSignal,
    _ => true,
  };
}
