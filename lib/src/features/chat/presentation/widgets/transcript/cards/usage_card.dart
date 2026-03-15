import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.block});

  final CodexUsageBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
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
  final ConversationCardPalette cards;

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

class UsagePresentation {
  const UsagePresentation({required this.sections, this.contextWindow});

  factory UsagePresentation.fromBody(String body) {
    final sections = <UsageSection>[];
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
        .where(
          (section) => section.metrics.isNotEmpty || section.notes.isNotEmpty,
        )
        .toList(growable: false);

    return UsagePresentation(
      sections: compactSections,
      contextWindow: contextWindow,
    );
  }

  final List<UsageSection> sections;
  final String? contextWindow;
}

class UsageSection {
  const UsageSection({required this.metrics, required this.notes, this.label});

  final String? label;
  final List<UsageMetric> metrics;
  final List<String> notes;

  UsageSection copyWith({
    String? label,
    List<UsageMetric>? metrics,
    List<String>? notes,
  }) {
    return UsageSection(
      label: label ?? this.label,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
    );
  }

  bool hasSameContent(UsageSection other) {
    if (metrics.length != other.metrics.length ||
        notes.length != other.notes.length) {
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

  String? metricValue(String metricLabel) {
    for (final metric in metrics) {
      if (metric.label == metricLabel) {
        return metric.value;
      }
    }
    return null;
  }

  int? metricIntValue(String metricLabel) {
    return int.tryParse(metricValue(metricLabel) ?? '');
  }
}

class UsageMetric {
  const UsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  bool operator ==(Object other) {
    return other is UsageMetric && other.label == label && other.value == value;
  }

  @override
  int get hashCode => Object.hash(label, value);
}

UsageSection _parseUsageSection(String source, {String? label}) {
  final metrics = <UsageMetric>[];
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
      metrics.add(UsageMetric(label: metricLabel, value: metricValue));
      continue;
    }

    notes.add(segment);
  }

  return _normalizeUsageSection(
    UsageSection(label: label, metrics: metrics, notes: notes),
  );
}

UsageSection _normalizeUsageSection(UsageSection section) {
  final input = section.metricIntValue('input');
  final cached = section.metricIntValue('cached') ?? 0;
  final output = section.metricIntValue('output');
  final reasoning = section.metricIntValue('reasoning') ?? 0;

  final hasTokenBreakdown =
      input != null ||
      output != null ||
      cached > 0 ||
      reasoning > 0;
  if (!hasTokenBreakdown) {
    return section;
  }

  final normalizedInput = input == null
      ? null
      : ((input - cached) < 0 ? 0 : (input - cached));
  final normalizedOutput = output == null
      ? null
      : ((output - reasoning) < 0 ? 0 : (output - reasoning));
  final normalizedReasoning = output == null
      ? (reasoning > 0 ? reasoning : null)
      : (reasoning > 0 ? reasoning : 0);
  final blendedTotal =
      (normalizedInput ?? 0) + (normalizedOutput ?? 0) + (normalizedReasoning ?? 0);

  final normalizedMetrics = <UsageMetric>[
    if (normalizedInput != null)
      UsageMetric(label: 'input', value: '$normalizedInput'),
    if (cached > 0) UsageMetric(label: 'cached', value: '$cached'),
    if (normalizedOutput != null)
      UsageMetric(label: 'output', value: '$normalizedOutput'),
    if (normalizedReasoning != null && normalizedReasoning > 0)
      UsageMetric(label: 'reasoning', value: '$normalizedReasoning'),
    if (normalizedInput != null ||
        normalizedOutput != null ||
        normalizedReasoning != null)
      UsageMetric(label: 'total', value: '$blendedTotal'),
  ];

  return section.copyWith(metrics: normalizedMetrics);
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
