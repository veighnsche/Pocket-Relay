import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

class TranscriptPalette {
  const TranscriptPalette({
    required this.brightness,
    required this.surface,
    required this.neutralBorder,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.codeSurface,
    required this.codeBorder,
    required this.codeText,
    required this.terminalShell,
    required this.terminalBody,
    required this.terminalText,
  });

  factory TranscriptPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final pocket = context.pocketPalette;
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    return TranscriptPalette(
      brightness: brightness,
      surface: pocket.surface,
      neutralBorder: pocket.surfaceBorder,
      shadow: pocket.shadowColor,
      textPrimary: isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917),
      textSecondary: isDark ? const Color(0xFFD6D0C5) : const Color(0xFF57534E),
      textMuted: isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
      codeSurface: isDark ? const Color(0xFF0A1314) : const Color(0xFFE8E0CF),
      codeBorder: isDark ? const Color(0xFF274043) : const Color(0xFFD0C2A6),
      codeText: isDark ? const Color(0xFFE7F3F4) : const Color(0xFF1C1917),
      terminalShell: isDark ? const Color(0xFF111B1D) : const Color(0xFF1F2937),
      terminalBody: isDark ? const Color(0xFF0A1112) : const Color(0xFF111827),
      terminalText: isDark ? const Color(0xFFE5F0F1) : const Color(0xFFE5E7EB),
    );
  }

  final Brightness brightness;
  final Color surface;
  final Color neutralBorder;
  final Color shadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color codeSurface;
  final Color codeBorder;
  final Color codeText;
  final Color terminalShell;
  final Color terminalBody;
  final Color terminalText;

  bool get isDark => brightness == Brightness.dark;

  Color tintedSurface(
    Color accent, {
    double lightAlpha = 0.06,
    double darkAlpha = 0.14,
  }) {
    return Color.alphaBlend(
      accent.withValues(alpha: isDark ? darkAlpha : lightAlpha),
      surface,
    );
  }

  Color accentBorder(
    Color accent, {
    double lightAlpha = 0.32,
    double darkAlpha = 0.42,
  }) {
    return accent.withValues(alpha: isDark ? darkAlpha : lightAlpha);
  }
}

class BlockPalette {
  const BlockPalette({
    required this.accent,
    required this.border,
    required this.icon,
  });

  final Color accent;
  final Color border;
  final IconData icon;
}

BlockPalette paletteFor(TranscriptUiBlockKind kind, Brightness brightness) {
  return switch (kind) {
    TranscriptUiBlockKind.reasoning => BlockPalette(
      accent: violetAccent(brightness),
      border: violetAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.3),
      icon: Icons.psychology_alt_outlined,
    ),
    TranscriptUiBlockKind.plan ||
    TranscriptUiBlockKind.proposedPlan => BlockPalette(
      accent: blueAccent(brightness),
      border: blueAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.28),
      icon: Icons.checklist_rtl,
    ),
    TranscriptUiBlockKind.changedFiles => BlockPalette(
      accent: amberAccent(brightness),
      border: amberAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.42 : 0.3),
      icon: Icons.drive_file_rename_outline,
    ),
    _ => BlockPalette(
      accent: tealAccent(brightness),
      border: tealAccent(
        brightness,
      ).withValues(alpha: brightness == Brightness.dark ? 0.38 : 0.24),
      icon: Icons.auto_awesome,
    ),
  };
}

class PlanStepStatusPresentation {
  const PlanStepStatusPresentation({
    required this.label,
    required this.accent,
    required this.border,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color accent;
  final Color border;
  final Color background;
  final IconData icon;
}

PlanStepStatusPresentation planStepStatus(
  TranscriptRuntimePlanStepStatus status,
  TranscriptPalette cards,
) {
  return switch (status) {
    TranscriptRuntimePlanStepStatus.completed => PlanStepStatusPresentation(
      label: 'done',
      accent: tealAccent(cards.brightness),
      border: cards.accentBorder(
        tealAccent(cards.brightness),
        lightAlpha: 0.24,
        darkAlpha: 0.34,
      ),
      background: cards.tintedSurface(
        tealAccent(cards.brightness),
        lightAlpha: 0.08,
        darkAlpha: 0.18,
      ),
      icon: Icons.check_circle_outline,
    ),
    TranscriptRuntimePlanStepStatus.inProgress => PlanStepStatusPresentation(
      label: 'active',
      accent: blueAccent(cards.brightness),
      border: cards.accentBorder(
        blueAccent(cards.brightness),
        lightAlpha: 0.24,
        darkAlpha: 0.34,
      ),
      background: cards.tintedSurface(
        blueAccent(cards.brightness),
        lightAlpha: 0.08,
        darkAlpha: 0.18,
      ),
      icon: Icons.timelapse_outlined,
    ),
    TranscriptRuntimePlanStepStatus.pending => PlanStepStatusPresentation(
      label: 'pending',
      accent: neutralAccent(cards.brightness),
      border: cards.accentBorder(
        neutralAccent(cards.brightness),
        lightAlpha: 0.18,
        darkAlpha: 0.26,
      ),
      background: cards.tintedSurface(
        neutralAccent(cards.brightness),
        lightAlpha: 0.04,
        darkAlpha: 0.1,
      ),
      icon: Icons.radio_button_unchecked,
    ),
  };
}

IconData workLogIcon(TranscriptWorkLogEntryKind kind) {
  return switch (kind) {
    TranscriptWorkLogEntryKind.commandExecution => Icons.terminal,
    TranscriptWorkLogEntryKind.webSearch => Icons.travel_explore,
    TranscriptWorkLogEntryKind.imageView => Icons.image_outlined,
    TranscriptWorkLogEntryKind.imageGeneration => Icons.auto_awesome_outlined,
    TranscriptWorkLogEntryKind.mcpToolCall => Icons.extension_outlined,
    TranscriptWorkLogEntryKind.dynamicToolCall => Icons.build_outlined,
    TranscriptWorkLogEntryKind.collabAgentToolCall => Icons.groups_2_outlined,
    TranscriptWorkLogEntryKind.unknown => Icons.auto_awesome,
  };
}

Color workLogAccent(TranscriptWorkLogEntryKind kind, Brightness brightness) {
  return switch (kind) {
    TranscriptWorkLogEntryKind.commandExecution => blueAccent(brightness),
    TranscriptWorkLogEntryKind.webSearch => tealAccent(brightness),
    TranscriptWorkLogEntryKind.imageView => violetAccent(brightness),
    TranscriptWorkLogEntryKind.imageGeneration => pinkAccent(brightness),
    TranscriptWorkLogEntryKind.mcpToolCall => amberAccent(brightness),
    TranscriptWorkLogEntryKind.dynamicToolCall => redAccent(brightness),
    TranscriptWorkLogEntryKind.collabAgentToolCall => purpleAccent(brightness),
    TranscriptWorkLogEntryKind.unknown => tealAccent(brightness),
  };
}

Color tealAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF2DD4BF)
      : const Color(0xFF0F766E);
}

Color blueAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF60A5FA)
      : const Color(0xFF2563EB);
}

Color violetAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFC4B5FD)
      : const Color(0xFF7C3AED);
}

Color pinkAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFF9A8D4)
      : const Color(0xFFDB2777);
}

Color purpleAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFD8B4FE)
      : const Color(0xFF9333EA);
}

Color amberAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFFBBF24)
      : const Color(0xFFB45309);
}

Color redAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFF87171)
      : const Color(0xFFDC2626);
}

Color neutralAccent(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFC4BBB0)
      : const Color(0xFF78716C);
}
