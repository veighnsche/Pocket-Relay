import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
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
      final CodexCommandExecutionBlock commandBlock => _CommandCard(
        block: commandBlock,
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
    CodexUiBlockKind.plan => const _BlockPalette(
      accent: Color(0xFF2563EB),
      border: Color(0xFFBFDBFE),
      icon: Icons.checklist_rtl,
    ),
    CodexUiBlockKind.fileChange => const _BlockPalette(
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
