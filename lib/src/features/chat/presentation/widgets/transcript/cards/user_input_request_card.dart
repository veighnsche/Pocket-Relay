import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class UserInputRequestCard extends StatefulWidget {
  const UserInputRequestCard({
    super.key,
    required this.contract,
    this.onFieldChanged,
    this.onSubmit,
  });

  final PendingUserInputContract contract;
  final void Function(String fieldId, String value)? onFieldChanged;
  final Future<void> Function()? onSubmit;

  @override
  State<UserInputRequestCard> createState() => _UserInputRequestCardState();
}

class _UserInputRequestCardState extends State<UserInputRequestCard> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _syncControllersFromContract(widget.contract);
  }

  @override
  void didUpdateWidget(covariant UserInputRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromContract(widget.contract);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllersFromContract(PendingUserInputContract contract) {
    final fieldIds = contract.fields.map((field) => field.id).toSet();

    for (final entry in _controllers.entries.toList(growable: false)) {
      if (fieldIds.contains(entry.key)) {
        continue;
      }
      entry.value.dispose();
      _controllers.remove(entry.key);
    }

    for (final field in contract.fields) {
      final controller = _controllers[field.id];
      if (controller == null) {
        _controllers[field.id] = TextEditingController(text: field.value);
        continue;
      }
      if (controller.text == field.value) {
        continue;
      }
      controller.value = controller.value.copyWith(
        text: field.value,
        selection: TextSelection.collapsed(offset: field.value.length),
        composing: TextRange.empty,
      );
    }
  }

  void _applyFieldValue(String fieldId, String value) {
    final controller = _controllers[fieldId];
    if (controller == null) {
      return;
    }

    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
    widget.onFieldChanged?.call(fieldId, value);
  }

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(Theme.of(context).brightness);
    final canSubmit =
        widget.contract.isSubmitEnabled && widget.onSubmit != null;

    return PocketTranscriptFrame(
      maxWidth: 680,
      shadowColor: cards.shadow,
      boxShadow: const <BoxShadow>[],
      backgroundColor: cards.tintedSurface(
        accent,
        lightAlpha: 0.06,
        darkAlpha: 0.14,
      ),
      borderColor: cards.accentBorder(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 16, color: accent),
              const SizedBox(width: PocketSpacing.xs),
              Expanded(
                child: Text(
                  widget.contract.title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.contract.statusBadgeLabel case final badgeLabel?)
                TranscriptBadge(label: badgeLabel, color: accent),
            ],
          ),
          if (widget.contract.body.trim().isNotEmpty) ...[
            const SizedBox(height: PocketSpacing.xs),
            SelectableText(
              widget.contract.body,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 13,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: PocketSpacing.md),
          ..._buildFields(),
          if (!widget.contract.isResolved) ...[
            const SizedBox(height: PocketSpacing.sm),
            FilledButton(
              onPressed: canSubmit ? widget.onSubmit : null,
              child: Text(widget.contract.submitLabel),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFields() {
    final cards = ConversationCardPalette.of(context);

    return widget.contract.fields
        .map((field) {
          final controller = _controllers[field.id]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: PocketSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (field.header case final header?) ...[
                  Text(
                    header,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cards.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: PocketSpacing.xxs),
                ],
                if (field.prompt case final prompt?) ...[
                  Text(
                    prompt,
                    style: TextStyle(
                      color: cards.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
                if (field.options.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: PocketSpacing.xs,
                    runSpacing: PocketSpacing.xs,
                    children: field.options
                        .map(
                          (option) => ActionChip(
                            label: Text(option.label),
                            onPressed: field.isReadOnly
                                ? null
                                : () =>
                                      _applyFieldValue(field.id, option.label),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: PocketSpacing.xs),
                TextField(
                  key: ValueKey<String>('pending_user_input_${field.id}'),
                  controller: controller,
                  obscureText: field.isSecret,
                  readOnly: field.isReadOnly,
                  minLines: field.minLines,
                  maxLines: field.maxLines,
                  onChanged: field.isReadOnly
                      ? null
                      : (value) => widget.onFieldChanged?.call(field.id, value),
                  decoration: InputDecoration(
                    labelText: field.inputLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          );
        })
        .toList(growable: false);
  }
}
