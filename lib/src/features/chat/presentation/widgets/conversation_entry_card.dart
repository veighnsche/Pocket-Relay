import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ConversationEntryCard extends StatelessWidget {
  const ConversationEntryCard({
    super.key,
    required this.block,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
  });

  final CodexUiBlock block;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      final CodexUserMessageBlock userBlock => _UserMessageCard(
        block: userBlock,
      ),
      final CodexTextBlock textBlock => _TextBlockCard(block: textBlock),
      final CodexPlanUpdateBlock planUpdateBlock => _PlanUpdateCard(
        block: planUpdateBlock,
      ),
      final CodexProposedPlanBlock proposedPlanBlock => _ProposedPlanCard(
        block: proposedPlanBlock,
      ),
      final CodexCommandExecutionBlock commandBlock => _CommandCard(
        block: commandBlock,
      ),
      final CodexWorkLogEntryBlock workLogEntryBlock => _WorkLogGroupCard(
        block: CodexWorkLogGroupBlock(
          id: workLogEntryBlock.id,
          createdAt: workLogEntryBlock.createdAt,
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: workLogEntryBlock.id,
              createdAt: workLogEntryBlock.createdAt,
              entryKind: workLogEntryBlock.entryKind,
              title: workLogEntryBlock.title,
              preview: workLogEntryBlock.preview,
              isRunning: workLogEntryBlock.isRunning,
              exitCode: workLogEntryBlock.exitCode,
            ),
          ],
        ),
      ),
      final CodexWorkLogGroupBlock workLogGroupBlock => _WorkLogGroupCard(
        block: workLogGroupBlock,
      ),
      final CodexChangedFilesBlock changedFilesBlock => _ChangedFilesCard(
        block: changedFilesBlock,
      ),
      final CodexApprovalRequestBlock approvalBlock => _ApprovalRequestCard(
        block: approvalBlock,
        onApprove: onApproveRequest,
        onDeny: onDenyRequest,
      ),
      final CodexUserInputRequestBlock userInputBlock => _UserInputRequestCard(
        block: userInputBlock,
        onSubmit: onSubmitUserInput,
      ),
      final CodexStatusBlock statusBlock => _MetaCard(
        title: statusBlock.title,
        body: statusBlock.body,
        accent: const Color(0xFF0F766E),
        icon: Icons.info_outline,
      ),
      final CodexErrorBlock errorBlock => _MetaCard(
        title: errorBlock.title,
        body: errorBlock.body,
        accent: const Color(0xFFB91C1C),
        icon: Icons.warning_amber_rounded,
      ),
      final CodexUsageBlock usageBlock => _MetaCard(
        title: usageBlock.title,
        body: usageBlock.body,
        accent: const Color(0xFF7C3AED),
        icon: Icons.analytics_outlined,
      ),
    };
  }
}

class _UserMessageCard extends StatelessWidget {
  const _UserMessageCard({required this.block});

