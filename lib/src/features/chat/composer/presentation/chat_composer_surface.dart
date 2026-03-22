import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';

class ChatComposerSurface extends StatefulWidget {
  const ChatComposerSurface({
    super.key,
    required this.platformBehavior,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    this.localImagePicker,
  });

  final PocketPlatformBehavior platformBehavior;
  final ChatComposerContract contract;
  final ValueChanged<ChatComposerDraft> onChanged;
  final Future<void> Function() onSend;
  final Future<String?> Function()? localImagePicker;

  @override
  State<ChatComposerSurface> createState() => _ChatComposerSurfaceState();
}

class _DesktopSendIntent extends Intent {
  const _DesktopSendIntent();
}

class _DesktopInsertNewlineIntent extends Intent {
  const _DesktopInsertNewlineIntent();
}

class _ChatComposerSurfaceState extends State<ChatComposerSurface> {
  static const _desktopSendIntent = _DesktopSendIntent();
  static const _desktopInsertNewlineIntent = _DesktopInsertNewlineIntent();
  static const _imageTypeGroup = XTypeGroup(
    label: 'images',
    extensions: <String>['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'],
  );
  late final TextEditingController _controller;
  late final _AtomicPlaceholderTextInputFormatter _placeholderFormatter;
  late ChatComposerDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.contract.draft.normalized();
    _placeholderFormatter = _AtomicPlaceholderTextInputFormatter(
      draftProvider: () => _draft,
    );
    _controller = TextEditingController(text: _draft.text);
  }

  @override
  void didUpdateWidget(covariant ChatComposerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextDraft = widget.contract.draft.normalized();
    _draft = nextDraft;
    if (_controller.text == nextDraft.text) {
      return;
    }

    _controller.value = _controller.value.copyWith(
      text: nextDraft.text,
      selection: TextSelection.collapsed(offset: nextDraft.text.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildMaterialComposer(context);
  }

  Widget _buildMaterialComposer(BuildContext context) {
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: _buildContent(
          leadingAction: _showsLocalImageAttachmentAction
              ? SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    key: const ValueKey('attach_local_image'),
                    tooltip: 'Attach image',
                    onPressed: _handleAttachLocalImageTriggered,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.image_outlined, size: 18),
                  ),
                )
              : null,
          input: _buildInputRegion(context),
          primaryAction: SizedBox(
            width: 36,
            height: 36,
            child: IconButton.filled(
              key: const ValueKey('send'),
              onPressed: _isSendActionEnabled ? _handleSendTriggered : null,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
          ),
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
      ),
    );
  }

  Widget _buildInputRegion(BuildContext context) {
    final attachmentSummaries = _draft.localImageAttachments
        .map((attachment) => attachment.summaryLabel)
        .toList(growable: false);

    return _wrapInputWithKeyboardSubmit(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('composer_input'),
            controller: _controller,
            minLines: 1,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onTapOutside: (_) => _dismissKeyboard(),
            inputFormatters: <TextInputFormatter>[_placeholderFormatter],
            onChanged: _handleChanged,
            decoration: InputDecoration(
              hintText: widget.contract.placeholder,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          if (attachmentSummaries.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...attachmentSummaries.indexed.map(
              (entry) => Padding(
                padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 4),
                child: _ComposerAttachmentSummary(label: entry.$2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent({
    Widget? leadingAction,
    required Widget input,
    required Widget primaryAction,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end,
  }) {
    return Row(
      key: const ValueKey('chat_composer_content_row'),
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (leadingAction != null) ...[leadingAction, const SizedBox(width: 8)],
        Expanded(child: input),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: primaryAction,
        ),
      ],
    );
  }

  Widget _wrapInputWithKeyboardSubmit(BuildContext context, Widget input) {
    if (!widget.platformBehavior.usesDesktopKeyboardSubmit) {
      return input;
    }

    return Actions(
      actions: <Type, Action<Intent>>{
        _DesktopSendIntent: CallbackAction<_DesktopSendIntent>(
          onInvoke: (_) {
            if (!_canSubmitFromKeyboard) {
              return null;
            }

            unawaited(_handleSendTriggered());
            return null;
          },
        ),
        _DesktopInsertNewlineIntent:
            CallbackAction<_DesktopInsertNewlineIntent>(
              onInvoke: (_) {
                _insertTextAtSelection('\n');
                return null;
              },
            ),
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter, shift: true):
              _desktopInsertNewlineIntent,
          SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
              _desktopInsertNewlineIntent,
          SingleActivator(LogicalKeyboardKey.enter): _desktopSendIntent,
          SingleActivator(LogicalKeyboardKey.numpadEnter): _desktopSendIntent,
        },
        child: input,
      ),
    );
  }

  bool get _canSubmitFromKeyboard {
    return _isSendActionEnabled;
  }

  bool get _showsLocalImageAttachmentAction {
    return widget.contract.allowsLocalImageAttachment &&
        widget.platformBehavior.supportsLocalConnectionMode;
  }

  bool get _isSendActionEnabled {
    return widget.contract.isSendActionEnabled &&
        _controller.text.trim().isNotEmpty;
  }

  void _handleChanged(String value) {
    _draft = _draft.copyWith(text: value).normalized();
    if (_controller.text != _draft.text) {
      _controller.value = _controller.value.copyWith(
        text: _draft.text,
        selection: _clampSelection(_controller.selection, _draft.text.length),
        composing: TextRange.empty,
      );
    }
    setState(() {});
    widget.onChanged(_draft);
  }

  Future<void> _handleSendTriggered() async {
    _dismissKeyboard();
    await widget.onSend();
  }

  Future<void> _handleAttachLocalImageTriggered() async {
    final imagePath = await _pickLocalImagePath();
    if (!mounted || imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    _draft = _draft.copyWith(text: _controller.text).normalized();
    final currentSelection = _controller.selection;
    final insertion = _draft.insertLocalImage(
      path: imagePath.trim(),
      selectionStart: currentSelection.start,
      selectionEnd: currentSelection.end,
    );
    _draft = insertion.draft;
    _controller.value = _controller.value.copyWith(
      text: _draft.text,
      selection: TextSelection.collapsed(offset: insertion.selectionOffset),
      composing: TextRange.empty,
    );
    setState(() {});
    widget.onChanged(_draft);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _insertTextAtSelection(String insertedText) {
    final currentValue = _controller.value;
    final currentSelection = currentValue.selection;
    final selection = currentSelection.isValid
        ? currentSelection
        : TextSelection.collapsed(offset: currentValue.text.length);
    final nextText = currentValue.text.replaceRange(
      selection.start,
      selection.end,
      insertedText,
    );
    final nextOffset = selection.start + insertedText.length;

    final proposedValue = currentValue.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
    _controller.value = _placeholderFormatter.formatEditUpdate(
      currentValue,
      proposedValue,
    );
    _draft = _draft.copyWith(text: _controller.text).normalized();
    widget.onChanged(_draft);
  }

  Future<String?> _pickLocalImagePath() async {
    if (widget.localImagePicker case final picker?) {
      return picker();
    }

    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_imageTypeGroup],
    );
    return file?.path;
  }
}

class _ComposerAttachmentSummary extends StatelessWidget {
  const _ComposerAttachmentSummary({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.image_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _AtomicPlaceholderTextInputFormatter extends TextInputFormatter {
  _AtomicPlaceholderTextInputFormatter({required this.draftProvider});

  final ChatComposerDraft Function() draftProvider;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    final placeholderSpans = draftProvider().normalized().placeholderSpans();
    if (placeholderSpans.isEmpty) {
      return newValue;
    }

    final editDelta = _TextEditDelta.fromValues(oldValue.text, newValue.text);
    if (editDelta.isInsertionOnly) {
      final containingSpan = placeholderSpans.where(
        (span) => span.containsOffset(editDelta.oldStart),
      );
      if (containingSpan.isNotEmpty) {
        final span = containingSpan.first;
        final adjustedText = oldValue.text.replaceRange(
          span.end,
          span.end,
          editDelta.insertedText,
        );
        final nextOffset = span.end + editDelta.insertedText.length;
        return newValue.copyWith(
          text: adjustedText,
          selection: TextSelection.collapsed(offset: nextOffset),
          composing: TextRange.empty,
        );
      }
      return newValue;
    }

    final intersectedSpans = placeholderSpans
        .where(
          (span) => _rangesIntersect(
            editDelta.oldStart,
            editDelta.oldEnd,
            span.start,
            span.end,
          ),
        )
        .toList(growable: false);
    if (intersectedSpans.isEmpty) {
      return newValue;
    }

    final expandedStart = intersectedSpans.first.start < editDelta.oldStart
        ? intersectedSpans.first.start
        : editDelta.oldStart;
    final expandedEnd = intersectedSpans.last.end > editDelta.oldEnd
        ? intersectedSpans.last.end
        : editDelta.oldEnd;
    final adjustedText = oldValue.text.replaceRange(
      expandedStart,
      expandedEnd,
      editDelta.insertedText,
    );
    final nextOffset = expandedStart + editDelta.insertedText.length;
    return newValue.copyWith(
      text: adjustedText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }
}

class _TextEditDelta {
  const _TextEditDelta({
    required this.oldStart,
    required this.oldEnd,
    required this.insertedText,
  });

  factory _TextEditDelta.fromValues(String oldText, String newText) {
    var prefixLength = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefixLength < minLength &&
        oldText.codeUnitAt(prefixLength) == newText.codeUnitAt(prefixLength)) {
      prefixLength += 1;
    }

    var oldSuffixStart = oldText.length;
    var newSuffixStart = newText.length;
    while (oldSuffixStart > prefixLength &&
        newSuffixStart > prefixLength &&
        oldText.codeUnitAt(oldSuffixStart - 1) ==
            newText.codeUnitAt(newSuffixStart - 1)) {
      oldSuffixStart -= 1;
      newSuffixStart -= 1;
    }

    return _TextEditDelta(
      oldStart: prefixLength,
      oldEnd: oldSuffixStart,
      insertedText: newText.substring(prefixLength, newSuffixStart),
    );
  }

  final int oldStart;
  final int oldEnd;
  final String insertedText;

  bool get isInsertionOnly => oldStart == oldEnd && insertedText.isNotEmpty;
}

TextSelection _clampSelection(TextSelection selection, int textLength) {
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: textLength);
  }

  final baseOffset = selection.baseOffset.clamp(0, textLength);
  final extentOffset = selection.extentOffset.clamp(0, textLength);
  return TextSelection(
    baseOffset: baseOffset,
    extentOffset: extentOffset,
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}

bool _rangesIntersect(
  int leftStart,
  int leftEnd,
  int rightStart,
  int rightEnd,
) {
  return leftStart < rightEnd && rightStart < leftEnd;
}
