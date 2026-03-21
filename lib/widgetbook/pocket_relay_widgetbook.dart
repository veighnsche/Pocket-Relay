import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/widgetbook/story_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetbook/widgetbook.dart' as wb;

class PocketRelayWidgetbook extends StatefulWidget {
  const PocketRelayWidgetbook({super.key});

  @override
  State<PocketRelayWidgetbook> createState() => _PocketRelayWidgetbookState();
}

class _PocketRelayWidgetbookState extends State<PocketRelayWidgetbook> {
  String? _initialRoute;

  @override
  void initState() {
    super.initState();
    _loadInitialRoute();
  }

  Future<void> _loadInitialRoute() async {
    final initialRoute = await _resolveInitialRoute();
    if (!mounted) {
      return;
    }

    setState(() {
      _initialRoute = initialRoute;
    });
  }

  Future<String> _resolveInitialRoute() async {
    final baseUri = Uri.base.fragment.isNotEmpty
        ? Uri.parse(Uri.base.fragment)
        : Uri.parse('/');

    final routeTheme = _decodeThemeSelection(baseUri.queryParameters['theme']);
    if (routeTheme != null) {
      return baseUri.toString();
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final savedTheme = preferences.getString(
        _WidgetbookThemePersistence.preferenceKey,
      );
      if (savedTheme == null || savedTheme.isEmpty) {
        return baseUri.toString();
      }

      return baseUri
          .replace(
            queryParameters: <String, String>{
              ...baseUri.queryParameters,
              'theme': _encodeThemeSelection(savedTheme),
            },
          )
          .toString();
    } catch (_) {
      return baseUri.toString();
    }
  }

  List<wb.WidgetbookAddon> get _addons => <wb.WidgetbookAddon>[
    wb.MaterialThemeAddon(
      themes: <wb.WidgetbookTheme<ThemeData>>[
        wb.WidgetbookTheme<ThemeData>(
          name: 'Pocket Light',
          data: buildPocketTheme(Brightness.light),
        ),
        wb.WidgetbookTheme<ThemeData>(
          name: 'Pocket Dark',
          data: buildPocketTheme(Brightness.dark),
        ),
      ],
    ),
    wb.ViewportAddon(<wb.ViewportData>[
      wb.Viewports.none,
      wb.IosViewports.iPhone13,
      wb.MacosViewports.desktop,
      wb.MacosViewports.macbookPro,
    ]),
    wb.TextScaleAddon(initialScale: 1.0, min: 0.8, max: 1.4, divisions: 3),
  ];

  @override
  Widget build(BuildContext context) {
    if (_initialRoute == null) {
      return MaterialApp(
        title: 'Pocket Relay Widgetbook',
        themeMode: ThemeMode.system,
        theme: _buildWidgetbookShellTheme(Brightness.light),
        darkTheme: _buildWidgetbookShellTheme(Brightness.dark),
        debugShowCheckedModeBanner: false,
        home: const SizedBox.shrink(),
      );
    }

    return wb.Widgetbook.material(
      initialRoute: _initialRoute!,
      directories: buildPocketRelayWidgetbookCatalog(),
      addons: _addons,
      home: const _PocketRelayWidgetbookHome(),
      appBuilder: (context, child) => wb.materialAppBuilder(
        context,
        _WidgetbookThemePersistence(child: child),
      ),
      lightTheme: _buildWidgetbookShellTheme(Brightness.light),
      darkTheme: _buildWidgetbookShellTheme(Brightness.dark),
      themeMode: ThemeMode.system,
    );
  }
}

class _WidgetbookThemePersistence extends StatefulWidget {
  const _WidgetbookThemePersistence({required this.child});

  final Widget child;

  static const String preferenceKey = 'widgetbook.selected_theme';

  @override
  State<_WidgetbookThemePersistence> createState() =>
      _WidgetbookThemePersistenceState();
}

class _WidgetbookThemePersistenceState
    extends State<_WidgetbookThemePersistence> {
  wb.WidgetbookState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextState = wb.WidgetbookState.of(context);
    if (identical(nextState, _state)) {
      return;
    }

    _state?.removeListener(_persistThemeSelection);
    _state = nextState;
    _state?.addListener(_persistThemeSelection);
  }

  @override
  void dispose() {
    _state?.removeListener(_persistThemeSelection);
    super.dispose();
  }

  Future<void> _persistThemeSelection() async {
    final encodedTheme = _state?.queryParams['theme'];
    final selectedTheme = _decodeThemeSelection(encodedTheme);
    if (selectedTheme == null || selectedTheme.isEmpty) {
      return;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _WidgetbookThemePersistence.preferenceKey,
        selectedTheme,
      );
    } catch (_) {
      // Persistence failure should not affect the catalog.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PocketRelayWidgetbookHome extends StatelessWidget {
  const _PocketRelayWidgetbookHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<PocketPalette>()!;
    final textTheme = theme.textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.surfaceBorder),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.shadowColor.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pocket Relay Widgetbook',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preview real app-owned surfaces and backend-driven states.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _HomeBullet(
                    title: 'Browse from Navigation',
                    body:
                        'Select a transcript card, settings surface, or workspace preview from the left panel.',
                  ),
                  const SizedBox(height: 12),
                  _HomeBullet(
                    title: 'Compare with Addons',
                    body:
                        'Use theme, viewport, and text-scale controls without changing the underlying app widget.',
                  ),
                  const SizedBox(height: 12),
                  _HomeBullet(
                    title: 'Stay Runtime-Literal',
                    body:
                        'This catalog should only reflect real Pocket Relay surfaces, not preview-only inventions.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBullet extends StatelessWidget {
  const _HomeBullet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

ThemeData _buildWidgetbookShellTheme(Brightness brightness) {
  final base = buildPocketTheme(brightness);
  final palette = base.extension<PocketPalette>()!;
  final isDark = brightness == Brightness.dark;
  final solidSurface = palette.surface;

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      surface: solidSurface,
      onSurface: isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2B2924)
          : const Color(0xFFE9E2D5),
      outline: palette.surfaceBorder,
      primary: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0F766E),
      secondary: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
    ),
    canvasColor: solidSurface,
    scaffoldBackgroundColor: palette.backgroundBottom,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: solidSurface,
      modalBackgroundColor: solidSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: solidSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    cardTheme: CardThemeData(
      color: solidSurface,
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
      backgroundColor: solidSurface,
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

String _encodeThemeSelection(String themeName) {
  final encodedName = Uri.encodeComponent(themeName);
  return '{name:$encodedName}';
}

String? _decodeThemeSelection(String? encodedTheme) {
  if (encodedTheme == null ||
      encodedTheme.isEmpty ||
      !encodedTheme.startsWith('{name:') ||
      !encodedTheme.endsWith('}')) {
    return null;
  }

  final value = encodedTheme.substring(
    '{name:'.length,
    encodedTheme.length - 1,
  );
  return Uri.decodeComponent(value);
}
