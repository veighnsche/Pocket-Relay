import 'package:flutter/widgets.dart';

class ChatChromeMenuAction {
  const ChatChromeMenuAction({
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onSelected;
  final bool isDestructive;
}
