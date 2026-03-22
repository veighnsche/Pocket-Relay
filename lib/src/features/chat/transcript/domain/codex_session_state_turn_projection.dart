part of 'codex_session_state.dart';

List<CodexUiBlock> projectCodexTurnArtifacts(
  Iterable<CodexTurnArtifact> artifacts,
) {
  final projected = <CodexUiBlock>[];

  for (final artifact in artifacts) {
    switch (artifact) {
      case CodexTurnTextArtifact():
        projected.add(
          CodexTextBlock(
            id: artifact.id,
            kind: artifact.kind,
            createdAt: artifact.createdAt,
            title: artifact.title,
            body: artifact.body,
            isRunning: artifact.isStreaming,
          ),
        );
      case CodexTurnWorkArtifact():
        projected.add(
          CodexWorkLogGroupBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            entries: artifact.entries,
          ),
        );
      case CodexTurnPlanArtifact():
        projected.add(
          CodexProposedPlanBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            title: artifact.title,
            markdown: artifact.markdown,
            isStreaming: artifact.isStreaming,
          ),
        );
      case CodexTurnChangedFilesArtifact():
        projected.add(
          CodexChangedFilesBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            title: artifact.title,
            files: artifact.files,
            unifiedDiff: artifact.unifiedDiff,
            isRunning: artifact.isStreaming,
          ),
        );
      case CodexTurnBlockArtifact():
        projected.add(artifact.block);
    }
  }

  return projected;
}

List<CodexTurnArtifact> appendCodexTurnArtifact(
  List<CodexTurnArtifact> artifacts,
  CodexTurnArtifact nextArtifact,
) {
  final nextArtifacts = List<CodexTurnArtifact>.from(artifacts);
  if (nextArtifacts.isNotEmpty) {
    nextArtifacts[nextArtifacts.length - 1] = freezeCodexTurnArtifact(
      nextArtifacts.last,
    );
  }
  nextArtifacts.add(nextArtifact);
  return nextArtifacts;
}

CodexTurnArtifact freezeCodexTurnArtifact(CodexTurnArtifact artifact) {
  return switch (artifact) {
    CodexTurnTextArtifact(:final isStreaming) when isStreaming =>
      CodexTurnTextArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        kind: artifact.kind,
        title: artifact.title,
        body: artifact.body,
        itemId: artifact.itemId,
        isStreaming: false,
      ),
    CodexTurnWorkArtifact() => CodexTurnWorkArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      entries: artifact.entries
          .map((entry) => entry.copyWith(isRunning: false))
          .toList(growable: false),
    ),
    CodexTurnPlanArtifact(:final isStreaming) when isStreaming =>
      CodexTurnPlanArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        title: artifact.title,
        markdown: artifact.markdown,
        itemId: artifact.itemId,
        isStreaming: false,
      ),
    CodexTurnChangedFilesArtifact(:final isStreaming) when isStreaming =>
      CodexTurnChangedFilesArtifact(
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
    CodexTurnBlockArtifact(:final block) => CodexTurnBlockArtifact(
      block: _freezeCodexUiBlock(block),
    ),
    _ => artifact,
  };
}

CodexUiBlock _freezeCodexUiBlock(CodexUiBlock block) {
  return switch (block) {
    CodexTextBlock(:final isRunning) when isRunning => block.copyWith(
      isRunning: false,
    ),
    CodexProposedPlanBlock(:final isStreaming) when isStreaming =>
      block.copyWith(isStreaming: false),
    CodexChangedFilesBlock(:final isRunning) when isRunning => block.copyWith(
      isRunning: false,
    ),
    _ => block,
  };
}

bool _shouldAppearInTranscript(CodexUiBlock block) {
  return switch (block) {
    CodexApprovalRequestBlock(:final isResolved) => isResolved,
    CodexUserInputRequestBlock(:final isResolved) => isResolved,
    CodexStatusBlock(:final isTranscriptSignal) => isTranscriptSignal,
    _ => true,
  };
}
