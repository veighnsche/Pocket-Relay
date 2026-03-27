import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/core/theme/pocket_typography.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

MarkdownStyleSheet buildConversationMarkdownStyle({
  required ThemeData theme,
  required TranscriptPalette cards,
  required Color accent,
  bool isAssistant = false,
}) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 16 : 14,
      height: isAssistant ? 1.45 : 1.38,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: _codeBlockDecoration(cards),
    blockquoteDecoration: BoxDecoration(
      color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
      borderRadius: BorderRadius.circular(12),
    ),
    h1: theme.textTheme.headlineSmall?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 21 : 19,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 18 : 16,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      color: cards.textPrimary,
      fontSize: isAssistant ? 16 : 15,
    ),
    code: _codeTextStyle(
      theme.textTheme.bodyMedium,
      cards: cards,
      fontSize: isAssistant ? 14 : 13,
    ),
  );
}

MarkdownStyleSheet buildPlanMarkdownStyle({
  required ThemeData theme,
  required TranscriptPalette cards,
  required Color accent,
}) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(
      color: cards.textPrimary,
      fontSize: 14,
      height: 1.38,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: _codeBlockDecoration(cards),
    blockquoteDecoration: BoxDecoration(
      color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
      borderRadius: BorderRadius.circular(12),
    ),
    code: _codeTextStyle(
      theme.textTheme.bodyMedium,
      cards: cards,
      fontSize: 13,
    ),
  );
}

TextStyle? _codeTextStyle(
  TextStyle? base, {
  required TranscriptPalette cards,
  required double fontSize,
}) {
  return PocketTypography.monospaceStyle(
    base: base,
    color: cards.codeText,
    fontSize: fontSize,
    height: 1.45,
    letterSpacing: 0,
    backgroundColor: cards.codeSurface,
  );
}

BoxDecoration _codeBlockDecoration(TranscriptPalette cards) {
  return BoxDecoration(
    color: cards.codeSurface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: cards.codeBorder),
  );
}
