import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class UserInputRequestCard extends StatefulWidget {
  const UserInputRequestCard({super.key, required this.block, this.onSubmit});

  final CodexUserInputRequestBlock block;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmit;

  @override
  State<UserInputRequestCard> createState() => _UserInputRequestCardState();
}

class _UserInputRequestCardState extends State<UserInputRequestCard> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _syncControllersFromBlock(widget.block);
  }

  @override
  void didUpdateWidget(covariant UserInputRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.requestId == widget.block.requestId &&
        _sameFieldIds(oldWidget.block, widget.block) &&
        _sameAnswers(oldWidget.block.answers, widget.block.answers)) {
      return;
    }

    _syncControllersFromBlock(widget.block);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllersFromBlock(CodexUserInputRequestBlock block) {
    final fieldIds = _fieldIdsFor(block);

    for (final entry in _controllers.entries.toList(growable: false)) {
      if (!fieldIds.contains(entry.key)) {
        entry.value.dispose();
        _controllers.remove(entry.key);
      }
    }

    for (final fieldId in fieldIds) {
      final answerText = block.answers[fieldId]?.join(', ') ?? '';
      final controller = _controllers[fieldId];
      if (controller == null) {
        _controllers[fieldId] = TextEditingController(text: answerText);
        continue;
      }
      if (controller.text != answerText) {
        controller.value = controller.value.copyWith(
          text: answerText,
          selection: TextSelection.collapsed(offset: answerText.length),
          composing: TextRange.empty,
        );
      }
    }
  }

  Set<String> _fieldIdsFor(CodexUserInputRequestBlock block) {
    if (block.questions.isEmpty) {
      return const <String>{'response'};
    }
    return block.questions.map((question) => question.id).toSet();
  }

  bool _sameFieldIds(
    CodexUserInputRequestBlock previous,
    CodexUserInputRequestBlock next,
  ) {
    final previousIds = _fieldIdsFor(previous);
    final nextIds = _fieldIdsFor(next);
    return setEquals(previousIds, nextIds);
  }

  bool _sameAnswers(
    Map<String, List<String>> previous,
    Map<String, List<String>> next,
  ) {
    if (previous.length != next.length) {
      return false;
    }
    for (final entry in previous.entries) {
      final nextValues = next[entry.key];
      if (nextValues == null || !listEquals(entry.value, nextValues)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(Theme.of(context).brightness);
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
                  TranscriptBadge(label: 'submitted', color: accent),
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
    final cards = ConversationCardPalette.of(context);
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
