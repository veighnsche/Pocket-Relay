import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/widgetbook/story_catalog.dart';
import 'package:widgetbook/widgetbook.dart';

class PocketRelayWidgetbook extends StatelessWidget {
  const PocketRelayWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: buildPocketRelayWidgetbookCatalog(),
      addons: <WidgetbookAddon>[
        MaterialThemeAddon(
          themes: <WidgetbookTheme<ThemeData>>[
            WidgetbookTheme<ThemeData>(
              name: 'Pocket Light',
              data: buildPocketTheme(Brightness.light),
            ),
            WidgetbookTheme<ThemeData>(
              name: 'Pocket Dark',
              data: buildPocketTheme(Brightness.dark),
            ),
          ],
        ),
        ViewportAddon(<ViewportData>[
          Viewports.none,
          IosViewports.iPhone13,
          MacosViewports.desktop,
          MacosViewports.macbookPro,
        ]),
        TextScaleAddon(initialScale: 1.0, min: 0.8, max: 1.4, divisions: 3),
      ],
      lightTheme: _buildWidgetbookShellTheme(Brightness.light),
      darkTheme: _buildWidgetbookShellTheme(Brightness.dark),
      home: const _PocketRelayWidgetbookHome(),
      header: const _PocketRelayWidgetbookHeader(),
    );
  }
}

ThemeData _buildWidgetbookShellTheme(Brightness brightness) {
  final base = buildPocketTheme(brightness);
  final palette = base.extension<PocketPalette>()!;
  final isDark = brightness == Brightness.dark;

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      surface: palette.surface,
      onSurface: isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2B2924)
          : const Color(0xFFE9E2D5),
      outline: palette.surfaceBorder,
      primary: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0F766E),
      secondary: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
    ),
    canvasColor: palette.surface,
    scaffoldBackgroundColor: palette.backgroundBottom,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      modalBackgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.surfaceBorder),
      ),
    ),
    dividerColor: palette.surfaceBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      fillColor: isDark ? const Color(0xFF454850) : const Color(0xFFE8E4DA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0F766E),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.surface,
      selectedItemColor: isDark
          ? const Color(0xFF7DD3FC)
          : const Color(0xFF0F766E),
      unselectedItemColor:
          (isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917))
              .withValues(alpha: 0.7),
      type: BottomNavigationBarType.fixed,
    ),
  );
}

class _PocketRelayWidgetbookHeader extends StatelessWidget {
  const _PocketRelayWidgetbookHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pocket Relay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Design Review Catalog',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

class _PocketRelayWidgetbookHome extends StatelessWidget {
  const _PocketRelayWidgetbookHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = WidgetbookState.of(context);
    final counts =
        '${state.root.componentsCount} components · ${state.root.useCasesCount} use cases';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: 420,
                  child: _HomePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pocket Relay Widgetbook',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A reviewable catalog for transcript components, shared primitives, and product scenes.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.76,
                            ),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _MetricPill(label: counts),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: _HomePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _ChecklistItem(
                          title: 'Foundations',
                          body:
                              'Review badges, panel surfaces, and transcript framing before feature-level states.',
                        ),
                        SizedBox(height: 16),
                        _ChecklistItem(
                          title: 'Transcript Cards',
                          body:
                              'Validate approval, plan, changed-file, work-log, and SSH variants across themes.',
                        ),
                        SizedBox(height: 16),
                        _ChecklistItem(
                          title: 'Review Scenes',
                          body:
                              'Use the mixed transcript scenes for real state-flow review instead of isolated widgets only.',
                        ),
                      ],
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

class _HomePanel extends StatelessWidget {
  const _HomePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<PocketPalette>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
