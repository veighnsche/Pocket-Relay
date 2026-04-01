import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/markdown_style_factory.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ProposedPlanSurface extends StatefulWidget {
  const ProposedPlanSurface({super.key, required this.block});

  final TranscriptProposedPlanBlock block;

  @override
  State<ProposedPlanSurface> createState() => _ProposedPlanSurfaceState();
}

class _ProposedPlanSurfaceState extends State<ProposedPlanSurface> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = TranscriptPalette.of(context);
    final accent = blueAccent(theme.brightness);
    final markdownStyle = buildPlanMarkdownStyle(
      theme: theme,
      cards: cards,
      accent: accent,
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

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.description_outlined,
        label: title,
        accent: accent,
        trailing: widget.block.isStreaming
            ? const InlinePulseChip(label: 'drafting')
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: displayedText.trim().isEmpty
                ? '_Waiting for plan…_'
                : displayedText,
            selectable: true,
            styleSheet: markdownStyle,
          ),
          if (canCollapse) ...[
            const SizedBox(height: PocketSpacing.sm),
            OutlinedButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Collapse plan' : 'Expand plan'),
            ),
          ],
        ],
      ),
    );
  }
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
