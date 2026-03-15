import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

class CupertinoChatComposerRegion extends StatelessWidget {
  const CupertinoChatComposerRegion({
    super.key,
    required this.composer,
    required this.onComposerDraftChanged,
    required this.onSendPrompt,
    required this.onStopActiveTurn,
  });

  final ChatComposerContract composer;
  final ValueChanged<String> onComposerDraftChanged;
  final Future<void> Function() onSendPrompt;
  final Future<void> Function() onStopActiveTurn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: CupertinoChatComposer(
          contract: composer,
          onChanged: onComposerDraftChanged,
          onSend: onSendPrompt,
          onStop: onStopActiveTurn,
        ),
      ),
    );
  }
}

class CupertinoChatComposer extends StatefulWidget {
  const CupertinoChatComposer({
    super.key,
    required this.contract,
    required this.onChanged,
    required this.onSend,
    required this.onStop,
  });

  final ChatComposerContract contract;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;

  @override
  State<CupertinoChatComposer> createState() => _CupertinoChatComposerState();
}

class _CupertinoChatComposerState extends State<CupertinoChatComposer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.contract.draftText);
  }

  @override
  void didUpdateWidget(covariant CupertinoChatComposer oldWidget) {
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
    final separatorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );
    final surfaceColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    ).withValues(alpha: 0.82);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
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
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _controller,
                    enabled: widget.contract.isTextInputEnabled,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    placeholder: widget.contract.placeholder,
                    onChanged: widget.onChanged,
                    padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
                    decoration: const BoxDecoration(),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child:
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
