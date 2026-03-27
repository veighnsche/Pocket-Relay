part of 'work_log_group_surface.dart';

class _WorkLogEntryRow extends StatelessWidget {
  const _WorkLogEntryRow({required this.entry, this.onOpenTerminal});

  final ChatWorkLogEntryContract entry;
  final void Function(ChatWorkLogTerminalContract terminal)? onOpenTerminal;

  VoidCallback? _shellRowTap(ChatShellWorkLogEntryContract shellEntry) {
    final openTerminal = onOpenTerminal;
    if (openTerminal == null) {
      return null;
    }
    return () =>
        openTerminal(ChatWorkLogTerminalContract.fromEntry(shellEntry));
  }

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final ChatSedReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: blueAccent(Theme.of(context).brightness),
        icon: Icons.menu_book_outlined,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatCatReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: tealAccent(Theme.of(context).brightness),
        icon: Icons.description_outlined,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatTypeReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: redAccent(Theme.of(context).brightness),
        icon: Icons.text_snippet_outlined,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatMoreReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.read_more_outlined,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatHeadReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.vertical_align_top,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatTailReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: pinkAccent(Theme.of(context).brightness),
        icon: Icons.vertical_align_bottom,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatGetContentReadWorkLogEntryContract readEntry =>
        _ReadWorkLogEntryRow(
          entry: readEntry,
          accent: violetAccent(Theme.of(context).brightness),
          icon: Icons.subject_outlined,
          onTap: _shellRowTap(readEntry),
        ),
      final ChatAwkReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: violetAccent(Theme.of(context).brightness),
        icon: Icons.code_outlined,
        onTap: _shellRowTap(readEntry),
      ),
      final ChatRipgrepSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: tealAccent(Theme.of(context).brightness),
          icon: Icons.manage_search_outlined,
          onTap: _shellRowTap(searchEntry),
        ),
      final ChatGrepSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: blueAccent(Theme.of(context).brightness),
          icon: Icons.saved_search_outlined,
          onTap: _shellRowTap(searchEntry),
        ),
      final ChatSelectStringSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: violetAccent(Theme.of(context).brightness),
          icon: Icons.find_in_page_outlined,
          onTap: _shellRowTap(searchEntry),
        ),
      final ChatFindStrSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: amberAccent(Theme.of(context).brightness),
          icon: Icons.travel_explore_outlined,
          onTap: _shellRowTap(searchEntry),
        ),
      final ChatGitWorkLogEntryContract gitEntry => _GitWorkLogEntryRow(
        entry: gitEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.source_outlined,
        onTap: _shellRowTap(gitEntry),
      ),
      final ChatCommandWaitWorkLogEntryContract waitEntry =>
        _CommandWaitWorkLogEntryRow(
          entry: waitEntry,
          accent: Theme.of(context).colorScheme.tertiary,
          icon: Icons.hourglass_top_rounded,
          onTap: _shellRowTap(waitEntry),
        ),
      final ChatCommandExecutionWorkLogEntryContract commandEntry =>
        _CommandExecutionWorkLogEntryRow(
          entry: commandEntry,
          accent: blueAccent(Theme.of(context).brightness),
          icon: Icons.terminal_outlined,
          onTap: _shellRowTap(commandEntry),
        ),
      final ChatWebSearchWorkLogEntryContract webSearchEntry =>
        _WebSearchWorkLogEntryRow(
          entry: webSearchEntry,
          accent: tealAccent(Theme.of(context).brightness),
          icon: Icons.travel_explore_outlined,
        ),
      final ChatMcpToolCallWorkLogEntryContract mcpEntry =>
        _McpToolCallWorkLogEntryRow(
          entry: mcpEntry,
          accent: mcpEntry.status == ChatMcpToolCallStatus.failed
              ? redAccent(Theme.of(context).brightness)
              : amberAccent(Theme.of(context).brightness),
          icon: Icons.extension_outlined,
        ),
      final ChatGenericWorkLogEntryContract genericEntry =>
        _GenericWorkLogEntryRow(entry: genericEntry),
    };
  }
}