  final CodexUserMessageBlock block;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.only(left: 56),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F766E),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                block.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextBlockCard extends StatelessWidget {
  const _TextBlockCard({required this.block});

  final CodexTextBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteFor(block.kind);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        color: const Color(0xFF1C1917),
        height: 1.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF0EBDE),
        borderRadius: BorderRadius.circular(16),
      ),
      blockquoteDecoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      h1: theme.textTheme.headlineSmall,
      h2: theme.textTheme.titleLarge,
      h3: theme.textTheme.titleMedium,
      code: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1C1917),
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF0EBDE),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(palette.icon, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Text(
                  block.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                    letterSpacing: 0.4,
                  ),
                ),
                if (block.isRunning) ...[
                  const SizedBox(width: 10),
                  const _InlinePulseChip(label: 'running'),
                ],
              ],
            ),
            if (block.isRunning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                minHeight: 2,
                color: palette.accent,
                backgroundColor: palette.accent.withValues(alpha: 0.08),
              ),
            ],
            const SizedBox(height: 12),
            MarkdownBody(
              data: block.body.trim().isEmpty
                  ? '_Waiting for content…_'
                  : block.body,
              selectable: true,
              styleSheet: markdownStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanUpdateCard extends StatelessWidget {
  const _PlanUpdateCard({required this.block});

  final CodexPlanUpdateBlock block;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFBFDBFE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.checklist_rtl, size: 18, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'Plan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            if (block.explanation != null &&
                block.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                block.explanation!,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (block.steps.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...block.steps.map((step) {
                final status = _planStepStatus(step.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: status.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(status.icon, size: 18, color: status.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.step,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Badge(label: status.label, color: status.accent),
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Waiting for plan steps…',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposedPlanCard extends StatefulWidget {
  const _ProposedPlanCard({required this.block});

  final CodexProposedPlanBlock block;

  @override
  State<_ProposedPlanCard> createState() => _ProposedPlanCardState();
}

class _ProposedPlanCardState extends State<_ProposedPlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        color: const Color(0xFF1C1917),
        height: 1.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF0EBDE),
        borderRadius: BorderRadius.circular(16),
      ),
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(16),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF1C1917),
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFF0EBDE),
      ),
    );
    final title =
        _proposedPlanTitle(widget.block.markdown) ?? widget.block.title;
    final displayedMarkdown = _stripDisplayedPlanMarkdown(
      widget.block.markdown,
    );
    final lineCount = '\n'.allMatches(displayedMarkdown).length + 1;
    final canCollapse = displayedMarkdown.length > 900 || lineCount > 20;
    final displayedText = _expanded || !canCollapse
        ? displayedMarkdown
        : _buildCollapsedPlanPreview(
            widget.block.markdown,
            maxVisibleLines: 10,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFBFDBFE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (widget.block.isStreaming)
                  const _InlinePulseChip(label: 'drafting'),
              ],
            ),
            const SizedBox(height: 14),
            Stack(
              children: [
                MarkdownBody(
                  data: displayedText.trim().isEmpty
                      ? '_Waiting for plan…_'
                      : displayedText,
                  selectable: true,
                  styleSheet: markdownStyle,
                ),
                if (canCollapse && !_expanded)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 48,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x00FFFFFF),
                              Color(0xFFFFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (canCollapse) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Collapse plan' : 'Expand plan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkLogGroupCard extends StatefulWidget {
  const _WorkLogGroupCard({required this.block});

  final CodexWorkLogGroupBlock block;

  @override
  State<_WorkLogGroupCard> createState() => _WorkLogGroupCardState();
}

class _WorkLogGroupCardState extends State<_WorkLogGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.block.entries;
    final hasOverflow = entries.length > 4;
    final visibleEntries = hasOverflow && !_expanded
        ? entries.skip(entries.length - 4).toList(growable: false)
        : entries;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD7CDB8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.construction_outlined,
                  size: 18,
                  color: Color(0xFF78716C),
                ),
                const SizedBox(width: 8),
                Text(
                  entries.every(
                        (entry) =>
                            entry.entryKind != CodexWorkLogEntryKind.unknown,
                      )
                      ? 'Work log'
                      : 'Activity',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF57534E),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length}',
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...visibleEntries.map((entry) => _WorkLogEntryRow(entry: entry)),
            if (hasOverflow) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? 'Show less'
                      : 'Show ${entries.length - visibleEntries.length} more',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkLogEntryRow extends StatelessWidget {
  const _WorkLogEntryRow({required this.entry});

  final CodexWorkLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = _workLogIcon(entry.entryKind);
    final accent = _workLogAccent(entry.entryKind);
    final title = _normalizeCompactToolLabel(entry.title);
    final preview = _normalizedWorkLogPreview(entry.preview, title);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF57534E),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (entry.isRunning)
            const _Badge(label: 'running', color: Color(0xFF0F766E))
          else if (entry.exitCode != null)
            _Badge(
              label: 'exit ${entry.exitCode}',
              color: entry.exitCode == 0
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFDC2626),
            ),
        ],
      ),
    );
  }
}

class _ChangedFilesCard extends StatefulWidget {
  const _ChangedFilesCard({required this.block});

  final CodexChangedFilesBlock block;

