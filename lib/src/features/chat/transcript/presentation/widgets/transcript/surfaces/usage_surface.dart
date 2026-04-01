import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

import 'usage_surface_presentation.dart';

class UsageSurface extends StatelessWidget {
  const UsageSurface({super.key, required this.block});

  final TranscriptUsageBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final summary = UsagePresentation.fromBody(block.body);
    final title = _displayTitle(block.title);
    final notes = _combinedNotes(summary.sections);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 1, 2, 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                if (summary.contextWindow != null)
                  Text(
                    _contextLabel(summary.contextWindow!),
                    style: TextStyle(
                      color: cards.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
              ],
            ),
            if (summary.sections.isNotEmpty) ...[
              const SizedBox(height: 4),
              _UsageTable(summary: summary, cards: cards),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  notes.join(' · '),
                  style: TextStyle(
                    color: cards.textMuted,
                    fontSize: 10.5,
                    height: 1.1,
                  ),
                ),
              ],
            ] else if (block.body.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                block.body.trim(),
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11,
                  height: 1.1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageTable extends StatelessWidget {
  const _UsageTable({required this.summary, required this.cards});

  final UsagePresentation summary;
  final TranscriptPalette cards;

  @override
  Widget build(BuildContext context) {
    const metricOrder = <String>[
      'input',
      'cached',
      'output',
      'reasoning',
      'total',
    ];

    final sections = summary.sections.toList(growable: false);

    TextStyle labelStyle(Color color, {FontWeight weight = FontWeight.w600}) {
      return TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: weight,
        height: 1.1,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
    }

    Widget cell(
      String text, {
      TextAlign align = TextAlign.center,
      required TextStyle style,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Text(text, textAlign: align, style: style, maxLines: 1),
      );
    }

    return Table(
      columnWidths: const <int, TableColumnWidth>{0: FixedColumnWidth(54)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        TableRow(
          children: <Widget>[
            cell('', align: TextAlign.left, style: labelStyle(cards.textMuted)),
            for (final metric in metricOrder)
              cell(
                _displayMetricLabel(metric),
                style: labelStyle(cards.textMuted),
              ),
          ],
        ),
        for (final section in sections)
          TableRow(
            children: <Widget>[
              cell(
                _displaySectionLabel(section.label ?? 'current'),
                align: TextAlign.left,
                style: labelStyle(cards.textSecondary, weight: FontWeight.w700),
              ),
              for (final metric in metricOrder)
                cell(
                  _cellValue(section, metric),
                  style: labelStyle(cards.textPrimary, weight: FontWeight.w700),
                ),
            ],
          ),
      ],
    );
  }
}

String _displayTitle(String title) {
  return switch (title) {
    'Thread token usage' => 'Thread usage',
    _ => title,
  };
}

String _displaySectionLabel(String label) {
  return switch (label.toLowerCase()) {
    'last' => 'current',
    'total' => 'total',
    _ => label.toLowerCase(),
  };
}

String _displayMetricLabel(String label) {
  return switch (label.toLowerCase()) {
    'input' => 'in',
    'cached' => 'cache',
    'output' => 'out',
    'reasoning' => 'rsn',
    'total' => 'all',
    _ => label.toLowerCase(),
  };
}

String _displayMetricValue(String value) {
  return _compactNumericString(value);
}

String _contextLabel(String value) {
  return 'ctx ${_compactNumericString(value)}';
}

String _compactNumericString(String value) {
  final parsed = int.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final absolute = parsed.abs();
  if (absolute < 1000) {
    return '$parsed';
  }
  if (absolute < 1000000) {
    return _compactWithUnit(parsed / 1000, 'k');
  }
  if (absolute < 1000000000) {
    return _compactWithUnit(parsed / 1000000, 'm');
  }
  return _compactWithUnit(parsed / 1000000000, 'b');
}

String _compactWithUnit(double scaled, String unit) {
  final whole = scaled.truncateToDouble();
  final display = scaled == whole
      ? scaled.toStringAsFixed(0)
      : scaled.toStringAsFixed(1);
  return '${display.replaceFirst(RegExp(r'\.0$'), '')}$unit';
}

String _cellValue(UsageSection section, String metricLabel) {
  for (final metric in section.metrics) {
    if (metric.label == metricLabel) {
      return _displayMetricValue(metric.value);
    }
  }
  return '-';
}

List<String> _combinedNotes(List<UsageSection> sections) {
  final notes = <String>[];
  for (final section in sections) {
    if (section.notes.isEmpty) {
      continue;
    }
    final prefix = section.label == null
        ? null
        : _displaySectionLabel(section.label!);
    for (final note in section.notes) {
      notes.add(prefix == null ? note : '$prefix $note');
    }
  }
  return notes;
}
