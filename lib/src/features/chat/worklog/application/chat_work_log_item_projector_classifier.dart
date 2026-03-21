part of 'chat_work_log_item_projector.dart';

typedef _EntryClassifier =
    ChatWorkLogEntryContract? Function(
      ChatWorkLogItemProjector projector,
      CodexWorkLogEntry entry,
      String normalizedTitle,
    );

final List<_EntryClassifier> _entryClassifiers = <_EntryClassifier>[
  (projector, entry, normalizedTitle) =>
      entry.entryKind == CodexWorkLogEntryKind.mcpToolCall
      ? projector._projectMcpToolCall(entry)
      : null,
  (projector, entry, normalizedTitle) =>
      entry.entryKind == CodexWorkLogEntryKind.webSearch
      ? projector._projectWebSearch(entry)
      : null,
  (projector, entry, normalizedTitle) =>
      entry.entryKind == CodexWorkLogEntryKind.commandExecution
      ? projector._projectCommandWait(entry, normalizedTitle: normalizedTitle)
      : null,
  (projector, entry, normalizedTitle) =>
      switch (entry.entryKind == CodexWorkLogEntryKind.commandExecution
      ? _tryParseReadCommand(normalizedTitle)
      : null) {
        final _ParsedReadCommand readCommand => projector._projectReadCommand(
          readCommand: readCommand,
          entry: entry,
          normalizedTitle: normalizedTitle,
        ),
        _ => null,
      },
  (projector, entry, normalizedTitle) =>
      switch (entry.entryKind == CodexWorkLogEntryKind.commandExecution
      ? _tryParseGitCommand(normalizedTitle)
      : null) {
        final _ParsedGitCommand gitCommand => projector._projectGitCommand(
          gitCommand: gitCommand,
          entry: entry,
          normalizedTitle: normalizedTitle,
        ),
        _ => null,
      },
  (projector, entry, normalizedTitle) =>
      switch (entry.entryKind == CodexWorkLogEntryKind.commandExecution
      ? _tryParseContentSearchCommand(normalizedTitle)
      : null) {
        final _ParsedContentSearchCommand searchCommand =>
          projector._projectSearchCommand(
            searchCommand: searchCommand,
            entry: entry,
            normalizedTitle: normalizedTitle,
          ),
        _ => null,
      },
  (projector, entry, normalizedTitle) =>
      entry.entryKind == CodexWorkLogEntryKind.commandExecution
      ? projector._projectCommandExecution(
          entry,
          normalizedTitle: normalizedTitle,
        )
      : null,
];
