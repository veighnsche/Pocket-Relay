import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

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
    final brightness = Theme.of(context).brightness;
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
        accent: _tealAccent(brightness),
        icon: Icons.info_outline,
      ),
      final CodexErrorBlock errorBlock => _MetaCard(
        title: errorBlock.title,
        body: errorBlock.body,
        accent: _redAccent(brightness),
        icon: Icons.warning_amber_rounded,
      ),
      final CodexUsageBlock usageBlock => _UsageCard(
        block: usageBlock,
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
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          margin: const EdgeInsets.only(left: 48),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F766E),
                blurRadius: 16,
                offset: Offset(0, 8),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                block.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
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
    final cards = _ConversationCardPalette.of(context);
    final palette = _paletteFor(block.kind, theme.brightness);
    final isAssistant = block.kind == CodexUiBlockKind.assistantMessage;
    final cardRadius = isAssistant ? 22.0 : 20.0;
    final cardPadding = EdgeInsets.fromLTRB(
      isAssistant ? 16 : 14,
      isAssistant ? 15 : 12,
      isAssistant ? 16 : 14,
      isAssistant ? 16 : 13,
    );
    final blockSurface = isAssistant
        ? cards.tintedSurface(palette.accent, lightAlpha: 0.1, darkAlpha: 0.18)
        : cards.surface;
    final cardBorder = isAssistant
        ? cards.accentBorder(palette.accent, lightAlpha: 0.42, darkAlpha: 0.56)
        : palette.border;
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        color: cards.textPrimary,
        fontSize: isAssistant ? 16 : 14,
        height: isAssistant ? 1.45 : 1.38,
      ),
      codeblockDecoration: BoxDecoration(
        color: cards.codeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      blockquoteDecoration: BoxDecoration(
        color: cards.tintedSurface(
          palette.accent,
          lightAlpha: 0.08,
          darkAlpha: 0.18,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      h1: theme.textTheme.headlineSmall?.copyWith(
        color: cards.textPrimary,
        fontSize: isAssistant ? 21 : 19,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: cards.textPrimary,
        fontSize: isAssistant ? 18 : 16,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        color: cards.textPrimary,
        fontSize: isAssistant ? 16 : 15,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        color: cards.codeText,
        fontFamily: 'monospace',
        backgroundColor: cards.codeSurface,
        fontSize: isAssistant ? 14 : 13,
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isAssistant ? 780 : 660),
      child: Container(
        padding: cardPadding,
        decoration: BoxDecoration(
          color: blockSurface,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: cardBorder),
          boxShadow: isAssistant
              ? [
                  BoxShadow(
                    color: palette.accent.withValues(
                      alpha: cards.isDark ? 0.16 : 0.1,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: cards.shadow.withValues(
                      alpha: cards.isDark ? 0.26 : 0.08,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: cards.shadow.withValues(
                      alpha: cards.isDark ? 0.2 : 0.06,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  palette.icon,
                  size: isAssistant ? 18 : 16,
                  color: palette.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  block.title,
                  style: TextStyle(
                    fontSize: isAssistant ? 13 : 12,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                    letterSpacing: isAssistant ? 0.3 : 0.2,
                  ),
                ),
                if (block.isRunning) ...[
                  const SizedBox(width: 8),
                  const _InlinePulseChip(label: 'running'),
                ],
              ],
            ),
            if (block.isRunning) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                minHeight: 2,
                color: palette.accent,
                backgroundColor: palette.accent.withValues(alpha: 0.08),
              ),
            ],
            SizedBox(height: isAssistant ? 10 : 8),
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
    final theme = Theme.of(context);
    final cards = _ConversationCardPalette.of(context);
    final accent = _blueAccent(theme.brightness);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rtl, size: 16, color: accent),
                const SizedBox(width: 7),
                Text(
                  'Plan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            if (block.explanation != null &&
                block.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                block.explanation!,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 13,
                  height: 1.32,
                ),
              ),
            ],
            if (block.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...block.steps.map((step) {
                final status = _planStepStatus(step.status, cards);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: status.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(status.icon, size: 16, color: status.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.step,
                          style: TextStyle(
                            color: cards.textPrimary,
                            fontSize: 13,
                            height: 1.28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Badge(label: status.label, color: status.accent),
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Waiting for plan steps…',
                style: TextStyle(color: cards.textMuted),
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
    final cards = _ConversationCardPalette.of(context);
    final accent = _blueAccent(theme.brightness);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(
        color: cards.textPrimary,
        fontSize: 14,
        height: 1.38,
      ),
      codeblockDecoration: BoxDecoration(
        color: cards.codeSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      blockquoteDecoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        color: cards.codeText,
        fontFamily: 'monospace',
        backgroundColor: cards.codeSurface,
        fontSize: 13,
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
        : _buildCollapsedPlanPreview(widget.block.markdown, maxVisibleLines: 8);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, size: 16, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (widget.block.isStreaming)
                  const _InlinePulseChip(label: 'drafting'),
              ],
            ),
            const SizedBox(height: 10),
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
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              cards.surface.withValues(alpha: 0),
                              cards.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (canCollapse) ...[
              const SizedBox(height: 10),
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
    final cards = _ConversationCardPalette.of(context);
    final entries = widget.block.entries;
    final hasOverflow = entries.length > 3;
    final visibleEntries = hasOverflow && !_expanded
        ? entries.skip(entries.length - 3).toList(growable: false)
        : entries;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cards.neutralBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 16,
                  color: cards.textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  entries.every(
                        (entry) =>
                            entry.entryKind != CodexWorkLogEntryKind.unknown,
                      )
                      ? 'Work log'
                      : 'Activity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cards.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length}',
                  style: TextStyle(
                    color: cards.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visibleEntries.map((entry) => _WorkLogEntryRow(entry: entry)),
            if (hasOverflow) ...[
              const SizedBox(height: 4),
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
    final theme = Theme.of(context);
    final cards = _ConversationCardPalette.of(context);
    final icon = _workLogIcon(entry.entryKind);
    final accent = _workLogAccent(entry.entryKind, theme.brightness);
    final title = _normalizeCompactToolLabel(entry.title);
    final preview = _normalizedWorkLogPreview(entry.preview, title);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textSecondary,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.isRunning)
            _Badge(label: 'running', color: _tealAccent(theme.brightness))
          else if (entry.exitCode != null)
            _Badge(
              label: 'exit ${entry.exitCode}',
              color: entry.exitCode == 0
                  ? _blueAccent(theme.brightness)
                  : _redAccent(theme.brightness),
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
    final theme = Theme.of(context);
    final cards = _ConversationCardPalette.of(context);
    final accent = _amberAccent(theme.brightness);
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
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drive_file_rename_outline, size: 16, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.block.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (widget.block.isRunning)
                  const _InlinePulseChip(label: 'updating'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  fileCountLabel,
                  style: TextStyle(
                    color: cards.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (hasStats) ...[
                  const SizedBox(width: 8),
                  Text(
                    '+$totalAdditions -$totalDeletions',
                    style: TextStyle(color: cards.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (files.isEmpty)
              Text(
                'Waiting for changed files…',
                style: TextStyle(color: cards.textMuted),
              )
            else
              Column(
                children: files
                    .map(
                      (file) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cards.tintedSurface(
                            accent,
                            lightAlpha: 0.08,
                            darkAlpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cards.accentBorder(
                              accent,
                              lightAlpha: 0.32,
                              darkAlpha: 0.42,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 13,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                file.path,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  color: cards.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (file.additions > 0 || file.deletions > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '+${file.additions} -${file.deletions}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cards.textMuted,
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
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => _showDiff = !_showDiff),
                child: Text(_showDiff ? 'Hide diff' : 'Show diff'),
              ),
            ],
            if (_showDiff && diff != null && diff.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cards.terminalBody,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  diff,
                  style: TextStyle(
                    color: cards.terminalText,
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    height: 1.28,
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
    final theme = Theme.of(context);
    final cards = _ConversationCardPalette.of(context);
    final runningColor = _tealAccent(theme.brightness);
    final output = block.output.trim().isEmpty
        ? 'Waiting for output…'
        : block.output;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        decoration: BoxDecoration(
          color: cards.terminalShell,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Icon(
                    Icons.terminal,
                    color: cards.terminalText.withValues(alpha: 0.72),
                    size: 16,
                  ),
                  Text(
                    block.command,
                    style: TextStyle(
                      color: cards.terminalText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (block.isRunning)
                    _StateChip(label: 'running', color: runningColor)
                  else if (block.exitCode != null)
                    _StateChip(
                      label: 'exit ${block.exitCode}',
                      color: block.exitCode == 0
                          ? _blueAccent(theme.brightness)
                          : _redAccent(theme.brightness),
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: cards.terminalBody,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: SelectableText(
                output,
                style: TextStyle(
                  color: cards.terminalText,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.32,
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
    final theme = Theme.of(context);
    final cards = _ConversationCardPalette.of(context);
    final accent = _amberAccent(theme.brightness);
    final canRespond = !block.isResolved && onApprove != null && onDeny != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gpp_maybe_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (block.isResolved)
                  _Badge(
                    label: block.resolutionLabel ?? 'resolved',
                    color: accent,
                  ),
              ],
            ),
            if (block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                block.body,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 13,
                  height: 1.32,
                ),
              ),
            ],
            const SizedBox(height: 10),
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
                    foregroundColor: Colors.white,
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
    final theme = Theme.of(context);
    final cards = _ConversationCardPalette.of(context);
    final accent = _blueAccent(theme.brightness);
    final canSubmit = !widget.block.isResolved && widget.onSubmit != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.06, darkAlpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.block.title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.block.isResolved)
                  _Badge(label: 'submitted', color: accent),
              ],
            ),
            if (widget.block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                widget.block.body,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 13,
                  height: 1.32,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ..._buildFields(),
            const SizedBox(height: 10),
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
    final cards = _ConversationCardPalette.of(context);
    if (widget.block.questions.isEmpty) {
      return <Widget>[
        TextField(
          controller: _controllers['response'],
          minLines: 2,
          maxLines: 3,
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
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.header,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cards.textPrimary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              question.question,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 12,
                height: 1.25,
              ),
            ),
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 6),
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
            const SizedBox(height: 8),
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
    final cards = _ConversationCardPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cards.accentBorder(accent)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, color: accent, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body.trim().isNotEmpty)
                      TextSpan(
                        text: '  ${body.trim()}',
                        style: TextStyle(
                          color: cards.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
                style: TextStyle(color: cards.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.block});

  final CodexUsageBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = _ConversationCardPalette.of(context);
    final accent = _violetAccent(Theme.of(context).brightness);
    final summary = _UsagePresentation.fromBody(block.body);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.05, darkAlpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cards.accentBorder(accent, lightAlpha: 0.24, darkAlpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (summary.contextWindow != null)
                  _UsageBadge(
                    label: 'ctx ${summary.contextWindow!}',
                    color: accent,
                    tinted: true,
                  ),
              ],
            ),
            if (summary.sections.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (var index = 0; index < summary.sections.length; index += 1) ...[
                if (index > 0) const SizedBox(height: 5),
                _UsageSectionWrap(
                  section: summary.sections[index],
                  accent: accent,
                  cards: cards,
                ),
              ],
            ] else if (block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                block.body.trim(),
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageSectionWrap extends StatelessWidget {
  const _UsageSectionWrap({
    required this.section,
    required this.accent,
    required this.cards,
  });

  final _UsageSection section;
  final Color accent;
  final _ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (section.label != null)
          _UsageBadge(label: section.label!, color: accent, tinted: true),
        for (final metric in section.metrics)
          _UsageBadge(
            label: '${metric.label} ${metric.value}',
            color: accent,
            tinted: false,
          ),
        for (final note in section.notes)
          _UsageNoteBadge(label: note, cards: cards),
      ],
    );
  }
}

class _UsageBadge extends StatelessWidget {
  const _UsageBadge({
    required this.label,
    required this.color,
    required this.tinted,
  });

  final String label;
  final Color color;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final cards = _ConversationCardPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: tinted
            ? color.withValues(alpha: cards.isDark ? 0.18 : 0.1)
            : cards.surface.withValues(alpha: cards.isDark ? 0.68 : 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tinted
              ? color.withValues(alpha: cards.isDark ? 0.42 : 0.24)
              : cards.accentBorder(
                  color,
                  lightAlpha: 0.14,
                  darkAlpha: 0.22,
                ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tinted ? color : cards.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _UsageNoteBadge extends StatelessWidget {
  const _UsageNoteBadge({required this.label, required this.cards});

  final String label;
  final _ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: cards.surface.withValues(alpha: cards.isDark ? 0.68 : 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cards.neutralBorder.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cards.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _UsagePresentation {
  const _UsagePresentation({
    required this.sections,
    this.contextWindow,
  });

  factory _UsagePresentation.fromBody(String body) {
    final sections = <_UsageSection>[];
    String? contextWindow;

    for (final rawLine in body.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final contextMatch = RegExp(
        r'^Context window:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (contextMatch != null) {
        contextWindow = contextMatch.group(1)?.trim();
        continue;
      }

      final labeledMatch = RegExp(
        r'^(Last|Total):\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (labeledMatch != null) {
        sections.add(
          _parseUsageSection(
            labeledMatch.group(2) ?? '',
            label: labeledMatch.group(1)?.toLowerCase(),
          ),
        );
        continue;
      }

      sections.add(_parseUsageSection(line));
    }

    final compactSections = sections
        .where((section) => section.metrics.isNotEmpty || section.notes.isNotEmpty)
        .toList(growable: false);

    if (compactSections.length == 2 &&
        compactSections.first.hasSameContent(compactSections.last)) {
      return _UsagePresentation(
        sections: <_UsageSection>[
          compactSections.first.copyWith(label: null),
        ],
        contextWindow: contextWindow,
      );
    }

    return _UsagePresentation(
      sections: compactSections,
      contextWindow: contextWindow,
    );
  }

  final List<_UsageSection> sections;
  final String? contextWindow;
}

class _UsageSection {
  const _UsageSection({
    required this.metrics,
    required this.notes,
    this.label,
  });

  final String? label;
  final List<_UsageMetric> metrics;
  final List<String> notes;

  _UsageSection copyWith({
    String? label,
    List<_UsageMetric>? metrics,
    List<String>? notes,
  }) {
    return _UsageSection(
      label: label,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
    );
  }

  bool hasSameContent(_UsageSection other) {
    if (metrics.length != other.metrics.length || notes.length != other.notes.length) {
      return false;
    }

    for (var index = 0; index < metrics.length; index += 1) {
      if (metrics[index] != other.metrics[index]) {
        return false;
      }
    }

    for (var index = 0; index < notes.length; index += 1) {
      if (notes[index] != other.notes[index]) {
        return false;
      }
    }

    return true;
  }
}

class _UsageMetric {
  const _UsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  bool operator ==(Object other) {
    return other is _UsageMetric &&
        other.label == label &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(label, value);
}

_UsageSection _parseUsageSection(String source, {String? label}) {
  final metrics = <_UsageMetric>[];
  final notes = <String>[];
  final recognizedMetricLabels = <String>{
    'input',
    'cached',
    'output',
    'reasoning',
    'total',
    'cost',
    'exit',
  };

  for (final rawSegment in source.split('·')) {
    final segment = rawSegment.trim();
    if (segment.isEmpty) {
      continue;
    }

    final match = RegExp(r'^([A-Za-z]+)\s+(.+)$').firstMatch(segment);
    final metricLabel = match?.group(1)?.toLowerCase();
    final metricValue = match?.group(2)?.trim();
    if (metricLabel != null &&
        metricValue != null &&
        metricValue.isNotEmpty &&
        recognizedMetricLabels.contains(metricLabel)) {
      metrics.add(_UsageMetric(label: metricLabel, value: metricValue));
      continue;
    }

    notes.add(segment);
  }

  return _UsageSection(label: label, metrics: metrics, notes: notes);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
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
    final accent = _tealAccent(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConversationCardPalette {
  const _ConversationCardPalette({
    required this.brightness,
    required this.surface,
    required this.neutralBorder,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.codeSurface,
    required this.codeText,
    required this.terminalShell,
    required this.terminalBody,
    required this.terminalText,
  });

  factory _ConversationCardPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final pocket = context.pocketPalette;
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    return _ConversationCardPalette(
      brightness: brightness,
      surface: pocket.surface,
      neutralBorder: pocket.surfaceBorder,
      shadow: pocket.shadowColor,
      textPrimary: isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917),
      textSecondary: isDark ? const Color(0xFFD6D0C5) : const Color(0xFF57534E),
      textMuted: isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
      codeSurface: isDark ? const Color(0xFF0F191B) : const Color(0xFFF0EBDE),
      codeText: isDark ? const Color(0xFFE7F3F4) : const Color(0xFF1C1917),
      terminalShell: isDark ? const Color(0xFF111B1D) : const Color(0xFF1F2937),
      terminalBody: isDark ? const Color(0xFF0A1112) : const Color(0xFF111827),
      terminalText: isDark ? const Color(0xFFE5F0F1) : const Color(0xFFE5E7EB),
    );
  }

  final Brightness brightness;
  final Color surface;
  final Color neutralBorder;
  final Color shadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color codeSurface;
  final Color codeText;
  final Color terminalShell;
  final Color terminalBody;
  final Color terminalText;

  bool get isDark => brightness == Brightness.dark;

  Color tintedSurface(
    Color accent, {
    double lightAlpha = 0.06,
    double darkAlpha = 0.14,
  }) {
    return Color.alphaBlend(
      accent.withValues(alpha: isDark ? darkAlpha : lightAlpha),
      surface,
    );
  }

  Color accentBorder(
    Color accent, {
    double lightAlpha = 0.32,
    double darkAlpha = 0.42,
  }) {
    return accent.withValues(alpha: isDark ? darkAlpha : lightAlpha);
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

_BlockPalette _paletteFor(CodexUiBlockKind kind, Brightness brightness) {
  return switch (kind) {
    CodexUiBlockKind.reasoning => _BlockPalette(
      accent: _violetAccent(brightness),
      border: _violetAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.3),
      icon: Icons.psychology_alt_outlined,
    ),
    CodexUiBlockKind.plan || CodexUiBlockKind.proposedPlan => _BlockPalette(
      accent: _blueAccent(brightness),
      border: _blueAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.28),
      icon: Icons.checklist_rtl,
    ),
    CodexUiBlockKind.fileChange ||
    CodexUiBlockKind.changedFiles => _BlockPalette(
      accent: _amberAccent(brightness),
      border: _amberAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.42 : 0.3),
      icon: Icons.drive_file_rename_outline,
    ),
    _ => _BlockPalette(
      accent: _tealAccent(brightness),
      border: _tealAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.38 : 0.24),
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

_PlanStepStatusPresentation _planStepStatus(
  CodexRuntimePlanStepStatus status,
  _ConversationCardPalette cards,
) {
  return switch (status) {
    CodexRuntimePlanStepStatus.completed => _PlanStepStatusPresentation(
      label: 'done',
      accent: _tealAccent(cards.brightness),
      border: cards.accentBorder(
        _tealAccent(cards.brightness),
        lightAlpha: 0.24,
        darkAlpha: 0.34,
      ),
      background: cards.tintedSurface(
        _tealAccent(cards.brightness),
        lightAlpha: 0.08,
        darkAlpha: 0.18,
      ),
      icon: Icons.check_circle_outline,
    ),
    CodexRuntimePlanStepStatus.inProgress => _PlanStepStatusPresentation(
      label: 'active',
      accent: _blueAccent(cards.brightness),
      border: cards.accentBorder(
        _blueAccent(cards.brightness),
        lightAlpha: 0.24,
        darkAlpha: 0.34,
      ),
      background: cards.tintedSurface(
        _blueAccent(cards.brightness),
        lightAlpha: 0.08,
        darkAlpha: 0.18,
      ),
      icon: Icons.timelapse_outlined,
    ),
    CodexRuntimePlanStepStatus.pending => _PlanStepStatusPresentation(
      label: 'pending',
      accent: _neutralAccent(cards.brightness),
      border: cards.accentBorder(
        _neutralAccent(cards.brightness),
        lightAlpha: 0.18,
        darkAlpha: 0.26,
      ),
      background: cards.tintedSurface(
        _neutralAccent(cards.brightness),
        lightAlpha: 0.04,
        darkAlpha: 0.1,
      ),
      icon: Icons.radio_button_unchecked,
    ),
  };
}

IconData _workLogIcon(CodexWorkLogEntryKind kind) {
  return switch (kind) {
    CodexWorkLogEntryKind.commandExecution => Icons.terminal,
    CodexWorkLogEntryKind.webSearch => Icons.travel_explore,
    CodexWorkLogEntryKind.imageView => Icons.image_outlined,
    CodexWorkLogEntryKind.imageGeneration => Icons.auto_awesome_outlined,
    CodexWorkLogEntryKind.mcpToolCall => Icons.extension_outlined,
    CodexWorkLogEntryKind.dynamicToolCall => Icons.build_outlined,
    CodexWorkLogEntryKind.collabAgentToolCall => Icons.groups_2_outlined,
    CodexWorkLogEntryKind.fileChange => Icons.drive_file_rename_outline,
    CodexWorkLogEntryKind.unknown => Icons.auto_awesome,
  };
}

Color _workLogAccent(CodexWorkLogEntryKind kind, Brightness brightness) {
  return switch (kind) {
    CodexWorkLogEntryKind.commandExecution => _blueAccent(brightness),
    CodexWorkLogEntryKind.webSearch => _tealAccent(brightness),
    CodexWorkLogEntryKind.imageView => _violetAccent(brightness),
    CodexWorkLogEntryKind.imageGeneration => _pinkAccent(brightness),
    CodexWorkLogEntryKind.mcpToolCall => _amberAccent(brightness),
    CodexWorkLogEntryKind.dynamicToolCall => _redAccent(brightness),
    CodexWorkLogEntryKind.collabAgentToolCall => _purpleAccent(brightness),
    CodexWorkLogEntryKind.fileChange => _amberAccent(brightness),
    CodexWorkLogEntryKind.unknown => _tealAccent(brightness),
  };
}

Color _tealAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF2DD4BF)
      : const Color(0xFF0F766E);
}

Color _blueAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF60A5FA)
      : const Color(0xFF2563EB);
}

Color _violetAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFC4B5FD)
      : const Color(0xFF7C3AED);
}

Color _pinkAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFF9A8D4)
      : const Color(0xFFDB2777);
}

Color _purpleAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFD8B4FE)
      : const Color(0xFF9333EA);
}

Color _amberAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFFBBF24)
      : const Color(0xFFB45309);
}

Color _redAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFF87171)
      : const Color(0xFFDC2626);
}

Color _neutralAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFC4BBB0)
      : const Color(0xFF78716C);
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
