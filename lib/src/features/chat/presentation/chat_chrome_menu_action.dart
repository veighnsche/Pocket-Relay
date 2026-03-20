import 'package:flutter/widgets.dart';

class ChatChromeMenuAction {
  const ChatChromeMenuAction({
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
    this.isEnabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final bool isDestructive;
  final bool isEnabled;
}