  @override
  State<_ChangedFilesCard> createState() => _ChangedFilesCardState();
}

class _ChangedFilesCardState extends State<_ChangedFilesCard> {
  bool _showDiff = false;

  @override
  Widget build(BuildContext context) {
    final files = widget.block.files;
    final diff = widget.block.unifiedDiff?.trim();
    final canToggleDiff = diff != null && diff.isNotEmpty;
    final fileCountLabel =
        '${files.length} ${files.length == 1 ? 'file' : 'files'}';
    final totalAdditions = files.fold<int>(
      0,
      (sum, file) => sum + file.additions,
    );
    final totalDeletions = files.fold<int>(
      0,
      (sum, file) => sum + file.deletions,
    );
    final hasStats = totalAdditions > 0 || totalDeletions > 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFCD34D)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.drive_file_rename_outline,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.block.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (widget.block.isRunning)
                  const _InlinePulseChip(label: 'updating'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  fileCountLabel,
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (hasStats) ...[
                  const SizedBox(width: 8),
                  Text(
                    '+$totalAdditions -$totalDeletions',
                    style: const TextStyle(
                      color: Color(0xFF57534E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (files.isEmpty)
              const Text(
                'Waiting for changed files…',
                style: TextStyle(color: Color(0xFF78716C)),
              )
            else
              Column(
                children: files
                    .map(
                      (file) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFFCD34D,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 14,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                file.path,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF44403C),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            if (file.additions > 0 || file.deletions > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '+${file.additions} -${file.deletions}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF78716C),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (canToggleDiff) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => setState(() => _showDiff = !_showDiff),
                child: Text(_showDiff ? 'Hide diff' : 'Show diff'),
              ),
            ],
            if (_showDiff && diff != null && diff.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  diff,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.block});

  final CodexCommandExecutionBlock block;

  @override
  Widget build(BuildContext context) {
    final output = block.output.trim().isEmpty
        ? 'Waiting for output…'
        : block.output;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  const Icon(Icons.terminal, color: Colors.white70, size: 18),
                  Text(
                    block.command,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (block.isRunning)
                    const _StateChip(label: 'running', color: Color(0xFF0F766E))
                  else if (block.exitCode != null)
                    _StateChip(
                      label: 'exit ${block.exitCode}',
                      color: block.exitCode == 0
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFDC2626),
                    ),
                ],
              ),
            ),
            if (block.isRunning)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SelectableText(
                output,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalRequestCard extends StatelessWidget {
  const _ApprovalRequestCard({
    required this.block,
    this.onApprove,
    this.onDeny,
  });

  final CodexApprovalRequestBlock block;
  final Future<void> Function(String requestId)? onApprove;
  final Future<void> Function(String requestId)? onDeny;

  @override
  Widget build(BuildContext context) {
    final canRespond = !block.isResolved && onApprove != null && onDeny != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10F59E0B),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gpp_maybe_outlined, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    block.title,
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (block.isResolved)
                  _Badge(
                    label: block.resolutionLabel ?? 'resolved',
                    color: const Color(0xFFB45309),
                  ),
              ],
            ),
            if (block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                block.body,
                style: const TextStyle(
                  color: Color(0xFF3F3F46),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(
                  onPressed: canRespond ? () => onDeny!(block.requestId) : null,
                  child: const Text('Deny'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: canRespond
                      ? () => onApprove!(block.requestId)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserInputRequestCard extends StatefulWidget {
  const _UserInputRequestCard({required this.block, this.onSubmit});

  final CodexUserInputRequestBlock block;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmit;

  @override
  State<_UserInputRequestCard> createState() => _UserInputRequestCardState();
}

class _UserInputRequestCardState extends State<_UserInputRequestCard> {
  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final question in widget.block.questions) {
      _controllers[question.id] = TextEditingController(
        text: widget.block.answers[question.id]?.join(', ') ?? '',
      );
    }
    if (widget.block.questions.isEmpty) {
      _controllers['response'] = TextEditingController(
        text: widget.block.answers['response']?.join(', ') ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !widget.block.isResolved && widget.onSubmit != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.block.title,
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.block.isResolved)
                  const _Badge(label: 'submitted', color: Color(0xFF2563EB)),
              ],
            ),
            if (widget.block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                widget.block.body,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ..._buildFields(),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: const Text('Submit response'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    if (widget.block.questions.isEmpty) {
      return <Widget>[
        TextField(
          controller: _controllers['response'],
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Response',
            border: OutlineInputBorder(),
          ),
        ),
      ];
    }

    return widget.block.questions.map((question) {
      final controller = _controllers[question.id]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.header,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              question.question,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.options
                    .map(
                      (option) => ActionChip(
                        label: Text(option.label),
                        onPressed: widget.block.isResolved
                            ? null
                            : () => controller.text = option.label,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              obscureText: question.isSecret,
              minLines: 1,
              maxLines: question.isOther ? 4 : 2,
              decoration: InputDecoration(
                labelText: question.isOther ? 'Custom answer' : 'Answer',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _submit() async {
    final answers = <String, List<String>>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        continue;
      }
      answers[entry.key] = <String>[value];
    }

    await widget.onSubmit?.call(widget.block.requestId, answers);
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String body;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      body,
                      style: const TextStyle(
                        color: Color(0xFF292524),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlinePulseChip extends StatelessWidget {
  const _InlinePulseChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0F766E),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BlockPalette {
  const _BlockPalette({
    required this.accent,
    required this.border,
    required this.icon,
  });

  final Color accent;
  final Color border;
  final IconData icon;
}

_BlockPalette _paletteFor(CodexUiBlockKind kind) {
  return switch (kind) {
    CodexUiBlockKind.reasoning => const _BlockPalette(
      accent: Color(0xFF7C3AED),
      border: Color(0xFFD8B4FE),
      icon: Icons.psychology_alt_outlined,
    ),
    CodexUiBlockKind.plan ||
    CodexUiBlockKind.proposedPlan => const _BlockPalette(
      accent: Color(0xFF2563EB),
      border: Color(0xFFBFDBFE),
      icon: Icons.checklist_rtl,
    ),
    CodexUiBlockKind.fileChange ||
    CodexUiBlockKind.changedFiles => const _BlockPalette(
      accent: Color(0xFFB45309),
      border: Color(0xFFFCD34D),
      icon: Icons.drive_file_rename_outline,
    ),
    _ => const _BlockPalette(
      accent: Color(0xFF0F766E),
      border: Color(0xFFD5CCB8),
      icon: Icons.auto_awesome,
    ),
  };
}

class _PlanStepStatusPresentation {
  const _PlanStepStatusPresentation({
    required this.label,
    required this.accent,
    required this.border,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color accent;
  final Color border;
  final Color background;
  final IconData icon;
}

_PlanStepStatusPresentation _planStepStatus(CodexRuntimePlanStepStatus status) {
  return switch (status) {
    CodexRuntimePlanStepStatus.completed => const _PlanStepStatusPresentation(
      label: 'done',
      accent: Color(0xFF0F766E),
      border: Color(0xFFA7F3D0),
      background: Color(0xFFF0FDFA),
      icon: Icons.check_circle_outline,
    ),
    CodexRuntimePlanStepStatus.inProgress => const _PlanStepStatusPresentation(
      label: 'active',
      accent: Color(0xFF2563EB),
      border: Color(0xFFBFDBFE),
      background: Color(0xFFEFF6FF),
      icon: Icons.timelapse_outlined,
    ),
    CodexRuntimePlanStepStatus.pending => const _PlanStepStatusPresentation(
      label: 'pending',
      accent: Color(0xFF78716C),
      border: Color(0xFFE7E5E4),
      background: Color(0xFFFAFAF9),
      icon: Icons.radio_button_unchecked,
    ),
  };
}

IconData _workLogIcon(CodexWorkLogEntryKind kind) {
  return switch (kind) {
    CodexWorkLogEntryKind.commandExecution => Icons.terminal,
    CodexWorkLogEntryKind.webSearch => Icons.travel_explore,
    CodexWorkLogEntryKind.imageView => Icons.image_outlined,
    CodexWorkLogEntryKind.mcpToolCall => Icons.extension_outlined,
    CodexWorkLogEntryKind.dynamicToolCall => Icons.build_outlined,
    CodexWorkLogEntryKind.collabAgentToolCall => Icons.groups_2_outlined,
    CodexWorkLogEntryKind.fileChange => Icons.drive_file_rename_outline,
    CodexWorkLogEntryKind.unknown => Icons.auto_awesome,
  };
}

Color _workLogAccent(CodexWorkLogEntryKind kind) {
  return switch (kind) {
    CodexWorkLogEntryKind.commandExecution => const Color(0xFF2563EB),
    CodexWorkLogEntryKind.webSearch => const Color(0xFF0F766E),
    CodexWorkLogEntryKind.imageView => const Color(0xFF7C3AED),
    CodexWorkLogEntryKind.mcpToolCall => const Color(0xFFB45309),
    CodexWorkLogEntryKind.dynamicToolCall => const Color(0xFFDC2626),
    CodexWorkLogEntryKind.collabAgentToolCall => const Color(0xFF9333EA),
    CodexWorkLogEntryKind.fileChange => const Color(0xFFB45309),
    CodexWorkLogEntryKind.unknown => const Color(0xFF0F766E),
  };
}

String _normalizeCompactToolLabel(String value) {
  return value
      .replaceFirst(
        RegExp(r'\s+(?:complete|completed)\s*$', caseSensitive: false),
        '',
      )
      .trim();
}

String? _normalizedWorkLogPreview(String? preview, String normalizedTitle) {
  final value = preview?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value == normalizedTitle) {
    return null;
  }
  return value;
}

String? _proposedPlanTitle(String markdown) {
  final match = RegExp(
    r'^\s{0,3}#{1,6}\s+(.+)$',
    multiLine: true,
  ).firstMatch(markdown);
  final title = match?.group(1)?.trim();
  return title == null || title.isEmpty ? null : title;
}

String _stripDisplayedPlanMarkdown(String markdown) {
  final sourceLines = markdown.trimRight().split(RegExp(r'\r?\n')).toList();
  if (sourceLines.isNotEmpty &&
      RegExp(r'^\s{0,3}#{1,6}\s+').hasMatch(sourceLines.first)) {
    sourceLines.removeAt(0);
  }

  while (sourceLines.isNotEmpty && sourceLines.first.trim().isEmpty) {
    sourceLines.removeAt(0);
  }

  if (sourceLines.isNotEmpty) {
    final summaryMatch = RegExp(
      r'^\s{0,3}#{1,6}\s+(.+)$',
    ).firstMatch(sourceLines.first);
    if (summaryMatch?.group(1)?.trim().toLowerCase() == 'summary') {
      sourceLines.removeAt(0);
      while (sourceLines.isNotEmpty && sourceLines.first.trim().isEmpty) {
        sourceLines.removeAt(0);
      }
    }
  }

  return sourceLines.join('\n');
}

String _buildCollapsedPlanPreview(String markdown, {int maxVisibleLines = 8}) {
  final lines = _stripDisplayedPlanMarkdown(markdown)
      .trimRight()
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trimRight())
      .toList();
  final previewLines = <String>[];
  var visibleLineCount = 0;
  var hasMoreContent = false;

  for (final line in lines) {
    final isVisibleLine = line.trim().isNotEmpty;
    if (isVisibleLine && visibleLineCount >= maxVisibleLines) {
      hasMoreContent = true;
      break;
    }
    previewLines.add(line);
    if (isVisibleLine) {
      visibleLineCount += 1;
    }
  }

  while (previewLines.isNotEmpty && previewLines.last.trim().isEmpty) {
    previewLines.removeLast();
  }

  if (previewLines.isEmpty) {
    return _proposedPlanTitle(markdown) ?? 'Plan preview unavailable.';
  }

  if (hasMoreContent) {
    previewLines.addAll(const <String>['', '...']);
  }

  return previewLines.join('\n');
}
