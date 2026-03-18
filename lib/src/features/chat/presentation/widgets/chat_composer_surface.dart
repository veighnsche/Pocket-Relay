import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

enum ChatComposerVisualStyle { material, cupertino }

class ChatComposerSurface extends StatefulWidget {
  const ChatComposerSurface({
    super.key,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
    required this.style,
  });

  final ChatComposerContract contract;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;
  final ChatComposerVisualStyle style;

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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.contract.draftText);
  }

  @override
  void didUpdateWidget(covariant ChatComposerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.contract.draftText) {
      return;
    }

    _controller.value = _controller.value.copyWith(
      text: widget.contract.draftText,
      selection: TextSelection.collapsed(
        offset: widget.contract.draftText.length,
      ),
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
    return switch (widget.style) {
      ChatComposerVisualStyle.material => _buildMaterialComposer(context),
      ChatComposerVisualStyle.cupertino => _buildCupertinoComposer(context),
    };
  }

  Widget _buildMaterialComposer(BuildContext context) {
    final palette = context.pocketPalette;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: _buildContent(
        input: _wrapInputWithKeyboardSubmit(
          context,
          TextField(
            controller: _controller,
            enabled: widget.contract.isTextInputEnabled,
            minLines: 1,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.contract.placeholder,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        primaryAction:
            widget.contract.primaryAction == ChatComposerPrimaryAction.stop
            ? FilledButton.tonalIcon(
                key: const ValueKey('stop'),
                onPressed: widget.contract.isPrimaryActionEnabled
                    ? widget.onStop
                    : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
              )
            : IconButton.filled(
                key: const ValueKey('send'),
                onPressed: widget.contract.isPrimaryActionEnabled
                    ? widget.onSend
                    : null,
                icon: const Icon(Icons.send_rounded),
              ),
      ),
    );
  }

  Widget _buildCupertinoComposer(BuildContext context) {
    const surfacePadding = EdgeInsets.fromLTRB(14, 8, 10, 8);
    const inputPadding = EdgeInsets.fromLTRB(2, 6, 8, 6);
    final separatorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );
    final surfaceColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondarySystemGroupedBackground,
      context,
    ).withValues(alpha: 0.82);
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final placeholderColor = CupertinoDynamicColor.resolve(
      CupertinoColors.placeholderText,
      context,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          key: const ValueKey('cupertino_composer_surface'),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: separatorColor.withValues(alpha: 0.35)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: surfacePadding,
            child: _buildContent(
              input: _wrapInputWithKeyboardSubmit(
                context,
                CupertinoTextField(
                  controller: _controller,
                  enabled: widget.contract.isTextInputEnabled,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  placeholder: widget.contract.placeholder,
                  style: TextStyle(color: labelColor),
                  placeholderStyle: TextStyle(color: placeholderColor),
                  onChanged: widget.onChanged,
                  padding: inputPadding,
                  decoration: const BoxDecoration(),
                ),
              ),
              primaryAction:
                  widget.contract.primaryAction ==
                      ChatComposerPrimaryAction.stop
                  ? CupertinoButton.filled(
                      key: const ValueKey('stop'),
                      onPressed: widget.contract.isPrimaryActionEnabled
                          ? widget.onStop
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.stop_circle, size: 18),
                          SizedBox(width: 6),
                          Text('Stop'),
                        ],
                      ),
                    )
                  : CupertinoButton.filled(
                      key: const ValueKey('send'),
                      onPressed: widget.contract.isPrimaryActionEnabled
                          ? widget.onSend
                          : null,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        CupertinoIcons.arrow_up_circle_fill,
                        size: 22,
                      ),
                    ),
              crossAxisAlignment: CrossAxisAlignment.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required Widget input,
    required Widget primaryAction,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end,
  }) {
    return Row(
      key: const ValueKey('chat_composer_content_row'),
      crossAxisAlignment: crossAxisAlignment,
      children: [
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
    if (!_usesDesktopKeyboardSubmit(context)) {
      return input;
    }

    return Actions(
      actions: <Type, Action<Intent>>{
        _DesktopSendIntent: CallbackAction<_DesktopSendIntent>(
          onInvoke: (_) {
            if (!_canSubmitFromKeyboard) {
              return null;
            }

            unawaited(widget.onSend());
            return null;
          },
        ),
        _DesktopInsertNewlineIntent:
            CallbackAction<_DesktopInsertNewlineIntent>(
              onInvoke: (_) {
                if (!_canEditFromKeyboard) {
                  return null;
                }

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

  bool _usesDesktopKeyboardSubmit(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  bool get _canSubmitFromKeyboard {
    return widget.contract.isTextInputEnabled &&
        widget.contract.isPrimaryActionEnabled &&
        widget.contract.primaryAction == ChatComposerPrimaryAction.send;
  }

  bool get _canEditFromKeyboard => widget.contract.isTextInputEnabled;

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

    _controller.value = currentValue.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
    widget.onChanged(nextText);
  }
}
