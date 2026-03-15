import 'package:pocket_relay/src/features/chat/application/transcript_changed_files_parser.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptItemBlockFactory {
  const TranscriptItemBlockFactory({
    TranscriptChangedFilesParser changedFilesParser =
        const TranscriptChangedFilesParser(),
  }) : _changedFilesParser = changedFilesParser;

  final TranscriptChangedFilesParser _changedFilesParser;

  CodexUiBlock blockFromActiveItem(CodexSessionActiveItem item) {
    final title = item.title ?? defaultItemTitle(item.itemType);
    return switch (item.blockKind) {
      CodexUiBlockKind.userMessage => CodexUserMessageBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        text: item.body,
        deliveryState: CodexUserMessageDeliveryState.sent,
        providerItemId: item.itemId,
      ),
      CodexUiBlockKind.commandExecution => CodexCommandExecutionBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        command: title,
        output: item.body,
        turnId: item.turnId,
        isRunning: item.isRunning,
        exitCode: item.exitCode,
      ),
      CodexUiBlockKind.workLogEntry => CodexWorkLogEntryBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        entryKind: workLogEntryKindFor(item.itemType),
        turnId: item.turnId,
        preview: workLogPreview(item),
        isRunning: item.isRunning,
        exitCode: item.exitCode,
      ),
      CodexUiBlockKind.changedFiles => CodexChangedFilesBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        files: _changedFilesParser.changedFilesFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        unifiedDiff: _changedFilesParser.unifiedDiffFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        turnId: item.turnId,
        isRunning: item.isRunning,
      ),
      CodexUiBlockKind.reasoning => CodexTextBlock(
        id: item.entryId,
        kind: CodexUiBlockKind.reasoning,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
        turnId: item.turnId,
        isRunning: item.isRunning,
      ),
      CodexUiBlockKind.proposedPlan => CodexProposedPlanBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        markdown: item.body,
        turnId: item.turnId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.plan => CodexPlanUpdateBlock(
        id: item.entryId,
        createdAt: item.createdAt,
      ),
      CodexUiBlockKind.status => CodexStatusBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
      ),
      CodexUiBlockKind.error => CodexErrorBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
      ),
      _ => CodexTextBlock(
        id: item.entryId,
        kind: CodexUiBlockKind.assistantMessage,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
        turnId: item.turnId,
        isRunning: item.isRunning,
      ),
    };
  }

  CodexUiBlockKind blockKindForItemType(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => CodexUiBlockKind.userMessage,
      CodexCanonicalItemType.commandExecution ||
      CodexCanonicalItemType.webSearch ||
      CodexCanonicalItemType.imageView ||
      CodexCanonicalItemType.imageGeneration ||
      CodexCanonicalItemType.mcpToolCall ||
      CodexCanonicalItemType.dynamicToolCall ||
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexUiBlockKind.workLogEntry,
      CodexCanonicalItemType.reasoning => CodexUiBlockKind.reasoning,
      CodexCanonicalItemType.plan => CodexUiBlockKind.proposedPlan,
      CodexCanonicalItemType.fileChange => CodexUiBlockKind.changedFiles,
      CodexCanonicalItemType.reviewEntered ||
      CodexCanonicalItemType.reviewExited ||
      CodexCanonicalItemType.contextCompaction ||
      CodexCanonicalItemType.unknown => CodexUiBlockKind.status,
      CodexCanonicalItemType.error => CodexUiBlockKind.error,
      _ => CodexUiBlockKind.assistantMessage,
    };
  }

  String defaultItemTitle(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => 'You',
      CodexCanonicalItemType.assistantMessage => 'Codex',
      CodexCanonicalItemType.reasoning => 'Reasoning',
      CodexCanonicalItemType.plan => 'Proposed plan',
      CodexCanonicalItemType.commandExecution => 'Command',
      CodexCanonicalItemType.fileChange => 'Changed files',
      CodexCanonicalItemType.webSearch => 'Web search',
      CodexCanonicalItemType.imageView => 'Image view',
      CodexCanonicalItemType.imageGeneration => 'Image generation',
      CodexCanonicalItemType.mcpToolCall => 'MCP tool call',
      CodexCanonicalItemType.dynamicToolCall => 'Tool call',
      CodexCanonicalItemType.collabAgentToolCall => 'Agent tool call',
      CodexCanonicalItemType.reviewEntered => 'Review started',
      CodexCanonicalItemType.reviewExited => 'Review finished',
      CodexCanonicalItemType.contextCompaction => 'Context compacted',
      CodexCanonicalItemType.error => 'Error',
      _ => 'Codex',
    };
  }

  CodexWorkLogEntryKind workLogEntryKindFor(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution =>
        CodexWorkLogEntryKind.commandExecution,
      CodexCanonicalItemType.webSearch => CodexWorkLogEntryKind.webSearch,
      CodexCanonicalItemType.imageView => CodexWorkLogEntryKind.imageView,
      CodexCanonicalItemType.imageGeneration =>
        CodexWorkLogEntryKind.imageGeneration,
      CodexCanonicalItemType.mcpToolCall => CodexWorkLogEntryKind.mcpToolCall,
      CodexCanonicalItemType.dynamicToolCall =>
        CodexWorkLogEntryKind.dynamicToolCall,
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexWorkLogEntryKind.collabAgentToolCall,
      CodexCanonicalItemType.fileChange => CodexWorkLogEntryKind.fileChange,
      _ => CodexWorkLogEntryKind.unknown,
    };
  }

  String? workLogPreview(CodexSessionActiveItem item) {
    final body = item.body.trim();
    if (body.isEmpty) {
      return null;
    }

    if (item.itemType == CodexCanonicalItemType.commandExecution) {
      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return lines.isEmpty ? null : lines.last;
    }

    return body.split(RegExp(r'\r?\n')).first.trim();
  }
}
