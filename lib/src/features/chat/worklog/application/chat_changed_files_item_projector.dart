import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';

part 'chat_changed_files_item_projector_diff.dart';
part 'chat_changed_files_item_projector_review.dart';
part 'chat_changed_files_item_projector_support.dart';

class ChatChangedFilesItemProjector {
  const ChatChangedFilesItemProjector();

  ChatChangedFilesItemContract project(TranscriptChangedFilesBlock block) {
    final patches = _parseUnifiedDiff(block.unifiedDiff);
    final files = _displayFiles(block.files, patches);
    final headerStats = _resolveHeaderStats(files: files, patches: patches);

    return ChatChangedFilesItemContract(
      id: block.id,
      title: block.title,
      isRunning: block.isRunning,
      headerStats: ChatChangedFileStatsContract(
        additions: headerStats.additions,
        deletions: headerStats.deletions,
      ),
      rows: files.indexed
          .map(
            (entry) => _projectChangedFileRow(
              blockId: block.id,
              index: entry.$1,
              file: entry.$2,
              patches: patches,
              totalFiles: files.length,
            ),
          )
          .toList(growable: false),
    );
  }

  ChatChangedFileDiffLineKind _mapLineKind(_DiffLineKind kind) {
    return switch (kind) {
      _DiffLineKind.meta => ChatChangedFileDiffLineKind.meta,
      _DiffLineKind.hunk => ChatChangedFileDiffLineKind.hunk,
      _DiffLineKind.addition => ChatChangedFileDiffLineKind.addition,
      _DiffLineKind.deletion => ChatChangedFileDiffLineKind.deletion,
      _DiffLineKind.context => ChatChangedFileDiffLineKind.context,
    };
  }
}
